import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  paymentProviderConfigured,
  validateWebhookNotification,
  verifyWebhookHmacSha256,
  type WebhookNotificationInput,
  webhookSigningPayload,
} from "./payment_contract.ts";

const NOW = Date.parse("2026-09-12T00:00:00.000Z");

function env(values: Record<string, string>): Pick<typeof Deno.env, "get"> {
  return { get: (name: string) => values[name] };
}

Deno.test("payment readiness requires an explicit adapter, provider and secret", () => {
  assertEquals(paymentProviderConfigured(env({})), false);
  assertEquals(
    paymentProviderConfigured(env({
      MEMBERSHIP_PAYMENT_PROVIDER: "stripe",
      MEMBERSHIP_PAYMENT_ADAPTER_READY: "true",
      MEMBERSHIP_PAYMENT_WEBHOOK_SECRET: "short",
    })),
    false,
  );
  assertEquals(
    paymentProviderConfigured(env({
      MEMBERSHIP_PAYMENT_PROVIDER: "stripe",
      MEMBERSHIP_PAYMENT_ADAPTER_READY: "true",
      MEMBERSHIP_PAYMENT_WEBHOOK_SECRET: "local-test-webhook-secret",
    })),
    true,
  );
});

function input(
  overrides: Partial<WebhookNotificationInput> = {},
): WebhookNotificationInput {
  return {
    channel: "test-channel",
    orderId: "order-123",
    channelTransactionId: "transaction-123",
    amountFenCny: 3990,
    currency: "CNY",
    signature: `sha256=${"00".repeat(32)}`,
    event: "payment_succeeded",
    timestamp: new Date(NOW).toISOString(),
    ...overrides,
  };
}

Deno.test("webhook validation requires the configured amount and currency", () => {
  const amount = validateWebhookNotification(
    input({ amountFenCny: 3989 }),
    NOW,
  );
  assertEquals(amount.ok, false);
  if (!amount.ok) assertEquals(amount.code, "payment_amount_mismatch");

  const currency = validateWebhookNotification(input({ currency: "USD" }), NOW);
  assertEquals(currency.ok, false);
  if (!currency.ok) assertEquals(currency.code, "payment_amount_mismatch");
});

Deno.test("webhook validation rejects missing signatures and stale events", () => {
  const missingSignature = validateWebhookNotification(
    input({ signature: "" }),
    NOW,
  );
  assertEquals(missingSignature.ok, false);
  if (!missingSignature.ok) {
    assertEquals(missingSignature.code, "invalid_webhook_fields");
  }

  const stale = validateWebhookNotification(
    input({ timestamp: "2026-09-11T23:00:00.000Z" }),
    NOW,
  );
  assertEquals(stale.ok, false);
  if (!stale.ok) assertEquals(stale.code, "stale_payment_event");
});

Deno.test("webhook validation rejects unsupported events", () => {
  const result = validateWebhookNotification(
    input({ event: "unknown_event" as WebhookNotificationInput["event"] }),
    NOW,
  );
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "unsupported_payment_event");
});

Deno.test("webhook HMAC verification uses the stable canonical payload", async () => {
  const secret = "local-test-webhook-secret";
  const unsigned = input();
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(webhookSigningPayload(unsigned)),
    ),
  );
  const signature = Array.from(
    digest,
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
  const checked = validateWebhookNotification(
    input({ signature: `sha256=${signature}` }),
    NOW,
  );
  assert(checked.ok);
  assert(await verifyWebhookHmacSha256(checked.data, secret));
  assertEquals(
    await verifyWebhookHmacSha256(checked.data, "wrong-secret-value"),
    false,
  );
});

Deno.test("public webhook is closed before verification and refund support exists only when wired", async () => {
  const source = await Deno.readTextFile(
    "supabase/functions/membership-payment-webhook/index.ts",
  );
  assert(
    source.indexOf("validateWebhookNotification") <
      source.indexOf("const supabase = createClient"),
  );
  assert(
    source.indexOf("MEMBERSHIP_PAYMENT_WEBHOOK_SECRET") <
      source.indexOf('supabase.rpc("apply_verified_payment"'),
  );
  assertStringIncludes(source, "webhook_verification_unavailable");
  assertStringIncludes(source, "refund_reconciliation_unavailable");
});
