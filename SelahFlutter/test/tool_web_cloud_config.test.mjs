import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const flutterRoot = join(here, '..');
const buildScript = readFileSync(
  join(flutterRoot, 'tool', 'web.ps1'),
  'utf8',
);
const serveScript = readFileSync(
  join(flutterRoot, 'tool', 'serve_release.js'),
  'utf8',
);

test('web build verifies that provided public Supabase config is bundled', () => {
  assert.match(buildScript, /mainDartJs[\s\S]*ReadAllText/);
  assert.match(buildScript, /SUPABASE_URL/);
  assert.match(buildScript, /Selah Web build is missing bundled Supabase public config/);
});

test('release server warns when serving a bundle without cloud login config', () => {
  assert.match(serveScript, /main\.dart\.js/);
  assert.match(serveScript, /Supabase project URL/i);
  assert.match(serveScript, /cloud login is unavailable/i);
});
