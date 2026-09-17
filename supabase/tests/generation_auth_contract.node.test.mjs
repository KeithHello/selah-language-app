import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

const root = new URL('../', import.meta.url);
const config = await readFile(new URL('config.toml', root), 'utf8');

const functions = [
  ['sentences-generate', 'sentences-generate/index.ts'],
  ['sentences-batch-generate', 'sentences-batch-generate/index.ts'],
  ['sentences-prepare', 'sentences-prepare/index.ts'],
  ['audio-generate', 'audio-generate/index.ts'],
  ['audio-download', 'audio-download/index.ts'],
  ['speech-transcribe', 'speech-transcribe/index.ts'],
];

const billableFunctions = functions.filter(
  ([name]) => name !== 'audio-download',
);

for (const [name, sourcePath] of functions) {
  test(`${name} requires an authenticated session before provider work`, async () => {
    assert.match(config, new RegExp(`\\[functions\\.${name.replace('-', '\\-')}\\][\\s\\S]*?verify_jwt\\s*=\\s*true`));
    const source = await readFile(new URL(`functions/${sourcePath}`, root), 'utf8');
    if (name === 'audio-download') {
      assert.match(source, /requireAuth\(/);
    } else {
      assert.match(source, /authorizeBillableIdentity\(/);
      assert.match(
        source,
        /authorizeBillableIdentity\(req, controls\)|authorize\(req, controls\)/,
      );
    }
  });
}

for (const [name, sourcePath] of billableFunctions) {
  test(`${name} uses the membership enforcement switch instead of a hard quota gate`, async () => {
    const source = await readFile(new URL(`functions/${sourcePath}`, root), 'utf8');
    assert.match(source, /readServiceControls\(/);
    assert.match(
      source,
      /enforcementEnabled:\s*controls\.membershipEnforcementEnabled/,
    );
  });
}

test('sentence completion keeps legacy persistence available when enforcement is off', async () => {
  const completionSource = await readFile(
    new URL('functions/_shared/personal_generation_completion.ts', root),
    'utf8',
  );
  assert.match(
    completionSource,
    /input\.enforcementEnabled === false[\s\S]*isMissingPersonalCompletionRpc[\s\S]*completeLegacyGeneration/,
  );
});
