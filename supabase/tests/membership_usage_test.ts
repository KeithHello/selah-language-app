import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { MONTHLY_ENTITLEMENTS } from "../functions/_shared/membership_contract.ts";
import { aggregateUsage } from "../functions/_shared/membership_usage.ts";

Deno.test("sentence and batch usage share one allowance", () => {
  const usage = aggregateUsage(
    [
      { feature: "sentence", units: 12, status: "settled" },
      { feature: "sentence", units: 2, status: "reserved" },
      { feature: "batch", units: 7, status: "settled" },
      { feature: "batch", units: 1, status: "unknown" },
    ],
    MONTHLY_ENTITLEMENTS,
    "2026-10-02T00:00:00.000Z",
  );

  assertEquals(usage.sentences, { used: 22, limit: 300, remaining: 278 });
});

Deno.test("usage counts in-flight reservations and excludes released work", () => {
  const usage = aggregateUsage(
    [
      { feature: "tts", units: 900, status: "settled" },
      { feature: "tts", units: 100, status: "dispatch_claimed" },
      { feature: "transcription", units: 30000, status: "unknown" },
      { feature: "preparation", units: 1, status: "released_unsent" },
    ],
    MONTHLY_ENTITLEMENTS,
    "2026-10-02T00:00:00.000Z",
  );

  assertEquals(usage.ttsCharacters, {
    used: 1000,
    limit: 30000,
    remaining: 29000,
  });
  assertEquals(usage.transcriptionMs, {
    used: 30000,
    limit: 3600000,
    remaining: 3570000,
  });
  assertEquals(usage.preparations, {
    used: 0,
    limit: 30,
    remaining: 30,
  });
});
