import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const SOURCE = await Deno.readTextFile(
  "supabase/functions/membership-status/index.ts",
);

Deno.test("membership status tolerates absent membership schema while free mode is off", () => {
  assertStringIncludes(SOURCE, "membershipEnforcementEnabled");
  assertStringIncludes(
    SOURCE,
    "if (!controls.membershipEnforcementEnabled && isMissingRpcError(error))",
  );
  assertStringIncludes(SOURCE, "function isMissingRpcError");
  assertStringIncludes(SOURCE, 'plan: "free"');
  assertStringIncludes(SOURCE, 'status: "none"');
});

Deno.test("membership status fails closed when membership mode is enabled but schema is missing", () => {
  assertEquals(
    /controls\.membershipEnforcementEnabled[\s\S]*membership_query_failed/.test(
      SOURCE,
    ),
    true,
  );
});

Deno.test("membership status returns aggregated usage and future periods", () => {
  assertStringIncludes(SOURCE, "aggregateUsage");
  assertStringIncludes(SOURCE, "futurePeriods");
  assertStringIncludes(SOURCE, "released_unsent");
  assertStringIncludes(SOURCE, "usage: null");
});

Deno.test("membership status computes usage before the enforcement-off early return", () => {
  const liveUsageIndex = SOURCE.indexOf(
    "const liveUsage = await loadLiveUsage(supabase, userId, record);",
  );
  const modeOffIndex = SOURCE.indexOf(
    "if (!controls.membershipEnforcementEnabled)",
  );
  assertEquals(liveUsageIndex > -1, true);
  assertEquals(modeOffIndex > liveUsageIndex, true);
});

Deno.test("membership status passes live usage through in mode-off responses", () => {
  assertStringIncludes(SOURCE, "liveUsage.usage");
  assertStringIncludes(SOURCE, "liveUsage.futurePeriods");
});
