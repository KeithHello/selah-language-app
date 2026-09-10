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
        content_hash = hashlib.sha256(
            f'{canonical}|{voice}|tts-1|0.85|mp3'.encode()).hexdigest()
        if (row.get('content_hash') != content_hash or row.get('tts_model') != 'tts-1'
                or row.get('speed') != 0.85 or row.get('audio_format') != 'mp3'
                or row['storage_path'] != f'seed/{seed}/{voice}/{content_hash}.mp3'):
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
            'path': f'assets/audio/{filename}', 'sha256': row['sha256'], 'byteSize': len(body)}
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
    args = parser.parse_args()
    if args.local:
        source = ROOT / 'preview-output' / 'selah-default-voice'
        audio_dir = ASSETS / 'audio'
        audio_dir.mkdir(parents=True, exist_ok=True)
        manifest_path = ASSETS / 'content' / 'seed-audio.json'
        entries = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {}
        for item in sorted(source.glob('seed-*.mp3')):
            body = item.read_bytes()
            if not (body.startswith(b'ID3') or body[:1] == b'\xff'):
                raise RuntimeError(f'Invalid local MP3: {item.name}')
            seed, voice = item.stem[:8], item.stem[9:]
            (audio_dir / item.name).write_bytes(body)
            entries[f'{seed}:{voice}'] = {'path': f'assets/audio/{item.name}',
                'sha256': hashlib.sha256(body).hexdigest(), 'byteSize': len(body)}
        if not entries:
            raise RuntimeError('No existing local seed MP3 files found.')
        (ASSETS / 'content' / 'seed-audio.json').write_text(json.dumps(entries, indent=2), encoding='utf-8')
        print(f'Packaged {len(entries)} existing local seed MP3s with content hashes; remote manifest comparison not performed.')
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
