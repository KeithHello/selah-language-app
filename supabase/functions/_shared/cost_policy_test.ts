// Unit tests for cost policy, currency conversions, quotes and entitlement limits.
// Run with Deno in CI or test via Node runner locally.

import {
  assert,
  assertEquals,
  assertFalse,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  calculateBatchMaxCost,
  calculateFullPackageCost,
  calculateOperationMaxCost,
  calculatePreparationMaxCost,
  calculateSingleSentenceMaxCost,
  calculateTranscriptionMaxCost,
  calculateTtsMaxCost,
  cnyFenToUsdNanoFloor,
  createCostQuote,
  FX_GUARD_VERSION,
  PRICE_POLICY_VERSION,
  usdNanoToCnyFenCeil,
  verifyCostQuote,
} from "./cost_policy.ts";

import {
  addCalendarMonthsUtc,
  calculateMonthlyPeriods,
  MONTHLY_ENTITLEMENTS,
  MONTHLY_MAX_PREPARATIONS,
  MONTHLY_MAX_SENTENCES,
  MONTHLY_MAX_TRANSCRIPTION_MS,
  MONTHLY_MAX_TTS_CHARACTERS,
  MONTHLY_PRICE_FEN_CNY,
  TRIAL_ENTITLEMENTS,
  TRIAL_MAX_PREPARATIONS,
  TRIAL_MAX_SENTENCES,
  TRIAL_MAX_TRANSCRIPTION_MS,
  TRIAL_MAX_TTS_CHARACTERS,
} from "./membership_contract.ts";

Deno.test("single sentence max cost matches token upper bounds", () => {
  // 4096 * 150 + 2048 * 600 = 614400 + 1228800 = 1843200 nano USD
  const cost = calculateSingleSentenceMaxCost();
  assertEquals(cost, 1_843_200n);
});

Deno.test("preparation max cost matches token upper bounds", () => {
  // 16384 * 150 + 4096 * 600 = 2457600 + 2457600 = 4915200 nano USD
  const cost = calculatePreparationMaxCost();
  assertEquals(cost, 4_915_200n);
});

Deno.test("batch max cost bounds output tokens per segment", () => {
  // 1 item: min(1 * 2048 + 1024, 8192) = 3072 input; min(1 * 2048, 8192) = 2048 output
  // 3072 * 150 + 2048 * 600 = 460800 + 1228800 = 1689600 nano USD
  assertEquals(calculateBatchMaxCost(1), 1_689_600n);
  // 5 items: min(5 * 2048 + 1024, 8192) = 8192 input; min(5 * 2048, 8192) = 8192 output
  // 8192 * 150 + 8192 * 600 = 1228800 + 4915200 = 6144000 nano USD
  assertEquals(calculateBatchMaxCost(5), 6_144_000n);
  assertThrows(() => calculateBatchMaxCost(0));
  assertThrows(() => calculateBatchMaxCost(6));
});

Deno.test("TTS cost calculation respects character rates", () => {
  // 1000 chars * 15,000 nano USD = 15,000,000 nano USD
  assertEquals(calculateTtsMaxCost(1000), 15_000_000n);
  assertThrows(() => calculateTtsMaxCost(0));
  assertThrows(() => calculateTtsMaxCost(-5));
});

Deno.test("transcription cost calculation respects ms rates and ceiling", () => {
  // 60,000 ms (1 min) * 50 = 3,000,000 nano USD ($0.003)
  assertEquals(calculateTranscriptionMaxCost(60_000), 3_000_000n);
  // 180,000 ms (3 min max single call) * 50 = 9,000,000 nano USD ($0.009)
  assertEquals(calculateTranscriptionMaxCost(180_000), 9_000_000n);
  assertThrows(() => calculateOperationMaxCost("transcription", { durationMs: 180_001 }));
  assertThrows(() => calculateTranscriptionMaxCost(0));
});

Deno.test("currency conversions ceil expenses and floor budgets", () => {
  // 1 USD = 1,000,000,000 nano USD
  // At fx=7.0: 1 USD = 7.0 CNY = 700 fen
  assertEquals(usdNanoToCnyFenCeil(1_000_000_000n, 7.0), 700);
  // Any non-zero remainder ceils up to prevent underestimating costs
  assertEquals(usdNanoToCnyFenCeil(1n, 7.0), 1);
  assertEquals(usdNanoToCnyFenCeil(0n, 7.0), 0);

  // Budget floor: 700 fen at fx 7.0 -> 1,000,000,000 nano USD
  assertEquals(cnyFenToUsdNanoFloor(700, 7.0), 1_000_000_000n);
  // 1 fen -> 1,000,000,000 / 700 = 1,428,571 nano USD
  assertEquals(cnyFenToUsdNanoFloor(1, 7.0), 1_428_571n);
  assertEquals(cnyFenToUsdNanoFloor(0, 7.0), 0n);
});

