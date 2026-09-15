// Edge Function: /v1/membership/status
// Returns membership status, dates, and immutable static entitlements without returning live usage balances.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  FREE_ENTITLEMENTS,
  MONTHLY_ENTITLEMENTS,
  PRO_ENTITLEMENTS,
  PRO_PRICE_FEN_CNY,
  TRIAL_ENTITLEMENTS,
  entitlementVersionForPlan,
  trialStateFromMembership,
  type TrialState,
  type MembershipStatusResponse,
} from "../_shared/membership_contract.ts";
import {
  environmentFallback,
  readServiceControls,
  type ServiceControlsClient,
} from "../_shared/service_controls.ts";
import { paymentProviderConfigured } from "../_shared/payment_contract.ts";

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
    return errorResponse("Service unavailable", 503, "membership_service_unavailable");
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
    return errorResponse("Failed to query membership status", 500, "membership_query_failed");
  }

  const record = data as Record<string, unknown>;
  return json(buildResponse(record, controls));
});

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

  const staticEntitlements =
    plan === "monthly" && status === "active"
      ? MONTHLY_ENTITLEMENTS
      : plan === "pro" && status === "active"
      ? PRO_ENTITLEMENTS
      : plan === "trial" && status === "trial"
      ? TRIAL_ENTITLEMENTS
      : FREE_ENTITLEMENTS;

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
  };
}
