"""Seed packaging must recover existing default audio without synthesizing it."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    'packager', Path(__file__).resolve().parents[1] / 'tool/package_seed_audio.py')
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


VOICES = ('gentle-natural', 'clear-slow', 'daily-bright', 'elegant-british')


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
        content_hash = hashlib.sha256(
            f'{canonical}|{voice}|tts-1|0.85|mp3'.encode()).hexdigest()
        return {'seed_sentence_id': seed['id'], 'voice_profile': voice,
                'storage_path': f"seed/{seed['id']}/{voice}/{content_hash}.mp3",
                'content_hash': content_hash, 'tts_model': 'tts-1', 'speed': 0.85,
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
