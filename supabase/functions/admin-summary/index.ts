// Service-role backed admin dashboard aggregator. Browser users receive only
// the final aggregate; OpenAI and Supabase service credentials stay server-side.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import { normalizeAudienceQuery } from "../_shared/admin_audience_contract.ts";

interface RpcClient {
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
}

export interface AdminSummaryDependencies {
  env?: Pick<typeof Deno.env, "get">;
  requireAuth?: typeof requireAuth;
  createSupabase?: (url: string, key: string) => RpcClient;
  rpcResults?: {
    summary?: Record<string, unknown>;
    attempts?: unknown[];
  };
}

interface RpcResult<T> {
  data: T | null;
  error: unknown;
}

function normalize<T>(value: unknown): RpcResult<T> {
  if (
    value && typeof value === "object" && "data" in value && "error" in value
  ) {
    return value as RpcResult<T>;
  }
  return { data: value as T, error: null };
}

export function createAdminSummaryHandler(
  dependencies: AdminSummaryDependencies = {},
): (req: Request) => Promise<Response> {
  const env = dependencies.env ?? Deno.env;
  const authenticate = dependencies.requireAuth ?? requireAuth;
  const makeSupabase = dependencies.createSupabase ??
    ((url: string, key: string) =>
      createClient(url, key) as unknown as RpcClient);

  return async (req: Request) => {
    if (req.method === "OPTIONS") return handleOptions();
    if (req.method !== "POST") {
      return errorResponse("Method not allowed", 405, "method_not_allowed");
    }
    const auth = authenticate(req);
    if (auth instanceof Response) return auth;

    const supabaseUrl = env.get("SUPABASE_URL") ?? "";
    const serviceKey = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      return errorResponse(
        "Admin service unavailable",
        503,
        "admin_unavailable",
      );
    }

    let body: {
      start?: string;
      end?: string;
      environment?: string;
      feature?: string | null;
      status?: string | null;
      limit?: number;
      view?: string;
      dimension?: unknown;
      cursor?: string | null;
    };
    try {
      body = await req.json();
    } catch {
      return errorResponse("Invalid JSON body", 400, "invalid_body");
    }
    const start = body.start;
    const end = body.end;
    if (
      !start || !end || Number.isNaN(Date.parse(start)) ||
      Number.isNaN(Date.parse(end))
    ) {
      return errorResponse(
        "A valid UTC period is required",
        400,
        "invalid_period",
      );
    }
    const startDate = new Date(start);
    const endDate = new Date(end);
    if (
      startDate >= endDate ||
      endDate.getTime() - startDate.getTime() > 93 * 86_400_000
    ) {
      return errorResponse(
        "The period is invalid or longer than 93 days",
        400,
        "invalid_period",
      );
    }

    const environment = body.environment ?? "production";
    if (!["production", "test"].includes(environment)) {
      return errorResponse("Invalid environment", 400, "invalid_environment");
    }
    const feature = body.feature ?? null;
    const status = body.status ?? null;
    const limit = Math.min(Math.max(Number(body.limit ?? 100), 1), 100);
    const view = body.view ?? "overview";
    if (!["overview", "usage", "orders", "audit", "audience"].includes(view)) {
      return errorResponse("Invalid dashboard view", 400, "invalid_view");
    }

    const supabase = makeSupabase(supabaseUrl, serviceKey);
    const adminResult = normalize<boolean>(
      await supabase.rpc("is_admin_member", { p_user_id: auth }),
    );
    if (adminResult.error || adminResult.data !== true) {
      return errorResponse("Admin access required", 403, "admin_forbidden");
    }

    if (view === "audience") {
      const audienceQuery = normalizeAudienceQuery({
        dimension: body.dimension,
        start,
        end,
      });
      if (!audienceQuery.ok) {
        return errorResponse(
          audienceQuery.message,
          400,
          audienceQuery.code,
        );
      }
      let audienceResult: RpcResult<Record<string, unknown>>;
      try {
        audienceResult = normalize<Record<string, unknown>>(
          await supabase.rpc("get_admin_audience_summary", {
            p_start: audienceQuery.start,
            p_end: audienceQuery.end,
            p_dimension: audienceQuery.dimension,
            p_admin_user_id: auth,
          }),
        );
      } catch {
        return errorResponse(
          "Admin audience data unavailable",
          503,
          "admin_query_failed",
        );
      }
      if (audienceResult.error || !audienceResult.data) {
        return errorResponse(
          "Admin audience data unavailable",
          503,
          "admin_query_failed",
        );
      }
      return json({
        audience: audienceResult.data,
        view,
        generatedAt: new Date().toISOString(),
      });
    }

    const [summaryResult, attemptsResult] = await Promise.all([
      supabase.rpc("admin_dashboard_summary", {
        p_start: startDate.toISOString(),
        p_end: endDate.toISOString(),
        p_environment: environment,
        p_admin_user_id: auth,
      }),
      supabase.rpc("admin_generation_attempts", {
        p_start: startDate.toISOString(),
        p_end: endDate.toISOString(),
        p_environment: environment,
        p_feature: feature,
        p_status: status,
        p_limit: limit,
        p_offset: 0,
        p_admin_user_id: auth,
      }),
    ]);
    const summary = normalize<Record<string, unknown>>(summaryResult);
    const attempts = normalize<unknown[]>(attemptsResult);
    if (summary.error || !summary.data || attempts.error) {
      return errorResponse(
        "Admin dashboard unavailable",
        503,
        "admin_query_failed",
      );
    }
    return json({
      summary: summary.data,
      attempts: attempts.data ?? [],
      view,
      generatedAt: new Date().toISOString(),
    });
  };
}

if (import.meta.main) {
  Deno.serve(createAdminSummaryHandler());
}
