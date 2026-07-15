// Supabase Edge Functions - Shared utilities
// Used by all Edge Functions for CORS, auth, and error handling.

export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}

export function errorResponse(
  message: string,
  status = 400,
  code?: string,
): Response {
  return json({ error: code ?? message, message }, status);
}

export function handleOptions(): Response {
  return new Response("ok", { headers: CORS_HEADERS });
}

/**
 * Parse the user ID from a JWT already verified by the Supabase gateway.
 *
 * This helper does not verify the signature. It is safe only for functions
 * deployed with `verify_jwt = true`; direct runtimes must verify upstream first.
 */
export function getGatewayVerifiedUserId(req: Request): string | null {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return null;
  }

  try {
    const token = authHeader.replace("Bearer ", "");
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    const payload = JSON.parse(atob(parts[1]));
    if (!payload.sub) return null;

    return payload.sub as string;
  } catch {
    return null;
  }
}

/**
 * Require gateway-verified JWT claims and return the subject.
 * This performs structural parsing only; signature verification belongs to
 * the Supabase gateway configured with `verify_jwt = true`.
 */
export function requireAuth(req: Request): string | Response {
  const userId = getGatewayVerifiedUserId(req);
  if (!userId) {
    return errorResponse("Unauthorized", 401, "unauthorized");
  }
  return userId;
}
