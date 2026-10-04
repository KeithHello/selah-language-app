import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildBatchTranslationRequest,
  buildCapturePreparationRequest,
  normalizePreparationSegments,
  validateBatchTranslationInput,
  validateCapturePreparationInput,
} from "../functions/_shared/capture_contract.ts";

const id = "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0";
const CAPTURE_CONTRACT_SOURCE = await Deno.readTextFile(
  "supabase/functions/_shared/capture_contract.ts",
);
const PREPARATION_FUNCTION_SOURCE = await Deno.readTextFile(
  "supabase/functions/sentences-prepare/index.ts",
);

Deno.test("capture preparation validates bounded transcript and UUID", () => {
  assertEquals(
    validateCapturePreparationInput({
      rawTranscript: "呃，我今天很累。",
      clientRequestId: id,
    }),
    {
      ok: true,
      rawTranscript: "呃，我今天很累。",
      sourceLanguage: "zh-Hant",
      targetLanguage: "en",
      clientRequestId: id,
    },
  );
});

Deno.test("capture preparation preserves Japanese source language", () => {
  const result = validateCapturePreparationInput({
    rawTranscript: "今日はいい天気です。",
    sourceLanguage: "ja",
    targetLanguage: "en",
    clientRequestId: id,
  });
  assertEquals(result, {
    ok: true,
    rawTranscript: "今日はいい天気です。",
    sourceLanguage: "ja",
    targetLanguage: "en",
    clientRequestId: id,
  });
  if (result.ok) {
    const request = buildCapturePreparationRequest(
      result.rawTranscript,
      result.sourceLanguage,
      result.targetLanguage,
    );
    assertStringIncludes(JSON.stringify(request), "Source language: ja");
  }
});

Deno.test("batch translation validates at most five unique segments", () => {
  const result = validateBatchTranslationInput({
    clientRequestId: id,
    segments: [
      { segmentId: id, orderIndex: 0, sourceText: "我今天很累。" },
    ],
  });
  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.segments.length, 1);
});

Deno.test("preparation request uses strict structured output", () => {
  const request = buildCapturePreparationRequest(
    "我今天很累。",
    "zh-Hant",
    "en",
  );
  const encoded = JSON.stringify(request);
  assertStringIncludes(encoded, '"type":"json_schema"');
  assertStringIncludes(encoded, '"name":"capture_preparation"');
  const system =
    (request.messages as Array<{ role: string; content: string }>)[0]
      .content;
  assertStringIncludes(system, "Remove meaningless conversational fillers");
  assertStringIncludes(
    system,
    "Keep negation, time, quantities, names, emotion, concrete facts",
  );
  assertStringIncludes(system, "Do not translate");
});

Deno.test("preparation prompt keeps complete learnable sentences together", () => {
  const request = buildCapturePreparationRequest(
    "我今天很累。",
    "zh-Hant",
    "en",
  );
  const system =
    (request.messages as Array<{ role: string; content: string }>)[0]
      .content;
  assertStringIncludes(
    system,
    "Prefer fewer, complete sentences: split only where each part can stand alone as a learnable sentence.",
  );
  assertStringIncludes(
    system,
    "Do not emit standalone segments that are only meaningless conversational fillers. Keep short acknowledgements as standalone sentences when they convey a complete response or useful learning value; otherwise attach fillers to the neighbouring segment or omit them.",
  );
});

Deno.test("preparation prompt has its own version", () => {
  assertStringIncludes(
    CAPTURE_CONTRACT_SOURCE,
    'export const PREPARATION_PROMPT_VERSION = "prep-v1"',
  );
});

Deno.test("batch request carries stable segment IDs", () => {
  const request = buildBatchTranslationRequest(
    [{ segmentId: id, sourceText: "我今天很累。" }],
    "zh-Hant",
    "en",
  );
  assertStringIncludes(JSON.stringify(request), id);
  assertStringIncludes(
    JSON.stringify(request),
    '"name":"batch_sentence_generation"',
  );
});

Deno.test("batch request carries Japanese source language", () => {
  const request = buildBatchTranslationRequest(
    [{ segmentId: id, sourceText: "今日はいい天気です。" }],
    "ja",
    "en",
  );
  assertStringIncludes(JSON.stringify(request), "Source language: ja");
  assertStringIncludes(
    JSON.stringify(request),
    "explanations in the source language",
  );
});

Deno.test("preparation claims capacity before calling OpenAI", () => {
  const claimIndex = PREPARATION_FUNCTION_SOURCE.indexOf(
    "claim_generation_request",
  );
  const providerIndex = PREPARATION_FUNCTION_SOURCE.indexOf(
    "https://api.openai.com/v1/chat/completions",
  );
  assertEquals(claimIndex >= 0, true);
  assertEquals(providerIndex > claimIndex, true);
});

Deno.test("preparation uses a dedicated operation and service-role client", () => {
  assertStringIncludes(PREPARATION_FUNCTION_SOURCE, "text_preparation");
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "SUPABASE_SERVICE_ROLE_KEY",
  );
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "CAPTURE_PREPARATION_DAILY_LIMIT",
  );
});

Deno.test("preparation completes and fails its request ledger", () => {
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "complete_generation_request",
  );
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "p_response_payload: payload",
  );
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "fail_generation_request",
  );
});

Deno.test("preparation response carries generation provenance", () => {
  assertStringIncludes(PREPARATION_FUNCTION_SOURCE, "model: TRANSLATION_MODEL");
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "promptVersion: PREPARATION_PROMPT_VERSION",
  );
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "sourceLanguage: validation.sourceLanguage",
  );
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "targetLanguage: validation.targetLanguage",
  );
});

Deno.test("preparation treats truncation and malformed completeness as failures", () => {
  assertStringIncludes(PREPARATION_FUNCTION_SOURCE, "isTruncatedCompletion");
  assertStringIncludes(
    PREPARATION_FUNCTION_SOURCE,
    "normalizePreparationSegments",
  );
  assertStringIncludes(PREPARATION_FUNCTION_SOURCE, "preparation_incomplete");
});

Deno.test("preparation rejects provider output beyond twenty segments", () => {
  const result = normalizePreparationSegments(
    Array.from({ length: 21 }, (_, index) => ({
      originalText: `第 ${index + 1} 段`,
      sourceText: `第 ${index + 1} 段`,
      removedText: [],
      selected: true,
    })),
  );
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "too_many_segments");
});

Deno.test("preparation rejects malformed provider segments instead of dropping them", () => {
  const result = normalizePreparationSegments([
    { originalText: "第一段", sourceText: "第一段", removedText: [] },
    { originalText: "", sourceText: "", removedText: [] },
  ]);
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "invalid_segment");
});
