import importlib.util
import json
import tempfile
import unittest
from unittest import mock
from pathlib import Path


SCRIPT_PATH = Path(__file__).parents[1] / "scripts" / "generate_azure_seed_audio.py"
SPEC = importlib.util.spec_from_file_location("azure_seed_audio", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


class AzureSeedAudioScriptTests(unittest.TestCase):
    def test_build_ssml_escapes_text_and_uses_taiwan_voice(self):
        ssml = MODULE.build_ssml("A&B <今天>")
        self.assertIn('name="zh-TW-HsiaoChenNeural"', ssml)
        self.assertIn("A&amp;B &lt;今天&gt;", ssml)
        self.assertIn('xml:lang="zh-TW"', ssml)

    def test_voice_output_path_uses_source_zh_hant_filename(self):
        path = MODULE.voice_output_path("seed-001", Path("audio"))
        self.assertEqual(path, Path("audio/seed-001-source-zh-Hant.mp3"))

    def test_load_local_env_strips_quotes_and_ignores_comments(self):
        with tempfile.TemporaryDirectory() as directory:
            env_path = Path(directory) / ".env"
            env_path.write_text(
                '# comment\nAZURE_SPEECH_KEY="secret"\n'
                "AZURE_SPEECH_REGION='eastasia'\nOTHER=value\n",
                encoding="utf-8",
            )
            values = MODULE.load_local_env(env_path)
        self.assertEqual(values["AZURE_SPEECH_KEY"], "secret")
        self.assertEqual(values["AZURE_SPEECH_REGION"], "eastasia")
        self.assertNotIn("# comment", values)

    def test_dry_run_plans_all_seed_sentences_without_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seed_path = root / "seed.json"
            seed_path.write_text(
                json.dumps(
                    {
                        "sentences": [
                            {"id": "seed-001", "zh_text": "第一句"},
                            {"id": "seed-006", "zh_text": "第二句"},
                        ]
                    },
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            count = MODULE.generate_seed_audio(
                seed_path=seed_path,
                audio_dir=root / "audio",
                env_path=root / ".env",
                dry_run=True,
            )
            self.assertEqual(count, 2)
            self.assertFalse((root / "audio").exists())

    def test_missing_credentials_fails_before_network_request(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seed_path = root / "seed.json"
            seed_path.write_text(
                json.dumps(
                    {"sentences": [{"id": "seed-001", "zh_text": "第一句"}]},
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            with mock.patch.dict(
                MODULE.os.environ,
                {"AZURE_SPEECH_KEY": "", "AZURE_SPEECH_REGION": ""},
                clear=False,
            ), mock.patch.object(MODULE, "_azure_speech_request") as request:
                with self.assertRaises(MODULE.AzureConfigurationError):
                    MODULE.generate_seed_audio(
                        seed_path=seed_path,
                        audio_dir=root / "audio",
                        env_path=root / ".env",
                    )
            request.assert_not_called()

    def test_is_valid_mp3_accepts_id3_and_mpeg_headers(self):
        self.assertTrue(MODULE.is_valid_mp3(b"ID3" + b"x" * 32))
        self.assertTrue(MODULE.is_valid_mp3(b"\xff\xfb" + b"x" * 32))
        self.assertFalse(MODULE.is_valid_mp3(b"not-mp3"))


if __name__ == "__main__":
    unittest.main()
