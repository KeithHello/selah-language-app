// Payment contract for Selah Monthly Membership SKU orders, webhooks and reconciliation.

import { MONTHLY_PRICE_FEN_CNY, MONTHLY_SKU } from "./membership_contract.ts";

const SUPPORTED_PAYMENT_PROVIDERS = new Set(["alipay", "wechat", "stripe"]);

function envFlag(value: string | undefined): boolean {
  const normalized = value?.trim().toLowerCase();
  return normalized === "1" || normalized === "true" ||
    normalized === "yes" || normalized === "on";
}

/**
 * Checkout stays closed until a real provider adapter, a supported provider
 * name and a sufficiently long webhook secret are deployed together. The
 * flag is an explicit release gate; it is not a payment implementation.
 */
export function paymentProviderConfigured(
  env: Pick<typeof Deno.env, "get"> = Deno.env,
): boolean {
  const provider =
    env.get("MEMBERSHIP_PAYMENT_PROVIDER")?.trim().toLowerCase() ?? "";
  const webhookSecret = env.get("MEMBERSHIP_PAYMENT_WEBHOOK_SECRET")?.trim() ??
    "";
  return envFlag(env.get("MEMBERSHIP_PAYMENT_ADAPTER_READY")) &&
    SUPPORTED_PAYMENT_PROVIDERS.has(provider) && webhookSecret.length >= 16;
}

export type PaymentOrderStatus = "pending" | "paid" | "failed" | "refunded";

export interface CreateOrderInput {
  userId: string;
  clientRequestId: string;
  sku?: string;
  amountFenCny?: number;
  channel?: string;
}

export interface MembershipOrderRecord {
  id: string;
  userId: string;
  clientRequestId: string;
  sku: string;
  amountFenCny: number;
  currency: "CNY";
  status: PaymentOrderStatus;
  channel: string;
  channelOrderId?: string | null;
  channelTransactionId?: string | null;
  verifiedAt?: string | null;
  createdAt: string;
}

export interface WebhookNotificationInput {
  channel: string;
  orderId: string;
  channelTransactionId: string;
  amountFenCny: number;
  currency: string;
  signature: string;
  event: "payment_succeeded" | "payment_failed" | "refund_processed";
  timestamp: string;
}

const WEBHOOK_EVENTS = new Set<WebhookNotificationInput["event"]>([
  "payment_succeeded",
  "payment_failed",
  "refund_processed",
]);
const WEBHOOK_MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;

export type WebhookValidationResult =
  | { ok: true; data: WebhookNotificationInput }
  | { ok: false; status: number; code: string; message: string };

/**
 * Validates the channel-neutral webhook envelope before any database call.
 * A concrete provider adapter must map its signed payload to this envelope.
 */
export function validateWebhookNotification(
  body: unknown,
  nowMs: number = Date.now(),
): WebhookValidationResult {
  if (!body || typeof body !== "object") {
    return {
      ok: false,
      status: 400,
      code: "invalid_body",
      message: "Body must be an object",
    };
  }
  const candidate = body as Record<string, unknown>;
  const channel = typeof candidate.channel === "string"
    ? candidate.channel.trim().toLowerCase()
    : "";
  const orderId = typeof candidate.orderId === "string"
    ? candidate.orderId.trim()
    : "";
  const channelTransactionId =
    typeof candidate.channelTransactionId === "string"
      ? candidate.channelTransactionId.trim()
      : "";
  const signature = typeof candidate.signature === "string"
    ? candidate.signature.trim()
    : "";
  const timestamp = typeof candidate.timestamp === "string"
    ? candidate.timestamp.trim()
    : "";
  const event = candidate.event;
  const currency = typeof candidate.currency === "string"
    ? candidate.currency.trim().toUpperCase()
    : "";

  if (
    !channel || channel.length > 100 || !orderId || orderId.length > 200 ||
    !channelTransactionId || channelTransactionId.length > 200 || !signature
  ) {
    return {
      ok: false,
      status: 400,
      code: "invalid_webhook_fields",
      message:
        "channel, orderId, channelTransactionId and signature are required",
    };
  }
  if (candidate.amountFenCny !== MONTHLY_PRICE_FEN_CNY || currency !== "CNY") {
    return {
      ok: false,
      status: 400,
      code: "payment_amount_mismatch",
      message: "Only the configured CNY membership amount is accepted",
    };
  }
  if (
    typeof event !== "string" ||
    !WEBHOOK_EVENTS.has(event as WebhookNotificationInput["event"])
  ) {
    return {
      ok: false,
      status: 400,
      code: "unsupported_payment_event",
      message: "Unsupported payment event",
    };
  }
  const timestampMs = Date.parse(timestamp);
  if (
    !timestamp || Number.isNaN(timestampMs) ||
    Math.abs(nowMs - timestampMs) > WEBHOOK_MAX_CLOCK_SKEW_MS
  ) {
    return {
      ok: false,
      status: 400,
      code: "stale_payment_event",
      message: "Payment event timestamp is invalid or stale",
    };
  }

  return {
    ok: true,
    data: {
      channel,
      orderId,
      channelTransactionId,
      amountFenCny: MONTHLY_PRICE_FEN_CNY,
      currency,
      signature,
      event: event as WebhookNotificationInput["event"],
      timestamp,
    },
  };
}

