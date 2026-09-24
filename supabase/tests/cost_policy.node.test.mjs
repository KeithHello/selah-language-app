import assert from "node:assert/strict";
import { test } from "node:test";

const {
  calculateSingleSentenceMaxCost,
  calculatePreparationMaxCost,
  calculateBatchMaxCost,
  calculateTtsMaxCost,
  calculateTranscriptionMaxCost,
  createCostQuote,
  verifyCostQuote,
  usdNanoToCnyFenCeil,
  cnyFenToUsdNanoFloor,
  calculateFullPackageCost,
  PRICE_POLICY_VERSION,
  FX_GUARD_VERSION,
} = await import("../functions/_shared/cost_policy.ts");

const {
  TRIAL_ENTITLEMENTS,
  MONTHLY_ENTITLEMENTS,
  MONTHLY_PRICE_FEN_CNY,
  addCalendarMonthsUtc,
  calculateMonthlyPeriods,
} = await import("../functions/_shared/membership_contract.ts");

test("single sentence max cost matches token upper bounds", () => {
  const cost = calculateSingleSentenceMaxCost();
  assert.deepStrictEqual(cost, 1_843_200n);
});

test("preparation max cost matches token upper bounds", () => {
  const cost = calculatePreparationMaxCost();
  assert.deepStrictEqual(cost, 4_915_200n);
});

test("batch max cost bounds output tokens per segment", () => {
  assert.deepStrictEqual(calculateBatchMaxCost(1), 1_689_600n);
  assert.deepStrictEqual(calculateBatchMaxCost(5), 6_144_000n);
  assert.throws(() => calculateBatchMaxCost(0));
  assert.throws(() => calculateBatchMaxCost(6));
});

test("TTS cost calculation respects character rates", () => {
  assert.deepStrictEqual(calculateTtsMaxCost(1000), 15_000_000n);
  assert.throws(() => calculateTtsMaxCost(0));
  assert.throws(() => calculateTtsMaxCost(-5));
});

test("transcription cost calculation respects ms rates and ceiling", () => {
  assert.deepStrictEqual(calculateTranscriptionMaxCost(60_000), 3_000_000n);
  assert.deepStrictEqual(calculateTranscriptionMaxCost(180_000), 9_000_000n);
  assert.throws(() =>
    calculateOperationMaxCost("transcription", { durationMs: 180_001 })
  );
  assert.throws(() => calculateTranscriptionMaxCost(0));
});

test("currency conversions ceil expenses and floor budgets", () => {
  assert.deepStrictEqual(usdNanoToCnyFenCeil(1_000_000_000n, 7.0), 700);
  assert.deepStrictEqual(usdNanoToCnyFenCeil(1n, 7.0), 1);
  assert.deepStrictEqual(usdNanoToCnyFenCeil(0n, 7.0), 0);
  assert.deepStrictEqual(cnyFenToUsdNanoFloor(700, 7.0), 1_000_000_000n);
  assert.deepStrictEqual(cnyFenToUsdNanoFloor(1, 7.0), 1_428_571n);
  assert.deepStrictEqual(cnyFenToUsdNanoFloor(0, 7.0), 0n);
});

test("quote generation and verification enforce version and validity", () => {
  const now = new Date("2026-09-11T10:00:00Z");
  const quote = createCostQuote("sentence", {}, now, 10);
  assert.deepStrictEqual(quote.priceVersion, PRICE_POLICY_VERSION);
  assert.deepStrictEqual(quote.fxGuardVersion, FX_GUARD_VERSION);
  assert.deepStrictEqual(quote.maxNanoUsd, "1843200");

  const verified = verifyCostQuote(quote, "sentence", {}, now);
  assert.strictEqual(verified.ok, true);
  if (verified.ok) {
    assert.deepStrictEqual(verified.maxNanoUsd, 1_843_200n);
  }

  const later = new Date("2026-09-11T10:11:00Z");
  const expired = verifyCostQuote(quote, "sentence", {}, later);
  assert.strictEqual(expired.ok, false);
  if (!expired.ok) {
    assert.deepStrictEqual(expired.code, "quote_expired");
  }

  const stale = verifyCostQuote(
    { ...quote, priceVersion: "old-version" },
    "sentence",
    {},
    now,
  );
  assert.strictEqual(stale.ok, false);
  if (!stale.ok) {
    assert.deepStrictEqual(stale.code, "stale_price_version");
  }

  const insufficient = verifyCostQuote(
    { ...quote, maxNanoUsd: "1000" },
    "sentence",
    {},
    now,
  );
  assert.strictEqual(insufficient.ok, false);
  if (!insufficient.ok) {
    assert.deepStrictEqual(insufficient.code, "insufficient_quote_ceiling");
  }
});

