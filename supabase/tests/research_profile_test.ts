import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  createUserResearchProfileHandler,
  type UserResearchProfileDependencies,
} from "../functions/user-research-profile/index.ts";

const USER_ID = "11111111-1111-1111-1111-111111111111";

function deps(overrides: Partial<UserResearchProfileDependencies> = {}) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const dependencies: UserResearchProfileDependencies = {
    requireAuth: () => USER_ID,
    env: {
      get: (name: string) =>
        name === "SUPABASE_URL" ? "https://example.test" : "service-key",
    },
    createSupabase: () => ({
      rpc: async (name: string, args: Record<string, unknown>) => {
        calls.push({ name, args });
        return {
          data: {
            profile: { learningGoal: "work" },
            promptState: "answered",
            consentState: "granted",
            noticeVersion: "2026-09-12-v1",
            revision: 2,
            canInvite: false,
          },
          error: null,
        };
      },
    }),
    ...overrides,
  };
  return { calls, dependencies };
}

function request(method: string, body?: Record<string, unknown>) {
  return new Request(
    "https://example.test/functions/v1/user-research-profile",
    {
      method,
      headers: body ? { "Content-Type": "application/json" } : undefined,
      body: body ? JSON.stringify(body) : undefined,
    },
  );
}

Deno.test("reads only the authenticated user's research profile", async () => {
  const setup = deps();
  const response = await createUserResearchProfileHandler(setup.dependencies)(
    request("GET"),
  );
  assertEquals(response.status, 200);
  assertEquals(setup.calls[0].name, "get_user_research_profile");
  assertEquals(setup.calls[0].args.p_user_id, USER_ID);
});

Deno.test("rejects saving without explicit consent before calling the database", async () => {
  const setup = deps();
  const response = await createUserResearchProfileHandler(setup.dependencies)(
    request("POST", {
      operation: "save",
      profile: { learningGoal: "daily" },
      noticeVersion: "2026-09-12-v1",
      researchConsent: false,
    }),
  );
  assertEquals(response.status, 400);
  assertEquals(setup.calls.length, 0);
});

Deno.test("keeps skip independent from consent and passes the server user id", async () => {
  const setup = deps();
  const response = await createUserResearchProfileHandler(setup.dependencies)(
    request("POST", {
      operation: "skip",
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(setup.calls[0].name, "update_user_research_profile");
  assertEquals(setup.calls[0].args.p_operation, "skip");
  assertEquals(setup.calls[0].args.p_user_id, USER_ID);
});

Deno.test("blocks under-14 collection until the product policy is enabled", async () => {
  const setup = deps();
  const response = await createUserResearchProfileHandler(setup.dependencies)(
    request("POST", {
      operation: "save",
      profile: { ageGroup: "under_14" },
      noticeVersion: "2026-09-12-v1",
      researchConsent: true,
    }),
  );
  assertEquals(response.status, 403);
  assertEquals(setup.calls.length, 0);
});
