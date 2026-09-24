export interface GatewayIdentity {
  userId: string;
  isAnonymous: boolean;
}

export interface AuthorizedIdentity extends GatewayIdentity {
  status: "allowed";
}

export type IdentityOrResponse = AuthorizedIdentity | Response;

function identityError(
  status: number,
  code: string,
  message: string,
): Response {
  return new Response(
    JSON.stringify({ error: code, message }),
    {
      status,
      headers: { "Content-Type": "application/json" },
    },
  );
}

/**
 * Read claims from a JWT already verified by the Supabase Edge gateway.
 * Direct runtimes must still verify the token before calling this helper.
 */
export function getGatewayVerifiedIdentity(
  req: Request,
): GatewayIdentity | null {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;

  try {
    const token = authHeader.replace("Bearer ", "");
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(atob(parts[1])) as Record<string, unknown>;
    if (typeof payload.sub !== "string" || !payload.sub) return null;
    return {
      userId: payload.sub,
      isAnonymous: payload.is_anonymous === true,
    };
  } catch {
    return null;
  }
}

/**
 * Reject identities that predate the registered-account-only product flow.
 * Account eligibility is never controlled by a service switch.
 */
export function authorizeBillableIdentity(req: Request): IdentityOrResponse {
  const identity = getGatewayVerifiedIdentity(req);
  if (!identity) {
    return identityError(401, "unauthorized", "Unauthorized");
  }
  if (identity.isAnonymous) {
    return identityError(
      403,
      "registered_account_required",
      "A registered account is required",
    );
  }
  return { ...identity, status: "allowed" as const };
}