test("full package extreme calculations prove 2元 trial and 20元 monthly budget limits", () => {
  const trial = calculateFullPackageCost("trial");
  assert.deepStrictEqual(trial.baseNanoUsd, 130_041_600n);
  assert.deepStrictEqual(trial.retryNanoUsd, 260_083_200n);
  assert.strictEqual(trial.baseFenCny <= 100, true);
  assert.strictEqual(trial.retryFenCny <= 200, true);

  const monthly = calculateFullPackageCost("monthly");
  assert.deepStrictEqual(monthly.baseNanoUsd, 1_330_416_000n);
  assert.deepStrictEqual(monthly.retryNanoUsd, 2_660_832_000n);
  assert.strictEqual(monthly.baseFenCny <= 1000, true);
  assert.strictEqual(monthly.retryFenCny <= 2000, true);
});

test("addCalendarMonthsUtc handles month-end anchors and leap years cleanly", () => {
  const jan31 = new Date(Date.UTC(2026, 0, 31, 10, 0, 0));
  const febEnd = addCalendarMonthsUtc(jan31, 1);
  assert.deepStrictEqual(febEnd.toISOString(), "2026-02-28T10:00:00.000Z");

  const marEnd = addCalendarMonthsUtc(jan31, 2);
  assert.deepStrictEqual(marEnd.toISOString(), "2026-03-31T10:00:00.000Z");

  const leapJan31 = new Date(Date.UTC(2028, 0, 31, 12, 0, 0));
  const leapFeb = addCalendarMonthsUtc(leapJan31, 1);
  assert.deepStrictEqual(leapFeb.toISOString(), "2028-02-29T12:00:00.000Z");

  const periods = calculateMonthlyPeriods(jan31, 3);
  assert.deepStrictEqual(periods.length, 3);
  assert.deepStrictEqual(
    periods[0].startsAt.toISOString(),
    "2026-01-31T10:00:00.000Z",
  );
  assert.deepStrictEqual(
    periods[0].endsAt.toISOString(),
    "2026-02-28T10:00:00.000Z",
  );
  assert.deepStrictEqual(
    periods[1].startsAt.toISOString(),
    "2026-02-28T10:00:00.000Z",
  );
  assert.deepStrictEqual(
    periods[1].endsAt.toISOString(),
    "2026-03-31T10:00:00.000Z",
  );
  assert.deepStrictEqual(
    periods[2].startsAt.toISOString(),
    "2026-03-31T10:00:00.000Z",
  );
  assert.deepStrictEqual(
    periods[2].endsAt.toISOString(),
    "2026-04-30T10:00:00.000Z",
  );
});

test("entitlement constants match approved business plan", () => {
  assert.deepStrictEqual(TRIAL_ENTITLEMENTS.maxSentences, 30);
  assert.deepStrictEqual(TRIAL_ENTITLEMENTS.maxTtsCharacters, 3000);
  assert.deepStrictEqual(TRIAL_ENTITLEMENTS.maxTranscriptionMs, 300_000);
  assert.deepStrictEqual(TRIAL_ENTITLEMENTS.maxPreparations, 3);

  assert.deepStrictEqual(MONTHLY_ENTITLEMENTS.maxSentences, 300);
  assert.deepStrictEqual(MONTHLY_ENTITLEMENTS.maxTtsCharacters, 30000);
  assert.deepStrictEqual(MONTHLY_ENTITLEMENTS.maxTranscriptionMs, 3_600_000);
  assert.deepStrictEqual(MONTHLY_ENTITLEMENTS.maxPreparations, 30);
  assert.deepStrictEqual(MONTHLY_PRICE_FEN_CNY, 3990);
});
