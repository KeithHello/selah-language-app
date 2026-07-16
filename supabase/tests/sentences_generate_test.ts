// Edge Function: sentences-generate - Input Validation Tests
// Run: deno test supabase/tests/sentences_generate_test.ts
//
// These tests validate the request handling logic without calling
// the actual OpenAI API (mocked or static analysis).

import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildTranslationRequest,
  TRANSLATION_MODEL,
  TRANSLATION_TEMPERATURE,
  validateSentenceGenerationInput,
} from "../functions/_shared/sentence_contract.ts";

// Read the Edge Function source for static validation
const FUNCTION_SOURCE = await Deno.readTextFile(
  "supabase/functions/sentences-generate/index.ts",
);

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
  assertStringIncludes(
    FUNCTION_SOURCE,
    "work, friends, vent, heartfelt, debate, daily_life",
  );
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
  assertEquals(TRANSLATION_MODEL, "gpt-4o-mini");
});

Deno.test("Uses JSON response format", () => {
  assertEquals(
    buildTranslationRequest("prompt", "source").response_format,
    { type: "json_object" },
  );
});

Deno.test("Temperature is 0.7", () => {
  assertEquals(TRANSLATION_TEMPERATURE, 0.7);
});

// ============================================================
// Input Validation
// ============================================================

Deno.test("Requires POST method", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"POST"');
});

Deno.test("Validates sourceText is not empty", () => {
  const result = validateSentenceGenerationInput({ sourceText: "   " });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "missing_source_text");
});

Deno.test("Validates sourceText max length 500", () => {
  const result = validateSentenceGenerationInput({
    sourceText: "a".repeat(501),
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "text_too_long");
});

Deno.test("Returns 400 for missing sourceText", () => {
  const result = validateSentenceGenerationInput({});
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.status, 400);
});

Deno.test("Returns 400 for text too long", () => {
  const result = validateSentenceGenerationInput({
    sourceText: "a".repeat(501),
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.status, 400);
});

Deno.test("Requires a UUID clientRequestId", () => {
  const missing = validateSentenceGenerationInput({ sourceText: "今天好累" });
  assertEquals(missing.ok, false);
  if (!missing.ok) assertEquals(missing.code, "invalid_client_request_id");

  const malformed = validateSentenceGenerationInput({
    sourceText: "今天好累",
    clientRequestId: "not-a-uuid",
  });
  assertEquals(malformed.ok, false);
  if (!malformed.ok) assertEquals(malformed.code, "invalid_client_request_id");
});

Deno.test("Returns the normalized clientRequestId", () => {
  const clientRequestId = "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0";
  const result = validateSentenceGenerationInput({
    sourceText: "今天好累",
    clientRequestId,
  });
  assertEquals(result, { ok: true, sourceText: "今天好累", clientRequestId });
});

Deno.test("Returns 502 for translation failed", () => {
  assertStringIncludes(FUNCTION_SOURCE, "translation_failed");
});

Deno.test("Builds request with normalized source text", () => {
  const result = validateSentenceGenerationInput({
    sourceText: "  今天好累  ",
    clientRequestId: "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0",
  });
  assertEquals(result, {
    ok: true,
    sourceText: "今天好累",
    clientRequestId: "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0",
  });
  if (!result.ok) return;
  assertEquals(buildTranslationRequest("prompt", result.sourceText), {
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "prompt" },
      { role: "user", content: "今天好累" },
    ],
    temperature: 0.7,
    response_format: { type: "json_object" },
  });
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

Deno.test("Claims capacity before calling the translation provider", () => {
  const claimIndex = FUNCTION_SOURCE.indexOf("claim_generation_request");
  const providerIndex = FUNCTION_SOURCE.indexOf(
    "https://api.openai.com/v1/chat/completions",
  );
  assertEquals(claimIndex >= 0, true);
  assertEquals(providerIndex > claimIndex, true);
});

Deno.test("Completes or fails the request ledger", () => {
  assertStringIncludes(FUNCTION_SOURCE, "complete_generation_request");
  assertStringIncludes(FUNCTION_SOURCE, "fail_generation_request");
});
