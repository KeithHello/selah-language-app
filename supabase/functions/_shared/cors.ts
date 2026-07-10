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
 * Extract and verify the Supabase JWT from the Authorization header.
 * Returns the user ID if valid, null otherwise.
 */
export function getUserId(req: Request): string | null {
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
 * Validate that the request has a valid user token.
 * Returns userId or sends a 401 response.
 */
export function requireAuth(req: Request): string | Response {
  const userId = getUserId(req);
  if (!userId) {
    return errorResponse("Unauthorized", 401, "unauthorized");
  }
  return userId;
}
