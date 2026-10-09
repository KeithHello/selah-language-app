from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import (
    NormalizerConfig,
    NormalizerError,
    SEED_AUDIO_REVISION,
    normalize_mp3,
)


class SeedAudioNormalizationTest(unittest.TestCase):
    def test_rejects_non_mp3_input(self) -> None:
        with self.assertRaises(NormalizerError):
            normalize_mp3(b"not-an-mp3", NormalizerConfig())

    def test_normalizes_to_target_loudness_and_fixed_mp3_format(self) -> None:
        ffmpeg = shutil.which("ffmpeg")
        ffprobe = shutil.which("ffprobe")
        if not ffmpeg or not ffprobe:
            self.skipTest("FFmpeg and ffprobe are required for the integration test")
        config = NormalizerConfig(
            ffmpeg=ffmpeg,
            ffprobe=ffprobe,
            process_timeout_seconds=30,
        )
        generated = subprocess.run(
            [
                ffmpeg,
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "sine=frequency=997:duration=1:sample_rate=44100",
                "-af",
                "volume=-10dB",
                "-c:a",
                "libmp3lame",
                "-b:a",
                "128k",
                "-f",
                "mp3",
                "-y",
                "-",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
            timeout=20,
        )
        output, metadata = normalize_mp3(generated.stdout, config)

        self.assertTrue(output.startswith(b"ID3") or output[0] == 0xFF)
        self.assertEqual(metadata["revision"], SEED_AUDIO_REVISION)
        self.assertLessEqual(abs(metadata["integratedLufs"] + 20.9), 1.0)
        self.assertLessEqual(metadata["truePeakDbtp"], -1.0)
        self.assertEqual(metadata["sampleRate"], 24000)
        self.assertEqual(metadata["channels"], 1)
        self.assertEqual(metadata["sha256"], hashlib.sha256(output).hexdigest())


if __name__ == "__main__":
    unittest.main()
