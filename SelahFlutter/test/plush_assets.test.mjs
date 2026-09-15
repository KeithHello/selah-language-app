import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';

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

test('all fifty website runtime poses use stable fixed-pose GIF bytes', async () => {
  const manifest = JSON.parse(await readFile(
    new URL('./fixtures/plush_fixed_pose_gifs.json', import.meta.url), 'utf8',
  ));
  assert.equal(manifest.version, 'fixed-pose-gifs-v1');
  assert.equal(manifest.files.length, 50);
  const files = new Set();
  for (const entry of manifest.files) {
    const bytes = await readFile(new URL(entry.file, runtimeRoot));
    const gifCopy = await readFile(new URL(entry.file.replace(/\.png$/, '.gif'), runtimeRoot));
    assert.match(entry.file, /^PlushV4S[1-5]A(0[1-9]|10)\.png$/);
    assert.equal(files.has(entry.file), false);
    files.add(entry.file);
    assert.equal(sha256(bytes), entry.sha256);
    assert.deepEqual(bytes, gifCopy, `${entry.file} and its GIF copy must be identical`);
    assert.equal(bytes.subarray(0, 6).toString('ascii'), 'GIF89a');
    assert.deepEqual([entry.canvasWidth, entry.canvasHeight], [768, 768]);
    assert.equal(entry.frameCount, 16);
    assert.equal(entry.loopCount, 0);
    assert.equal(entry.durationsMs.length, 16);
    assert.ok(entry.minMarginPixels >= 120);
    assert.ok(entry.widthJumpPixels <= 10);
    assert.ok(entry.heightJumpPixels <= 8);
  }
});
