// Unified admission control, idempotency, atomic reservation and settlement for billable generation.

import {
  type CostQuote,
  type CostUnits,
  createCostQuote,
  type GenerationFeature,
  verifyCostQuote,
} from "./cost_policy.ts";
import type { MembershipErrorCode } from "./membership_contract.ts";

export interface AdmissionCheckResult {
  allowed: boolean;
  reservationId?: string;
  reservationScope?: "membership" | "platform";
  errorCode?: MembershipErrorCode;
  errorMessage?: string;
  internalReason?:
    | "daily_limit_reached"
    | "budget_configuration_unavailable"
    | "admission_service_unavailable";
  resetsAt?: string;
  retryAfterSeconds?: number;
  quote?: CostQuote;
}

export interface GenerationAdmissionOptions {
  userId: string;
  clientRequestId: string;
  feature: GenerationFeature;
  units: CostUnits;
  payloadHash: string;
  quote?: CostQuote;
  /** When false, usage is metered without enforcing membership allowances. */
  enforcementEnabled?: boolean;
}

export function admissionErrorDetails(
  result: AdmissionCheckResult,
  options: Pick<GenerationAdmissionOptions, "feature" | "clientRequestId">,
): Record<string, unknown> {
  return {
    feature: options.feature,
    requestId: options.clientRequestId,
    ...(result.errorCode === "feature_limit_reached" ||
        result.errorCode === "trial_expired"
      ? { currentPeriodEndsAt: null }
      : {}),
    ...(result.resetsAt
      ? {
        resetsAt: result.resetsAt,
        retryAfterSeconds: result.retryAfterSeconds,
      }
      : {}),
  };
}

export function admissionHttpStatus(result: AdmissionCheckResult): number {
  if (result.errorCode === "rate_limited") return 429;
  if (result.errorCode === "service_budget_protected") return 503;
  return 403;
}

export function admissionPublicCode(result: AdmissionCheckResult): string {
  return result.errorCode === "service_budget_protected"
    ? "generation_temporarily_unavailable"
    : result.errorCode ?? "generation_request_unavailable";
}

export function admissionPublicMessage(result: AdmissionCheckResult): string {
  if (result.errorCode === "service_budget_protected") {
    return "Generation is temporarily unavailable";
  }
  return result.errorMessage ?? "Generation request unavailable";
}

export interface RpcCaller {
  rpc(name: string, args: Record<string, unknown>): Promise<{
    data: unknown;
    error: unknown;
  }>;
}

/**
 * Verify or mint cost quote and perform pre-flight bounds validation.
 */
export function prepareAdmissionQuote(
  feature: GenerationFeature,
  units: CostUnits,
  providedQuote?: CostQuote,
  now: Date = new Date(),
): { ok: true; quote: CostQuote } | {
  ok: false;
  code: MembershipErrorCode;
  message: string;
} {
  if (providedQuote) {
    const verification = verifyCostQuote(providedQuote, feature, units, now);
    if (!verification.ok) {
      return {
        ok: false,
        code: "service_budget_protected",
        message: verification.message,
      };
    }
    return { ok: true, quote: providedQuote };
  }
  try {
    const quote = createCostQuote(feature, units, now);
    return { ok: true, quote };
  } catch (err) {
    return {
      ok: false,
      code: "request_exceeds_feature_limit",
      message: String(err),
    };
  }
}

/**
 * Performs atomic admission check via Postgres RPC.
 * If Postgres is unavailable or capacity is exceeded, fails safe and closed.
 */
