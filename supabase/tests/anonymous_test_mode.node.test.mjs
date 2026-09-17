import assert from 'node:assert/strict';
import { test } from 'node:test';

const {
  authorizeBillableIdentity,
  getGatewayVerifiedIdentity,
} = await import('../functions/_shared/anonymous_test_mode.ts');

function requestWithClaims(claims) {
  const payload = Buffer.from(JSON.stringify(claims)).toString('base64url');
  return new Request('https://selah.test/v1/test', {
    headers: { Authorization: `Bearer header.${payload}.signature` },
  });
}

test('gateway identity reads a verified anonymous JWT claim', () => {
  const identity = getGatewayVerifiedIdentity(
    requestWithClaims({ sub: 'user-anon', is_anonymous: true }),
  );
  assert.deepEqual(identity, {
    userId: 'user-anon',
    isAnonymous: true,
  });
});

test('anonymous identity is allowed only while the test switch is enabled', async () => {
  const allowed = authorizeBillableIdentity(
    requestWithClaims({ sub: 'user-anon', is_anonymous: true }),
    { anonymousTestModeEnabled: true },
  );
  assert.equal(allowed.status, 'allowed');
  assert.equal(allowed.userId, 'user-anon');
  assert.equal(allowed.isAnonymous, true);

  const denied = authorizeBillableIdentity(
    requestWithClaims({ sub: 'user-anon', is_anonymous: true }),
    { anonymousTestModeEnabled: false },
  );
  assert.equal(denied.status, 403);
  const body = await denied.json();
  assert.equal(body.error, 'anonymous_test_ended');
});

test('registered identities are not controlled by the anonymous test switch', () => {
  const result = authorizeBillableIdentity(
    requestWithClaims({ sub: 'user-registered', is_anonymous: false }),
    { anonymousTestModeEnabled: false },
  );
  assert.equal(result.status, 'allowed');
  assert.equal(result.isAnonymous, false);
});

test('missing or malformed identity remains unauthorized', async () => {
  const missing = authorizeBillableIdentity(new Request('https://selah.test'), {
    anonymousTestModeEnabled: true,
  });
  assert.equal(missing.status, 401);
  assert.equal((await missing.json()).error, 'unauthorized');

  const malformed = authorizeBillableIdentity(
    new Request('https://selah.test', {
      headers: { Authorization: 'Bearer not-a-jwt' },
    }),
    { anonymousTestModeEnabled: true },
  );
  assert.equal(malformed.status, 401);
});
