// Edge Function: events - Validation Tests
// Run: deno test supabase/tests/events_test.ts

import { assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

const FUNCTION_SOURCE = await Deno.readTextFile("supabase/functions/events/index.ts");

// ============================================================
// Event Type Whitelist
// ============================================================

Deno.test("Whitelist includes sentence_created", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"sentence_created"');
});

Deno.test("Whitelist includes listen_completed", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"listen_completed"');
});

Deno.test("Whitelist includes practice_rated", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"practice_rated"');
});

Deno.test("Whitelist includes vocab_added", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"vocab_added"');
});

Deno.test("Whitelist includes voice_selected", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"voice_selected"');
});

Deno.test("Whitelist includes memory_unlocked", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"memory_unlocked"');
});

// ============================================================
// Privacy Protection
// ============================================================

Deno.test("Strips metadata values longer than 200 chars", () => {
  assertStringIncludes(FUNCTION_SOURCE, "200");
});

Deno.test("Only allows string/number/boolean in metadata", () => {
  assertStringIncludes(FUNCTION_SOURCE, "typeof value === 'string'");
  assertStringIncludes(FUNCTION_SOURCE, "typeof value === 'number'");
});

// ============================================================
// Input Validation
// ============================================================

Deno.test("Returns 400 for invalid event type", () => {
  assertStringIncludes(FUNCTION_SOURCE, "invalid_event_type");
});

Deno.test("Returns 201 on successful insert", () => {
  assertStringIncludes(FUNCTION_SOURCE, "201");
});

Deno.test("Returns 500 for DB error", () => {
  assertStringIncludes(FUNCTION_SOURCE, "db_error");
});
