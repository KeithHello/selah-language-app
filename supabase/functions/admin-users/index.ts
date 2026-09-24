// deno-lint-ignore-file no-explicit-any
// Edge Function: /v1/admin/users
// Lists users and retrieves detailed membership timelines for authorized
// administrators. Email addresses are masked before leaving the function.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import { maskEmail } from "../_shared/admin_membership_contract.ts";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type QueryResult = {
  data: any;
  error: unknown;
};

export interface AdminUsersClient {
  rpc(name: string, args: Record<string, unknown>): Promise<QueryResult>;
  from(table: string): any;
  auth?: {
    admin?: {
      listUsers(
        options: { page: number; perPage: number },
      ): Promise<QueryResult>;
    };
  };
}

export interface AdminUsersDependencies {
  env?: Pick<typeof Deno.env, "get">;
  requireAuth?: typeof requireAuth;
  createSupabase?: (url: string, key: string) => AdminUsersClient;
}

function parseLimit(value: unknown): number {
  const number = Number(value ?? 100);
  return Number.isSafeInteger(number)
    ? Math.min(Math.max(number, 1), 100)
    : 100;
}

function parseCursor(value: unknown): number {
  const number = Number(value ?? 0);
  return Number.isSafeInteger(number) && number >= 0 ? number : 0;
}

function inputFromRequest(req: Request): Record<string, unknown> {
  const url = new URL(req.url);
  return {
    userId: url.searchParams.get("userId"),
    search: url.searchParams.get("search"),
    limit: url.searchParams.get("limit"),
    cursor: url.searchParams.get("cursor"),
  };
}

async function bodyFromRequest(req: Request): Promise<Record<string, unknown>> {
  if (req.method !== "POST") return {};
  try {
    const body = await req.json();
    return body && typeof body === "object"
      ? body as Record<string, unknown>
      : {};
  } catch {
    throw new Error("invalid_body");
  }
}

function validTargetUserId(value: unknown): string | null {
  return typeof value === "string" && UUID_PATTERN.test(value.trim())
    ? value.trim()
    : null;
}

async function detail(
  supabase: AdminUsersClient,
  targetUserId: string,
): Promise<Response> {
  const [memberships, orders, logs] = await Promise.all([
    supabase.from("user_memberships")
      .select("*")
      .eq("user_id", targetUserId)
      .order("started_at", { ascending: false }),
    supabase.from("membership_orders")
      .select("*")
      .eq("user_id", targetUserId)
      .order("created_at", { ascending: false }),
    supabase.from("admin_audit_logs")
      .select("*")
      .eq("target_user_id", targetUserId)
      .order("created_at", { ascending: false }),
  ]);
  if (memberships.error || orders.error || logs.error) {
    return errorResponse("User detail unavailable", 503, "admin_query_failed");
  }
  return json({
    userId: targetUserId,
    periods: memberships.data ?? [],
    orders: orders.data ?? [],
    auditLogs: logs.data ?? [],
  });
}

function latestMembership(rows: any[]): any | null {
  return [...rows]
    .filter((row) => row && typeof row.user_id === "string")
    .sort((a, b) =>
      String(b.expires_at ?? "").localeCompare(String(a.expires_at ?? ""))
    )[0] ?? null;
}

