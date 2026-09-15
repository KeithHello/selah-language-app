// Manual, administrator-triggered OpenAI daily cost snapshot sync.
// It is intentionally separate from browser dashboard reads and never exposes
// the OpenAI admin key to clients.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import { fetchOpenAiDailyCosts } from "../_shared/openai_admin_costs.ts";

export interface VendorCost {
  date: string;
  lineItem: string;
  amount: number;
  currency?: string;
  projectId?: string | null;
}

interface CostFetchResult {
  data: VendorCost[];
}

interface RpcClient {
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
  from(table: "provider_cost_snapshots"): {
    upsert(values: unknown, options?: Record<string, unknown>): Promise<{
      error: unknown;
    }>;
  };
}

export interface AdminCostSyncDependencies {
  env?: Pick<typeof Deno.env, "get">;
  requireAuth?: typeof requireAuth;
  createSupabase?: (url: string, key: string) => RpcClient;
  fetchCosts?: (input: {
    adminKey: string;
    projectId: string;
    start: string;
    end: string;
  }) => Promise<CostFetchResult>;
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

export function createAdminCostSyncHandler(
  dependencies: AdminCostSyncDependencies = {},
): (req: Request) => Promise<Response> {
  const env = dependencies.env ?? Deno.env;
  const authenticate = dependencies.requireAuth ?? requireAuth;
  const makeSupabase = dependencies.createSupabase ??
    ((url: string, key: string) =>
      createClient(url, key) as unknown as RpcClient);
  const fetchCosts = dependencies.fetchCosts ?? fetchOpenAiDailyCosts;

  return async (req: Request) => {
    if (req.method === "OPTIONS") return handleOptions();
    if (req.method !== "POST") {
      return errorResponse("Method not allowed", 405, "method_not_allowed");
    }
    const auth = authenticate(req);
    if (auth instanceof Response) return auth;

    const supabaseUrl = env.get("SUPABASE_URL") ?? "";
    const serviceKey = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const openaiAdminKey = env.get("OPENAI_ADMIN_API_KEY") ?? "";
    const projectId = env.get("OPENAI_PROJECT_ID") ?? "";
    if (!supabaseUrl || !serviceKey || !openaiAdminKey || !projectId) {
      return errorResponse(
        "Cost sync is not configured",
        503,
        "cost_sync_unconfigured",
      );
    }

    let body: {
      start?: string;
      end?: string;
      environment?: string;
    };
    try {
      body = await req.json();
    } catch {
      return errorResponse("Invalid JSON body", 400, "invalid_body");
    }
    if (
      !body.start || !body.end || Number.isNaN(Date.parse(body.start)) ||
      Number.isNaN(Date.parse(body.end))
    ) {
      return errorResponse(
        "A valid UTC date range is required",
        400,
        "invalid_period",
      );
    }
    const start = new Date(body.start);
    const end = new Date(body.end);
    if (start >= end || end.getTime() - start.getTime() > 93 * 86_400_000) {
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

    const supabase = makeSupabase(supabaseUrl, serviceKey);
    const adminResult = normalize<boolean>(
      await supabase.rpc("is_admin_member", { p_user_id: auth }),
    );
    if (adminResult.error || adminResult.data !== true) {
      return errorResponse("Admin access required", 403, "admin_forbidden");
    }

    const result = await fetchCosts({
      adminKey: openaiAdminKey,
      projectId,
      start: start.toISOString().slice(0, 10),
      end: end.toISOString().slice(0, 10),
    });
    const rows = result.data.map((cost) => {
      const amount = Number(cost.amount);
      const date = new Date(cost.date);
      if (
        !Number.isFinite(amount) || amount < 0 || Number.isNaN(date.getTime())
      ) {
        throw new Error("invalid vendor cost");
      }
      const lineItem = String(cost.lineItem ?? "openai").slice(0, 200);
      return {
        provider: "openai",
        project_external_id: cost.projectId ?? projectId,
        environment,
        line_item: lineItem,
        currency: (cost.currency ?? "USD").slice(0, 3),
        amount,
        usage_date: date.toISOString().slice(0, 10),
        fetched_at: new Date().toISOString(),
      };
    });
    const upsert = await supabase.from("provider_cost_snapshots").upsert(rows, {
      onConflict:
        "provider,project_external_id,environment,line_item,usage_date",
    });
    if (upsert.error) {
      return errorResponse(
        "Vendor cost snapshot failed",
        503,
        "cost_sync_failed",
      );
    }
    return json({ upserted: rows.length });
  };
}

if (import.meta.main) {
  Deno.serve(createAdminCostSyncHandler());
}
