"""Package existing, verified seed audio for local Web learning; never generate TTS.

Reads server credentials only in this build tool. No credential is printed or
written to frontend assets. Source MP3s are the project's existing seed content.
"""
import concurrent.futures
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'SelahFlutter' / 'assets'
DEFAULT_VOICE = 'gentle-natural'
VOICES = ('gentle-natural', 'clear-slow', 'daily-bright', 'elegant-british')
SOURCE_VOICE = 'source'
NATIVE_LANGUAGES = ('zh-Hant', 'ja')
NORMALIZER_REVISION = 'lufs-v2'
DEFAULT_LOCAL_AUDIO_DIR = ROOT / 'preview-output' / 'azure-seed-audio'
VOICE_IDENTITIES = {
    'gentle-natural': ('azure-speech/en-US-JennyNeural', 1),
    'clear-slow': ('azure-speech/en-US-JennyNeural', 0.9),
    'daily-bright': ('azure-speech/en-US-GuyNeural', 1.05),
    'elegant-british': ('azure-speech/en-GB-SoniaNeural', 1),
}
NATIVE_PROFILES = ('native-gentle', 'native-clear', 'native-bright', 'native-calm')


def valid_audio(body, checksum, byte_size):
    return (len(body) == byte_size and hashlib.sha256(body).hexdigest() == checksum
            and (body.startswith(b'ID3') or body[:1] == b'\xff'))


def package_default_audio(rows, seeds, audio_dir, read, existing):
    """Validate and package every seed in every supported voice."""
    allowed = {seed['id']: seed['en_translation'] for seed in seeds}
    by_key = {}
    for row in rows:
        seed = row['seed_sentence_id']
        voice = row['voice_profile']
        if seed not in allowed or voice not in VOICES or (seed, voice) in by_key:
            raise RuntimeError('Unexpected or duplicate default seed manifest.')
        canonical = ' '.join(allowed[seed].strip().split()).lower()
        model, speed = VOICE_IDENTITIES[voice]
        text_hash = hashlib.sha256(
            f'en|mp3|{NORMALIZER_REVISION}|{canonical}'.encode()).hexdigest()
        provider_voice = f'{model.split("/", 1)[1]}@{voice}'
        content_hash = (
            f'azure:{provider_voice}:{speed}:{NORMALIZER_REVISION}:{text_hash}')
        if (row.get('content_hash') != content_hash or row.get('tts_model') != model
                or row.get('speed') != speed or row.get('audio_format') != 'mp3'
                or row['storage_path'] != f'seed/{seed}/{voice}/{text_hash}.mp3'):
            raise RuntimeError(f'Seed content identity mismatch: {seed}')
        by_key[(seed, voice)] = row
    expected = {(seed, voice) for seed in allowed for voice in VOICES}
    if set(by_key) != expected:
        missing = ', '.join(sorted(f'{seed}:{voice}' for seed, voice in expected - set(by_key)))
        raise RuntimeError(f'Missing ready seed audio: {missing}')

    entries = dict(existing)
    def load(row):
        seed = row['seed_sentence_id']
        voice = row['voice_profile']
        filename = f'{seed}-{voice}.mp3'
        target = audio_dir / filename
        body = target.read_bytes() if target.exists() else b''
        if not valid_audio(body, row['sha256'], row['byte_size']):
            body = read('/storage/v1/object/authenticated/audio-assets/'
                        + urllib.parse.quote(row['storage_path'], safe='/'))
        if not valid_audio(body, row['sha256'], row['byte_size']):
            raise RuntimeError(f'Seed audio integrity mismatch: {filename}')
        return filename, row, body

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        verified = list(pool.map(load, [
            by_key[(seed, voice)]
            for seed in allowed
            for voice in VOICES
        ]))
    audio_dir.mkdir(parents=True, exist_ok=True)
    for filename, row, body in verified:
        target = audio_dir / filename
        if not target.exists() or target.read_bytes() != body:
            target.write_bytes(body)
        entries[f"{row['seed_sentence_id']}:{row['voice_profile']}"] = {
            'path': f'assets/audio/{filename}', 'sha256': row['sha256'],
            'byteSize': len(body), 'normalizerRevision': NORMALIZER_REVISION}
    return dict(sorted(entries.items()))


