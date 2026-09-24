// Edge Function: /v1/membership/checkout
// Creates a pending payment order for Monthly Membership.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  MONTHLY_PRICE_FEN_CNY,
  MONTHLY_SKU,
} from "../_shared/membership_contract.ts";
import {
  paymentProviderConfigured,
  validateCreateOrderInput,
} from "../_shared/payment_contract.ts";
import {
  environmentFallback,
  readServiceControls,
  type ServiceControlsClient,
} from "../_shared/service_controls.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = requireAuth(req);
  if (auth instanceof Response) return auth;
  const userId = auth;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse(
      "Service unavailable",
      503,
      "checkout_service_unavailable",
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }

  const validation = validateCreateOrderInput(body);
  if (!validation.ok) {
    return errorResponse(
      validation.message,
      validation.status,
      validation.code,
    );
  }

  const { clientRequestId, channel } = validation.data;
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const controls = await readServiceControls(
    supabase as unknown as ServiceControlsClient,
    environmentFallback(),
  );
  if (
    !controls.configured ||
    !controls.membershipEnforcementEnabled ||
    !controls.membershipSalesEnabled
  ) {
    return errorResponse(
      "Membership sales are not enabled",
      403,
      "membership_sales_disabled",
    );
  }
  if (!paymentProviderConfigured()) {
    return errorResponse(
      "Payment provider is not configured",
      503,
      "payment_provider_unavailable",
    );
  }

  // Check if order with this clientRequestId already exists
  const existing = await supabase
    .from("membership_orders")
    .select("*")
    .eq("user_id", userId)
    .eq("client_request_id", clientRequestId)
    .maybeSingle();

  if (existing.data) {
    return json({
      orderId: existing.data.id,
      clientRequestId: existing.data.client_request_id,
      sku: existing.data.sku,
      amountFenCny: existing.data.amount_fen_cny,
      currency: existing.data.currency,
      status: existing.data.status,
      channel: existing.data.channel,
      reused: true,
    });
  }

  const { data: inserted, error: insertError } = await supabase
    .from("membership_orders")
    .insert({
      user_id: userId,
      client_request_id: clientRequestId,
      sku: MONTHLY_SKU,
      amount_fen_cny: MONTHLY_PRICE_FEN_CNY,
      currency: "CNY",
      status: "pending",
      channel,
    })
    .select("*")
    .single();

  if (insertError || !inserted) {
    console.error("Order insert failed", insertError);
    return errorResponse(
      "Failed to create order",
      500,
      "order_creation_failed",
    );
  }

  return json({
    orderId: inserted.id,
    clientRequestId: inserted.client_request_id,
    sku: inserted.sku,
    amountFenCny: inserted.amount_fen_cny,
    currency: inserted.currency,
    status: inserted.status,
    channel: inserted.channel,
    reused: false,
  });
});
