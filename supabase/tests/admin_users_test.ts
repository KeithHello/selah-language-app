import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type AdminUsersClient,
  createAdminUsersHandler,
} from "../functions/admin-users/index.ts";

const ADMIN_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const USER_ID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const SIGNED_IN_AT = "2026-10-03T06:30:00.000Z";

function query(data: unknown[]) {
  const result = Promise.resolve({ data, error: null });
  return {
    select() {
      return this;
    },
    eq() {
      return this;
    },
    order() {
      return this;
    },
    limit() {
      return result;
    },
    then(
      resolve: (value: unknown) => unknown,
      reject?: (reason: unknown) => unknown,
    ) {
      return result.then(resolve, reject);
    },
  };
}

function dependencies(
  isAdmin: boolean,
  loginLookupFails = false,
): AdminUsersClient {
  return {
    rpc() {
      return Promise.resolve({ data: isAdmin, error: null });
    },
    from(table: string) {
      const data: Record<string, unknown[]> = {
        user_memberships: [],
        membership_orders: [],
        admin_audit_logs: [],
        generation_usage_attempts: [{
          id: "usage-1",
          user_id: USER_ID,
          feature: "sentence",
          model: "gpt-4o-mini",
          provider_status: "succeeded",
          delivery_status: "succeeded",
          item_count: 1,
          usage_source: "provider",
          started_at: SIGNED_IN_AT,
        }],
      };
      return query(data[table] ?? []) as never;
    },
    auth: {
      admin: {
        getUserById() {
          return Promise.resolve({
            data: loginLookupFails ? null : {
              user: {
                created_at: "2026-09-01T00:00:00.000Z",
                last_sign_in_at: SIGNED_IN_AT,
              },
            },
            error: loginLookupFails ? new Error("auth unavailable") : null,
          });
        },
        listUsers() {
          return Promise.resolve({
            data: { users: [], lastPage: 1 },
            error: null,
          });
        },
      },
    },
  };
}

function handlerFor(isAdmin: boolean, loginLookupFails = false) {
  return createAdminUsersHandler({
    env: {
      get(name) {
        return name === "SUPABASE_URL"
          ? "https://selah.example"
          : "server-only-service-key";
      },
    },
    requireAuth: () => ADMIN_ID,
    createSupabase: () => dependencies(isAdmin, loginLookupFails),
  });
}

Deno.test("admin user detail returns recent login and provider usage", async () => {
  const response = await handlerFor(true)(
    new Request("https://selah.example/admin-users", {
      method: "POST",
      body: JSON.stringify({ userId: USER_ID }),
    }),
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    userId: USER_ID,
    periods: [],
    orders: [],
    auditLogs: [],
    usageAttempts: [{
      id: "usage-1",
      user_id: USER_ID,
      feature: "sentence",
      model: "gpt-4o-mini",
      provider_status: "succeeded",
      delivery_status: "succeeded",
      item_count: 1,
      usage_source: "provider",
      started_at: SIGNED_IN_AT,
    }],
    login: {
      available: true,
      lastLoginAt: SIGNED_IN_AT,
      createdAt: "2026-09-01T00:00:00.000Z",
    },
  });
});

Deno.test("admin user detail stays protected by the administrator allowlist", async () => {
  const response = await handlerFor(false)(
    new Request("https://selah.example/admin-users", {
      method: "POST",
      body: JSON.stringify({ userId: USER_ID }),
    }),
  );

  assertEquals(response.status, 403);
  assertEquals(await response.json(), {
    error: "admin_forbidden",
    message: "Admin access required",
  });
});

Deno.test("reports unavailable login information without hiding usage", async () => {
  const response = await handlerFor(true, true)(
    new Request("https://selah.example/admin-users", {
      method: "POST",
      body: JSON.stringify({ userId: USER_ID }),
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.login, {
    available: false,
    lastLoginAt: null,
    createdAt: null,
  });
  assertEquals(body.usageAttempts.length, 1);
});
