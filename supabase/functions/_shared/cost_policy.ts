// Strict cost policy and conservative upper-bound pricing for all billable paths.
// All internal financial calculations use integer nano USD (1 USD = 1,000,000,000 nano USD).

export const PRICE_POLICY_VERSION = "2026-09-11-v1";
export const FX_GUARD_VERSION = "cny-usd-7.0-v1";
export const DEFAULT_FX_RATE_CNY_PER_USD = 7.0;

export const NANO_USD_PER_USD = 1_000_000_000n;

export const TEXT_INPUT_NANO_USD_PER_TOKEN = 150n;
export const TEXT_OUTPUT_NANO_USD_PER_TOKEN = 600n;
export const TTS_NANO_USD_PER_CHARACTER = 15_000n;
export const TRANSCRIPTION_NANO_USD_PER_MS = 50n;

export const SINGLE_SENTENCE_MAX_INPUT_TOKENS = 4096n;
export const SINGLE_SENTENCE_MAX_OUTPUT_TOKENS = 2048n;
export const PREPARATION_MAX_INPUT_TOKENS = 16384n;
export const PREPARATION_MAX_OUTPUT_TOKENS = 4096n;
export const BATCH_SEGMENT_OUTPUT_BUDGET = 2048n;
export const BATCH_MAX_OUTPUT_TOKENS = 8192n;
export const MAX_BATCH_ITEMS = 5;
export const MAX_TRANSCRIPTION_DURATION_MS = 180_000;

export type GenerationFeature =
  | "transcription"
  | "sentence"
  | "preparation"
  | "batch"
  | "tts";

export interface CostQuote {
  currency: "USD";
  maxNanoUsd: string;
  priceVersion: string;
  fxGuardVersion: string;
  validUntil: string;
  evidenceVersion: string;
}

export interface AdmissionInput {
  userId: string;
  requestId: string;
  operation: GenerationFeature;
  payloadHash: string;
  entitlementUnits: number;
  quote: CostQuote;
}

export function calculateSingleSentenceMaxCost(): bigint {
  return (
    SINGLE_SENTENCE_MAX_INPUT_TOKENS * TEXT_INPUT_NANO_USD_PER_TOKEN +
    SINGLE_SENTENCE_MAX_OUTPUT_TOKENS * TEXT_OUTPUT_NANO_USD_PER_TOKEN
  );
}

export function calculatePreparationMaxCost(): bigint {
  return (
    PREPARATION_MAX_INPUT_TOKENS * TEXT_INPUT_NANO_USD_PER_TOKEN +
    PREPARATION_MAX_OUTPUT_TOKENS * TEXT_OUTPUT_NANO_USD_PER_TOKEN
  );
}

export function calculateBatchMaxCost(itemCount: number): bigint {
  if (
    !Number.isInteger(itemCount) || itemCount < 1 || itemCount > MAX_BATCH_ITEMS
  ) {
    throw new RangeError(`itemCount must be between 1 and ${MAX_BATCH_ITEMS}`);
  }
  const inputTokens = BigInt(Math.min(itemCount * 2048 + 1024, 8192));
  const outputTokens = BigInt(
    Math.min(itemCount * 2048, Number(BATCH_MAX_OUTPUT_TOKENS)),
  );
  return (
    inputTokens * TEXT_INPUT_NANO_USD_PER_TOKEN +
    outputTokens * TEXT_OUTPUT_NANO_USD_PER_TOKEN
  );
}

export function calculateTtsMaxCost(characters: number): bigint {
  if (!Number.isInteger(characters) || characters < 1) {
    throw new RangeError("characters must be a positive integer");
  }
  return BigInt(characters) * TTS_NANO_USD_PER_CHARACTER;
}

export function calculateTranscriptionMaxCost(durationMs: number): bigint {
  if (!Number.isInteger(durationMs) || durationMs < 1) {
    throw new RangeError("durationMs must be a positive integer");
  }
  return BigInt(durationMs) * TRANSCRIPTION_NANO_USD_PER_MS;
}

export function calculateOperationMaxCost(
  feature: GenerationFeature,
  units: {
    itemCount?: number;
    characters?: number;
    durationMs?: number;
  } = {},
): bigint {
  switch (feature) {
    case "sentence":
      return calculateSingleSentenceMaxCost();
    case "preparation":
      return calculatePreparationMaxCost();
    case "batch":
      return calculateBatchMaxCost(units.itemCount ?? 1);
    case "tts":
      return calculateTtsMaxCost(units.characters ?? 1);
    case "transcription":
      if ((units.durationMs ?? 1) > MAX_TRANSCRIPTION_DURATION_MS) {
        throw new RangeError(
          `durationMs exceeds single-call max of ${MAX_TRANSCRIPTION_DURATION_MS}`,
        );
      }
      return calculateTranscriptionMaxCost(units.durationMs ?? 1);
    default: {
      const _exhaustive: never = feature;
      throw new Error(`Unsupported feature: ${_exhaustive}`);
    }
  }
}

