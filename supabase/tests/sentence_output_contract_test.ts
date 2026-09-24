// Teaching output contract tests (shared by single/preparation/batch).
// Run: deno test --allow-read supabase/tests/sentence_output_contract_test.ts

import {
  assert,
  assertEquals,
  assertFalse,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildTranslationRequest,
  GENERATION_PROMPT_VERSION,
  GENERATION_SOURCE_LANGUAGE,
  GENERATION_TARGET_LANGUAGE,
  isTruncatedCompletion,
  MAX_TARGET_TEXT_LENGTH,
  normalizeTeachingOutput,
  OUTPUT_TOKEN_BUDGET,
  TRANSLATION_MODEL,
  validateSentenceGenerationInput,
} from "../functions/_shared/sentence_contract.ts";
import {
  buildBatchTranslationRequest,
  buildCapturePreparationRequest,
} from "../functions/_shared/capture_contract.ts";

const segment = {
  segmentId: "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0",
  sourceText: "我今天想早点休息。",
};
const FUNCTION_SOURCE = await Deno.readTextFile(
  "supabase/functions/sentences-generate/index.ts",
);

Deno.test("accepts a complete teaching output", () => {
  const result = normalizeTeachingOutput({
    targetText: "I want to get some rest early today.",
    category: "daily_life",
    vocabulary: [
      {
        surfaceText: "get some rest",
        meaningInContext: "休息一下",
        suggestedHelpState: "new",
      },
    ],
    deconstruction: [
      { surfaceText: "get some rest", meaning: "休息", type: "phrase" },
    ],
  });
  assert(result.ok);
  if (result.ok) {
    assertEquals(
      result.value.targetText,
      "I want to get some rest early today.",
    );
    assertEquals(result.value.category, "daily_life");
    assertEquals(result.value.vocabulary.length, 1);
  }
});

Deno.test("rejects missing or empty targetText", () => {
  assertFalse(normalizeTeachingOutput({ targetText: "   " }).ok);
  assertFalse(normalizeTeachingOutput({ targetText: "" }).ok);
  assertFalse(normalizeTeachingOutput({}).ok);
  assertFalse(normalizeTeachingOutput(null).ok);
});

Deno.test("rejects targetText over 1000 characters", () => {
  const result = normalizeTeachingOutput({
    targetText: "a".repeat(MAX_TARGET_TEXT_LENGTH + 1),
  });
  assertFalse(result.ok);
});

Deno.test("limits vocabulary to three and drops malformed items", () => {
  const result = normalizeTeachingOutput({
    targetText: "Hello.",
    vocabulary: [
      { surfaceText: "one", meaningInContext: "一" },
      { surfaceText: "two", meaningInContext: "二" },
      { surfaceText: "three", meaningInContext: "三" },
      { surfaceText: "four", meaningInContext: "四" },
      { surfaceText: "no-meaning" },
    ],
    deconstruction: [],
  });
  assertFalse(result.ok);
});

Deno.test("rejects an unknown category instead of silently changing meaning", () => {
  const result = normalizeTeachingOutput({
    targetText: "Hello.",
    category: "not-a-category",
  });
  assertFalse(result.ok);
});

Deno.test("accepts an omitted optional category using the existing default", () => {
  const result = normalizeTeachingOutput({ targetText: "Hello." });
  assert(result.ok);
  if (result.ok) assertEquals(result.value.category, "daily_life");
});

Deno.test("exposes stable provenance for generated sentence reuse", () => {
  assertEquals(TRANSLATION_MODEL, "gpt-4o-mini");
  assertEquals(GENERATION_PROMPT_VERSION, "v8.0");
  assertEquals(GENERATION_SOURCE_LANGUAGE, "zh-Hant");
  assertEquals(GENERATION_TARGET_LANGUAGE, "en");
  assertStringIncludes(
    FUNCTION_SOURCE,
    "sourceLanguage: validation.sourceLanguage",
  );
  assertStringIncludes(
    FUNCTION_SOURCE,
    "targetLanguage: validation.targetLanguage",
  );
  assertStringIncludes(
    FUNCTION_SOURCE,
    "promptVersion: GENERATION_PROMPT_VERSION",
  );
});

Deno.test("accepts Japanese source language for a new generation", () => {
  const result = validateSentenceGenerationInput({
    sourceText: "今日はいい天気です。",
    sourceLanguage: "ja",
    targetLanguage: "en",
    clientRequestId: segment.segmentId,
  });
  assertEquals(result.ok, true);
  if (result.ok) {
    assertEquals(result.sourceLanguage, "ja");
    assertEquals(result.targetLanguage, "en");
    const request = buildTranslationRequest(
      "Source language: ja. Target language: English.",
      result.sourceText,
    );
    assertEquals(
      (request.messages as Array<{ content: string }>)[1].content,
      "今日はいい天気です。",
    );
  }
});

Deno.test("detects a length-truncated provider completion", () => {
  assert(
    isTruncatedCompletion({
      choices: [{ finish_reason: "length", message: { content: "{}" } }],
    }),
  );
  assertFalse(
    isTruncatedCompletion({
      choices: [{ finish_reason: "stop", message: { content: "{}" } }],
    }),
  );
  assertFalse(isTruncatedCompletion({ choices: [] }));
});

Deno.test("request builders carry explicit output token budgets", () => {
  assertEquals(
    (buildTranslationRequest("p", "s") as { max_tokens: number }).max_tokens,
    OUTPUT_TOKEN_BUDGET.single,
  );
  assertEquals(
    (buildCapturePreparationRequest("t", "zh-Hant", "en") as {
      max_tokens: number;
    }).max_tokens,
    OUTPUT_TOKEN_BUDGET.preparation,
  );
  assertEquals(
    (buildBatchTranslationRequest([segment], "zh-Hant", "en") as {
      max_tokens: number;
    }).max_tokens,
    Math.min(1 * 2048, OUTPUT_TOKEN_BUDGET.batch),
  );
  assertEquals(
    (buildBatchTranslationRequest(
      [segment, segment, segment, segment, segment],
      "zh-Hant",
      "en",
    ) as {
      max_tokens: number;
    }).max_tokens,
    OUTPUT_TOKEN_BUDGET.batch,
  );
});
