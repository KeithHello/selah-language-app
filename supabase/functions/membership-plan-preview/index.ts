// Edge Function: /v1/membership/plan-preview
// Returns server-calculated plan-change quotes without creating orders.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import { paymentProviderConfigured } from "../_shared/payment_contract.ts";
import {
  environmentFallback,
  readServiceControls,
  type ServiceControlsClient,
} from "../_shared/service_controls.ts";
import {
  aggregateUsage,
  assertQuoteAction,
  legalPlanQuotes,
  limitsForPlan,
  type FuturePeriod,
  type ReservationUsageRow,
} from "../_shared/membership_usage.ts";

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

  const requestedAction = await readRequestedAction(req);
  if (!requestedAction.ok) {
    return errorResponse("Invalid request body", 400, "invalid_body");
  }
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse(
      "Service unavailable",
      503,
      "membership_service_unavailable",
    );
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const controls = await readServiceControls(
    supabase as unknown as ServiceControlsClient,
    environmentFallback(),
  );
  if (!controls.membershipEnforcementEnabled) {
    return errorResponse(
      "Membership mode is not enabled",
      403,
      "membership_mode_disabled",
    );
  }

  const asOf = new Date().toISOString();
  const { current, usage, futurePeriods, error } = await loadPlanState(
    supabase,
    auth,
    asOf,
  );
  if (error) {
    return errorResponse(
      "Failed to query membership status",
      500,
      "membership_query_failed",
    );
  }

  const quotes = legalPlanQuotes({
    now: asOf,
    current,
    usage,
    futurePeriods,
    salesEnabled: controls.membershipSalesEnabled,
    paymentConfigured: paymentProviderConfigured(),
    // Pro checkout and immediate entitlement changes remain gated pending the
    // separately approved payment and entitlement implementation.
    proSalesEnabled: false,
  });
  if (requestedAction.action !== null) {
    try {
      return json({
        quotes: [assertQuoteAction(quotes, requestedAction.action)],
      });
    } catch {
      return errorResponse(
        "Plan change is not available",
        409,
        "plan_change_not_available",
      );
    }
  }
  return json({ quotes });
});

async function readRequestedAction(
  req: Request,
): Promise<{ ok: true; action: string | null } | { ok: false }> {
  const text = await req.text();
  if (!text.trim()) return { ok: true, action: null };
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    return { ok: false };
  }
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return { ok: false };
  }
  const body = value as Record<string, unknown>;
  if (Object.keys(body).some((key) => key !== "action")) {
    return { ok: false };
  }
  if (body.action === undefined) return { ok: true, action: null };
  return typeof body.action === "string"
    ? { ok: true, action: body.action }
    : { ok: false };
}

async function loadPlanState(
  supabase: any,
  userId: string,
  asOf: string,
): Promise<{
  current: {
    plan: "trial" | "monthly" | "pro";
    startedAt: string;
    expiresAt: string;
  } | null;
  usage: ReturnType<typeof aggregateUsage> | null;
  futurePeriods: FuturePeriod[];
  error: boolean;
}> {
  const { data: currentRow, error: currentError } = await supabase
    .from("user_memberships")
    .select("id, plan, started_at, expires_at")
    .eq("user_id", userId)
    .in("status", ["trial", "active"])
    .lte("started_at", asOf)
    .gt("expires_at", asOf)
    .order("expires_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (currentError) {
    return { current: null, usage: null, futurePeriods: [], error: true };
  }

  const { data: futureRows, error: futureError } = await supabase
    .from("user_memberships")
    .select("id, plan, source, started_at, expires_at")
    .eq("user_id", userId)
    .in("status", ["trial", "active"])
    .gt("started_at", asOf)
    .order("started_at", { ascending: true });
  if (futureError || !futureRows) {
    return { current: null, usage: null, futurePeriods: [], error: true };
  }

  const futurePeriods: FuturePeriod[] = (futureRows as Array<{
    id: string;
    plan: string;
    source: string;
    started_at: string;
    expires_at: string;
  }>).map((period) => ({
    id: period.id,
    plan: period.plan as FuturePeriod["plan"],
    source: period.source as FuturePeriod["source"],
    startsAt: period.started_at,
    endsAt: period.expires_at,
  }));

  if (!currentRow) {
    return { current: null, usage: null, futurePeriods, error: false };
  }
  if (
    currentRow.plan !== "trial" && currentRow.plan !== "monthly" &&
    currentRow.plan !== "pro"
  ) {
    return { current: null, usage: null, futurePeriods: [], error: true };
  }

  const { data: reservationRows, error: reservationError } = await supabase
    .from("membership_reservations")
    .select("feature, status, units_reserved")
    .eq("membership_id", currentRow.id);
  if (reservationError || !reservationRows) {
    return { current: null, usage: null, futurePeriods: [], error: true };
  }
  const rows = (reservationRows as Array<{
    feature: string;
    status: string;
    units_reserved: number;
  }>).map((row): ReservationUsageRow => ({
    feature: row.feature,
    status: row.status,
    units: row.units_reserved,
  }));

  return {
    current: {
      plan: currentRow.plan,
      startedAt: currentRow.started_at,
      expiresAt: currentRow.expires_at,
    },
    usage: aggregateUsage(rows, limitsForPlan(currentRow.plan), asOf),
    futurePeriods,
    error: false,
  };
}
