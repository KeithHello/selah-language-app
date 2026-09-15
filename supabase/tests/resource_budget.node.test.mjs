import assert from 'node:assert/strict';
import { test } from 'node:test';

const { parseSingleByteRange } = await import('../functions/_shared/resource_budget.ts');

test('parseSingleByteRange handles full request when no range header', () => {
  const parsed = parseSingleByteRange(null, 1000);
  assert.strictEqual(parsed.valid, true);
  assert.strictEqual(parsed.start, 0);
  assert.strictEqual(parsed.end, 999);
  assert.strictEqual(parsed.isMultiRange, false);
});
test('parseSingleByteRange parses valid single range', () => {
  const parsed = parseSingleByteRange('bytes=100-200', 1000);
  assert.strictEqual(parsed.valid, true);
  assert.strictEqual(parsed.start, 100);
  assert.strictEqual(parsed.end, 200);
  assert.strictEqual(parsed.isMultiRange, false);
});

test('parseSingleByteRange rejects multi-range headers', () => {
  const parsed = parseSingleByteRange('bytes=0-50,100-150', 1000);
  assert.strictEqual(parsed.valid, false);
  assert.strictEqual(parsed.isMultiRange, true);
});

test('parseSingleByteRange rejects out of bounds ranges', () => {
  const parsed = parseSingleByteRange('bytes=500-200', 1000);
  assert.strictEqual(parsed.valid, false);

  const parsedOver = parseSingleByteRange('bytes=0-1500', 1000);
  assert.strictEqual(parsedOver.valid, false);
});
