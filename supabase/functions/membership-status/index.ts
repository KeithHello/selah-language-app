// deno-lint-ignore-file no-explicit-any
// Edge Function: /v1/membership/status
// Returns membership status, dates, entitlements, and current period usage.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  entitlementVersionForPlan,
  FREE_ENTITLEMENTS,
  type MembershipStatusResponse,
  MONTHLY_ENTITLEMENTS,
  PRO_ENTITLEMENTS,
  PRO_PRICE_FEN_CNY,
  TRIAL_ENTITLEMENTS,
  type TrialState,
  trialStateFromMembership,
} from "../_shared/membership_contract.ts";
import {
  environmentFallback,
  readServiceControls,
  type ServiceControlsClient,
} from "../_shared/service_controls.ts";
import { paymentProviderConfigured } from "../_shared/payment_contract.ts";
import {
  aggregateUsage,
  type FuturePeriod,
  limitsForPlan,
  type UsageSnapshot,
} from "../_shared/membership_usage.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "GET" && req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = requireAuth(req);
  if (auth instanceof Response) return auth;
  const userId = auth;

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
  const { data, error } = await supabase.rpc("get_user_membership_summary", {
    p_user_id: userId,
  });

  if (error || !data) {
    // Free/public mode must remain usable before the membership schema has been
    // deployed. Membership-enabled environments still fail closed below.
    if (!controls.membershipEnforcementEnabled && isMissingRpcError(error)) {
      const record: Record<string, unknown> = {
        plan: "free",
        status: "none",
      };
      return json(buildResponse(record, controls));
    }
    return errorResponse(
      "Failed to query membership status",
      500,
      "membership_query_failed",
    );
  }

  const record = data as Record<string, unknown>;
  if (!controls.membershipEnforcementEnabled) {
    return json(buildResponse(record, controls));
  }

  const liveUsage = await loadLiveUsage(supabase, userId, record);
  if (!liveUsage) {
    return errorResponse(
      "Failed to query membership status",
      500,
      "membership_query_failed",
    );
  }
  return json(
    buildResponse(record, controls, liveUsage.usage, liveUsage.futurePeriods),
  );
});

async function loadLiveUsage(
  supabase: any,
  userId: string,
  record: Record<string, unknown>,
): Promise<
  { usage: UsageSnapshot | null; futurePeriods: FuturePeriod[] } | null
> {
  const asOf = new Date().toISOString();
  const { data: current, error: currentError } = await supabase
    .from("user_memberships")
    .select("id")
    .eq("user_id", userId)
    .in("status", ["trial", "active"])
    .lte("started_at", asOf)
    .gt("expires_at", asOf)
    .order("expires_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (currentError) return null;

  const { data: scheduled, error: scheduledError } = await supabase
    .from("user_memberships")
    .select("id, plan, source, started_at, expires_at")
    .eq("user_id", userId)
    .in("status", ["trial", "active"])
    .gt("started_at", asOf)
    .order("started_at", { ascending: true });
  if (scheduledError || !scheduled) return null;

  const futureRows = scheduled as Array<{
    id: string;
    plan: string;
    source: string;
    started_at: string;
    expires_at: string;
  }>;
  const futurePeriods: FuturePeriod[] = futureRows.map((period) => ({
    id: period.id,
    plan: period.plan as FuturePeriod["plan"],
    source: period.source as FuturePeriod["source"],
    startsAt: period.started_at,
    endsAt: period.expires_at,
  }));

  if (!current) return { usage: null, futurePeriods };

  const { data: reservations, error: reservationsError } = await supabase
    .from("membership_reservations")
    .select("feature, status, units_reserved")
    .eq("membership_id", current.id);
  if (reservationsError || !reservations) return null;

  // aggregateUsage counts reserved, dispatch_claimed, settled, and unknown; released_unsent is excluded.
  const reservationRows = reservations as Array<{
    feature: string;
    status: string;
    units_reserved: number;
  }>;
  const usage = aggregateUsage(
    reservationRows.map((reservation) => ({
      feature: reservation.feature,
      status: reservation.status,
      units: reservation.units_reserved,
    })),
    limitsForPlan(String(record.plan ?? "free")),
    asOf,
  );
  return { usage, futurePeriods };
}

function isMissingRpcError(error: unknown): boolean {
  const message = typeof error === "object" && error !== null
    ? ((error as { message?: string }).message ?? "").toLowerCase()
    : String(error ?? "").toLowerCase();
  return message.includes("get_user_membership_summary") && (
    message.includes("not found") ||
    message.includes("does not exist") ||
    message.includes("could not find") ||
    message.includes("schema cache")
  );
}

function buildResponse(
  record: Record<string, unknown>,
  controls: Awaited<ReturnType<typeof readServiceControls>>,
  usage: UsageSnapshot | null = null,
  futurePeriods: FuturePeriod[] = [],
): MembershipStatusResponse {
  const plan = (record.plan as string) || "free";
  const status = (record.status as string) || "none";
  const trialState: TrialState = trialStateFromMembership(record);
  const trialStartedAt = typeof record.trialStartedAt === "string"
    ? record.trialStartedAt
    : typeof record.trial_started_at === "string"
    ? record.trial_started_at
    : plan === "trial" && typeof record.periodStartsAt === "string"
    ? record.periodStartsAt
    : null;
  const trialExpiresAt = typeof record.trialExpiresAt === "string"
    ? record.trialExpiresAt
    : typeof record.trial_expires_at === "string"
    ? record.trial_expires_at
    : plan === "trial" && typeof record.periodEndsAt === "string"
    ? record.periodEndsAt
    : null;

  const staticEntitlements = plan === "monthly" && status === "active"
    ? MONTHLY_ENTITLEMENTS
    : plan === "pro" && status === "active"
    ? PRO_ENTITLEMENTS
    : plan === "trial" && status === "trial"
    ? TRIAL_ENTITLEMENTS
    : FREE_ENTITLEMENTS;

  // Without a current membership period, return usage: null rather than a zero balance.
  return {
    membershipModeEnabled: controls.membershipEnforcementEnabled,
    trialSignupsEnabled: controls.trialSignupsEnabled,
    membershipSalesEnabled: controls.membershipSalesEnabled,
    // A pending order is not a payment integration. Keep checkout disabled
    // until a provider adapter and verified webhook path are deployed.
    paymentProviderConfigured: paymentProviderConfigured(),
    // Keep Pro visible as a deliberate, disabled contract until its
    // migration and provider adapter are live together.
    proSalesEnabled: false,
    proPriceFenCny: PRO_PRICE_FEN_CNY,
    proEntitlements: PRO_ENTITLEMENTS,
    trialState,
    trialStartedAt,
    trialExpiresAt,
    plan: (record.plan as any) ?? "free",
    status: (record.status as any) ?? "none",
    periodStartsAt: (record.periodStartsAt as string) || null,
    periodEndsAt: (record.periodEndsAt as string) || null,
    membershipSource: (record.membershipSource as any) || null,
    nextPeriodStartsAt: (record.nextPeriodStartsAt as string) || null,
    nextPeriodSource: (record.nextPeriodSource as any) || null,
    renewalMode: "manual",
    entitlementVersion: entitlementVersionForPlan(plan, status),
    modelDisclosure: "openai-gpt-4o-mini-v1",
    staticEntitlements,
    usage,
    futurePeriods,
  };
}