async function listUsers(
  supabase: AdminUsersClient,
  search: string,
  limit: number,
  cursor: number,
): Promise<Response> {
  const authAdmin = supabase.auth?.admin;
  let authUsers: any[] = [];
  let nextCursor: number | null = null;

  if (authAdmin?.listUsers) {
    const result = await authAdmin.listUsers({
      page: Math.floor(cursor / limit) + 1,
      perPage: limit,
    });
    if (result.error) {
      return errorResponse("User list unavailable", 503, "admin_query_failed");
    }
    authUsers = Array.isArray(result.data?.users) ? result.data.users : [];
    const lastPage = result.data?.lastPage;
    if (
      typeof lastPage === "number" && Math.floor(cursor / limit) + 1 < lastPage
    ) {
      nextCursor = cursor + authUsers.length;
    }
  }

  // The fallback keeps local preview environments useful when auth.admin is
  // not exposed by the injected client. It still returns only masked IDs.
  if (authUsers.length === 0 && !authAdmin?.listUsers) {
    const result = await supabase.from("user_memberships")
      .select("user_id, plan, status, expires_at, created_at")
      .order("created_at", { ascending: false })
      .limit(limit);
    if (result.error) {
      return errorResponse("User list unavailable", 503, "admin_query_failed");
    }
    const items = (result.data ?? []).map((row: any) => ({
      userId: row.user_id,
      emailMasked: maskEmail(
        `user-${String(row.user_id).slice(0, 6)}@selah.app`,
      ),
      plan: row.plan ?? "free",
      status: row.status ?? "none",
      expiresAt: row.expires_at ?? null,
      serviceStatus: "active",
      createdAt: row.created_at,
    }));
    return json({ users: items, nextCursor: null });
  }

  const ids = authUsers
    .map((user) => typeof user.id === "string" ? user.id : null)
    .filter((id): id is string => id != null);
  const membershipResult = ids.length === 0
    ? { data: [], error: null }
    : await supabase.from("user_memberships")
      .select("user_id, plan, status, expires_at, created_at")
      .in("user_id", ids)
      .order("expires_at", { ascending: false });
  if (membershipResult.error) {
    return errorResponse("User list unavailable", 503, "admin_query_failed");
  }
  const byUser = new Map<string, any[]>();
  for (const row of membershipResult.data ?? []) {
    const list = byUser.get(row.user_id) ?? [];
    list.push(row);
    byUser.set(row.user_id, list);
  }
  const normalizedSearch = search.trim().toLowerCase();
  const items = authUsers.flatMap((user) => {
    const id = typeof user.id === "string" ? user.id : "";
    const email = typeof user.email === "string" ? user.email : "";
    if (
      !id || (normalizedSearch &&
        !id.toLowerCase().includes(normalizedSearch) &&
        !email.toLowerCase().includes(normalizedSearch))
    ) {
      return [];
    }
    const membership = latestMembership(byUser.get(id) ?? []);
    return [{
      userId: id,
      emailMasked: maskEmail(email || `user-${id.slice(0, 6)}@selah.app`),
      plan: membership?.plan ?? "free",
      status: membership?.status ?? "none",
      expiresAt: membership?.expires_at ?? null,
      serviceStatus: "active",
      createdAt: user.created_at ?? membership?.created_at ??
        new Date().toISOString(),
    }];
  });
  return json({ users: items.slice(0, limit), nextCursor });
}

export function createAdminUsersHandler(
  dependencies: AdminUsersDependencies = {},
): (req: Request) => Promise<Response> {
  const env = dependencies.env ?? Deno.env;
  const authenticate = dependencies.requireAuth ?? requireAuth;
  const makeSupabase = dependencies.createSupabase ??
    ((url: string, key: string) =>
      createClient(url, key) as unknown as AdminUsersClient);

  return async (req: Request) => {
    if (req.method === "OPTIONS") return handleOptions();
    if (req.method !== "GET" && req.method !== "POST") {
      return errorResponse("Method not allowed", 405, "method_not_allowed");
    }
    const auth = authenticate(req);
    if (auth instanceof Response) return auth;
    const urlInput = inputFromRequest(req);
    let body: Record<string, unknown>;
    try {
      body = await bodyFromRequest(req);
    } catch {
      return errorResponse("Invalid JSON body", 400, "invalid_body");
    }
    const input = { ...urlInput, ...body };
    const supabaseUrl = env.get("SUPABASE_URL") ?? "";
    const serviceKey = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      return errorResponse(
        "Admin service unavailable",
        503,
        "admin_unavailable",
      );
    }
    const supabase = makeSupabase(supabaseUrl, serviceKey);
    const adminResult = await supabase.rpc("is_admin_member", {
      p_user_id: auth,
    });
    if (adminResult.error || adminResult.data !== true) {
      return errorResponse("Admin access required", 403, "admin_forbidden");
    }

    const targetUserId = validTargetUserId(input.userId);
    if (input.userId != null && targetUserId == null) {
      return errorResponse("Invalid userId", 400, "invalid_user_id");
    }
    if (targetUserId) return detail(supabase, targetUserId);

    return listUsers(
      supabase,
      typeof input.search === "string" ? input.search : "",
      parseLimit(input.limit),
      parseCursor(input.cursor),
    );
  };
}

if (import.meta.main) {
  Deno.serve(createAdminUsersHandler());
}
