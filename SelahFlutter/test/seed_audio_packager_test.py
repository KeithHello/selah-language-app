"""Seed packaging must recover existing default audio without synthesizing it."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'packager', Path(__file__).resolve().parents[1] / 'tool/package_seed_audio.py')
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


VOICES = ('gentle-natural', 'clear-slow', 'daily-bright', 'elegant-british')
VOICE_MODELS = {
    'gentle-natural': 'azure-speech/en-US-JennyNeural',
    'clear-slow': 'azure-speech/en-US-JennyNeural',
    'daily-bright': 'azure-speech/en-US-GuyNeural',
    'elegant-british': 'azure-speech/en-GB-SoniaNeural',
}
VOICE_SPEEDS = {
    'gentle-natural': 1,
    'clear-slow': 0.9,
    'daily-bright': 1.05,
    'elegant-british': 1,
}


class SeedAudioPackagingTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.audio_dir = Path(self.directory.name)
        self.seeds = [{'id': 'seed-001', 'en_translation': 'A quiet day.'},
                      {'id': 'seed-002', 'en_translation': 'Let us begin.'}]
        self.bodies = {
            (seed['id'], voice): b'ID3' + seed['id'].encode() + voice.encode()
            for seed in self.seeds for voice in VOICES
        }
        self.rows = [
            self.row(seed, voice) for seed in self.seeds for voice in VOICES
        ]
        self.requests = []

    def row(self, seed, voice='gentle-natural'):
        body = self.bodies[(seed['id'], voice)]
        canonical = ' '.join(seed['en_translation'].strip().split()).lower()
        model = VOICE_MODELS[voice]
        text_hash = hashlib.sha256(
            f'en|mp3|lufs-v1|{canonical}'.encode()).hexdigest()
        provider_voice = f'{model.split("/", 1)[1]}@{voice}'
        content_hash = f'azure:{provider_voice}:{VOICE_SPEEDS[voice]}:lufs-v1:{text_hash}'
        return {'seed_sentence_id': seed['id'], 'voice_profile': voice,
                'storage_path': f"seed/{seed['id']}/{voice}/{text_hash}.mp3",
                'content_hash': content_hash, 'tts_model': VOICE_MODELS[voice],
                'speed': VOICE_SPEEDS[voice],
                'audio_format': 'mp3', 'byte_size': len(body),
                'sha256': hashlib.sha256(body).hexdigest()}

    def read(self, path):
        self.requests.append(path)
        for (seed, voice), body in self.bodies.items():
            if f'/seed/{seed}/{voice}/' in path:
                return body
        raise AssertionError(f'unexpected storage path: {path}')

    def package(self, rows=None, existing=None, read=None):
        return packager.package_default_audio(
            self.rows if rows is None else rows, self.seeds, self.audio_dir,
            read or self.read, existing or {})

    def test_packages_all_four_voices_and_downloads_only_missing_files(self):
        for voice in VOICES:
            (self.audio_dir / f'seed-001-{voice}.mp3').write_bytes(
                self.bodies[('seed-001', voice)])
        entries = self.package()
        self.assertEqual(len(entries), 8)
        self.assertEqual(len(self.requests), 4)
        self.assertEqual(entries['seed-001:gentle-natural']['normalizerRevision'], 'lufs-v1')
        self.assertTrue(all('/seed/seed-002/' in path for path in self.requests))
        self.assertTrue(all(path.startswith('/storage/v1/object/authenticated/audio-assets/seed/')
                            for path in self.requests))

    def test_preserves_unrelated_existing_manifest_entry(self):
        legacy_body = b'ID3legacy-voice'
        (self.audio_dir / 'legacy-clear-slow.mp3').write_bytes(legacy_body)
        legacy = {'path': 'assets/audio/legacy-clear-slow.mp3',
                  'sha256': hashlib.sha256(legacy_body).hexdigest(),
                  'byteSize': len(legacy_body)}
        entries = self.package(existing={'legacy:clear-slow': legacy})
        self.assertEqual(entries['legacy:clear-slow'], legacy)

    def test_packages_existing_chinese_and_japanese_native_audio(self):
        seeds = [{'id': 'seed-001'}, {'id': 'seed-002'}]
        zh_body = b'\xff\xf3native-zh'
        ja_body = b'ID3native-ja'
        (self.audio_dir / 'seed-001-source-zh-Hant.mp3').write_bytes(zh_body)
        (self.audio_dir / 'seed-001-source-ja.mp3').write_bytes(ja_body)

        entries, missing = packager.package_local_native_audio(
            seeds, self.audio_dir, {'existing:key': {'path': 'assets/audio/x.mp3'}})

        self.assertEqual(missing, [
            'seed-002-source-zh-Hant.mp3',
            'seed-002-source-ja.mp3',
        ])
        self.assertEqual(entries['existing:key']['path'], 'assets/audio/x.mp3')
        self.assertEqual(
            entries['seed-001:source:zh-Hant']['path'],
            'assets/audio/seed-001-source-zh-Hant.mp3')
        self.assertEqual(
            entries['seed-001:source:ja']['path'],
            'assets/audio/seed-001-source-ja.mp3')
        self.assertNotIn('seed-001:source:zh-Hant:native-gentle', entries)
        self.assertNotIn('seed-001:source:ja:native-gentle', entries)
        self.assertEqual(entries['seed-001:source:zh-Hant']['byteSize'], len(zh_body))
        self.assertEqual(entries['seed-001:source:ja']['byteSize'], len(ja_body))

    def test_packages_complete_verified_local_english_seed_audio(self):
        seeds = [{'id': 'seed-001'}, {'id': 'seed-002'}]
        source_dir = self.audio_dir / 'staged'
        source_dir.mkdir()
        index = {}
        for seed in seeds:
            for voice in VOICES:
                filename = f"{seed['id']}-{voice}.mp3"
                body = self.bodies[(seed['id'], voice)]
                (source_dir / filename).write_bytes(body)
                index[f"{seed['id']}:{voice}"] = {
                    'path': filename,
                    'sha256': hashlib.sha256(body).hexdigest(),
                    'byteSize': len(body),
                    'normalizerRevision': 'lufs-v1',
                    'integratedLufs': -22.0,
                    'truePeakDbtp': -1.2,
                }
        (source_dir / 'audio-index.json').write_text(
            json.dumps(index), encoding='utf-8')

        entries = packager.package_local_default_audio(
            seeds, self.audio_dir, {}, source_dir)

        self.assertEqual(len(entries), 8)
        self.assertEqual(
            entries['seed-001:gentle-natural']['normalizerRevision'], 'lufs-v1')
        self.assertEqual(
            (self.audio_dir / 'seed-002-elegant-british.mp3').read_bytes(),
            self.bodies[('seed-002', 'elegant-british')])

    def test_rejects_unverified_or_incomplete_local_english_seed_audio(self):
        seeds = [{'id': 'seed-001'}]
        source_dir = self.audio_dir / 'staged'
        source_dir.mkdir()
        filename = 'seed-001-gentle-natural.mp3'
        body = self.bodies[('seed-001', 'gentle-natural')]
        (source_dir / filename).write_bytes(body)
        (source_dir / 'audio-index.json').write_text('{}', encoding='utf-8')

        with self.assertRaises(RuntimeError):
            packager.package_local_default_audio(seeds, self.audio_dir, {}, source_dir)
        self.assertFalse(any(self.audio_dir.glob('seed-*.mp3')))

    def test_packages_a_native_profile_variant_without_aliasing_other_profiles(self):
        seeds = [{'id': 'seed-001'}]
        clear_body = b'ID3native-clear'
        (self.audio_dir / 'seed-001-source-ja-native-clear.mp3').write_bytes(clear_body)

        entries, missing = packager.package_local_native_audio(
            seeds, self.audio_dir, {})

        self.assertEqual(entries['seed-001:source:ja:native-clear']['sha256'],
                         hashlib.sha256(clear_body).hexdigest())
        self.assertNotIn('seed-001:source:ja:native-gentle', entries)
        self.assertEqual(len(missing), 2)

    def test_missing_duplicate_and_wrong_content_are_rejected_before_download(self):
        invalid_content = [dict(row) for row in self.rows]
        invalid_content[0]['content_hash'] = '0' * 64
        for rows in [self.rows[:1], self.rows + self.rows[:1], invalid_content]:
            with self.subTest(rows=rows), self.assertRaises(RuntimeError):
                self.package(rows=rows)
        self.assertEqual(self.requests, [])

    def test_corrupt_local_file_is_recovered_from_verified_existing_storage(self):
        target = self.audio_dir / 'seed-001-elegant-british.mp3'
        target.write_bytes(b'corrupt')
        self.package()
        self.assertEqual(target.read_bytes(), self.bodies[('seed-001', 'elegant-british')])
        self.assertEqual(len(self.requests), 8)

    def test_corrupt_remote_file_is_not_written(self):
        with self.assertRaises(RuntimeError):
            self.package(read=lambda _: b'ID3wrong-file')
        self.assertEqual(list(self.audio_dir.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
