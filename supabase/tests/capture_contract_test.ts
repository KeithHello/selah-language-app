import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildBatchTranslationRequest,
  buildCapturePreparationRequest,
  validateBatchTranslationInput,
  validateCapturePreparationInput,
} from "../functions/_shared/capture_contract.ts";

const id = "8d42c8e5-4f0e-4a37-b63d-51c4ab25d1f0";

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
