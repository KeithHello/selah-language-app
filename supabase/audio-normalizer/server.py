#!/usr/bin/env python3
"""Offline FFmpeg processing for bundled Azure seed audio."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import math
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any


SEED_AUDIO_REVISION = "lufs-v2"
TARGET_LUFS = -20.9
FILTER_TRUE_PEAK_DBTP = -1.5
MAX_FINAL_TRUE_PEAK_DBTP = -1.0
LOUDNESS_TOLERANCE_LU = 1.0
MAX_DURATION_SECONDS = 600.0
PROCESS_TIMEOUT_SECONDS_DEFAULT = 45
MP3_SIGNATURES = (b"ID3", b"\xff\xfb", b"\xff\xf3", b"\xff\xf2")


class NormalizerError(RuntimeError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


@dataclass(frozen=True)
class NormalizerConfig:
    process_timeout_seconds: int = PROCESS_TIMEOUT_SECONDS_DEFAULT
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
        raise NormalizerError("normalization_timeout") from error
    except OSError as error:
        raise NormalizerError("audio_processor_unavailable") from error
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
            f"loudnorm=I={TARGET_LUFS}:TP={FILTER_TRUE_PEAK_DBTP}:LRA=11:print_format=json",
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
        raise NormalizerError("audio_input_invalid")
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
            "revision": SEED_AUDIO_REVISION,
            "integratedLufs": integrated_lufs,
            "truePeakDbtp": true_peak_dbtp,
            "durationMs": round(duration_seconds * 1000),
            "sampleRate": sample_rate,
            "channels": 1,
            "mode": mode if mode in {"linear", "dynamic"} else "dynamic",
            "sha256": hashlib.sha256(output).hexdigest(),
        }
        return output, metadata
