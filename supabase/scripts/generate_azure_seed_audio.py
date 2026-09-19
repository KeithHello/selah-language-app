#!/usr/bin/env python3
"""Generate the ten bundled Traditional Chinese source tracks with Azure Speech.

The script reads credentials from the ignored project .env file or matching
process environment variables. It never prints credentials and never writes
them to frontend assets. The default voice is Taiwan Mandarin
``zh-TW-HsiaoChenNeural``.
"""

from __future__ import annotations

import argparse
import json
import os
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SEED_PATH = ROOT / "SeedContent" / "seed-sentences.json"
DEFAULT_AUDIO_DIR = ROOT / "SelahFlutter" / "assets" / "audio"
DEFAULT_ENV_PATH = ROOT / ".env"
DEFAULT_VOICE = "zh-TW-HsiaoChenNeural"
OUTPUT_FORMAT = "audio-16khz-128kbitrate-mono-mp3"


class AzureConfigurationError(RuntimeError):
    """Raised when the local Azure configuration is incomplete."""


def load_local_env(path: Path) -> dict[str, str]:
    """Read simple KEY=VALUE entries without exposing or interpreting secrets."""

    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        values[name.strip()] = value.strip().strip('"').strip("'")
    return values


def build_ssml(text: str, voice: str = DEFAULT_VOICE) -> str:
    """Build escaped SSML for a Taiwan Mandarin neural voice."""

    safe_text = escape(text, {"'": "&apos;", '"': "&quot;"})
    safe_voice = escape(voice, {"'": "&apos;", '"': "&quot;"})
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<speak version="1.0" xml:lang="zh-TW">'
        f'<voice name="{safe_voice}" xml:lang="zh-TW">{safe_text}</voice>'
        "</speak>"
    )


def voice_output_path(seed_id: str, audio_dir: Path) -> Path:
    return audio_dir / f"{seed_id}-source-zh-Hant.mp3"


def is_valid_mp3(body: bytes) -> bool:
    return body.startswith(b"ID3") or body[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2")


def _azure_speech_request(region: str, key: str, ssml: str) -> bytes:
    endpoint = f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    request = urllib.request.Request(
        endpoint,
        data=ssml.encode("utf-8"),
        method="POST",
        headers={
            "Accept": "audio/mpeg",
            "Content-Type": "application/ssml+xml",
            "Ocp-Apim-Subscription-Key": key,
            "User-Agent": "SelahSeedAudio/1.0",
            "X-Microsoft-OutputFormat": OUTPUT_FORMAT,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"Azure Speech HTTP {error.code}") from None
    except urllib.error.URLError as error:
        raise RuntimeError("Azure Speech network request failed") from error
    if not is_valid_mp3(body):
        raise RuntimeError("Azure Speech returned an invalid MP3")
    return body


def _atomic_write(path: Path, body: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as handle:
            temporary = handle.name
            handle.write(body)
            handle.flush()
            os.fsync(handle.fileno())
        Path(temporary).replace(path)
        temporary = None
    finally:
        if temporary:
            Path(temporary).unlink(missing_ok=True)


def generate_seed_audio(
    seed_path: Path,
    audio_dir: Path,
    env_path: Path,
    voice: str = DEFAULT_VOICE,
    dry_run: bool = False,
) -> int:
    seed_data = json.loads(seed_path.read_text(encoding="utf-8"))
    sentences = seed_data.get("sentences")
    if not isinstance(sentences, list) or not sentences:
        raise ValueError("Seed content has no sentences")

    config = load_local_env(env_path)
    key = os.environ.get("AZURE_SPEECH_KEY", config.get("AZURE_SPEECH_KEY", ""))
    region = os.environ.get("AZURE_SPEECH_REGION", config.get("AZURE_SPEECH_REGION", ""))
    if not dry_run and (not key or not region):
        raise AzureConfigurationError(
            "AZURE_SPEECH_KEY and AZURE_SPEECH_REGION are required in .env or the process environment"
        )

    for sentence in sentences:
        seed_id = str(sentence.get("id", "")).strip()
        text = str(sentence.get("zh_text", "")).strip()
        if not seed_id or not text:
            raise ValueError("Every seed sentence needs id and zh_text")
        output = voice_output_path(seed_id, audio_dir)
        if dry_run:
            print(f"PLAN {seed_id} -> {output}")
            continue
        body = _azure_speech_request(region, key, build_ssml(text, voice))
        _atomic_write(output, body)
        print(f"READY {seed_id} ({len(body)} bytes)")
    return len(sentences)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed-path", type=Path, default=DEFAULT_SEED_PATH)
    parser.add_argument("--audio-dir", type=Path, default=DEFAULT_AUDIO_DIR)
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_PATH)
    parser.add_argument("--voice", default=DEFAULT_VOICE)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        count = generate_seed_audio(
            seed_path=args.seed_path,
            audio_dir=args.audio_dir,
            env_path=args.env_file,
            voice=args.voice,
            dry_run=args.dry_run,
        )
    except (AzureConfigurationError, OSError, RuntimeError, ValueError) as error:
        print(f"Azure seed audio generation failed: {error}")
        return 1
    mode = "planned" if args.dry_run else "generated"
    print(f"Azure seed audio {mode}: {count} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
