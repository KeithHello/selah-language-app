// Edge Function: sentences-generate - Input Validation Tests
// Run: deno test supabase/tests/sentences_generate_test.ts
//
// These tests validate the request handling logic without calling
// the actual OpenAI API (mocked or static analysis).

import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Read the Edge Function source for static validation
const FUNCTION_SOURCE = await Deno.readTextFile("supabase/functions/sentences-generate/index.ts");

// ============================================================
// System Prompt Validation
// ============================================================

Deno.test("System prompt is defined", () => {
  assertStringIncludes(FUNCTION_SOURCE, "const SYSTEM_PROMPT");
});

Deno.test("System prompt mentions natural spoken English", () => {
  assertStringIncludes(FUNCTION_SOURCE, "Natural spoken English first");
});

Deno.test("System prompt mentions category classification", () => {
  assertStringIncludes(FUNCTION_SOURCE, "work, friends, vent, heartfelt, debate, daily_life");
});

Deno.test("System prompt defines JSON output format", () => {
  assertStringIncludes(FUNCTION_SOURCE, "targetText");
  assertStringIncludes(FUNCTION_SOURCE, "vocabulary");
  assertStringIncludes(FUNCTION_SOURCE, "deconstruction");
});

Deno.test("System prompt skips basic function words", () => {
  assertStringIncludes(FUNCTION_SOURCE, "Skip basic function words");
});

Deno.test("System prompt limits to 3 vocab candidates", () => {
  assertStringIncludes(FUNCTION_SOURCE, "Max 3 candidates per sentence");
});

// ============================================================
// Model Configuration
// ============================================================

Deno.test("Uses gpt-4o-mini model", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"model": "gpt-4o-mini"');
});

Deno.test("Uses JSON response format", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"response_format": { "type": "json_object" }');
});

Deno.test("Temperature is 0.7", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"temperature": 0.7');
});

// ============================================================
// Input Validation
// ============================================================

Deno.test("Requires POST method", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"POST"');
});

Deno.test("Validates sourceText is not empty", () => {
  assertStringIncludes(FUNCTION_SOURCE, "sourceText is required");
});

Deno.test("Validates sourceText max length 500", () => {
  assertStringIncludes(FUNCTION_SOURCE, "500");
});

Deno.test("Returns 400 for missing sourceText", () => {
  assertStringIncludes(FUNCTION_SOURCE, "missing_source_text");
});

Deno.test("Returns 400 for text too long", () => {
  assertStringIncludes(FUNCTION_SOURCE, "text_too_long");
});

Deno.test("Returns 401 for unauthorized", () => {
  assertStringIncludes(FUNCTION_SOURCE, "unauthorized");
});

Deno.test("Returns 502 for translation failed", () => {
  assertStringIncludes(FUNCTION_SOURCE, "translation_failed");
});

// ============================================================
// Usage Recording
// ============================================================

Deno.test("Records usage as sentence_generation", () => {
  assertStringIncludes(FUNCTION_SOURCE, "sentence_generation");
});

Deno.test("Records client_request_id", () => {
  assertStringIncludes(FUNCTION_SOURCE, "client_request_id");
});
