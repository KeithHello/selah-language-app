// Edge Function: /v1/membership/payment-webhook
// Verifies channel payment signature and idempotently activates membership.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
} from "../_shared/cors.ts";
import {
  validateWebhookNotification,
  verifyWebhookHmacSha256,
} from "../_shared/payment_contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse("Service unavailable", 503, "webhook_service_unavailable");
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }

  const validation = validateWebhookNotification(body);
  if (!validation.ok) {
    return errorResponse(validation.message, validation.status, validation.code);
  }

  const webhookSecret = Deno.env.get("MEMBERSHIP_PAYMENT_WEBHOOK_SECRET")?.trim() ?? "";
  if (!webhookSecret) {
    return errorResponse(
      "Payment webhook verification is not configured",
      503,
      "webhook_verification_unavailable",
    );
  }
  if (!(await verifyWebhookHmacSha256(validation.data, webhookSecret))) {
    return errorResponse("Invalid payment webhook signature", 401, "webhook_signature_invalid");
  }

  const { orderId, channelTransactionId, event } = validation.data;

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  if (event === "payment_succeeded") {
    const { data, error } = await supabase.rpc("apply_verified_payment", {
      p_order_id: orderId,
      p_channel_transaction_id: channelTransactionId,
    });

    if (error) {
      console.error("apply_verified_payment failed", error);
      return errorResponse("Payment reconciliation failed", 500, "reconciliation_failed");
    }

    return json({ success: true, result: data });
  }

  if (event === "payment_failed") {
    await supabase
      .from("membership_orders")
      .update({ status: "failed", channel_transaction_id: channelTransactionId })
      .eq("id", orderId)
      .eq("status", "pending");
    return json({ success: true, status: "failed" });
  }

  return errorResponse(
    "Refund reconciliation is not configured",
    503,
    "refund_reconciliation_unavailable",
  );
});
