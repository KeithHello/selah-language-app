import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { PRO_ENTITLEMENTS } from "./membership_contract.ts";
import { aggregateUsage, legalPlanQuotes } from "./membership_usage.ts";

const startedAt = "2026-09-01T00:00:00.000Z";
const expiresAt = "2026-09-11T00:00:00.000Z";

Deno.test("sentence and batch share one pool and released rows are ignored", () => {
  const usage = aggregateUsage([
    { feature: "sentence", status: "settled", units: 20 },
    { feature: "batch", status: "reserved", units: 5 },
    { feature: "batch", status: "released_unsent", units: 9 },
    { feature: "tts", status: "unknown", units: 100 },
    { feature: "transcription", status: "dispatch_claimed", units: 60000 },
    { feature: "preparation", status: "settled", units: 1 },
  ], {
    maxSentences: 30,
    maxTtsCharacters: 3000,
    maxTranscriptionMs: 300000,
    maxPreparations: 3,
  }, startedAt);
  assertEquals(usage.sentences, { used: 25, limit: 30, remaining: 5 });
  assertEquals(usage.ttsCharacters.remaining, 2900);
  assertEquals(usage.transcriptionMs.remaining, 240000);
  assertEquals(usage.preparations.remaining, 2);
});

Deno.test("monthly upgrade at least 24 hours prorates price and caps", () => {
  const quotes = legalPlanQuotes({
    now: "2026-09-09T23:58:48.000Z",
    current: { plan: "monthly", startedAt, expiresAt },
    usage: zeroUsage(startedAt),
    futurePeriods: [],
    salesEnabled: true,
    paymentConfigured: true,
    proSalesEnabled: true,
  });
  const upgrade = quotes.find((quote) => quote.action === "upgrade_pro_now");
  assertEquals(upgrade?.chargeFenCny, 601);
  assertEquals(upgrade?.currentPeriodEffect, "replace_remainder");
  assertEquals(upgrade?.limitsAfter?.maxSentences, 90);
  assertEquals(upgrade?.limitsAfter?.maxTtsCharacters, 9007);
  assertEquals(upgrade?.limitsAfter?.maxTranscriptionMs, 1080900);
  assertEquals(upgrade?.limitsAfter?.maxPreparations, 9);
  assertEquals(quotes.some((quote) => quote.action === "schedule_pro"), false);
});

Deno.test("under 24 hours schedules a full Pro period instead of prorating", () => {
  const quotes = legalPlanQuotes({
    now: "2026-09-10T00:00:00.001Z",
    current: { plan: "monthly", startedAt, expiresAt },
    usage: zeroUsage(startedAt),
    futurePeriods: [],
    salesEnabled: true,
    paymentConfigured: false,
    proSalesEnabled: false,
  });
  assertEquals(
    quotes.some((quote) => quote.action === "upgrade_pro_now"),
    false,
  );
  const scheduled = quotes.find((quote) => quote.action === "schedule_pro");
  assertEquals(scheduled?.chargeFenCny, 9990);
  assertEquals(scheduled?.effectiveAt, expiresAt);
  assertEquals(scheduled?.limitsAfter, PRO_ENTITLEMENTS);
  assertEquals(scheduled?.unavailableReason, "payment_not_configured");
});

Deno.test("trial purchase starts now and warns that trial remainder is dropped", () => {
  const quotes = legalPlanQuotes({
    now: startedAt,
    current: { plan: "trial", startedAt, expiresAt },
    usage: zeroUsage(startedAt),
    futurePeriods: [],
    salesEnabled: true,
    paymentConfigured: true,
    proSalesEnabled: true,
  });
  const monthly = quotes.find((quote) => quote.action === "buy_monthly");
  assertEquals(monthly?.chargeFenCny, 3990);
  assertEquals(monthly?.effectiveAt, startedAt);
  assertEquals(monthly?.warnings.includes("trial_remainder_dropped"), true);
  assertEquals(
    quotes.some((quote) => quote.action === "upgrade_pro_now"),
    false,
  );
});

Deno.test("active Pro only offers another Pro period and keeps future periods", () => {
  const future = [{
    id: "future-1",
    plan: "monthly" as const,
    source: "grant" as const,
    startsAt: expiresAt,
    endsAt: "2026-10-11T00:00:00.000Z",
  }];
  const quotes = legalPlanQuotes({
    now: startedAt,
    current: { plan: "pro", startedAt, expiresAt },
    usage: zeroUsage(startedAt),
    futurePeriods: future,
    salesEnabled: false,
    paymentConfigured: true,
    proSalesEnabled: true,
  });
  assertEquals(quotes.map((quote) => quote.action), ["extend_pro"]);
  assertEquals(quotes[0].effectiveAt, "2026-10-11T00:00:00.000Z");
  assertEquals(quotes[0].unavailableReason, "sales_disabled");
  assertEquals(quotes[0].warnings, ["future_periods_unchanged"]);
});

function zeroUsage(asOf: string) {
  const row = { used: 0, limit: 0, remaining: 0 };
  return {
    asOf,
    sentences: row,
    ttsCharacters: row,
    transcriptionMs: row,
    preparations: row,
  };
}
