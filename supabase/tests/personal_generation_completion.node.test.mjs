import assert from 'node:assert/strict';
import { test } from 'node:test';

const {
  completePersonalGeneration,
  PersonalGenerationCompletionError,
} = await import('../functions/_shared/personal_generation_completion.ts');

const item = {
  requestId: 'req-1',
  responsePayload: { targetText: 'I am ready.' },
};

test('completePersonalGeneration sends one atomic completion RPC', async () => {
  let call;
  const result = await completePersonalGeneration({
    rpc: async (name, args) => {
      call = { name, args };
      return {
        data: {
          items: [item],
          trialState: 'active',
          trialStartedAt: '2026-09-12T00:00:00.000Z',
          trialExpiresAt: '2026-09-19T00:00:00.000Z',
        },
        error: null,
      };
    },
  }, {
    userId: 'user-1',
    parentRequestId: 'parent-1',
    reservationId: 'reservation-1',
    items: [item],
  });

  assert.deepEqual(result.items, [item]);
  assert.equal(call.name, 'complete_personal_generation');
  assert.deepEqual(call.args, {
    p_user_id: 'user-1',
    p_parent_request_id: 'parent-1',
    p_reservation_id: 'reservation-1',
    p_items: [item],
  });
});

test('completion allows free-mode requests without a reservation', async () => {
  let reservation;
  await completePersonalGeneration({
    rpc: async (_name, args) => {
      reservation = args.p_reservation_id;
      return { data: { items: [item] }, error: null };
    },
  }, {
    userId: 'user-1',
    parentRequestId: 'parent-1',
    reservationId: null,
    items: [item],
  });
  assert.equal(reservation, null);
});

test('free mode falls back to the legacy completion RPC only when the new RPC is missing', async () => {
  const calls = [];
  const result = await completePersonalGeneration({
    rpc: async (name, args) => {
      calls.push({ name, args });
      if (name === 'complete_personal_generation') {
        return {
          data: null,
          error: { message: 'Could not find the function public.complete_personal_generation in the schema cache' },
        };
      }
      return { data: true, error: null };
    },
  }, {
    userId: 'user-1',
    parentRequestId: 'parent-1',
    reservationId: null,
    enforcementEnabled: false,
    items: [item],
  });

  assert.deepEqual(result.items, [item]);
  assert.deepEqual(calls.map(({ name }) => name), [
    'complete_personal_generation',
    'complete_generation_request',
  ]);
  assert.deepEqual(calls[1].args, {
    p_user_id: 'user-1',
    p_operation_type: 'sentence_generation',
    p_client_request_id: 'req-1',
    p_response_payload: item.responsePayload,
  });
});

test('membership mode never falls back when the atomic RPC is unavailable', async () => {
  let calls = 0;
  await assert.rejects(
    () => completePersonalGeneration({
      rpc: async () => {
        calls += 1;
        return {
          data: null,
          error: { message: 'Could not find the function public.complete_personal_generation in the schema cache' },
        };
      },
    }, {
      userId: 'user-1',
      parentRequestId: 'parent-1',
      reservationId: 'reservation-1',
      enforcementEnabled: true,
      items: [item],
    }),
    (error) => error instanceof PersonalGenerationCompletionError &&
      error.code === 'generation_completion_unavailable',
  );
  assert.equal(calls, 1);
});

test('completion rejects malformed item lists before calling the database', async () => {
  let calls = 0;
  await assert.rejects(
    () => completePersonalGeneration({
      rpc: async () => {
        calls += 1;
        return { data: { items: [] }, error: null };
      },
    }, {
      userId: 'user-1',
      parentRequestId: 'parent-1',
      reservationId: null,
      items: [{ requestId: '', responsePayload: {} }],
    }),
    (error) => error instanceof PersonalGenerationCompletionError &&
      error.code === 'invalid_completion_input',
  );
  assert.equal(calls, 0);
});

test('completion surfaces an unavailable RPC without treating output as saved', async () => {
  await assert.rejects(
    () => completePersonalGeneration({
      rpc: async () => ({
        data: null,
        error: { message: 'function unavailable' },
      }),
    }, {
      userId: 'user-1',
      parentRequestId: 'parent-1',
      reservationId: null,
      items: [item],
    }),
    (error) => error instanceof PersonalGenerationCompletionError &&
      error.code === 'generation_completion_unavailable',
  );
});
