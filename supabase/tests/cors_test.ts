// Supabase Edge Functions - Shared CORS Utilities Tests
// Run: deno test supabase/tests/cors_test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  CORS_HEADERS,
  errorResponse,
  getUserId,
  handleOptions,
  json,
  requireAuth,
} from "../functions/_shared/cors.ts";

// ============================================================
// CORS_HEADERS
// ============================================================

Deno.test("CORS_HEADERS contains required headers", () => {
  assertEquals(CORS_HEADERS["Access-Control-Allow-Origin"], "*");
  assertEquals(
    CORS_HEADERS["Access-Control-Allow-Methods"],
    "POST, GET, OPTIONS",
  );
  assertEquals(
    CORS_HEADERS["Access-Control-Allow-Headers"],
    "authorization, x-client-info, apikey, content-type",
  );
});

// ============================================================
// json()
// ============================================================

Deno.test("json() returns 200 with JSON body", async () => {
  const response = json({ message: "hello" });
  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Content-Type"), "application/json");
  const body = await response.json();
  assertEquals(body.message, "hello");
});

Deno.test("json() accepts custom status code", async () => {
  const response = json({ error: "not found" }, 404);
  assertEquals(response.status, 404);
  const body = await response.json();
  assertEquals(body.error, "not found");
});

Deno.test("json() includes CORS headers", () => {
  const response = json({});
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});

// ============================================================
// errorResponse()
// ============================================================

Deno.test("errorResponse() returns error JSON with default status 400", async () => {
  const response = errorResponse("Bad request");
  assertEquals(response.status, 400);
  const body = await response.json();
  assertEquals(body.error, "Bad request");
  assertEquals(body.message, "Bad request");
});

Deno.test("errorResponse() accepts custom code", async () => {
  const response = errorResponse("Not found", 404, "not_found");
  assertEquals(response.status, 404);
  const body = await response.json();
  assertEquals(body.error, "not_found");
  assertEquals(body.message, "Not found");
});

Deno.test("errorResponse() includes CORS headers", () => {
  const response = errorResponse("test");
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});

// ============================================================
// handleOptions()
// ============================================================

Deno.test("handleOptions() returns 200 with CORS headers", () => {
  const response = handleOptions();
  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});

// ============================================================
// getUserId()
// ============================================================

Deno.test("getUserId() returns null for missing Authorization header", () => {
  const req = new Request("https://example.com", {
    headers: new Headers(),
  });
  assertEquals(getUserId(req), null);
});

Deno.test("getUserId() returns null for malformed token", () => {
  const req = new Request("https://example.com", {
    headers: { Authorization: "Bearer not-a-jwt" },
  });
  assertEquals(getUserId(req), null);
});

Deno.test("getUserId() returns null for empty Bearer", () => {
  const req = new Request("https://example.com", {
    headers: { Authorization: "Bearer " },
  });
  assertEquals(getUserId(req), null);
});

Deno.test("getUserId() extracts user ID from valid JWT payload", () => {
  // Create a fake JWT with a payload containing sub
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = btoa(JSON.stringify({ sub: "user-123", exp: 9999999999 }));
  const signature = "fake-signature";
  const token = `${header}.${payload}.${signature}`;

  const req = new Request("https://example.com", {
    headers: { Authorization: `Bearer ${token}` },
  });
  assertEquals(getUserId(req), "user-123");
});

// ============================================================
// requireAuth()
// ============================================================

Deno.test("requireAuth() returns 401 Response for missing token", () => {
  const req = new Request("https://example.com", {
    headers: new Headers(),
  });
  const result = requireAuth(req);
  assertTrue(result instanceof Response);
  assertEquals((result as Response).status, 401);
});

Deno.test("requireAuth() returns userId string for valid token", () => {
  const header = btoa(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = btoa(JSON.stringify({ sub: "user-456", exp: 9999999999 }));
  const token = `${header}.${payload}.sig`;

  const req = new Request("https://example.com", {
    headers: { Authorization: `Bearer ${token}` },
  });
  const result = requireAuth(req);
  assertEquals(result, "user-456");
});

// ============================================================
// Helper: assertTrue (since std/assert doesn't export it in all versions)
// ============================================================

function assertTrue(value: unknown) {
  if (!value) {
    throw new Error(`Expected truthy value, got: ${value}`);
  }
}
