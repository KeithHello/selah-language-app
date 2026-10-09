import importlib.util
import hashlib
import json
import re
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
        self.assertIn('volume="-14%"', ssml)

    def test_build_ssml_routes_japanese_and_applies_native_profile(self):
        ssml = MODULE.build_ssml("今日は晴れです。", "ja", "native-calm")
        self.assertIn('name="ja-JP-NanamiNeural"', ssml)
        self.assertIn('xml:lang="ja-JP"', ssml)
        self.assertIn('rate="-8%"', ssml)
        self.assertIn('pitch="-1st"', ssml)
        self.assertIn('volume="-31%"', ssml)

    def test_build_ssml_routes_english_to_profile_voice_and_prosody(self):
        ssml = MODULE.build_ssml("A quiet day.", "en", "clear-slow")
        self.assertIn('name="en-US-JennyNeural"', ssml)
        self.assertIn('xml:lang="en-US"', ssml)
        self.assertIn('rate="-10%"', ssml)
        self.assertNotIn('pitch=', ssml)
        self.assertIn('volume="+6%"', ssml)

    def test_default_jenny_ssml_applies_calibrated_volume(self):
        ssml = MODULE.build_ssml("A quiet day.", "en", "gentle-natural")
        self.assertIn('<voice name="en-US-JennyNeural"', ssml)
        self.assertIn('<prosody volume="+6%">', ssml)

    def test_python_volume_table_matches_online_typescript_table(self):
        routing = (SCRIPT_PATH.parents[1] / "functions" / "_shared" / "audio_routing.ts")
        source = routing.read_text(encoding="utf-8")
        match = re.search(
            r"AZURE_VOICE_VOLUME[^=]*=\s*\{(.*?)\n\};",
            source,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(match)
        online = {
            voice: None if volume == "null" else volume.strip('"')
            for voice, volume in re.findall(
                r'"([^"]+)"\s*:\s*(null|"[^"]+")', match.group(1)
            )
        }
        self.assertEqual(MODULE.VOICE_VOLUME, online)

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

    def test_saves_the_azure_mp3_unchanged_and_indexes_measurements(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seed_path = root / "seed.json"
            seed_path.write_text(
                json.dumps({"sentences": [{"id": "seed-001", "ja_text": "こんにちは。"}]}, ensure_ascii=False),
                encoding="utf-8",
            )
            azure_audio = b"ID3" + b"azure-mp3" * 50
            with mock.patch.dict(MODULE.os.environ, {"AZURE_SPEECH_KEY": "test-key", "AZURE_SPEECH_REGION": "japaneast"}), \
                 mock.patch.object(MODULE, "_azure_speech_request", return_value=azure_audio) as request, \
                 mock.patch.object(MODULE, "measure_mp3", return_value=(-20.35, -1.2)) as measure:
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
            self.assertEqual(output.read_bytes(), azure_audio)
            index = json.loads((root / "audio" / "audio-index.json").read_text(encoding="utf-8"))
            self.assertEqual(
                index["seed-001:source:ja:native-gentle"]["normalizerRevision"],
                "azure-vol-v2",
            )
            self.assertEqual(
                index["seed-001:source:ja:native-gentle"]["sha256"],
                hashlib.sha256(azure_audio).hexdigest(),
            )
            self.assertEqual(index["seed-001:source:ja:native-gentle"]["byteSize"], len(azure_audio))
            self.assertEqual(index["seed-001:source:ja:native-gentle"]["integratedLufs"], -20.35)
            self.assertEqual(index["seed-001:source:ja:native-gentle"]["truePeakDbtp"], -1.2)
            request.assert_called_once()
            self.assertIn(b"NanamiNeural", request.call_args.args[2].encode())
            measure.assert_called_once_with(azure_audio, mock.ANY)

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
            azure_audio = b"ID3" + b"azure-mp3" * 50
            with mock.patch.dict(
                MODULE.os.environ,
                {"AZURE_SPEECH_KEY": "test-key", "AZURE_SPEECH_REGION": "eastasia"},
            ), mock.patch.object(
                MODULE, "_azure_speech_request", return_value=azure_audio
            ) as request, mock.patch.object(
                MODULE, "measure_mp3", return_value=(-20.4, -1.4)
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
            self.assertEqual(output.read_bytes(), azure_audio)
            index = json.loads((root / "audio" / "audio-index.json").read_text())
            self.assertEqual(
                index["seed-001:clear-slow"]["normalizerRevision"], "azure-vol-v2"
            )
            self.assertEqual(
                index["seed-001:clear-slow"]["sha256"],
                hashlib.sha256(azure_audio).hexdigest(),
            )
            request.assert_called_once()
            self.assertIn(b"en-US-JennyNeural", request.call_args.args[2].encode())

    def test_measurement_uses_ffmpeg_loudnorm_without_creating_audio_output(self):
        result = MODULE.subprocess.CompletedProcess(
            args=["ffmpeg"],
            returncode=0,
            stdout=b"",
            stderr=b'{"input_i":"-20.4","input_tp":"-1.7"}',
        )
        with mock.patch.object(MODULE.subprocess, "run", return_value=result) as run:
            self.assertEqual(MODULE.measure_mp3(b"ID3audio"), (-20.4, -1.7))
        args = run.call_args.args[0]
        self.assertIn("pipe:0", args)
        self.assertIn("null", args)
        self.assertIn("-20.4", args[args.index("-af") + 1])
        self.assertEqual(run.call_args.kwargs["input"], b"ID3audio")

    def test_is_valid_mp3_accepts_id3_and_mpeg_headers(self):
        self.assertTrue(MODULE.is_valid_mp3(b"ID3" + b"x" * 32))
        self.assertTrue(MODULE.is_valid_mp3(b"\xff\xfb" + b"x" * 32))
        self.assertFalse(MODULE.is_valid_mp3(b"not-mp3"))


if __name__ == "__main__":
    unittest.main()
