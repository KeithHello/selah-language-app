// Unified admission control, idempotency, atomic reservation and settlement for billable generation.

import {
  calculateOperationMaxCost,
  type CostQuote,
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
  quote?: CostQuote;
}

export interface GenerationAdmissionOptions {
  userId: string;
  clientRequestId: string;
  feature: GenerationFeature;
  units: {
    itemCount?: number;
    characters?: number;
    durationMs?: number;
  };
  payloadHash: string;
  quote?: CostQuote;
  /**
   * Temporary anonymous testing bypasses membership quotas only. It still
   * reserves against the platform-wide daily budget before provider work.
   */
  isAnonymous?: boolean;
  /**
   * Set by the service-control snapshot. When false, the product is in test
   * mode: authenticated test identities bypass membership and platform
   * reservations after the request bounds have been validated. The default
   * remains true for callers that have not opted into the global flag yet.
   */
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
  };
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
  units: {
    itemCount?: number;
    characters?: number;
    durationMs?: number;
  },
  providedQuote?: CostQuote,
  now: Date = new Date(),
): { ok: true; quote: CostQuote } | { ok: false; code: MembershipErrorCode; message: string } {
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

  // The global switch is evaluated on the server before any reservation RPC.
  // We still validate and quote the request so malformed or unbounded calls
  // cannot use test mode to bypass feature ceilings. Test mode is intended for
  // the shared browser preview, so it must not depend on a daily platform
  // ledger row that can be missing after a UTC date rollover.
  if (options.enforcementEnabled === false) {
    return { allowed: true, quote };
  }

  const unitsCount = options.units.itemCount ??
    options.units.characters ??
    options.units.durationMs ??
    1;

  // Anonymous test identities have no trial or paid membership, but they must
  // consume the shared daily platform budget before any provider request.
  if (options.isAnonymous === true) {
    try {
      const result = await client.rpc("reserve_platform_generation_allowance", {
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
        return {
          allowed: false,
          errorCode: errStr.includes("rate_limited")
            ? "rate_limited"
            : "service_budget_protected",
          errorMessage: errStr || "Platform budget limit reached",
        };
      }
      const platformReservationId = typeof result.data === "string"
        ? result.data
        : (result.data as { reservationId?: string })?.reservationId;
      if (!platformReservationId) {
        return {
          allowed: false,
          errorCode: "service_budget_protected",
          errorMessage: "Platform budget reservation unavailable",
        };
      }
      return {
        allowed: true,
        reservationId: platformReservationId,
        reservationScope: "platform",
        quote,
      };
    } catch (err) {
      return {
        allowed: false,
        errorCode: "service_budget_protected",
        errorMessage: `Platform budget unavailable: ${String(err)}`,
      };
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
        return { allowed: false, errorCode: "trial_expired", errorMessage: "Trial has expired" };
      }
      if (errStr.includes("feature_limit_reached")) {
        return { allowed: false, errorCode: "feature_limit_reached", errorMessage: "Feature limit reached" };
      }
      if (errStr.includes("membership_required")) {
        return { allowed: false, errorCode: "membership_required", errorMessage: "Membership required" };
      }
      if (errStr.includes("rate_limited")) {
        return { allowed: false, errorCode: "rate_limited", errorMessage: "Rate limit reached" };
      }
      return {
        allowed: false,
        errorCode: "service_budget_protected",
        errorMessage: errStr || "Platform budget limit reached",
      };
    }

    const reservationId = typeof result.data === "string"
      ? result.data
      : (result.data as { reservationId?: string })?.reservationId || "mock-res-id";

    return {
      allowed: true,
      reservationId,
      reservationScope: "membership",
      quote,
    };
  } catch (err) {
    return {
      allowed: false,
      errorCode: "service_budget_protected",
      errorMessage: `Admission service unavailable: ${String(err)}`,
    };
  }
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
      p_actual_nano_usd: actualNanoUsd != null ? actualNanoUsd.toString() : null,
      },
    );
  } catch (err) {
    console.error("settleGenerationAdmission failed", err);
  }
}
