// Edge Function: /v1/admin/service-controls
// Reads and updates application-level service flags. This never changes
// provider dashboards, secrets, or deployment configuration.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  environmentFallback,
  parseServiceControls,
  publicServiceControls,
  readServiceControls,
  SERVICE_CONTROLS_VERSION,
  type ServiceControlsClient,
} from "../_shared/service_controls.ts";

export interface AdminServiceControlsDependencies {
  env?: Pick<typeof Deno.env, "get">;
  requireAuth?: typeof requireAuth;
  createSupabase?: (url: string, key: string) => ServiceControlsClient;
}

type ControlsAction = "read" | "update";

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function booleanValue(value: unknown): boolean | undefined {
  return typeof value === "boolean" ? value : undefined;
}

function parseAction(value: unknown): ControlsAction | null {
  if (value === "read" || value === "update") return value;
  return null;
}

export function createAdminServiceControlsHandler(
  dependencies: AdminServiceControlsDependencies = {},
): (req: Request) => Promise<Response> {
  const env = dependencies.env ?? Deno.env;
  const authenticate = dependencies.requireAuth ?? requireAuth;
  const makeSupabase = dependencies.createSupabase ??
    ((url: string, key: string) =>
      createClient(url, key) as unknown as ServiceControlsClient);

  return async (req: Request) => {
    if (req.method === "OPTIONS") return handleOptions();
    if (req.method !== "GET" && req.method !== "POST") {
      return errorResponse("Method not allowed", 405, "method_not_allowed");
    }

    const operatorId = authenticate(req);
    if (operatorId instanceof Response) return operatorId;

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
      p_user_id: operatorId,
    });
    if (adminResult.error || adminResult.data !== true) {
      return errorResponse("Admin access required", 403, "admin_forbidden");
    }

    if (req.method === "GET") {
      const controls = await readServiceControls(
        supabase,
        environmentFallback(env),
      );
      return json(publicServiceControls(controls));
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json() as Record<string, unknown>;
    } catch {
      return errorResponse("Invalid JSON body", 400, "invalid_body");
    }
    const action = parseAction(body.action ?? "update");
    if (action !== "update") {
      return errorResponse(
        "Only the update action is supported",
        400,
        "invalid_action",
      );
    }

    // A separate RPC is intentional: membership allowlisting grants read
    // access, while a future role table controls high-impact writes.
    const writeResult = await supabase.rpc("is_admin_operator", {
      p_user_id: operatorId,
    });
    if (writeResult.error || writeResult.data !== true) {
      return errorResponse(
        "Management permission required",
        403,
        "admin_write_forbidden",
      );
    }

    const current = await readServiceControls(
      supabase,
      environmentFallback(env),
    );
    const expectedVersion = stringValue(body.expectedVersion);
    if (expectedVersion && expectedVersion !== current.version) {
      return errorResponse(
        "Service controls changed; reload and try again",
        409,
        "controls_version_conflict",
      );
    }

    const flags = {
      membershipEnforcementEnabled: booleanValue(
        body.membershipEnforcementEnabled,
      ),
      trialSignupsEnabled: booleanValue(body.trialSignupsEnabled),
      membershipSalesEnabled: booleanValue(body.membershipSalesEnabled),
      generationEnabled: booleanValue(body.generationEnabled),
    };
    if (Object.values(flags).every((value) => value === undefined)) {
      return errorResponse(
        "At least one service flag is required",
        400,
        "missing_flags",
      );
    }
    const updated = {
      membershipEnforcementEnabled: flags.membershipEnforcementEnabled ??
        current.membershipEnforcementEnabled,
      trialSignupsEnabled: flags.trialSignupsEnabled ??
        current.trialSignupsEnabled,
      membershipSalesEnabled: flags.membershipSalesEnabled ??
        current.membershipSalesEnabled,
      generationEnabled: flags.generationEnabled ?? current.generationEnabled,
    };

    const result = await supabase.rpc("set_platform_service_controls", {
      p_admin_user_id: operatorId,
      p_expected_version: current.version,
      p_version: SERVICE_CONTROLS_VERSION,
      p_membership_enforcement_enabled: updated.membershipEnforcementEnabled,
      p_trial_signups_enabled: updated.trialSignupsEnabled,
      p_membership_sales_enabled: updated.membershipSalesEnabled,
      p_generation_enabled: updated.generationEnabled,
      p_anonymous_test_mode_enabled: false,
      p_reason: stringValue(body.reason) ?? "service_control_update",
      p_client_request_id: stringValue(body.clientRequestId),
    });
    if (result.error || result.data == null) {
      return errorResponse(
        "Service controls could not be updated",
        503,
        "controls_update_failed",
      );
    }
    const parsed = parseServiceControls(result.data, updated);
    return json(publicServiceControls({
      ...parsed,
      configured: true,
      source: "database",
    }));
  };
}

if (import.meta.main) {
  Deno.serve(createAdminServiceControlsHandler());
}