/** Stable payload passed to the selected channel's HMAC adapter. */
export function webhookSigningPayload(input: WebhookNotificationInput): string {
  return [
    input.channel.trim().toLowerCase(),
    input.orderId.trim(),
    input.channelTransactionId.trim(),
    String(input.amountFenCny),
    input.currency.trim().toUpperCase(),
    input.event,
    input.timestamp.trim(),
  ].join("\n");
}

function decodeHex(value: string): Uint8Array | null {
  if (!/^[0-9a-f]{64}$/i.test(value)) return null;
  const bytes = new Uint8Array(32);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
}

function encodeHex(value: Uint8Array): string {
  return Array.from(value, (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
}

/**
 * Verifies the repository's channel-neutral HMAC-SHA256 envelope. The
 * production endpoint remains closed until a selected provider maps its
 * official signature to this exact payload and supplies the secret.
 */
export async function verifyWebhookHmacSha256(
  input: WebhookNotificationInput,
  secret: string,
): Promise<boolean> {
  const normalizedSecret = secret.trim();
  if (normalizedSecret.length < 16) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(normalizedSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(webhookSigningPayload(input)),
    ),
  );
  const supplied = input.signature.trim().toLowerCase().replace(/^sha256=/, "");
  const suppliedBytes = decodeHex(supplied);
  if (!suppliedBytes || suppliedBytes.length !== digest.length) return false;
  let difference = 0;
  for (let index = 0; index < digest.length; index += 1) {
    difference |= suppliedBytes[index] ^ digest[index];
  }
  return difference === 0;
}

export function validateCreateOrderInput(body: unknown): {
  ok: true;
  data: {
    clientRequestId: string;
    sku: string;
    amountFenCny: number;
    channel: string;
  };
} | { ok: false; status: number; code: string; message: string } {
  if (!body || typeof body !== "object") {
    return {
      ok: false,
      status: 400,
      code: "invalid_body",
      message: "Body must be an object",
    };
  }
  const candidate = body as Record<string, unknown>;
  const clientRequestId = typeof candidate.clientRequestId === "string"
    ? candidate.clientRequestId.trim().toLowerCase()
    : "";
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(clientRequestId)
  ) {
    return {
      ok: false,
      status: 400,
      code: "invalid_client_request_id",
      message: "Valid clientRequestId is required",
    };
  }
  const sku = typeof candidate.sku === "string" && candidate.sku.trim()
    ? candidate.sku.trim()
    : MONTHLY_SKU;
  if (sku !== MONTHLY_SKU) {
    return {
      ok: false,
      status: 400,
      code: "invalid_sku",
      message: `Only SKU ${MONTHLY_SKU} is supported`,
    };
  }
  const channel =
    typeof candidate.channel === "string" && candidate.channel.trim()
      ? candidate.channel.trim().toLowerCase()
      : "mock_channel";

  return {
    ok: true,
    data: {
      clientRequestId,
      sku,
      amountFenCny: MONTHLY_PRICE_FEN_CNY,
      channel,
    },
  };
}
