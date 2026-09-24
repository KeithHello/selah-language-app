// deno-lint-ignore-file require-await
import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AdminCostSyncDependencies,
  createAdminCostSyncHandler,
  type VendorCost,
} from "../functions/admin-cost-sync/index.ts";
import { fetchOpenAiDailyCosts } from "../functions/_shared/openai_admin_costs.ts";

const USER_ID = "5a9b8d4c-6e2f-4c7a-9b1d-2e3f4a5b6c7d";

function request(body: Record<string, unknown> = {}) {
  return new Request("https://example.test/functions/v1/admin-cost-sync", {
    method: "POST",
    headers: {
      Authorization: `Bearer token.${
        btoa(JSON.stringify({ sub: USER_ID }))
      }.token`,
    },
    body: JSON.stringify({
      start: "2026-09-01",
      end: "2026-09-08",
      environment: "production",
      ...body,
    }),
  });
}

function deps(overrides: { admin?: boolean; costs?: unknown[] } = {}) {
  const calls: string[] = [];
  const dependencies: AdminCostSyncDependencies = {
    requireAuth: () => USER_ID,
    env: { get: () => "configured" },
    createSupabase: () => ({
      rpc: async (name: string) => {
        calls.push(name);
        if (name === "is_admin_member") {
          return { data: overrides.admin ?? true, error: null };
        }
        return { data: null, error: new Error("unexpected RPC") };
      },
      from: () => ({
        upsert: (values: unknown) => {
          calls.push("upsert:" + JSON.stringify(values));
          return Promise.resolve({ error: null });
        },
      }),
    }),
    fetchCosts: async () => {
      const data: VendorCost[] =
        (overrides.costs as VendorCost[] | undefined) ?? [
          {
            date: "2026-09-02",
            lineItem: "tts",
            amount: 6,
            currency: "USD",
            projectId: "proj_1",
          },
        ];
      return { data };
    },
  };
  return { dependencies, calls };
}

Deno.test("admin cost sync stores normalized daily vendor costs", async () => {
  const setup = deps();
  const response = await createAdminCostSyncHandler(setup.dependencies)(
    request(),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.upserted, 1);
  assertEquals(
    setup.calls.some((call) => call.includes('"line_item":"tts"')),
    true,
  );
  assertEquals(
    setup.calls.some((call) => call.includes("raw_line_item_key")),
    false,
  );
});

Deno.test("OpenAI cost client uses the documented time query parameters", async () => {
  const requestedUrls: string[] = [];
  await fetchOpenAiDailyCosts({
    adminKey: "admin-key",
    projectId: "proj_1",
    start: "2026-09-01",
    end: "2026-09-08",
  }, {
    fetch: (input: RequestInfo | URL) => {
      requestedUrls.push(String(input));
      return Promise.resolve(
        new Response(JSON.stringify({ data: [] }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
      );
    },
  });
  assertEquals(requestedUrls.length, 1);
  const url = new URL(requestedUrls[0]);
  assertEquals(url.searchParams.has("start_time"), true);
  assertEquals(url.searchParams.has("end_time"), true);
  assertEquals(url.searchParams.has("start_ts"), false);
  assertEquals(url.searchParams.has("end_ts"), false);
});

Deno.test("non-administrator cannot trigger a vendor cost sync", async () => {
  const setup = deps({ admin: false });
  const response = await createAdminCostSyncHandler(setup.dependencies)(
    request(),
  );
  assertEquals(response.status, 403);
});

Deno.test("rejects a period longer than 93 days", async () => {
  const setup = deps();
  const response = await createAdminCostSyncHandler(setup.dependencies)(
    request({ start: "2026-01-01", end: "2026-09-08" }),
  );
  assertEquals(response.status, 400);
});

Deno.test("never accepts negative vendor cost", async () => {
  const setup = deps({
    costs: [{
      date: "2026-09-02",
      lineItem: "tts",
      amount: -1,
      currency: "USD",
    }],
  });
  await assertRejects(() =>
    createAdminCostSyncHandler(setup.dependencies)(request())
  );
});
