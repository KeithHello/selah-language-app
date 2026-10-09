import importlib.util
import hashlib
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
        ssml = MODULE.build_ssml("A&B <今天>", "zh-Hant", "native-gentle")
        self.assertIn('name="zh-TW-HsiaoChenNeural"', ssml)
        self.assertIn("A&amp;B &lt;今天&gt;", ssml)
        self.assertIn('xml:lang="zh-TW"', ssml)
        self.assertIn('volume="-19%"', ssml)

    def test_build_ssml_routes_japanese_and_applies_native_profile(self):
        ssml = MODULE.build_ssml("今日は晴れです。", "ja", "native-calm")
        self.assertIn('name="ja-JP-NanamiNeural"', ssml)
        self.assertIn('xml:lang="ja-JP"', ssml)
        self.assertIn('rate="-8%"', ssml)
        self.assertIn('pitch="-1st"', ssml)
        self.assertIn('volume="-35%"', ssml)

    def test_build_ssml_routes_english_to_profile_voice_and_prosody(self):
        ssml = MODULE.build_ssml("A quiet day.", "en", "clear-slow")
        self.assertIn('name="en-US-JennyNeural"', ssml)
        self.assertIn('xml:lang="en-US"', ssml)
        self.assertIn('rate="-10%"', ssml)
        self.assertNotIn('pitch=', ssml)
        self.assertNotIn('volume=', ssml)

    def test_default_jenny_ssml_omits_default_prosody(self):
        ssml = MODULE.build_ssml("A quiet day.", "en", "gentle-natural")
        self.assertIn('<voice name="en-US-JennyNeural"', ssml)
        self.assertNotIn('<prosody', ssml)

    def test_voice_output_path_uses_source_zh_hant_filename(self):
        path = MODULE.voice_output_path("seed-001", Path("audio"))
        self.assertEqual(path, Path("audio/seed-001-source-zh-Hant.mp3"))

    def test_voice_output_path_uses_target_profile_filename(self):
        path = MODULE.voice_output_path(
            "seed-001", Path("audio"), "en", "gentle-natural"
        )
        self.assertEqual(path, Path("audio/seed-001-gentle-natural.mp3"))

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
        self.assertNotIn("OTHER", values)
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
            with mock.patch.object(MODULE, "load_local_env", side_effect=AssertionError("dry-run must not read env")):
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
                        execute=True,
                    )
            request.assert_not_called()

    def test_normalizes_azure_audio_before_atomic_write(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seed_path = root / "seed.json"
            seed_path.write_text(
                json.dumps({"sentences": [{"id": "seed-001", "ja_text": "こんにちは。"}]}, ensure_ascii=False),
                encoding="utf-8",
            )
            normalized = b"ID3" + b"normalized" * 50
            metadata = {"integratedLufs": -20.9, "truePeakDbtp": -1.2, "revision": "lufs-v2"}
            with mock.patch.dict(MODULE.os.environ, {"AZURE_SPEECH_KEY": "test-key", "AZURE_SPEECH_REGION": "japaneast"}), \
                 mock.patch.object(MODULE, "_azure_speech_request", return_value=b"ID3" + b"raw" * 50) as request, \
                 mock.patch.object(MODULE, "normalize_mp3", return_value=(normalized, metadata)) as normalize:
                count = MODULE.generate_seed_audio(
                    seed_path=seed_path,
                    audio_dir=root / "audio",
                    env_path=root / ".env",
                    language="ja",
                    voice_profile="native-gentle",
                    execute=True,
                )
            output = root / "audio" / "seed-001-source-ja.mp3"
            self.assertEqual(count, 1)
            self.assertEqual(output.read_bytes(), normalized)
            index = json.loads((root / "audio" / "audio-index.json").read_text(encoding="utf-8"))
            self.assertEqual(
                index["seed-001:source:ja:native-gentle"]["normalizerRevision"],
                "lufs-v2",
            )
            self.assertEqual(
                index["seed-001:source:ja:native-gentle"]["sha256"],
                hashlib.sha256(normalized).hexdigest(),
            )
            request.assert_called_once()
            self.assertIn(b"NanamiNeural", request.call_args.args[2].encode())
            normalize.assert_called_once()

    def test_reuses_calibration_mp3_without_env_access_or_azure_call(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seed_path = root / "seed.json"
            seed_path.write_text(
                json.dumps({"sentences": [{"id": "seed-001", "ja_text": "こんにちは。"}]}, ensure_ascii=False),
                encoding="utf-8",
            )
            raw_dir = root / "raw"
            raw_dir.mkdir()
            raw = b"ID3" + b"calibration-source" * 30
            (raw_dir / "baseline__ja__native-gentle__seed-001__default.mp3").write_bytes(raw)
            normalized = b"ID3" + b"normalized" * 50
            metadata = {"integratedLufs": -20.9, "truePeakDbtp": -1.2, "revision": "lufs-v2"}
            with mock.patch.object(MODULE, "load_local_env", side_effect=AssertionError("offline reuse must not read env")), \
                 mock.patch.object(MODULE, "_azure_speech_request", side_effect=AssertionError("offline reuse must not call Azure")) as request, \
                 mock.patch.object(MODULE, "normalize_mp3", return_value=(normalized, metadata)) as normalize:
                count = MODULE.generate_seed_audio(
                    seed_path=seed_path,
                    audio_dir=root / "audio",
                    env_path=root / ".env",
                    language="ja",
                    voice_profile="native-gentle",
                    raw_audio_dir=raw_dir,
                )
            self.assertEqual(count, 1)
            self.assertEqual((root / "audio" / "seed-001-source-ja.mp3").read_bytes(), normalized)
            request.assert_not_called()
            normalize.assert_called_once_with(raw, mock.ANY)

    def test_generates_english_target_audio_with_manifest_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seed_path = root / "seed.json"
            seed_path.write_text(
                json.dumps(
                    {"sentences": [{"id": "seed-001", "en_translation": "A quiet day."}]}
                ),
                encoding="utf-8",
            )
            normalized = b"ID3" + b"normalized" * 50
            metadata = {
                "integratedLufs": -20.9,
                "truePeakDbtp": -1.2,
                "revision": "lufs-v2",
            }
            with mock.patch.dict(
                MODULE.os.environ,
                {"AZURE_SPEECH_KEY": "test-key", "AZURE_SPEECH_REGION": "eastasia"},
            ), mock.patch.object(
                MODULE, "_azure_speech_request", return_value=b"ID3" + b"raw" * 50
            ) as request, mock.patch.object(
                MODULE, "normalize_mp3", return_value=(normalized, metadata)
            ):
                count = MODULE.generate_seed_audio(
                    seed_path=seed_path,
                    audio_dir=root / "audio",
                    env_path=root / ".env",
                    language="en",
                    voice_profile="clear-slow",
                    execute=True,
                )

            output = root / "audio" / "seed-001-clear-slow.mp3"
            self.assertEqual(count, 1)
            self.assertEqual(output.read_bytes(), normalized)
            index = json.loads((root / "audio" / "audio-index.json").read_text())
            self.assertEqual(
                index["seed-001:clear-slow"]["normalizerRevision"], "lufs-v2"
            )
            self.assertEqual(
                index["seed-001:clear-slow"]["sha256"],
                hashlib.sha256(normalized).hexdigest(),
            )
            request.assert_called_once()
            self.assertIn(b"en-US-JennyNeural", request.call_args.args[2].encode())

    def test_is_valid_mp3_accepts_id3_and_mpeg_headers(self):
        self.assertTrue(MODULE.is_valid_mp3(b"ID3" + b"x" * 32))
        self.assertTrue(MODULE.is_valid_mp3(b"\xff\xfb" + b"x" * 32))
        self.assertFalse(MODULE.is_valid_mp3(b"not-mp3"))


if __name__ == "__main__":
    unittest.main()