Deno.test("quote generation and verification enforce version and validity", () => {
  const now = new Date("2026-09-11T10:00:00Z");
  const quote = createCostQuote("sentence", {}, now, 10);
  assertEquals(quote.priceVersion, PRICE_POLICY_VERSION);
  assertEquals(quote.fxGuardVersion, FX_GUARD_VERSION);
  assertEquals(quote.maxNanoUsd, "1843200");

  // Valid verification
  const verified = verifyCostQuote(quote, "sentence", {}, now);
  assert(verified.ok);
  if (verified.ok) {
    assertEquals(verified.maxNanoUsd, 1_843_200n);
  }

  // Expired quote
  const later = new Date("2026-09-11T10:11:00Z");
  const expired = verifyCostQuote(quote, "sentence", {}, later);
  assertFalse(expired.ok);
  if (!expired.ok) {
    assertEquals(expired.code, "quote_expired");
  }

  // Stale version rejected
  const stale = verifyCostQuote(
    { ...quote, priceVersion: "old-version" },
    "sentence",
    {},
    now,
  );
  assertFalse(stale.ok);
  if (!stale.ok) {
    assertEquals(stale.code, "stale_price_version");
  }

  // Insufficient ceiling rejected
  const insufficient = verifyCostQuote(
    { ...quote, maxNanoUsd: "1000" },
    "sentence",
    {},
    now,
  );
  assertFalse(insufficient.ok);
  if (!insufficient.ok) {
    assertEquals(insufficient.code, "insufficient_quote_ceiling");
  }
});

Deno.test("full package extreme calculations prove 2元 trial and 20元 monthly budget limits", () => {
  // Trial verification
  const trial = calculateFullPackageCost("trial");
  // Base: 130,041,600 nano USD; Retry (doubled): 260,083,200 nano USD
  assertEquals(trial.baseNanoUsd, 130_041_600n);
  assertEquals(trial.retryNanoUsd, 260_083_200n);
  // Trial at fx 7.0: base is ~92 fen, retry is ~183 fen <= 200 fen (2.00 RMB)
  assert(trial.baseFenCny <= 100);
  assert(trial.retryFenCny <= 200);

  // Monthly verification
  const monthly = calculateFullPackageCost("monthly");
  // Base: 1,330,416,000 nano USD; Retry (doubled): 2,660,832,000 nano USD
  assertEquals(monthly.baseNanoUsd, 1_330_416_000n);
  assertEquals(monthly.retryNanoUsd, 2_660_832_000n);
  // Monthly at fx 7.0: base is ~932 fen (~9.32 RMB), retry is ~1863 fen (~18.63 RMB) <= 2000 fen (20.00 RMB)
  assert(monthly.baseFenCny <= 1000);
  assert(monthly.retryFenCny <= 2000);
});

Deno.test("addCalendarMonthsUtc handles month-end anchors and leap years cleanly", () => {
  // Jan 31, 2026 -> Feb 28, 2026 (non-leap year)
  const jan31 = new Date(Date.UTC(2026, 0, 31, 10, 0, 0));
  const febEnd = addCalendarMonthsUtc(jan31, 1);
  assertEquals(febEnd.toISOString(), "2026-02-28T10:00:00.000Z");

  // Jan 31, 2026 -> Mar 31, 2026
  const marEnd = addCalendarMonthsUtc(jan31, 2);
  assertEquals(marEnd.toISOString(), "2026-03-31T10:00:00.000Z");

  // Leap year: Jan 31, 2028 -> Feb 29, 2028
  const leapJan31 = new Date(Date.UTC(2028, 0, 31, 12, 0, 0));
  const leapFeb = addCalendarMonthsUtc(leapJan31, 1);
  assertEquals(leapFeb.toISOString(), "2028-02-29T12:00:00.000Z");

  // 3 consecutive periods
  const periods = calculateMonthlyPeriods(jan31, 3);
  assertEquals(periods.length, 3);
  assertEquals(periods[0].startsAt.toISOString(), "2026-01-31T10:00:00.000Z");
  assertEquals(periods[0].endsAt.toISOString(), "2026-02-28T10:00:00.000Z");
  assertEquals(periods[1].startsAt.toISOString(), "2026-02-28T10:00:00.000Z");
  assertEquals(periods[1].endsAt.toISOString(), "2026-03-31T10:00:00.000Z");
  assertEquals(periods[2].startsAt.toISOString(), "2026-03-31T10:00:00.000Z");
  assertEquals(periods[2].endsAt.toISOString(), "2026-04-30T10:00:00.000Z");
});

Deno.test("entitlement constants match approved business plan", () => {
  assertEquals(TRIAL_ENTITLEMENTS.maxSentences, 30);
  assertEquals(TRIAL_ENTITLEMENTS.maxTtsCharacters, 3000);
  assertEquals(TRIAL_ENTITLEMENTS.maxTranscriptionMs, 300_000);
  assertEquals(TRIAL_ENTITLEMENTS.maxPreparations, 3);

  assertEquals(MONTHLY_ENTITLEMENTS.maxSentences, 300);
  assertEquals(MONTHLY_ENTITLEMENTS.maxTtsCharacters, 30000);
  assertEquals(MONTHLY_ENTITLEMENTS.maxTranscriptionMs, 3_600_000);
  assertEquals(MONTHLY_ENTITLEMENTS.maxPreparations, 30);
  assertEquals(MONTHLY_PRICE_FEN_CNY, 3990);
});