def package_local_native_audio(seeds, audio_dir, existing, source_audio_dir=None):
    """Package optional local native MP3s for offline seed loop listening."""
    entries = dict(existing)
    missing = []
    source_audio_dir = source_audio_dir or audio_dir
    index_path = source_audio_dir / 'audio-index.json'
    audio_index = json.loads(index_path.read_text(encoding='utf-8')) if index_path.exists() else {}
    for seed in seeds:
        for language in NATIVE_LANGUAGES:
            entries.pop(f"{seed['id']}:{SOURCE_VOICE}:{language}:native-gentle", None)
    for seed in seeds:
        seed_id = seed['id']
        for language in NATIVE_LANGUAGES:
            for profile in NATIVE_PROFILES:
                suffix = '' if profile == 'native-gentle' else f'-{profile}'
                filename = f'{seed_id}-{SOURCE_VOICE}-{language}{suffix}.mp3'
                source = source_audio_dir / filename
                target = audio_dir / filename
                if not source.exists():
                    if profile == 'native-gentle':
                        missing.append(f'{seed_id}-{SOURCE_VOICE}-{language}.mp3')
                    continue
                body = source.read_bytes()
                if not (body.startswith(b'ID3') or body[:1] == b'\xff'):
                    raise RuntimeError(f'Invalid native MP3: {filename}')
                entry = {
                    'path': f'assets/audio/{filename}',
                    'sha256': hashlib.sha256(body).hexdigest(),
                    'byteSize': len(body),
                }
                indexed = audio_index.get(
                    f'{seed_id}:{SOURCE_VOICE}:{language}:{profile}')
                if indexed is not None:
                    if (indexed.get('path') != filename
                            or indexed.get('sha256') != entry['sha256']
                            or indexed.get('byteSize') != entry['byteSize']
                            or indexed.get('normalizerRevision') != NORMALIZER_REVISION
                            or not isinstance(indexed.get('integratedLufs'), (int, float))
                            or abs(indexed['integratedLufs'] + 20.9) > 1.0
                            or not isinstance(indexed.get('truePeakDbtp'), (int, float))
                            or indexed['truePeakDbtp'] > -1.0):
                        raise RuntimeError(f'Native audio normalization proof mismatch: {filename}')
                    entry['normalizerRevision'] = NORMALIZER_REVISION
                if not target.exists() or target.read_bytes() != body:
                    target.write_bytes(body)
                if profile != 'native-gentle':
                    entries[f'{seed_id}:{SOURCE_VOICE}:{language}:{profile}'] = entry
                if profile == 'native-gentle':
                    entries[f'{seed_id}:{SOURCE_VOICE}:{language}'] = entry
    return dict(sorted(entries.items())), missing


def package_local_default_audio(seeds, audio_dir, existing, source_audio_dir):
    """Package the complete local English seed set with verified LUFS proof."""
    index_path = source_audio_dir / 'audio-index.json'
    if not index_path.exists():
        raise RuntimeError('Missing local English audio normalization index.')
    audio_index = json.loads(index_path.read_text(encoding='utf-8'))
    verified = []
    for seed in seeds:
        seed_id = seed['id']
        for voice in VOICES:
            filename = f'{seed_id}-{voice}.mp3'
            body = (source_audio_dir / filename).read_bytes()
            indexed = audio_index.get(f'{seed_id}:{voice}')
            if (
                indexed is None
                or indexed.get('path') != filename
                or not valid_audio(body, indexed.get('sha256'), indexed.get('byteSize'))
                or indexed.get('normalizerRevision') != NORMALIZER_REVISION
                or not isinstance(indexed.get('integratedLufs'), (int, float))
                or abs(indexed['integratedLufs'] + 20.9) > 1.0
                or not isinstance(indexed.get('truePeakDbtp'), (int, float))
                or indexed['truePeakDbtp'] > -1.0
            ):
                raise RuntimeError(f'Local English audio normalization proof mismatch: {filename}')
            verified.append((seed_id, voice, filename, body, indexed))

    audio_dir.mkdir(parents=True, exist_ok=True)
    entries = dict(existing)
    for seed_id, voice, filename, body, indexed in verified:
        target = audio_dir / filename
        if not target.exists() or target.read_bytes() != body:
            target.write_bytes(body)
        entries[f'{seed_id}:{voice}'] = {
            'path': f'assets/audio/{filename}',
            'sha256': indexed['sha256'],
            'byteSize': len(body),
            'normalizerRevision': NORMALIZER_REVISION,
        }
    return dict(sorted(entries.items()))