export async function requestGenerationAdmission(
  client: RpcCaller,
  options: GenerationAdmissionOptions,
): Promise<AdmissionCheckResult> {
  const quotePrep = prepareAdmissionQuote(
    options.feature,
    options.units,
    options.quote,
  );
  if (!quotePrep.ok) {
    return {
      allowed: false,
      errorCode: quotePrep.code,
      errorMessage: quotePrep.message,
    };
  }
  const quote = quotePrep.quote;
  const unitsCount = options.units.itemCount ??
    options.units.characters ??
    options.units.durationMs ??
    1;

  // Metering and the platform daily safeguard are always on. The public-mode
  // recorder skips personal membership entitlements; the member RPC checks
  // those entitlements and the same shared platform budget.
  if (options.enforcementEnabled === false) {
    try {
      const result = await client.rpc("record_generation_usage", {
        p_user_id: options.userId,
        p_client_request_id: options.clientRequestId,
        p_feature: options.feature,
        p_units: unitsCount,
        p_nano_usd: quote.maxNanoUsd,
        p_payload_hash: options.payloadHash,
      });
      if (result.error) {
        return platformAdmissionFailure(result.error, options);
      }
      const reservationId = typeof result.data === "string"
        ? result.data
        : (result.data as { reservationId?: string })?.reservationId;
      return {
        allowed: true,
        ...(reservationId ? { reservationId } : {}),
        reservationScope: "membership",
        quote,
      };
    } catch {
      return platformAdmissionFailure(null, options);
    }
  }

  try {
    const result = await client.rpc("reserve_generation_allowance", {
      p_user_id: options.userId,
      p_client_request_id: options.clientRequestId,
      p_feature: options.feature,
      p_units: unitsCount,
      p_nano_usd: quote.maxNanoUsd,
      p_payload_hash: options.payloadHash,
    });

    if (result.error) {
      const errStr = typeof result.error === "object" && result.error !== null
        ? (result.error as { message?: string }).message || ""
        : String(result.error);

      if (errStr.includes("trial_expired")) {
        return {
          allowed: false,
          errorCode: "trial_expired",
          errorMessage: "Trial has expired",
        };
      }
      if (errStr.includes("feature_limit_reached")) {
        return {
          allowed: false,
          errorCode: "feature_limit_reached",
          errorMessage: "Feature limit reached",
        };
      }
      if (errStr.includes("membership_required")) {
        return {
          allowed: false,
          errorCode: "membership_required",
          errorMessage: "Membership required",
        };
      }
      if (errStr.includes("rate_limited")) {
        return {
          allowed: false,
          errorCode: "rate_limited",
          errorMessage: "Rate limit reached",
        };
      }
      return platformAdmissionFailure(errStr, options);
    }

    const reservationId = typeof result.data === "string"
      ? result.data
      : (result.data as { reservationId?: string })?.reservationId ||
        "mock-res-id";

    return {
      allowed: true,
      reservationId,
      reservationScope: "membership",
      quote,
    };
  } catch (err) {
    return platformAdmissionFailure(err, options);
  }
}

function platformAdmissionFailure(
  error: unknown,
  options: Pick<GenerationAdmissionOptions, "feature" | "clientRequestId">,
): AdmissionCheckResult {
  const details = typeof error === "object" && error !== null
    ? (error as { message?: string }).message ?? ""
    : String(error ?? "");
  const now = new Date();
  if (details.includes("platform_daily_budget_exhausted")) {
    const resetsAt = new Date(Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + 1,
    ));
    const result: AdmissionCheckResult = {
      allowed: false,
      errorCode: "service_budget_protected",
      errorMessage: "platform_daily_budget_exhausted",
      internalReason: "daily_limit_reached",
      resetsAt: resetsAt.toISOString(),
      retryAfterSeconds: Math.max(
        1,
        Math.ceil((resetsAt.getTime() - now.getTime()) / 1000),
      ),
    };
    console.warn("Generation admission failed", {
      feature: options.feature,
      requestId: options.clientRequestId,
      reason: result.internalReason,
    });
    return result;
  }
  if (
    details.includes("platform_daily_budget_unavailable") ||
    details.includes("service_budget_protected")
  ) {
    const result: AdmissionCheckResult = {
      allowed: false,
      errorCode: "service_budget_protected",
      errorMessage: "platform_daily_budget_unavailable",
      internalReason: "budget_configuration_unavailable",
    };
    console.error("Generation admission failed", {
      feature: options.feature,
      requestId: options.clientRequestId,
      reason: result.internalReason,
    });
    return result;
  }
  const result: AdmissionCheckResult = {
    allowed: false,
    errorCode: "service_budget_protected",
    errorMessage: "generation_admission_unavailable",
    internalReason: "admission_service_unavailable",
  };
  console.error("Generation admission failed", {
    feature: options.feature,
    requestId: options.clientRequestId,
    reason: result.internalReason,
  });
  return result;
}

export async function settleGenerationAdmission(
  client: RpcCaller,
  reservationId: string,
  status: "settled" | "released_unsent" | "unknown",
  actualNanoUsd?: bigint,
  scope: "membership" | "platform" = "membership",
): Promise<void> {
  try {
    await client.rpc(
      scope === "platform"
        ? "settle_platform_generation_allowance"
        : "settle_generation_allowance",
      {
        p_reservation_id: reservationId,
        p_status: status,
        p_actual_nano_usd: actualNanoUsd != null
          ? actualNanoUsd.toString()
          : null,
      },
    );
  } catch (err) {
    console.error("settleGenerationAdmission failed", err);
  }
}
