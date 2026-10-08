#!/usr/bin/env python3
"""Private HTTP service for validating and normalizing MP3 audio."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import hmac
import json
import math
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import re
import shutil
import subprocess
import tempfile
import threading
from pathlib import Path
from typing import Any


NORMALIZER_REVISION = "lufs-v1"
TARGET_LUFS = -22.0
FILTER_TRUE_PEAK_DBTP = -1.5
MAX_FINAL_TRUE_PEAK_DBTP = -1.0
LOUDNESS_TOLERANCE_LU = 1.0
MAX_BODY_BYTES_DEFAULT = 10 * 1024 * 1024
MAX_DURATION_SECONDS = 600.0
MAX_CONCURRENT_JOBS_DEFAULT = 2
PROCESS_TIMEOUT_SECONDS_DEFAULT = 45
MP3_SIGNATURES = (b"ID3", b"\xff\xfb", b"\xff\xf3", b"\xff\xf2")


class NormalizerError(Exception):
    def __init__(self, code: str, status: int = 422) -> None:
        super().__init__(code)
        self.code = code
        self.status = status


@dataclass(frozen=True)
class NormalizerConfig:
    token: str
    max_body_bytes: int = MAX_BODY_BYTES_DEFAULT
    process_timeout_seconds: int = PROCESS_TIMEOUT_SECONDS_DEFAULT
    max_concurrent_jobs: int = MAX_CONCURRENT_JOBS_DEFAULT
    ffmpeg: str = "ffmpeg"
    ffprobe: str = "ffprobe"


def is_likely_mp3(audio: bytes) -> bool:
    return any(audio.startswith(signature) for signature in MP3_SIGNATURES)


def _run(
    command: list[str],
    timeout_seconds: int,
    *,
    capture_stdout: bool = False,
) -> subprocess.CompletedProcess[bytes]:
    try:
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE if capture_stdout else subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=timeout_seconds,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise NormalizerError("normalization_timeout", 504) from error
    except OSError as error:
        raise NormalizerError("audio_processor_unavailable", 503) from error
    if result.returncode != 0:
        raise NormalizerError("audio_processing_failed")
    return result


def _parse_loudnorm(stderr: bytes) -> dict[str, Any]:
    decoded = stderr.decode("utf-8", errors="replace")
    candidates = re.findall(r"\{[^{}]*\}", decoded)
    for candidate in reversed(candidates):
        if '"input_i"' not in candidate:
            continue
        try:
            parsed = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(parsed, dict):
            return parsed
    raise NormalizerError("audio_measurement_unavailable")


def _metric(values: dict[str, Any], key: str) -> float:
    try:
        value = float(values[key])
    except (KeyError, TypeError, ValueError) as error:
        raise NormalizerError("audio_measurement_unavailable") from error
    if not math.isfinite(value):
        raise NormalizerError("audio_measurement_invalid")
    return value


def _measure(
    input_path: Path,
    config: NormalizerConfig,
) -> dict[str, Any]:
    result = _run(
        [
            config.ffmpeg,
            "-hide_banner",
            "-nostats",
            "-i",
            str(input_path),
            "-map",
            "0:a:0",
            "-af",
            "loudnorm=I=-22:TP=-1.5:LRA=11:print_format=json",
            "-f",
            "null",
            "-",
        ],
        config.process_timeout_seconds,
    )
    return _parse_loudnorm(result.stderr)


def _render(
    input_path: Path,
    output_path: Path,
    measured: dict[str, Any],
    config: NormalizerConfig,
    linear: bool,
) -> dict[str, Any]:
    measured_args = (
        f"measured_I={_metric(measured, 'input_i')}:"
        f"measured_TP={_metric(measured, 'input_tp')}:"
        f"measured_LRA={_metric(measured, 'input_lra')}:"
        f"measured_thresh={_metric(measured, 'input_thresh')}:"
        f"offset={_metric(measured, 'target_offset')}"
    )
    loudnorm_filter = (
        f"loudnorm=I={TARGET_LUFS}:TP={FILTER_TRUE_PEAK_DBTP}:LRA=11:"
        f"{measured_args}:linear={'true' if linear else 'false'}:"
        "print_format=json"
    )
    result = _run(
        [
            config.ffmpeg,
            "-hide_banner",
            "-nostats",
            "-i",
            str(input_path),
            "-map",
            "0:a:0",
            "-map_metadata",
            "-1",
            "-af",
            loudnorm_filter,
            "-ar",
            "24000",
            "-ac",
            "1",
            "-c:a",
            "libmp3lame",
            "-b:a",
            "160k",
            "-y",
            str(output_path),
        ],
        config.process_timeout_seconds,
    )
    return _parse_loudnorm(result.stderr)


def _probe(path: Path, config: NormalizerConfig) -> tuple[float, int]:
    result = _run(
        [
            config.ffprobe,
            "-v",
            "error",
            "-select_streams",
            "a:0",
            "-show_entries",
            "stream=codec_name,sample_rate,channels",
            "-show_entries",
            "format=duration",
            "-of",
            "json",
            str(path),
        ],
        config.process_timeout_seconds,
        capture_stdout=True,
    )
    try:
        data = json.loads(result.stdout)
        stream = data["streams"][0]
        duration = float(data["format"]["duration"])
        sample_rate = int(stream["sample_rate"])
        channels = int(stream["channels"])
        codec = stream["codec_name"]
    except (IndexError, KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise NormalizerError("audio_probe_invalid") from error
    if (
        codec != "mp3"
        or sample_rate != 24000
        or channels != 1
        or not math.isfinite(duration)
        or duration <= 0
        or duration > MAX_DURATION_SECONDS
    ):
        raise NormalizerError("audio_format_invalid")
    return duration, sample_rate


def normalize_mp3(
    source: bytes,
    config: NormalizerConfig,
) -> tuple[bytes, dict[str, Any]]:
    if not is_likely_mp3(source):
        raise NormalizerError("audio_input_invalid", 415)
    with tempfile.TemporaryDirectory(prefix="selah-normalize-") as directory:
        root = Path(directory)
        source_path = root / "source.mp3"
        output_path = root / "normalized.mp3"
        source_path.write_bytes(source)

        measured = _measure(source_path, config)
        _metric(measured, "input_i")
        _metric(measured, "input_tp")
        _metric(measured, "input_lra")
        _metric(measured, "input_thresh")
        _metric(measured, "target_offset")

        rendered = _render(
            source_path,
            output_path,
            measured,
            config,
            linear=True,
        )
        output = output_path.read_bytes()
        output_measurement = _measure(output_path, config)
        integrated_lufs = _metric(output_measurement, "input_i")
        true_peak_dbtp = _metric(output_measurement, "input_tp")
        mode = str(rendered.get("normalization_type", "")).lower()
        if mode not in {"linear", "dynamic"}:
            mode = "dynamic"

        meets_target = (
            TARGET_LUFS - LOUDNESS_TOLERANCE_LU
            <= integrated_lufs
            <= TARGET_LUFS + LOUDNESS_TOLERANCE_LU
            and true_peak_dbtp <= MAX_FINAL_TRUE_PEAK_DBTP
        )
        if not meets_target and mode == "linear":
            rendered = _render(
                source_path,
                output_path,
                measured,
                config,
                linear=False,
            )
            output = output_path.read_bytes()
            output_measurement = _measure(output_path, config)
            integrated_lufs = _metric(output_measurement, "input_i")
            true_peak_dbtp = _metric(output_measurement, "input_tp")
            mode = str(rendered.get("normalization_type", "dynamic")).lower()

        if (
            not is_likely_mp3(output)
            or len(output) < 512
            or not (
                TARGET_LUFS - LOUDNESS_TOLERANCE_LU
                <= integrated_lufs
                <= TARGET_LUFS + LOUDNESS_TOLERANCE_LU
            )
            or true_peak_dbtp > MAX_FINAL_TRUE_PEAK_DBTP
        ):
            raise NormalizerError("audio_loudness_out_of_range")

        duration_seconds, sample_rate = _probe(output_path, config)
        metadata = {
            "revision": NORMALIZER_REVISION,
            "integratedLufs": integrated_lufs,
            "truePeakDbtp": true_peak_dbtp,
            "durationMs": round(duration_seconds * 1000),
            "sampleRate": sample_rate,
            "channels": 1,
            "mode": mode if mode in {"linear", "dynamic"} else "dynamic",
            "sha256": hashlib.sha256(output).hexdigest(),
        }
        return output, metadata


class NormalizerHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 16

    def __init__(self, address: tuple[str, int], config: NormalizerConfig) -> None:
        super().__init__(address, NormalizerHandler)
        self.config = config
        self.jobs = threading.BoundedSemaphore(config.max_concurrent_jobs)


class NormalizerHandler(BaseHTTPRequestHandler):
    server: NormalizerHTTPServer

    def log_message(self, format: str, *args: Any) -> None:
        return

    def _json(self, status: int, code: str) -> None:
        body = json.dumps({"error": code}, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path != "/healthz":
            self._json(404, "not_found")
            return
        body = json.dumps(
            {"status": "ok", "revision": NORMALIZER_REVISION},
            separators=(",", ":"),
        ).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:
        if self.path != "/v1/normalize":
            self._json(404, "not_found")
            return
        expected_authorization = f"Bearer {self.server.config.token}"
        actual_authorization = self.headers.get("Authorization", "")
        if not hmac.compare_digest(actual_authorization, expected_authorization):
            self._json(401, "unauthorized")
            return
        if self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "audio/mpeg":
            self._json(415, "unsupported_media_type")
            return
        if self.headers.get("Transfer-Encoding"):
            self._json(400, "transfer_encoding_unsupported")
            return
        revision = self.headers.get("X-Audio-Normalizer-Revision", "")
        if revision != NORMALIZER_REVISION:
            self._json(409, "normalizer_revision_mismatch")
            return
        expected_sha = self.headers.get("X-Audio-SHA256", "").lower()
        if not re.fullmatch(r"[a-f0-9]{64}", expected_sha):
            self._json(400, "invalid_audio_digest")
            return
        try:
            content_length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            self._json(411, "content_length_required")
            return
        if content_length < 512 or content_length > self.server.config.max_body_bytes:
            self._json(413, "audio_size_out_of_range")
            return
        if not self.server.jobs.acquire(blocking=False):
            self._json(503, "normalizer_busy")
            return
        try:
            source = self.rfile.read(content_length)
            if len(source) != content_length:
                self._json(400, "audio_body_incomplete")
                return
            if hashlib.sha256(source).hexdigest() != expected_sha:
                self._json(400, "audio_digest_mismatch")
                return
            try:
                output, metadata = normalize_mp3(source, self.server.config)
            except NormalizerError as error:
                self._json(error.status, error.code)
                return
            self.send_response(200)
            self.send_header("Content-Type", "audio/mpeg")
            self.send_header("Content-Length", str(len(output)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Audio-Normalizer-Revision", metadata["revision"])
            self.send_header("X-Audio-SHA256", metadata["sha256"])
            self.send_header(
                "X-Audio-Integrated-Lufs",
                f'{metadata["integratedLufs"]:.2f}',
            )
            self.send_header(
                "X-Audio-True-Peak-Dbtp",
                f'{metadata["truePeakDbtp"]:.2f}',
            )
            self.send_header("X-Audio-Duration-Ms", str(metadata["durationMs"]))
            self.send_header("X-Audio-Sample-Rate", str(metadata["sampleRate"]))
            self.send_header("X-Audio-Channels", str(metadata["channels"]))
            self.send_header("X-Audio-Normalization-Mode", metadata["mode"])
            self.end_headers()
            self.wfile.write(output)
        except (BrokenPipeError, ConnectionResetError):
            return
        except Exception:
            self._json(500, "normalizer_internal_error")
        finally:
            self.server.jobs.release()


def config_from_env() -> NormalizerConfig:
    token = os.environ.get("AUDIO_NORMALIZER_TOKEN", "")
    if len(token) < 32:
        raise RuntimeError("AUDIO_NORMALIZER_TOKEN must contain at least 32 characters")
    max_body_bytes = int(
        os.environ.get("AUDIO_NORMALIZER_MAX_BODY_BYTES", MAX_BODY_BYTES_DEFAULT)
    )
    process_timeout = int(
        os.environ.get(
            "AUDIO_NORMALIZER_PROCESS_TIMEOUT_SECONDS",
            PROCESS_TIMEOUT_SECONDS_DEFAULT,
        )
    )
    max_jobs = int(
        os.environ.get(
            "AUDIO_NORMALIZER_MAX_CONCURRENT_JOBS",
            MAX_CONCURRENT_JOBS_DEFAULT,
        )
    )
    if not 512 <= max_body_bytes <= MAX_BODY_BYTES_DEFAULT:
        raise RuntimeError("AUDIO_NORMALIZER_MAX_BODY_BYTES is out of range")
    if not 1 <= process_timeout <= 120:
        raise RuntimeError("AUDIO_NORMALIZER_PROCESS_TIMEOUT_SECONDS is out of range")
    if not 1 <= max_jobs <= 8:
        raise RuntimeError("AUDIO_NORMALIZER_MAX_CONCURRENT_JOBS is out of range")
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"):
        raise RuntimeError("ffmpeg and ffprobe are required")
    return NormalizerConfig(
        token=token,
        max_body_bytes=max_body_bytes,
        process_timeout_seconds=process_timeout,
        max_concurrent_jobs=max_jobs,
    )


def main() -> None:
    config = config_from_env()
    host = os.environ.get("AUDIO_NORMALIZER_BIND", "0.0.0.0")
    port = int(os.environ.get("AUDIO_NORMALIZER_PORT", "8080"))
    server = NormalizerHTTPServer((host, port), config)
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
