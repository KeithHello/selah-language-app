import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { createAdminServiceControlsHandler } from "../functions/admin-service-controls/index.ts";

const USER_ID = "5a9b8d4c-6e2f-4c7a-9b1d-2e3f4a5b6c7d";

function request(method: "GET" | "POST", body?: Record<string, unknown>) {
  return new Request(
    "https://example.test/functions/v1/admin-service-controls",
    {
      method,
      headers: {
        Authorization: `Bearer token.${
          btoa(JSON.stringify({ sub: USER_ID }))
        }.token`,
        "Content-Type": "application/json",
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    },
  );
}

function setup(options: {
  isAdmin?: boolean;
  isOperator?: boolean;
  updateResult?: Record<string, unknown>;
} = {}) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  return {
    calls,
    dependencies: {
      requireAuth: () => USER_ID,
      env: {
        get(name: string) {
          return name === "SUPABASE_URL"
            ? "https://example.test"
            : "service-key";
        },
      },
      createSupabase: () => ({
        async rpc(name: string, args: Record<string, unknown>) {
          calls.push({ name, args });
          if (name === "is_admin_member") {
            return { data: options.isAdmin ?? true, error: null };
          }
          if (name === "is_admin_operator") {
            return { data: options.isOperator ?? true, error: null };
          }
          if (name === "get_platform_service_controls") {
            return {
              data: {
                version: "2026-09-17-v1",
                configured: true,
                membership_enforcement_enabled: false,
                trial_signups_enabled: false,
                membership_sales_enabled: false,
                generation_enabled: true,
                anonymous_test_mode_enabled: true,
              },
              error: null,
            };
          }
          if (name === "set_platform_service_controls") {
            return {
              data: options.updateResult ?? {
                version: "2026-09-17-v1",
                configured: true,
                membership_enforcement_enabled: true,
                trial_signups_enabled: true,
                membership_sales_enabled: true,
                generation_enabled: true,
                anonymous_test_mode_enabled: true,
              },
              error: null,
            };
          }
          return { data: null, error: new Error("unexpected rpc") };
        },
      }),
    },
  };
}

Deno.test("service controls read is admin-only", async () => {
  const setupData = setup({ isAdmin: false });
  const response = await createAdminServiceControlsHandler(
    setupData.dependencies,
  )(request("GET"));
  assertEquals(response.status, 403);
  assertEquals(setupData.calls.map((call) => call.name), ["is_admin_member"]);
});
Deno.test("service controls update requires operator and expected version", async () => {
  const setupData = setup({ isOperator: true });
  const response = await createAdminServiceControlsHandler(
    setupData.dependencies,
  )(
    request("POST", {
      action: "update",
      expectedVersion: "2026-09-17-v1",
      membershipEnforcementEnabled: true,
      trialSignupsEnabled: true,
      membershipSalesEnabled: true,
      anonymousTestModeEnabled: true,
      reason: "launch_membership_mode",
    }),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.membershipEnforcementEnabled, true);
  assertEquals(body.membershipSalesEnabled, true);
  assertEquals("anonymousTestModeEnabled" in body, false);
  const update = setupData.calls.find((call) =>
    call.name === "set_platform_service_controls"
  );
  assertEquals(update?.args.p_reason, "launch_membership_mode");
  assertEquals(update?.args.p_anonymous_test_mode_enabled, false);
});

Deno.test("service controls update is rejected for read-only admin", async () => {
  const setupData = setup({ isOperator: false });
  const response = await createAdminServiceControlsHandler(
    setupData.dependencies,
  )(
    request("POST", {
      action: "update",
      membershipEnforcementEnabled: true,
    }),
  );
  assertEquals(response.status, 403);
});
