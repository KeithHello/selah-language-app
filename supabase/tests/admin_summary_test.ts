import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AdminSummaryDependencies,
  createAdminSummaryHandler,
} from "../functions/admin-summary/index.ts";

const USER_ID = "5a9b8d4c-6e2f-4c7a-9b1d-2e3f4a5b6c7d";
const START = new Date("2026-09-01T00:00:00Z").toISOString();
const END = new Date("2026-09-08T00:00:00Z").toISOString();

function makeRequest(overrides: Record<string, unknown> = {}) {
  return new Request("https://example.test/functions/v1/admin-summary", {
    method: "POST",
    headers: {
      Authorization: `Bearer token.${
        btoa(JSON.stringify({ sub: USER_ID }))
      }.token`,
    },
    body: JSON.stringify({ start: START, end: END, ...overrides }),
  });
}

function deps(overrides: Partial<AdminSummaryDependencies["rpcResults"]> = {}) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  return {
    calls,
    deps: {
      requireAuth: () => USER_ID,
      env: { get: () => "https://example.test" },
      createSupabase: () => ({
        rpc: async (name: string, args: Record<string, unknown>) => {
          calls.push({ name, args });
          if (name === "is_admin_member") {
            return { data: true, error: null };
          }
          if (name === "admin_dashboard_summary") {
            return {
              data: overrides.summary ?? { activeLearners: 2 },
              error: null,
            };
          }
          if (name === "admin_generation_attempts") {
            return { data: overrides.attempts ?? [], error: null };
          }
          return { data: null, error: new Error("unexpected RPC") };
        },
      }),
    } satisfies AdminSummaryDependencies,
  };
}

Deno.test("returns summary and attempts for an administrator", async () => {
  const setup = deps({
    summary: { activeLearners: 12, api: { providerAttempts: 3 } },
    attempts: [{ id: "attempt-1", feature: "tts" }],
  });
  const response = await createAdminSummaryHandler(setup.deps)(makeRequest());
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.summary.activeLearners, 12);
  assertEquals(body.attempts.length, 1);
  assertEquals(setup.calls[0].name, "is_admin_member");
});

Deno.test("rejects a non-administrator without reading dashboard data", async () => {
  const setup = deps();
  const denied: AdminSummaryDependencies = {
    ...setup.deps,
    createSupabase: () => ({
      rpc: async (name: string) => {
        if (name === "is_admin_member") {
          return { data: false, error: null };
        }
        throw new Error("dashboard data must not be queried");
      },
    }),
  };
  const response = await createAdminSummaryHandler(denied)(makeRequest());
  assertEquals(response.status, 403);
});

Deno.test("requires a bounded UTC time range", async () => {
  const setup = deps();
  const response = await createAdminSummaryHandler(setup.deps)(
    makeRequest({ start: undefined, end: undefined }),
  );
  assertEquals(response.status, 400);
});

Deno.test("returns aggregate audience data for one requested dimension", async () => {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  const setup: AdminSummaryDependencies = {
    requireAuth: () => USER_ID,
    env: { get: () => "https://example.test" },
    createSupabase: () => ({
      rpc: async (name: string, args: Record<string, unknown>) => {
        calls.push({ name, args });
        if (name === "is_admin_member") return { data: true, error: null };
        if (name === "get_admin_audience_summary") {
          return {
            data: {
              dimension: "ageGroup",
              registered: 20,
              profileCovered: 12,
              groups: [],
            },
            error: null,
          };
        }
        throw new Error("overview RPC must not run for audience view");
      },
    }),
  };
  const response = await createAdminSummaryHandler(setup)(makeRequest({
    view: "audience",
    dimension: "ageGroup",
  }));
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.audience.registered, 20);
  assertEquals(calls.at(-1)?.name, "get_admin_audience_summary");
  assertEquals(calls.at(-1)?.args.p_dimension, "ageGroup");
});
