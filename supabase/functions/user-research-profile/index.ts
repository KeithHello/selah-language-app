import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  PROFILE_NOTICE_VERSION,
  type ProfileOperation,
  validateProfileOperation,
} from "../_shared/research_profile_contract.ts";

export interface UserResearchProfileRpcClient {
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
}

export interface UserResearchProfileDependencies {
  env?: Pick<typeof Deno.env, "get">;
  requireAuth?: (req: Request) => string | Response;
  createSupabase?: (url: string, key: string) => UserResearchProfileRpcClient;
}

interface RpcResult {
  data: unknown;
  error: unknown;
}

function normalizeRpcResult(value: unknown): RpcResult {
  if (
    value && typeof value === "object" && "data" in value && "error" in value
  ) {
    const result = value as { data: unknown; error: unknown };
    return { data: result.data, error: result.error };
  }
  return { data: value, error: null };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function profileError(message: string): { status: number; code: string } {
  if (message.includes("profile_invalid_input")) {
    return { status: 400, code: "profile_invalid_input" };
  }
  if (message.includes("profile_consent_required")) {
    return { status: 400, code: "profile_consent_required" };
  }
  if (message.includes("profile_age_policy_required")) {
    return { status: 403, code: "profile_age_policy_required" };
  }
  if (message.includes("profile_conflict")) {
    return { status: 409, code: "profile_conflict" };
  }
  if (message.includes("profile_notice_changed")) {
    return { status: 409, code: "profile_notice_changed" };
  }
  return { status: 503, code: "profile_unavailable" };
}

function rpcErrorMessage(error: unknown): string {
  if (typeof error === "string") return error;
  if (error && typeof error === "object" && "message" in error) {
    return String((error as { message?: unknown }).message ?? "");
  }
  return String(error ?? "");
}

export function createUserResearchProfileHandler(
  dependencies: UserResearchProfileDependencies = {},
): (req: Request) => Promise<Response> {
  const env = dependencies.env ?? Deno.env;
  const authenticate = dependencies.requireAuth ?? requireAuth;
  const makeSupabase = dependencies.createSupabase ??
    ((url: string, key: string) =>
      createClient(url, key) as unknown as UserResearchProfileRpcClient);

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return handleOptions();
    if (req.method !== "GET" && req.method !== "POST") {
      return errorResponse("Method not allowed", 405, "method_not_allowed");
    }

    const auth = authenticate(req);
    if (auth instanceof Response) return auth;
    const supabaseUrl = env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return errorResponse(
        "Research profile unavailable",
        503,
        "profile_unavailable",
      );
    }
    const supabase = makeSupabase(supabaseUrl, serviceRoleKey);

    if (req.method === "GET") {
      let result: RpcResult;
      try {
        result = normalizeRpcResult(
          await supabase.rpc("get_user_research_profile", { p_user_id: auth }),
        );
      } catch {
        return errorResponse(
          "Research profile unavailable",
          503,
          "profile_unavailable",
        );
      }
      if (result.error || !isRecord(result.data)) {
        return errorResponse(
          "Research profile unavailable",
          503,
          "profile_unavailable",
        );
      }
      return json(result.data);
    }

    let body: Record<string, unknown>;
    try {
      const parsed = await req.json();
      if (!isRecord(parsed)) throw new Error("invalid body");
      body = parsed;
    } catch {
      return errorResponse(
        "Invalid profile request",
        400,
        "profile_invalid_input",
      );
    }
    const allowed = new Set([
      "operation",
      "profile",
      "noticeVersion",
      "researchConsent",
      "expectedRevision",
    ]);
    if (Object.keys(body).some((key) => !allowed.has(key))) {
      return errorResponse(
        "Invalid profile request",
        400,
        "profile_invalid_input",
      );
    }
    const validation = validateProfileOperation({
      operation: body.operation,
      profile: body.profile,
      noticeVersion: body.noticeVersion,
      researchConsent: body.researchConsent,
    });
    if (!validation.ok) {
      return errorResponse(validation.message, 400, validation.code);
    }
    if (
      validation.operation === "save" &&
      validation.profile?.ageGroup === "under_14" &&
      !isEnabled(env.get("RESEARCH_PROFILE_CHILDREN_ENABLED"))
    ) {
      return errorResponse(
        "Age policy is required before collecting this profile",
        403,
        "profile_age_policy_required",
      );
    }
    const expectedRevision = body.expectedRevision;
    if (
      expectedRevision !== undefined &&
      (typeof expectedRevision !== "number" ||
        !Number.isSafeInteger(expectedRevision) ||
        expectedRevision < 0)
    ) {
      return errorResponse(
        "Invalid profile revision",
        400,
        "profile_invalid_input",
      );
    }
    const args: Record<string, unknown> = {
      p_user_id: auth,
      p_operation: validation.operation as ProfileOperation,
      p_profile: validation.profile,
      p_notice_version: body.noticeVersion ?? PROFILE_NOTICE_VERSION,
      p_research_consent: body.researchConsent === true,
      p_expected_revision: expectedRevision ?? null,
    };
    let result: RpcResult;
    try {
      result = normalizeRpcResult(
        await supabase.rpc("update_user_research_profile", args),
      );
    } catch {
      return errorResponse(
        "Research profile unavailable",
        503,
        "profile_unavailable",
      );
    }
    if (result.error || !isRecord(result.data)) {
      const details = profileError(rpcErrorMessage(result.error));
      return errorResponse(
        "Research profile unavailable",
        details.status,
        details.code,
      );
    }
    return json(result.data);
  };
}

function isEnabled(value: string | undefined): boolean {
  return ["1", "true", "yes", "on"].includes(
    (value ?? "").trim().toLowerCase(),
  );
}

if (import.meta.main) {
  Deno.serve(createUserResearchProfileHandler());
}
