// Edge Function: /v1/admin/membership-actions
// Executes administrative membership operations (grant, compensate, revoke, replay order).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  AdminMembershipActionRequest,
  AdminMembershipActionType,
} from "../_shared/admin_membership_contract.ts";
import { calculateMonthlyPeriods } from "../_shared/membership_contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function validateAdminMembershipAction(
  body: Partial<AdminMembershipActionRequest>,
): { ok: true } | { ok: false; status: number; code: string; message: string } {
  if (!body.action || !body.targetUserId || !body.reason || !body.clientRequestId) {
    return {
      ok: false,
      status: 400,
      code: "missing_fields",
      message: "action, targetUserId, reason, and clientRequestId are required",
    };
  }
  if (!UUID_PATTERN.test(body.targetUserId) || !UUID_PATTERN.test(body.clientRequestId)) {
    return {
      ok: false,
      status: 400,
      code: "invalid_identifier",
      message: "targetUserId and clientRequestId must be UUIDs",
    };
  }
  const actions: AdminMembershipActionType[] = [
    "grant_membership",
    "compensate_membership",
    "revoke_grant",
    "replay_order",
    "record_manual_payment",
    "toggle_generation_service",
  ];
  if (!actions.includes(body.action as AdminMembershipActionType)) {
    return { ok: false, status: 400, code: "unsupported_action", message: "Unsupported action" };
  }
  if (body.reason.trim().length < 3 || body.reason.trim().length > 500) {
    return { ok: false, status: 400, code: "invalid_reason", message: "A concise reason is required" };
  }
  if (body.months != null && (!Number.isInteger(body.months) || body.months < 1 || body.months > 12)) {
    return { ok: false, status: 400, code: "invalid_months", message: "months must be between 1 and 12" };
  }
  if (body.action === "replay_order" && !body.orderId) {
    return { ok: false, status: 400, code: "missing_order_id", message: "orderId is required" };
  }
  if (body.action === "revoke_grant" && !body.membershipId) {
    return { ok: false, status: 400, code: "missing_membership_id", message: "membershipId is required" };
  }
  if (body.action === "record_manual_payment" &&
      (!body.channel || !body.transactionId || body.amountFenCny !== 3990)) {
    return {
      ok: false,
      status: 400,
      code: "invalid_manual_payment",
      message: "A verified channel, unique transactionId and exact amount are required",
    };
  }
  if (body.action === "toggle_generation_service") {
    return {
      ok: false,
      status: 400,
      code: "use_service_controls",
      message: "Use the service controls endpoint for platform switches",
    };
  }
  return { ok: true };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = requireAuth(req);
  if (auth instanceof Response) return auth;
  const operatorId = auth;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse("Admin service unavailable", 503, "admin_unavailable");
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: isAdmin } = await supabase.rpc("is_admin_member", { p_user_id: operatorId });
  if (isAdmin !== true) {
    return errorResponse("Admin access required", 403, "admin_forbidden");
  }
  const { data: isOperator, error: operatorError } = await supabase.rpc(
    "is_admin_operator",
    { p_user_id: operatorId },
  );
  if (operatorError || isOperator !== true) {
    return errorResponse("Management permission required", 403, "admin_write_forbidden");
  }

  let body: AdminMembershipActionRequest;
  try {
    body = await req.json() as AdminMembershipActionRequest;
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }

  const validation = validateAdminMembershipAction(body);
  if (!validation.ok) {
    return errorResponse(validation.message, validation.status, validation.code);
  }
  const { action, targetUserId, months, reason, clientRequestId } = body;

  // All high-impact changes should be committed by one database transaction
  // that reserves future capacity and writes its audit row atomically. The
  // legacy direct insert is opt-in for local migration previews only.
  const atomic = await supabase.rpc("admin_apply_membership_action", {
    p_admin_user_id: operatorId,
    p_target_user_id: targetUserId,
    p_action: action,
    p_months: months ?? 1,
    p_reason: reason.trim(),
    p_client_request_id: clientRequestId,
    p_order_id: body.orderId ?? null,
    p_membership_id: body.membershipId ?? null,
    p_channel: body.channel ?? null,
    p_transaction_id: body.transactionId ?? null,
    p_amount_fen_cny: body.amountFenCny ?? null,
  });
  if (!atomic.error && atomic.data != null) {
    return json({ success: true, action, result: atomic.data });
  }
  if (Deno.env.get("ALLOW_LEGACY_ADMIN_GRANT") !== "true") {
    return errorResponse(
      "Atomic membership operation is not configured",
      503,
      "admin_action_unavailable",
    );
  }

  if (action === "grant_membership" || action === "compensate_membership") {
    const grantMonths = Math.max(1, Math.min(months ?? 1, 12));
    const source = action === "compensate_membership" ? "compensation" : "grant";

    // Find current active/queued periods to determine start date
    const { data: latest } = await supabase
      .from("user_memberships")
      .select("expires_at")
      .eq("user_id", targetUserId)
      .gt("expires_at", new Date().toISOString())
      .order("expires_at", { ascending: false })
      .limit(1);

    const startDate = latest && latest.length > 0
      ? new Date(latest[0].expires_at)
      : new Date();

    const periods = calculateMonthlyPeriods(startDate, grantMonths);
    const insertedRows = periods.map((p, idx) => ({
      user_id: targetUserId,
      plan: "monthly",
      status: "active",
      source,
      started_at: p.startsAt.toISOString(),
      expires_at: p.endsAt.toISOString(),
      period_index: idx + 1,
      total_periods: grantMonths,
      grant_reason: reason,
      granted_by: operatorId,
    }));

    const { data: created, error: insertError } = await supabase
      .from("user_memberships")
      .insert(insertedRows)
      .select("*");

    if (insertError) {
      console.error("Grant insertion failed", insertError);
      return errorResponse("Failed to grant membership", 500, "grant_failed");
    }

    // Record audit log
    await supabase.from("admin_audit_logs").insert({
      operator_id: operatorId,
      target_user_id: targetUserId,
      action,
      reason,
      client_request_id: clientRequestId,
      new_state: { grantedMonths: grantMonths, source, periods: created },
    });

    return json({
      success: true,
      action,
      grantedMonths: grantMonths,
      periods: created,
    });
  }

  if (action === "replay_order" && body.orderId) {
    const { data: replayed, error: replayError } = await supabase.rpc("apply_verified_payment", {
      p_order_id: body.orderId,
      p_channel_transaction_id: body.transactionId ?? "manual_replay",
    });
    if (replayError) {
      return errorResponse("Failed to replay order", 500, "replay_failed");
    }
    await supabase.from("admin_audit_logs").insert({
      operator_id: operatorId,
      target_user_id: targetUserId,
      action: "replay_order",
      reason,
      client_request_id: clientRequestId,
      new_state: { orderId: body.orderId, result: replayed },
    });
    return json({ success: true, result: replayed });
  }

  return errorResponse("Unsupported action", 400, "unsupported_action");
});
