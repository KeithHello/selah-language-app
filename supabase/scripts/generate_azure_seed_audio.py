#!/usr/bin/env python3
"""Plan or generate normalized Chinese and Japanese native seed audio.

The default mode is a dry-run. ``--execute`` is required for paid Azure calls;
it writes to a preview directory and refuses to replace existing audio unless
``--overwrite`` is also provided.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SEED_PATH = ROOT / "SeedContent" / "seed-sentences.json"
DEFAULT_AUDIO_DIR = ROOT / "preview-output" / "azure-native-seed-audio"
DEFAULT_ENV_PATH = ROOT / ".env"
DEFAULT_LANGUAGE = "zh-Hant"
DEFAULT_VOICE_PROFILE = "native-gentle"
OUTPUT_FORMAT = "audio-24khz-160kbitrate-mono-mp3"
LANGUAGES = {
    "zh-Hant": ("zh-TW", "zh-TW-HsiaoChenNeural", "zh_text"),
    "ja": ("ja-JP", "ja-JP-NanamiNeural", "ja_text"),
}
NATIVE_PROFILES = {
    "native-gentle": ("0%", "0st", 1),
    "native-clear": ("-5%", "0st", 0.95),
    "native-bright": ("+5%", "+1st", 1.05),
    "native-calm": ("-8%", "-1st", 0.92),
}

sys.path.insert(0, str(ROOT / "supabase" / "audio-normalizer"))
from server import NormalizerConfig, normalize_mp3


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


def build_ssml(
    text: str,
    language: str = DEFAULT_LANGUAGE,
    voice_profile: str = DEFAULT_VOICE_PROFILE,
) -> str:
    """Build escaped SSML for the selected native-language Azure route."""
    locale, voice, _ = LANGUAGES[language]
    rate, pitch, _speed = NATIVE_PROFILES[voice_profile]
    safe_text = escape(text, {"'": "&apos;", '"': "&quot;"})
    safe_voice = escape(voice, {"'": "&apos;", '"': "&quot;"})
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        f'<speak version="1.0" xml:lang="{locale}">'
        f'<voice name="{safe_voice}" xml:lang="{locale}">'
        f'<prosody rate="{rate}" pitch="{pitch}">{safe_text}</prosody>'
        '</voice>'
        "</speak>"
    )


def voice_output_path(
    seed_id: str,
    audio_dir: Path,
    language: str = DEFAULT_LANGUAGE,
    voice_profile: str = DEFAULT_VOICE_PROFILE,
) -> Path:
    suffix = "" if voice_profile == DEFAULT_VOICE_PROFILE else f"-{voice_profile}"
    return audio_dir / f"{seed_id}-source-{language}{suffix}.mp3"


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
    language: str = DEFAULT_LANGUAGE,
    voice_profile: str = DEFAULT_VOICE_PROFILE,
    execute: bool = False,
    dry_run: bool = False,
    overwrite: bool = False,
) -> int:
    if language not in LANGUAGES:
        raise ValueError(f"Unsupported native language: {language}")
    if voice_profile not in NATIVE_PROFILES:
        raise ValueError(f"Unsupported native voice profile: {voice_profile}")
    seed_data = json.loads(seed_path.read_text(encoding="utf-8"))
    sentences = seed_data.get("sentences")
    if not isinstance(sentences, list) or not sentences:
        raise ValueError("Seed content has no sentences")

    text_field = LANGUAGES[language][2]
    work_items: list[tuple[str, str, Path]] = []
    for sentence in sentences:
        seed_id = str(sentence.get("id", "")).strip()
        text = str(sentence.get(text_field, "")).strip()
        if not seed_id or not text:
            raise ValueError(f"Every seed sentence needs id and {text_field}")
        work_items.append((seed_id, text, voice_output_path(
            seed_id, audio_dir, language, voice_profile
        )))

    if dry_run or not execute:
        for seed_id, _text, output in work_items:
            print(f"PLAN {seed_id} {language} {voice_profile} -> {output}")
        return len(work_items)

    if not overwrite:
        existing = [str(output) for _seed_id, _text, output in work_items if output.exists()]
        if existing:
            raise FileExistsError(
                "Refusing to replace existing seed audio; choose another --audio-dir "
                "or explicitly pass --overwrite"
            )

    local_config = load_local_env(env_path)
    key = os.environ.get("AZURE_SPEECH_KEY", local_config.get("AZURE_SPEECH_KEY", ""))
    region = os.environ.get("AZURE_SPEECH_REGION", local_config.get("AZURE_SPEECH_REGION", ""))
    if not key or not region or not all(
        character.isalnum() or character == "-" for character in region
    ):
        raise AzureConfigurationError(
            "AZURE_SPEECH_KEY and a valid AZURE_SPEECH_REGION are required "
            "only when --execute is used"
        )

    ffmpeg = shutil.which("ffmpeg") or "ffmpeg"
    ffprobe = shutil.which("ffprobe") or "ffprobe"
    normalizer_config = NormalizerConfig(
        token="local-seed-audio-normalization",
        ffmpeg=ffmpeg,
        ffprobe=ffprobe,
    )
    index_path = audio_dir / "audio-index.json"
    if index_path.exists():
        index = json.loads(index_path.read_text(encoding="utf-8"))
        if not isinstance(index, dict):
            raise ValueError("Existing audio index must be a JSON object")
    else:
        index = {}
    for seed_id, text, output in work_items:
        raw_audio = _azure_speech_request(
            region,
            key,
            build_ssml(text, language, voice_profile),
        )
        normalized_audio, metadata = normalize_mp3(raw_audio, normalizer_config)
        _atomic_write(output, normalized_audio)
        index_key = f"{seed_id}:source:{language}:{voice_profile}"
        index[index_key] = {
            "path": output.name,
            "sha256": hashlib.sha256(normalized_audio).hexdigest(),
            "byteSize": len(normalized_audio),
            "normalizerRevision": metadata["revision"],
            "integratedLufs": metadata["integratedLufs"],
            "truePeakDbtp": metadata["truePeakDbtp"],
        }
        print(
            f"READY {seed_id} {language} {voice_profile} "
            f"({len(normalized_audio)} bytes, "
            f"{metadata['integratedLufs']:.2f} LUFS, "
            f"{metadata['truePeakDbtp']:.2f} dBTP)"
        )
    _atomic_write(
        index_path,
        json.dumps(index, ensure_ascii=False, indent=2).encode("utf-8"),
    )
    return len(work_items)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed-path", type=Path, default=DEFAULT_SEED_PATH)
    parser.add_argument("--audio-dir", type=Path, default=DEFAULT_AUDIO_DIR)
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_PATH)
    parser.add_argument("--language", choices=LANGUAGES, default=DEFAULT_LANGUAGE)
    parser.add_argument(
        "--voice-profile",
        choices=NATIVE_PROFILES,
        default=DEFAULT_VOICE_PROFILE,
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Make paid Azure Speech calls and normalize audio locally",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Allow replacing files in the selected output directory",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        count = generate_seed_audio(
            seed_path=args.seed_path,
            audio_dir=args.audio_dir,
            env_path=args.env_file,
            language=args.language,
            voice_profile=args.voice_profile,
            execute=args.execute,
            dry_run=args.dry_run,
            overwrite=args.overwrite,
        )
    except (AzureConfigurationError, OSError, RuntimeError, ValueError) as error:
        print(f"Azure seed audio generation failed: {error}")
        return 1
    mode = "generated" if args.execute and not args.dry_run else "planned"
    print(f"Azure seed audio {mode}: {count} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