def configuration():
    values = dict(os.environ)
    config_file = ROOT / '.env'
    if config_file.exists():
        for line in config_file.read_text(encoding='utf-8-sig').splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                name, value = line.split('=', 1)
                values.setdefault(name.strip(), value.strip().strip('\"').strip("'"))
    return values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--local', action='store_true', help='Package existing local preview MP3s, without any network request.')
    parser.add_argument('--local-audio-dir', type=Path, default=DEFAULT_LOCAL_AUDIO_DIR)
    args = parser.parse_args()
    if args.local:
        source = args.local_audio_dir
        audio_dir = ASSETS / 'audio'
        manifest_path = ASSETS / 'content' / 'seed-audio.json'
        entries = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
        seed_path = ROOT / 'SeedContent' / 'seed-sentences.json'
        if not seed_path.exists():
            seed_path = ROOT / 'SelahFlutter' / 'assets' / 'content' / 'seed-sentences.json'
        seeds = json.loads(seed_path.read_text(encoding='utf-8'))['sentences']
        entries = package_local_default_audio(seeds, audio_dir, entries, source)
        entries, missing_native = package_local_native_audio(
            seeds, audio_dir, entries, source)
        if missing_native:
            raise RuntimeError('Missing required native seed audio: ' + ', '.join(missing_native))
        if not entries:
            raise RuntimeError('No existing local seed MP3 files found.')
        (ASSETS / 'content' / 'seed-audio.json').write_text(json.dumps(entries, indent=2), encoding='utf-8')
        unique_paths = {entry.get('path') for entry in entries.values() if entry.get('path')}
        print(
            f'Packaged {len(unique_paths)} unique local seed MP3 files across '
            f'{len(entries)} manifest entries; remote manifest comparison not performed. '
            f'Missing native MP3s: {len(missing_native)}'
        )
        if missing_native:
            print('Missing native files: ' + ', '.join(missing_native))
        return
    values = configuration()
    base = values.get('SUPABASE_URL', '').rstrip('/')
    key = values.get('SUPABASE_SERVICE_ROLE_KEY', '')
    if not base.startswith('https://') or not key:
        raise RuntimeError('Missing server-side packaging configuration.')
    headers = {'apikey': key, 'Authorization': f'Bearer {key}', 'User-Agent': 'SelahSeedPackager/1.0'}

    def read(path):
        request = urllib.request.Request(base + path, headers=headers)
        with urllib.request.urlopen(request, timeout=45) as response:
            return response.read()

    query = urllib.parse.urlencode({
        'select': 'seed_sentence_id,voice_profile,storage_path,content_hash,tts_model,speed,audio_format,sha256,byte_size',
        'seed_sentence_id': 'not.is.null', 'generation_status': 'eq.ready',
        'voice_profile': 'in.(gentle-natural,clear-slow,daily-bright,elegant-british)'})
    rows = json.loads(read('/rest/v1/audio_manifests?' + query))
    seeds = json.loads((ROOT / 'SeedContent' / 'seed-sentences.json').read_text(encoding='utf-8'))['sentences']
    audio_dir = ASSETS / 'audio'
    manifest_path = ASSETS / 'content' / 'seed-audio.json'
    existing = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
    entries = package_default_audio(rows, seeds, audio_dir, read, existing)
    (ASSETS / 'content').mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(entries, indent=2), encoding='utf-8')
    print(f'Verified {len(seeds) * len(VOICES)} seed MP3s across {len(VOICES)} voices. No AI generation was invoked.')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # HTTP exceptions never include request headers or server response bodies.
        print(f'Seed packaging failed: {type(error).__name__}: {error}')
        raise SystemExit(1)