export function createCostQuote(
  feature: GenerationFeature,
  units: {
    itemCount?: number;
    characters?: number;
    durationMs?: number;
  } = {},
  now: Date = new Date(),
  validityMinutes: number = 10,
): CostQuote {
  const maxNanoUsd = calculateOperationMaxCost(feature, units);
  const validUntil = new Date(now.getTime() + validityMinutes * 60_000)
    .toISOString();
  return {
    currency: "USD",
    maxNanoUsd: maxNanoUsd.toString(),
    priceVersion: PRICE_POLICY_VERSION,
    fxGuardVersion: FX_GUARD_VERSION,
    validUntil,
    evidenceVersion: "2026-09-11-v1",
  };
}

export function verifyCostQuote(
  quote: CostQuote,
  expectedFeature: GenerationFeature,
  units: {
    itemCount?: number;
    characters?: number;
    durationMs?: number;
  } = {},
  now: Date = new Date(),
): { ok: true; maxNanoUsd: bigint } | {
  ok: false;
  code: string;
  message: string;
} {
  if (quote.currency !== "USD") {
    return {
      ok: false,
      code: "invalid_currency",
      message: "Quote currency must be USD",
    };
  }
  if (quote.priceVersion !== PRICE_POLICY_VERSION) {
    return {
      ok: false,
      code: "stale_price_version",
      message: "Price policy version is outdated",
    };
  }
  if (quote.fxGuardVersion !== FX_GUARD_VERSION) {
    return {
      ok: false,
      code: "stale_fx_guard",
      message: "FX guard version is outdated",
    };
  }
  const validUntilTime = new Date(quote.validUntil).getTime();
  if (Number.isNaN(validUntilTime) || now.getTime() > validUntilTime) {
    return {
      ok: false,
      code: "quote_expired",
      message: "Price quote has expired",
    };
  }
  let expectedMax: bigint;
  try {
    expectedMax = calculateOperationMaxCost(expectedFeature, units);
  } catch (err) {
    return { ok: false, code: "invalid_units", message: String(err) };
  }
  let claimedMax: bigint;
  try {
    claimedMax = BigInt(quote.maxNanoUsd);
  } catch {
    return {
      ok: false,
      code: "invalid_quote_amount",
      message: "maxNanoUsd is not a valid integer",
    };
  }
  if (claimedMax < expectedMax) {
    return {
      ok: false,
      code: "insufficient_quote_ceiling",
      message:
        `Quote ceiling ${claimedMax} is below required conservative ceiling ${expectedMax}`,
    };
  }
  return { ok: true, maxNanoUsd: claimedMax };
}

export function usdNanoToCnyFenCeil(
  nanoUsd: bigint,
  fxRate: number = DEFAULT_FX_RATE_CNY_PER_USD,
): number {
  if (nanoUsd <= 0n) return 0;
  const fxScaled = BigInt(Math.round(fxRate * 10000));
  const fenNumerator = nanoUsd * fxScaled * 100n;
  const fenDenominator = NANO_USD_PER_USD * 10000n;
  const integerDiv = fenNumerator / fenDenominator;
  const remainder = fenNumerator % fenDenominator;
  return Number(remainder > 0n ? integerDiv + 1n : integerDiv);
}

export function cnyFenToUsdNanoFloor(
  fen: number,
  fxRate: number = DEFAULT_FX_RATE_CNY_PER_USD,
): bigint {
  if (fen <= 0) return 0n;
  const fenBig = BigInt(fen);
  const fxScaled = BigInt(Math.round(fxRate * 10000));
  const numerator = fenBig * NANO_USD_PER_USD * 10000n;
  const denominator = fxScaled * 100n;
  return numerator / denominator;
}

export function calculateFullPackageCost(plan: "trial" | "monthly"): {
  baseNanoUsd: bigint;
  retryNanoUsd: bigint;
  baseFenCny: number;
  retryFenCny: number;
} {
  const sentencesCount = plan === "trial" ? 30 : 300;
  const prepCount = plan === "trial" ? 3 : 30;
  const ttsChars = plan === "trial" ? 3000 : 30000;
  const transMs = plan === "trial" ? 300_000 : 3_600_000;
  const sentenceCost = BigInt(sentencesCount) *
    calculateSingleSentenceMaxCost();
  const prepCost = BigInt(prepCount) * calculatePreparationMaxCost();
  const ttsCost = calculateTtsMaxCost(ttsChars);
  const transCost = calculateTranscriptionMaxCost(transMs);
  const baseNanoUsd = sentenceCost + prepCost + ttsCost + transCost;
  const retryNanoUsd = baseNanoUsd * 2n;
  return {
    baseNanoUsd,
    retryNanoUsd,
    baseFenCny: usdNanoToCnyFenCeil(baseNanoUsd),
    retryFenCny: usdNanoToCnyFenCeil(retryNanoUsd),
  };
}
