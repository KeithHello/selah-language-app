// deno-lint-ignore-file require-await
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  environmentFallback,
  parseServiceControls,
  readServiceControls,
} from "../functions/_shared/service_controls.ts";

Deno.test("service controls parse strict flags and database metadata", () => {
  const parsed = parseServiceControls({
    version: "db-v2",
    configured: true,
    settings: {
      membership_enforcement_enabled: true,
      trial_signups_enabled: true,
      membershipSalesEnabled: false,
      generation_enabled: false,
      anonymous_test_mode_enabled: true,
    },
    updated_at: "2026-09-12T00:00:00Z",
  });
  assertEquals(parsed.version, "db-v2");
  assertEquals(parsed.membershipEnforcementEnabled, true);
  assertEquals(parsed.trialSignupsEnabled, true);
  assertEquals(parsed.membershipSalesEnabled, false);
  assertEquals(parsed.generationEnabled, false);
  assertEquals("anonymousTestModeEnabled" in parsed, false);
  assertEquals(parsed.updatedAt, "2026-09-12T00:00:00Z");
});
Deno.test("environment fallback accepts explicit bootstrap values", () => {
  const fallback = environmentFallback({
    get(name: string) {
      return name === "MEMBERSHIP_ENFORCEMENT_ENABLED"
        ? "on"
        : name === "GENERATION_SERVICE_ENABLED"
        ? "off"
        : name === "ANONYMOUS_TEST_MODE_ENABLED"
        ? "on"
        : undefined;
    },
  });
  assertEquals(fallback.membershipEnforcementEnabled, true);
  assertEquals(fallback.generationEnabled, false);
  assertEquals("anonymousTestModeEnabled" in fallback, false);
  assertEquals(fallback.membershipSalesEnabled, false);
});

Deno.test("legacy anonymous control values are ignored", () => {
  const parsed = parseServiceControls({ configured: true });
  assertEquals("anonymousTestModeEnabled" in parsed, false);
});

Deno.test("missing settings RPC fails safe and keeps generation available", async () => {
  const controls = await readServiceControls(
    {
      async rpc() {
        throw new Error("function does not exist");
      },
    },
    { membershipEnforcementEnabled: true },
  );
  assertEquals(controls.configured, false);
  assertEquals(controls.source, "environment");
  assertEquals(controls.membershipEnforcementEnabled, true);
  assertEquals(controls.generationEnabled, true);
  assert(controls.version.length > 0);
});
