import {
  type MembershipSource,
  MONTHLY_ENTITLEMENTS,
  MONTHLY_PRICE_FEN_CNY,
  type PlanEntitlements,
  PRO_ENTITLEMENTS,
  PRO_PRICE_FEN_CNY,
  TRIAL_ENTITLEMENTS,
} from "./membership_contract.ts";

export const DAY_MS = 86_400_000;
const COUNTED = new Set(["reserved", "dispatch_claimed", "settled", "unknown"]);
const PRICE_DELTA = PRO_PRICE_FEN_CNY - MONTHLY_PRICE_FEN_CNY;

export interface FeatureUsage {
  used: number;
  limit: number;
  remaining: number;
}

export interface UsageSnapshot {
  asOf: string;
  sentences: FeatureUsage;
  ttsCharacters: FeatureUsage;
  transcriptionMs: FeatureUsage;
  preparations: FeatureUsage;
}

export interface ReservationUsageRow {
  feature: string;
  status: string;
  units: number;
}

export interface FuturePeriod {
  id: string;
  plan: "trial" | "monthly" | "pro";
  source: MembershipSource;
  startsAt: string;
  endsAt: string;
}

export interface CurrentPeriod {
  plan: "trial" | "monthly" | "pro";
  startedAt: string;
  expiresAt: string;
}

export type PlanChangeAction =
  | "upgrade_pro_now"
  | "schedule_pro"
  | "buy_monthly"
  | "buy_pro"
  | "extend_monthly"
  | "extend_pro";

export interface PlanChangeQuote {
  action: PlanChangeAction;
  chargeFenCny: number;
  effectiveAt: string;
  currentPeriodEffect: "replace_remainder" | "schedule_after" | "start_now";
  limitsAfter: PlanEntitlements | null;
  usageAfter: UsageSnapshot | null;
  futurePeriods: FuturePeriod[];
  warnings: Array<
    | "trial_remainder_dropped"
    | "future_periods_unchanged"
    | "feature_remaining_zero"
  >;
  unavailableReason:
    | "sales_disabled"
    | "payment_not_configured"
    | "pro_sales_disabled"
    | null;
}

export interface PlanQuoteInput {
  now: string;
  current: CurrentPeriod | null;
  usage: UsageSnapshot | null;
  futurePeriods: FuturePeriod[];
  salesEnabled: boolean;
  paymentConfigured: boolean;
  proSalesEnabled: boolean;
}

export function aggregateUsage(
  rows: readonly ReservationUsageRow[],
  limits: PlanEntitlements,
  asOf: string,
): UsageSnapshot {
  const used = { sentences: 0, tts: 0, transcription: 0, preparations: 0 };
  for (const row of rows) {
    if (
      !COUNTED.has(row.status) || !Number.isInteger(row.units) || row.units <= 0
    ) continue;
    if (row.feature === "sentence" || row.feature === "batch") {
      used.sentences += row.units;
    } else if (row.feature === "tts") used.tts += row.units;
    else if (row.feature === "transcription") used.transcription += row.units;
    else if (row.feature === "preparation") used.preparations += row.units;
  }
  return {
    asOf,
    sentences: cap(used.sentences, limits.maxSentences),
    ttsCharacters: cap(used.tts, limits.maxTtsCharacters),
    transcriptionMs: cap(used.transcription, limits.maxTranscriptionMs),
    preparations: cap(used.preparations, limits.maxPreparations),
  };
}

export function legalPlanQuotes(input: PlanQuoteInput): PlanChangeQuote[] {
  const nowMs = time(input.now);
  const current = input.current;
  const remaining = current == null ? 0 : time(current.expiresAt) - nowMs;
  const total = current == null
    ? 0
    : time(current.expiresAt) - time(current.startedAt);
  const active = current != null && remaining > 0 && total > 0 &&
    remaining <= total;
  if (active && current.plan === "monthly" && remaining >= DAY_MS) {
    return [
      upgradeNow(input, total, remaining),
      extend(input, "extend_monthly", MONTHLY_PRICE_FEN_CNY, false),
    ];
  }
  if (active && current.plan === "monthly") {
    return [
      schedulePro(input),
      extend(input, "extend_monthly", MONTHLY_PRICE_FEN_CNY, false),
    ];
  }
  if (active && current.plan === "pro") {
    return [extend(input, "extend_pro", PRO_PRICE_FEN_CNY, true)];
  }
  if (active && current.plan === "trial") {
    return [
      startPaid(input, "buy_monthly", MONTHLY_PRICE_FEN_CNY, false),
      startPaid(input, "buy_pro", PRO_PRICE_FEN_CNY, true),
    ];
  }
  return [
    buyLater(input, "buy_monthly", MONTHLY_PRICE_FEN_CNY, false),
    buyLater(input, "buy_pro", PRO_PRICE_FEN_CNY, true),
  ];
}

