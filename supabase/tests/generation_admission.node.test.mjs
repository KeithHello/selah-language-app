import assert from 'node:assert/strict';
import { test } from 'node:test';

const {
  prepareAdmissionQuote,
  requestGenerationAdmission,
} = await import('../functions/_shared/generation_admission.ts');

test('prepareAdmissionQuote generates valid quote for single sentence', () => {
  const prep = prepareAdmissionQuote('sentence', {});
  assert.strictEqual(prep.ok, true);
  if (prep.ok) {
    assert.strictEqual(prep.quote.maxNanoUsd, '1843200');
    assert.strictEqual(prep.quote.currency, 'USD');
  }
});

test('prepareAdmissionQuote rejects invalid batch counts', () => {
  const prep = prepareAdmissionQuote('batch', { itemCount: 10 });
  assert.strictEqual(prep.ok, false);
  if (!prep.ok) {
    assert.strictEqual(prep.code, 'request_exceeds_feature_limit');
  }
});

test('requestGenerationAdmission approves valid request and returns reservationId', async () => {
  const mockClient = {
    rpc: async (name, args) => {
      assert.strictEqual(name, 'reserve_generation_allowance');
      assert.strictEqual(args.p_feature, 'sentence');
      return { data: 'res-uuid-1234', error: null };
    }
  };

  const res = await requestGenerationAdmission(mockClient, {
    userId: '11111111-1111-1111-1111-111111111111',
    clientRequestId: '22222222-2222-2222-2222-222222222222',
    feature: 'sentence',
    units: {},
    payloadHash: 'hash123',
  });

  assert.strictEqual(res.allowed, true);
  assert.strictEqual(res.reservationId, 'res-uuid-1234');
});

test('free mode bypasses membership reservation for registered users but still validates the request', async () => {
  let calls = 0;
  const res = await requestGenerationAdmission({
    rpc: async () => {
      calls += 1;
      throw new Error('reservation must not be called in free mode');
    },
  }, {
    userId: '11111111-1111-1111-1111-111111111111',
    clientRequestId: '22222222-2222-2222-2222-222222222222',
    feature: 'sentence',
    units: {},
    payloadHash: 'hash123',
    enforcementEnabled: false,
  });
  assert.strictEqual(res.allowed, true);
  assert.strictEqual(res.reservationId, undefined);
  assert.strictEqual(calls, 0);
});

test('registered membership mode reserves through membership entitlements', async () => {
  const calls = [];
  const res = await requestGenerationAdmission({
    rpc: async (name, args) => {
      calls.push({ name, args });
      return { data: { reservationId: 'membership-reservation' }, error: null };
    },
  }, {
    userId: '11111111-1111-1111-1111-111111111111',
    clientRequestId: '22222222-2222-2222-2222-222222222222',
    feature: 'sentence',
    units: {},
    payloadHash: 'hash123',
    enforcementEnabled: true,
  });
  assert.strictEqual(res.allowed, true);
  assert.strictEqual(res.reservationId, 'membership-reservation');
  assert.strictEqual(res.reservationScope, 'membership');
  assert.deepStrictEqual(calls.map(({ name }) => name), ['reserve_generation_allowance']);
});

test('free mode still rejects an unbounded request before any provider call', async () => {
  let calls = 0;
  const res = await requestGenerationAdmission({
    rpc: async () => {
      calls += 1;
      return { data: 'unexpected', error: null };
    },
  }, {
    userId: '11111111-1111-1111-1111-111111111111',
    clientRequestId: '22222222-2222-2222-2222-222222222222',
    feature: 'batch',
    units: { itemCount: 10 },
    payloadHash: 'hash123',
    enforcementEnabled: false,
  });
  assert.strictEqual(res.allowed, false);
  assert.strictEqual(res.errorCode, 'request_exceeds_feature_limit');
  assert.strictEqual(calls, 0);
});

test('registered users must reserve membership entitlement when enforcement is on', async () => {
  const calls = [];
  const res = await requestGenerationAdmission({
    rpc: async (name, args) => {
      calls.push({ name, args });
      return { data: null, error: { message: 'membership_required' } };
    },
  }, {
    userId: '11111111-1111-1111-1111-111111111111',
    clientRequestId: '22222222-2222-2222-2222-222222222222',
    feature: 'tts',
    units: { characters: 12 },
    payloadHash: 'hash123',
    enforcementEnabled: true,
  });

  assert.strictEqual(res.allowed, false);
  assert.strictEqual(res.errorCode, 'membership_required');
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0].name, 'reserve_generation_allowance');
});

test('requestGenerationAdmission translates RPC error codes accurately', async () => {
  const trialExpiredClient = {
    rpc: async () => ({ data: null, error: { message: 'trial_expired: trial period ended' } })
  };
  const resTrial = await requestGenerationAdmission(trialExpiredClient, {
    userId: '11111111-1111-1111-1111-111111111111',
    clientRequestId: '22222222-2222-2222-2222-222222222222',
    feature: 'sentence',
    units: {},
    payloadHash: 'hash123',
  });
  assert.strictEqual(resTrial.allowed, false);
  assert.strictEqual(resTrial.errorCode, 'trial_expired');

  const limitClient = {
    rpc: async () => ({ data: null, error: { message: 'feature_limit_reached: 30 sentences used' } })
  };
  const resLimit = await requestGenerationAdmission(limitClient, {
    userId: '11111111-1111-1111-1111-111111111111',
    clientRequestId: '22222222-2222-2222-2222-222222222222',
    feature: 'sentence',
    units: {},
    payloadHash: 'hash123',
  });
  assert.strictEqual(resLimit.allowed, false);
  assert.strictEqual(resLimit.errorCode, 'feature_limit_reached');
});
