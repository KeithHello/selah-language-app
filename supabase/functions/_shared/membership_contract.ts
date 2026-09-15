// Immutable membership and trial entitlement contract for Selah.
// Pricing, quotas, and period boundaries are defined here.

export const MEMBERSHIP_ENTITLEMENT_VERSION = "monthly-v1";
export const TRIAL_ENTITLEMENT_VERSION = "trial-v1";

export const TRIAL_MAX_SENTENCES = 30;
export const TRIAL_MAX_TTS_CHARACTERS = 3000;
export const TRIAL_MAX_TRANSCRIPTION_MS = 300_000;
export const TRIAL_MAX_PREPARATIONS = 3;
export const TRIAL_DURATION_HOURS = 168;

export const MONTHLY_MAX_SENTENCES = 300;
export const MONTHLY_MAX_TTS_CHARACTERS = 30000;
export const MONTHLY_MAX_TRANSCRIPTION_MS = 3_600_000;
export const MONTHLY_MAX_PREPARATIONS = 30;
export const MONTHLY_PRICE_FEN_CNY = 3990;
export const MONTHLY_SKU = "selah_membership_monthly";

// Pro is a versioned, server-visible product contract.  It remains disabled
// until a database migration and a verified provider adapter are approved.
export const PRO_ENTITLEMENT_VERSION = "pro-v1";
export const PRO_MAX_SENTENCES = 900;
export const PRO_MAX_TTS_CHARACTERS = 90000;
export const PRO_MAX_TRANSCRIPTION_MS = 10_800_000;
export const PRO_MAX_PREPARATIONS = 90;
export const PRO_PRICE_FEN_CNY = 9990;
export const PRO_SKU = "selah_membership_pro";

export type MembershipPlan = "free" | "trial" | "monthly" | "pro";
export type MembershipStatus = "none" | "trial" | "active" | "expired";
export const TRIAL_STATES = [
  "not_started",
  "preparing",
  "active",
  "expired",
  "unavailable",
] as const;
export type TrialState = (typeof TRIAL_STATES)[number];
export type MembershipSource =
  | "paid"
  | "grant"
  | "compensation"
  | "system_trial";
export type RenewalMode = "manual";

export type EntitlementFeature =
  | "sentence"
  | "tts"
  | "transcription"
  | "preparation";

export interface PlanEntitlements {
  maxSentences: number;
  maxTtsCharacters: number;
  maxTranscriptionMs: number;
  maxPreparations: number;
}

export const FREE_ENTITLEMENTS: PlanEntitlements = Object.freeze({
  maxSentences: 0,
  maxTtsCharacters: 0,
  maxTranscriptionMs: 0,
  maxPreparations: 0,
});

export const TRIAL_ENTITLEMENTS: PlanEntitlements = Object.freeze({
  maxSentences: TRIAL_MAX_SENTENCES,
  maxTtsCharacters: TRIAL_MAX_TTS_CHARACTERS,
  maxTranscriptionMs: TRIAL_MAX_TRANSCRIPTION_MS,
  maxPreparations: TRIAL_MAX_PREPARATIONS,
});

export const MONTHLY_ENTITLEMENTS: PlanEntitlements = Object.freeze({
  maxSentences: MONTHLY_MAX_SENTENCES,
  maxTtsCharacters: MONTHLY_MAX_TTS_CHARACTERS,
  maxTranscriptionMs: MONTHLY_MAX_TRANSCRIPTION_MS,
  maxPreparations: MONTHLY_MAX_PREPARATIONS,
});

export const PRO_ENTITLEMENTS: PlanEntitlements = Object.freeze({
  maxSentences: PRO_MAX_SENTENCES,
  maxTtsCharacters: PRO_MAX_TTS_CHARACTERS,
  maxTranscriptionMs: PRO_MAX_TRANSCRIPTION_MS,
  maxPreparations: PRO_MAX_PREPARATIONS,
});

export interface MembershipPeriod {
  id: string;
  userId: string;
  plan: MembershipPlan;
  source: MembershipSource;
  startedAt: string;
  expiresAt: string;
  periodIndex: number;
  totalPeriods: number;
}

export interface MembershipStatusResponse {
  membershipModeEnabled: boolean;
  trialSignupsEnabled: boolean;
  membershipSalesEnabled: boolean;
  paymentProviderConfigured?: boolean;
  proSalesEnabled?: boolean;
  proPriceFenCny?: number;
  proEntitlements?: PlanEntitlements;
  trialState: TrialState;
  trialStartedAt: string | null;
  trialExpiresAt: string | null;
  plan: MembershipPlan;
  status: MembershipStatus;
  periodStartsAt: string | null;
  periodEndsAt: string | null;
  membershipSource: MembershipSource | null;
  nextPeriodStartsAt: string | null;
  nextPeriodSource: MembershipSource | null;
  renewalMode: RenewalMode;
  entitlementVersion: string;
  modelDisclosure: string;
  staticEntitlements: PlanEntitlements;
}

