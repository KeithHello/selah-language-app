import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { inflateSync } from 'node:zlib';

const actionIds = [
  'gentleFloat',
  'blink',
  'leafSway',
  'listenEnter',
  'listenPlaying',
  'listenComplete',
  'recRecording',
  'recDone',
  'quizGood',
  'quizFail',
];
const designRoot = new URL('../../design-system/selah/mascot/', import.meta.url);
const runtimeRoot = new URL('../assets/sprites/', import.meta.url);

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

function assertRgbPng(bytes, label) {
  assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', label);
  assert.equal(bytes.readUInt32BE(16), 1254, label);
  assert.equal(bytes.readUInt32BE(20), 1254, label);
  assert.equal(bytes[24], 8, label);
  assert.equal(bytes[25], 2, label);
}

test('the fifty original RGB design masters remain unchanged', async () => {
  const hashes = new Set();

  for (let stage = 1; stage <= 5; stage += 1) {
    const manifest = JSON.parse(
      await readFile(new URL(`seed-c-actions-v4-s${stage}-assets.json`, designRoot), 'utf8'),
    );
    assert.equal(manifest.status, 'complete');
    assert.equal(manifest.stage, stage);
    assert.equal(manifest.assets.length, 10);

    for (let action = 1; action <= 10; action += 1) {
      const suffix = String(action).padStart(2, '0');
      const entry = manifest.assets[action - 1];
      const design = await readFile(
        new URL(`seed-c-s${stage}-a${suffix}-v4.png`, designRoot),
      );
      const hash = sha256(design);

      assert.equal(entry.stage, stage);
      assert.equal(entry.actionIndex, action);
      assert.equal(entry.actionId, actionIds[action - 1]);
      assert.equal(entry.sha256, hash);
      assertRgbPng(design, `stage ${stage}, action ${action}`);
      assert.ok(!hashes.has(hash), `duplicate image at stage ${stage}, action ${action}`);
      hashes.add(hash);
    }
  }

  assert.equal(hashes.size, 50);
});

function decodeRgba(bytes) {
  assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  assert.equal(bytes[24], 8);
  assert.equal(bytes[25], 6, 'runtime images must contain an RGBA alpha channel');
  assert.equal(bytes[28], 0, 'non-interlaced PNG');
  const width = bytes.readUInt32BE(16);
  const height = bytes.readUInt32BE(20);
  const chunks = [];
  for (let offset = 8; offset < bytes.length;) {
    const length = bytes.readUInt32BE(offset);
    if (bytes.toString('ascii', offset + 4, offset + 8) === 'IDAT') {
      chunks.push(bytes.subarray(offset + 8, offset + 8 + length));
    }
    offset += length + 12;
  }
  const scanlines = inflateSync(Buffer.concat(chunks));
  const stride = width * 4;
  assert.equal(scanlines.length, (stride + 1) * height);
  const pixels = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y += 1) {
    const filter = scanlines[y * (stride + 1)];
    assert.ok(filter <= 4);
    for (let x = 0; x < stride; x += 1) {
      const at = y * stride + x;
      const left = x >= 4 ? pixels[at - 4] : 0;
      const up = y > 0 ? pixels[at - stride] : 0;
      const upperLeft = x >= 4 && y > 0 ? pixels[at - stride - 4] : 0;
      const p = left + up - upperLeft;
      const distances = [Math.abs(p - left), Math.abs(p - up), Math.abs(p - upperLeft)];
      const paeth = distances[0] <= distances[1] && distances[0] <= distances[2]
        ? left : distances[1] <= distances[2] ? up : upperLeft;
      const prediction = [0, left, up, Math.floor((left + up) / 2), paeth][filter];
      pixels[at] = (scanlines[y * (stride + 1) + x + 1] + prediction) & 255;
    }
  }
  return { width, height, pixels };
}

test('all fifty runtime poses have real transparent margins and solid characters', async () => {
  const manifest = JSON.parse(await readFile(
    new URL('seed-c-actions-v4-rgba-assets.json', designRoot), 'utf8',
  ));
  assert.equal(manifest.assets.length, 50);
  const files = new Set();
  for (const entry of manifest.assets) {
    const bytes = await readFile(new URL(entry.file, runtimeRoot));
    assert.match(entry.file, /^PlushV4S[1-5]A(0[1-9]|10)\.png$/);
    assert.ok(!files.has(entry.file));
    files.add(entry.file);
    assert.equal(sha256(bytes), entry.sha256);
    assert.equal(sha256(await readFile(new URL(entry.source, designRoot))), entry.sourceSha256);
    const { width, height, pixels } = decodeRgba(bytes);
    assert.equal(width, 768);
    assert.equal(height, 768);
    let transparent = 0;
    let partial = 0;
    let opaque = 0;
    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const alpha = pixels[(y * width + x) * 4 + 3];
        if (alpha === 0) transparent += 1;
        else if (alpha === 255) opaque += 1;
        else partial += 1;
        if (x === 0 || y === 0 || x === width - 1 || y === height - 1) {
          assert.equal(alpha, 0, `${entry.file} has opaque edges or a clipped pose`);
        }
      }
    }
    assert.ok(transparent > width * height * .3, entry.file);
    assert.ok(opaque > width * height * .15, entry.file);
    assert.ok(partial > 0, 'soft antialiased edges');
    assert.equal(transparent, entry.transparentPixels);
    assert.equal(partial, entry.partialPixels);
    assert.equal(opaque, entry.opaquePixels);
  }
});
