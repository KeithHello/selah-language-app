import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { aggregateMembershipUsage } from "../functions/_shared/membership_usage.ts";

Deno.test("membership usage keeps sentence and batch reservations separate", () => {
  const usage = aggregateMembershipUsage([
    { feature: "sentence", units_reserved: 12, status: "settled" },
    { feature: "sentence", units_reserved: 2, status: "reserved" },
    { feature: "batch", units_reserved: 7, status: "settled" },
    { feature: "batch", units_reserved: 1, status: "unknown" },
  ]);

  assertEquals(usage.sentence, { used: 12, reserved: 2 });
  assertEquals(usage.batch, { used: 7, reserved: 1 });
});

Deno.test("membership usage separates settled units from in-flight reservations", () => {
  const usage = aggregateMembershipUsage([
    { feature: "tts", units_reserved: 900, status: "settled" },
    { feature: "tts", units_reserved: 100, status: "dispatch_claimed" },
    { feature: "transcription", units_reserved: 30000, status: "unknown" },
    { feature: "preparation", units_reserved: 1, status: "released_unsent" },
  ]);

  assertEquals(usage.ttsCharacters, { used: 900, reserved: 100 });
  assertEquals(usage.transcriptionMs, { used: 0, reserved: 30000 });
  assertEquals(usage.preparations, { used: 0, reserved: 0 });
});