function upgradeNow(
  input: PlanQuoteInput,
  total: number,
  remaining: number,
): PlanChangeQuote {
  if (input.usage == null) throw new Error("usage_required");
  const charge = Number(
    (BigInt(PRICE_DELTA) * BigInt(remaining) + BigInt(total) / 2n) /
      BigInt(total),
  );
  const limits = {
    maxSentences: scale(PRO_ENTITLEMENTS.maxSentences, remaining, total),
    maxTtsCharacters: scale(
      PRO_ENTITLEMENTS.maxTtsCharacters,
      remaining,
      total,
    ),
    maxTranscriptionMs: scale(
      PRO_ENTITLEMENTS.maxTranscriptionMs,
      remaining,
      total,
    ),
    maxPreparations: scale(PRO_ENTITLEMENTS.maxPreparations, remaining, total),
  };
  const usageAfter = {
    asOf: input.usage.asOf,
    sentences: cap(input.usage.sentences.used, limits.maxSentences),
    ttsCharacters: cap(input.usage.ttsCharacters.used, limits.maxTtsCharacters),
    transcriptionMs: cap(
      input.usage.transcriptionMs.used,
      limits.maxTranscriptionMs,
    ),
    preparations: cap(input.usage.preparations.used, limits.maxPreparations),
  };
  const warnings: PlanChangeQuote["warnings"] = [];
  if (
    Object.values(usageAfter).some((item) =>
      typeof item !== "string" && item.remaining === 0
    )
  ) {
    warnings.push("feature_remaining_zero");
  }
  if (input.futurePeriods.length > 0) warnings.push("future_periods_unchanged");
  return quote(
    "upgrade_pro_now",
    charge,
    input.now,
    "replace_remainder",
    limits,
    usageAfter,
    input,
    true,
    warnings,
  );
}

function schedulePro(input: PlanQuoteInput): PlanChangeQuote {
  const effectiveAt = latestEnd(input);
  return quote(
    "schedule_pro",
    PRO_PRICE_FEN_CNY,
    effectiveAt,
    "schedule_after",
    PRO_ENTITLEMENTS,
    fresh(effectiveAt, PRO_ENTITLEMENTS),
    input,
    true,
    futureWarning(input),
  );
}

function extend(
  input: PlanQuoteInput,
  action: "extend_monthly" | "extend_pro",
  price: number,
  pro: boolean,
): PlanChangeQuote {
  return quote(
    action,
    price,
    latestEnd(input),
    "schedule_after",
    null,
    null,
    input,
    pro,
    futureWarning(input),
  );
}

function startPaid(
  input: PlanQuoteInput,
  action: "buy_monthly" | "buy_pro",
  price: number,
  pro: boolean,
): PlanChangeQuote {
  const limits = pro ? PRO_ENTITLEMENTS : MONTHLY_ENTITLEMENTS;
  return quote(
    action,
    price,
    input.now,
    "start_now",
    limits,
    fresh(input.now, limits),
    input,
    pro,
    ["trial_remainder_dropped"],
  );
}

function buyLater(
  input: PlanQuoteInput,
  action: "buy_monthly" | "buy_pro",
  price: number,
  pro: boolean,
): PlanChangeQuote {
  const effectiveAt = latestEnd(input);
  const effect = time(effectiveAt) > time(input.now)
    ? "schedule_after"
    : "start_now";
  return quote(
    action,
    price,
    effectiveAt,
    effect,
    pro ? PRO_ENTITLEMENTS : MONTHLY_ENTITLEMENTS,
    fresh(effectiveAt, pro ? PRO_ENTITLEMENTS : MONTHLY_ENTITLEMENTS),
    input,
    pro,
    futureWarning(input),
  );
}

function quote(
  action: PlanChangeAction,
  chargeFenCny: number,
  effectiveAt: string,
  currentPeriodEffect: PlanChangeQuote["currentPeriodEffect"],
  limitsAfter: PlanEntitlements | null,
  usageAfter: UsageSnapshot | null,
  input: PlanQuoteInput,
  pro: boolean,
  warnings: PlanChangeQuote["warnings"],
): PlanChangeQuote {
  return {
    action,
    chargeFenCny,
    effectiveAt,
    currentPeriodEffect,
    limitsAfter,
    usageAfter,
    futurePeriods: input.futurePeriods,
    warnings,
    unavailableReason: reason(input, pro),
  };
}

function reason(
  input: PlanQuoteInput,
  pro: boolean,
): PlanChangeQuote["unavailableReason"] {
  if (!input.salesEnabled) return "sales_disabled";
  if (!input.paymentConfigured) return "payment_not_configured";
  if (pro && !input.proSalesEnabled) return "pro_sales_disabled";
  return null;
}

function futureWarning(input: PlanQuoteInput): PlanChangeQuote["warnings"] {
  return input.futurePeriods.length > 0 ? ["future_periods_unchanged"] : [];
}

function latestEnd(input: PlanQuoteInput): string {
  let latest = input.current == null
    ? time(input.now)
    : Math.max(time(input.now), time(input.current.expiresAt));
  for (const period of input.futurePeriods) {
    latest = Math.max(latest, time(period.endsAt));
  }
  return new Date(latest).toISOString();
}

function fresh(asOf: string, limits: PlanEntitlements): UsageSnapshot {
  return aggregateUsage([], limits, asOf);
}

function scale(limit: number, remaining: number, total: number): number {
  return Number((BigInt(limit) * BigInt(remaining)) / BigInt(total));
}

function cap(used: number, limit: number): FeatureUsage {
  return { used, limit, remaining: Math.max(0, limit - used) };
}

function time(value: string): number {
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) throw new Error("invalid_time");
  return parsed;
}

export function limitsForPlan(plan: string): PlanEntitlements {
  if (plan === "pro") return PRO_ENTITLEMENTS;
  if (plan === "monthly") return MONTHLY_ENTITLEMENTS;
  if (plan === "trial") return TRIAL_ENTITLEMENTS;
  return {
    maxSentences: 0,
    maxTtsCharacters: 0,
    maxTranscriptionMs: 0,
    maxPreparations: 0,
  };
}
