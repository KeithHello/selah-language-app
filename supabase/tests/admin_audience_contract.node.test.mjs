import assert from 'node:assert/strict';
import { test } from 'node:test';

const {
  AUDIENCE_DIMENSIONS,
  normalizeAudienceQuery,
} = await import('../functions/_shared/admin_audience_contract.ts');

test('accepts one supported audience dimension and returns a bounded UTC range', () => {
  const result = normalizeAudienceQuery({
    dimension: 'ageGroup',
    start: '2026-09-01T00:00:00Z',
    end: '2026-09-08T00:00:00Z',
  });
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.equal(result.dimension, 'ageGroup');
    assert.equal(result.start, '2026-09-01T00:00:00.000Z');
    assert.equal(result.end, '2026-09-08T00:00:00.000Z');
  }
});
test('rejects unknown dimensions and unbounded ranges', () => {
  const unknown = normalizeAudienceQuery({
    dimension: 'email',
    start: '2026-09-01T00:00:00Z',
    end: '2026-09-08T00:00:00Z',
  });
  assert.equal(unknown.ok, false);
  if (!unknown.ok) assert.equal(unknown.code, 'invalid_dimension');

  const tooLong = normalizeAudienceQuery({
    dimension: 'gender',
    start: '2026-01-01T00:00:00Z',
    end: '2026-06-01T00:00:00Z',
  });
  assert.equal(tooLong.ok, false);
  if (!tooLong.ok) assert.equal(tooLong.code, 'invalid_period');
});

test('keeps the first release dimensions explicit', () => {
  assert.deepEqual(AUDIENCE_DIMENSIONS, [
    'learningGoal',
    'englishLevel',
    'ageGroup',
    'lifeStage',
    'gender',
  ]);
});
