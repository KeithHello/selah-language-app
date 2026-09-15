// Edge Function: /v1/membership/order-status
// Polls status for a pending or completed membership order.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "GET" && req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = requireAuth(req);
  if (auth instanceof Response) return auth;
  const userId = auth;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse("Service unavailable", 503, "order_status_service_unavailable");
  }

  let orderId: string | null = null;
  let clientRequestId: string | null = null;

  if (req.method === "GET") {
    const url = new URL(req.url);
    orderId = url.searchParams.get("orderId");
    clientRequestId = url.searchParams.get("clientRequestId");
  } else {
    try {
      const body = await req.json() as Record<string, unknown>;
      orderId = typeof body.orderId === "string" ? body.orderId : null;
      clientRequestId = typeof body.clientRequestId === "string" ? body.clientRequestId : null;
    } catch {
      // Fall through
    }
  }

  if (!orderId && !clientRequestId) {
    return errorResponse("orderId or clientRequestId is required", 400, "missing_identifier");
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  let query = supabase
    .from("membership_orders")
    .select("*")
    .eq("user_id", userId);

  if (orderId) {
    query = query.eq("id", orderId);
  } else if (clientRequestId) {
    query = query.eq("client_request_id", clientRequestId);
  }

  const { data, error } = await query.maybeSingle();
  if (error || !data) {
    return errorResponse("Order not found", 404, "order_not_found");
  }

  return json({
    orderId: data.id,
    clientRequestId: data.client_request_id,
    sku: data.sku,
    amountFenCny: data.amount_fen_cny,
    currency: data.currency,
    status: data.status,
    channel: data.channel,
    verifiedAt: data.verified_at,
    createdAt: data.created_at,
  });
});
