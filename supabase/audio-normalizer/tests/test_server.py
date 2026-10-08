from __future__ import annotations

import hashlib
from http.client import HTTPConnection
import shutil
import subprocess
import sys
import threading
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from server import (
    NORMALIZER_REVISION,
    NormalizerConfig,
    NormalizerHTTPServer,
    normalize_mp3,
)


class NormalizerServerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.config = NormalizerConfig(
            token="t" * 40,
            max_concurrent_jobs=1,
        )
        self.server = NormalizerHTTPServer(("127.0.0.1", 0), self.config)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self._close_server)
        self.host, self.port = self.server.server_address

    def _close_server(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def _request(self, headers: dict[str, str]) -> tuple[int, bytes]:
        connection = HTTPConnection(self.host, self.port, timeout=2)
        connection.request("POST", "/v1/normalize", body=b"x" * 512, headers=headers)
        response = connection.getresponse()
        result = response.status, response.read()
        connection.close()
        return result

    def test_health_probe_reports_revision(self) -> None:
        connection = HTTPConnection(self.host, self.port, timeout=2)
        connection.request("GET", "/healthz")
        response = connection.getresponse()
        body = response.read()
        connection.close()
        self.assertEqual(response.status, 200)
        self.assertIn(NORMALIZER_REVISION.encode(), body)

    def test_rejects_missing_authentication_without_processing_audio(self) -> None:
        status, body = self._request({
            "Content-Type": "audio/mpeg",
            "Content-Length": "512",
            "X-Audio-Normalizer-Revision": NORMALIZER_REVISION,
            "X-Audio-SHA256": hashlib.sha256(b"x" * 512).hexdigest(),
        })
        self.assertEqual(status, 401)
        self.assertIn(b"unauthorized", body)

    def test_rejects_stale_revision(self) -> None:
        status, body = self._request({
            "Authorization": f"Bearer {self.config.token}",
            "Content-Type": "audio/mpeg",
            "Content-Length": "512",
            "X-Audio-Normalizer-Revision": "lufs-v0",
            "X-Audio-SHA256": hashlib.sha256(b"x" * 512).hexdigest(),
        })
        self.assertEqual(status, 409)
        self.assertIn(b"revision_mismatch", body)

    def test_normalizes_to_target_loudness_and_fixed_mp3_format(self) -> None:
        ffmpeg = shutil.which("ffmpeg")
        ffprobe = shutil.which("ffprobe")
        if not ffmpeg or not ffprobe:
            self.skipTest("FFmpeg and ffprobe are required for the integration test")
        config = NormalizerConfig(
            token=self.config.token,
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
        self.assertEqual(metadata["revision"], NORMALIZER_REVISION)
        self.assertGreaterEqual(metadata["integratedLufs"], -23.0)
        self.assertLessEqual(metadata["integratedLufs"], -21.0)
        self.assertLessEqual(metadata["truePeakDbtp"], -1.0)
        self.assertEqual(metadata["sampleRate"], 24000)
        self.assertEqual(metadata["channels"], 1)
        self.assertEqual(metadata["mode"], "linear")
        self.assertEqual(metadata["sha256"], hashlib.sha256(output).hexdigest())


if __name__ == "__main__":
    unittest.main()
