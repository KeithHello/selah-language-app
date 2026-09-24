// Server-controlled feature flags for Selah's membership and generation modes.
// The database is authoritative when the platform settings RPC is available;
// environment values are only a safe local/bootstrap fallback.

export const SERVICE_CONTROLS_VERSION = "2026-09-17-v1";

export interface ServiceControls {
  version: string;
  membershipEnforcementEnabled: boolean;
  trialSignupsEnabled: boolean;
  membershipSalesEnabled: boolean;
  generationEnabled: boolean;
  configured: boolean;
  updatedAt: string | null;
  updatedBy: string | null;
  source: "database" | "environment" | "default";
}

export interface ServiceControlsClient {
  rpc(
    name: string,
    args: Record<string, unknown>,
  ): Promise<{ data: unknown; error: unknown }>;
}

export interface ServiceControlsFallback {
  membershipEnforcementEnabled?: boolean;
  trialSignupsEnabled?: boolean;
  membershipSalesEnabled?: boolean;
  generationEnabled?: boolean;
}

const DEFAULT_FALLBACK: Required<ServiceControlsFallback> = {
  // Registered free access is the safe bootstrap state: no membership gate
  // is applied until the platform enables membership enforcement.
  membershipEnforcementEnabled: false,
  trialSignupsEnabled: false,
  membershipSalesEnabled: false,
  generationEnabled: true,
};

function booleanValue(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value : null;
}

/**
 * Accepts the snake_case database shape and the camelCase API shape, while
 * rejecting non-boolean values instead of allowing a client to smuggle flags.
 */
export function parseServiceControls(
  raw: unknown,
  fallback: ServiceControlsFallback = {},
): ServiceControls {
  const defaults = { ...DEFAULT_FALLBACK, ...fallback };
  const source = raw && typeof raw === "object"
    ? raw as Record<string, unknown>
    : {};
  const settings = source.settings && typeof source.settings === "object"
    ? source.settings as Record<string, unknown>
    : source;
  const configured = source.configured === true || settings.configured === true;
  return {
    version: stringValue(source.version ?? settings.version) ??
      SERVICE_CONTROLS_VERSION,
    membershipEnforcementEnabled: booleanValue(
      settings.membershipEnforcementEnabled ??
        settings.membership_enforcement_enabled,
      defaults.membershipEnforcementEnabled,
    ),
    trialSignupsEnabled: booleanValue(
      settings.trialSignupsEnabled ?? settings.trial_signups_enabled,
      defaults.trialSignupsEnabled,
    ),
    membershipSalesEnabled: booleanValue(
      settings.membershipSalesEnabled ?? settings.membership_sales_enabled,
      defaults.membershipSalesEnabled,
    ),
    generationEnabled: booleanValue(
      settings.generationEnabled ?? settings.generation_enabled,
      defaults.generationEnabled,
    ),
    configured,
    updatedAt: stringValue(source.updatedAt ?? source.updated_at),
    updatedBy: stringValue(source.updatedBy ?? source.updated_by),
    source: configured ? "database" : "default",
  };
}

function envBoolean(
  env: Pick<typeof Deno.env, "get">,
  name: string,
  fallback: boolean,
): boolean {
  const value = env.get(name)?.trim().toLowerCase();
  if (value === "1" || value === "true" || value === "yes" || value === "on") {
    return true;
  }
  if (value === "0" || value === "false" || value === "no" || value === "off") {
    return false;
  }
  return fallback;
}

export function environmentFallback(
  env: Pick<typeof Deno.env, "get"> = Deno.env,
): ServiceControlsFallback {
  return {
    membershipEnforcementEnabled: envBoolean(
      env,
      "MEMBERSHIP_ENFORCEMENT_ENABLED",
      DEFAULT_FALLBACK.membershipEnforcementEnabled,
    ),
    trialSignupsEnabled: envBoolean(
      env,
      "MEMBERSHIP_TRIAL_SIGNUPS_ENABLED",
      DEFAULT_FALLBACK.trialSignupsEnabled,
    ),
    membershipSalesEnabled: envBoolean(
      env,
      "MEMBERSHIP_SALES_ENABLED",
      DEFAULT_FALLBACK.membershipSalesEnabled,
    ),
    generationEnabled: envBoolean(
      env,
      "GENERATION_SERVICE_ENABLED",
      DEFAULT_FALLBACK.generationEnabled,
    ),
  };
}

/**
 * Reads the platform settings without making generation fail merely because
 * the settings migration has not reached a local environment yet. A missing
 * settings RPC returns the safe environment/bootstrap state and marks it as
 * unconfigured, so sales remain disabled until the database is ready.
 */
export async function readServiceControls(
  client: ServiceControlsClient,
  fallback: ServiceControlsFallback = environmentFallback(),
): Promise<ServiceControls> {
  try {
    const result = await client.rpc("get_platform_service_controls", {});
    if (!result.error && result.data != null) {
      const parsed = parseServiceControls(result.data, fallback);
      return { ...parsed, source: "database", configured: true };
    }
  } catch {
    // Bootstrap environments may not have the settings migration yet.
  }
  const parsed = parseServiceControls({}, fallback);
  return {
    ...parsed,
    configured: false,
    source: Object.values(fallback).some((value) => value !== undefined)
      ? "environment"
      : "default",
  };
}

export function publicServiceControls(
  controls: ServiceControls,
): Record<string, unknown> {
  return {
    version: controls.version,
    membershipEnforcementEnabled: controls.membershipEnforcementEnabled,
    trialSignupsEnabled: controls.trialSignupsEnabled,
    membershipSalesEnabled: controls.membershipSalesEnabled,
    generationEnabled: controls.generationEnabled,
    configured: controls.configured,
    updatedAt: controls.updatedAt,
  };
}
