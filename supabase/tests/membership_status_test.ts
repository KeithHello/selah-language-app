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