export function entitlementVersionForPlan(
  plan: unknown,
  status: unknown,
): string {
  if (plan === "pro" && status === "active") return PRO_ENTITLEMENT_VERSION;
  if (plan === "trial" && status === "trial") return TRIAL_ENTITLEMENT_VERSION;
  return MEMBERSHIP_ENTITLEMENT_VERSION;
}

export function trialStateFromMembership(raw: {
  plan?: unknown;
  status?: unknown;
  trialState?: unknown;
  startedAt?: unknown;
  expiresAt?: unknown;
  started_at?: unknown;
  expires_at?: unknown;
  trialStartedAt?: unknown;
  trialExpiresAt?: unknown;
  trial_started_at?: unknown;
  trial_expires_at?: unknown;
  periodStartsAt?: unknown;
  periodEndsAt?: unknown;
  period_starts_at?: unknown;
  period_ends_at?: unknown;
}): TrialState {
  const explicit = typeof raw.trialState === "string" &&
      (TRIAL_STATES as readonly string[]).includes(raw.trialState)
    ? raw.trialState as TrialState
    : null;
  if (explicit) return explicit;
  if (raw.plan !== "trial") return "not_started";
  if (raw.status === "expired") return "expired";
  const started = raw.trialStartedAt ?? raw.trial_started_at ??
    raw.startedAt ?? raw.started_at ?? raw.periodStartsAt ?? raw.period_starts_at;
  const expires = raw.trialExpiresAt ?? raw.trial_expires_at ??
    raw.expiresAt ?? raw.expires_at ?? raw.periodEndsAt ?? raw.period_ends_at;
  if (typeof started === "string" && started && typeof expires === "string" && expires) {
    return "active";
  }
  return "preparing";
}

export function isTrialWindowOpen(start: Date, end: Date, now: Date): boolean {
  return Number.isFinite(start.getTime()) &&
    Number.isFinite(end.getTime()) &&
    Number.isFinite(now.getTime()) &&
    now.getTime() >= start.getTime() && now.getTime() < end.getTime();
}

export type MembershipErrorCode =
  | "trial_expired"
  | "membership_required"
  | "feature_limit_reached"
  | "request_exceeds_feature_limit"
  | "rate_limited"
  | "generation_in_progress"
  | "service_budget_protected"
  | "request_conflict";

export interface AdminMembershipActionInput {
  action:
    | "grant_membership"
    | "compensate_membership"
    | "revoke_grant"
    | "replay_order"
    | "record_manual_payment"
    | "toggle_generation_service";
  targetUserId: string;
  months?: number;
  reason: string;
  clientRequestId: string;
  orderId?: string;
  membershipId?: string;
  channel?: string;
  transactionId?: string;
  amountFenCny?: number;
  previewVersion?: string;
}

export function addCalendarMonthsUtc(start: Date, months: number): Date {
  if (!Number.isInteger(months) || months < 0) {
    throw new RangeError("months must be a non-negative integer");
  }
  if (months === 0) return new Date(start.getTime());

  const y = start.getUTCFullYear();
  const m = start.getUTCMonth();
  const d = start.getUTCDate();
  const h = start.getUTCHours();
  const min = start.getUTCMinutes();
  const s = start.getUTCSeconds();
  const ms = start.getUTCMilliseconds();

  const targetMonth = m + months;
  const targetYear = y + Math.floor(targetMonth / 12);
  const normalizedMonth = ((targetMonth % 12) + 12) % 12;

  const daysInTargetMonth = new Date(
    Date.UTC(targetYear, normalizedMonth + 1, 0),
  ).getUTCDate();
  const targetDay = Math.min(d, daysInTargetMonth);

  return new Date(
    Date.UTC(targetYear, normalizedMonth, targetDay, h, min, s, ms),
  );
}

export function calculateMonthlyPeriods(
  startTime: Date,
  months: number,
): Array<{ startsAt: Date; endsAt: Date }> {
  if (months < 1 || months > 12) {
    throw new RangeError("months must be between 1 and 12");
  }
  const periods: Array<{ startsAt: Date; endsAt: Date }> = [];
  let currentStart = startTime;
  for (let i = 1; i <= months; i++) {
    const nextEnd = addCalendarMonthsUtc(startTime, i);
    periods.push({
      startsAt: currentStart,
      endsAt: nextEnd,
    });
    currentStart = nextEnd;
  }
  return periods;
}
