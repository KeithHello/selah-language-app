import {
  TRANSLATION_MODEL,
  TRANSLATION_TEMPERATURE,
} from "./sentence_contract.ts";

export interface CapturePreparationInput {
  rawTranscript?: string;
  sourceLanguage?: string;
  targetLanguage?: string;
  clientRequestId?: string;
}

export interface CaptureSegmentInput {
  segmentId?: string;
  orderIndex?: number;
  sourceText?: string;
}

export interface BatchTranslationInput {
  segments?: CaptureSegmentInput[];
  sourceLanguage?: string;
  targetLanguage?: string;
  categoryHint?: string;
  clientRequestId?: string;
}

export type CaptureInputValidation =
  | {
    ok: true;
    rawTranscript: string;
    sourceLanguage: string;
    targetLanguage: string;
    clientRequestId: string;
  }
  | { ok: false; status: number; code: string; message: string };

export type BatchInputValidation =
  | {
    ok: true;
    segments: Array<
      { segmentId: string; orderIndex: number; sourceText: string }
    >;
    sourceLanguage: string;
    targetLanguage: string;
    categoryHint?: string;
    clientRequestId: string;
  }
  | { ok: false; status: number; code: string; message: string };

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function validateCapturePreparationInput(
  body: CapturePreparationInput,
): CaptureInputValidation {
  const rawTranscript = body.rawTranscript?.trim();
  if (!rawTranscript) {
    return invalid("missing_raw_transcript", "rawTranscript is required");
  }
  if (rawTranscript.length > 4000) {
    return invalid(
      "transcript_too_long",
      "rawTranscript too long (max 4000 chars)",
    );
  }
  const clientRequestId = body.clientRequestId?.trim().toLowerCase();
  if (!clientRequestId || !UUID_PATTERN.test(clientRequestId)) {
    return invalid(
      "invalid_client_request_id",
      "clientRequestId must be a UUID",
    );
  }
  return {
    ok: true,
    rawTranscript,
    sourceLanguage: body.sourceLanguage?.trim() || "zh-Hant",
    targetLanguage: body.targetLanguage?.trim() || "en",
    clientRequestId,
  };
}

export function validateBatchTranslationInput(
  body: BatchTranslationInput,
): BatchInputValidation {
  const segments = body.segments ?? [];
  if (segments.length < 1 || segments.length > 5) {
    return invalid(
      "invalid_segment_count",
      "segments must contain 1 to 5 items",
    );
  }
  const ids = new Set<string>();
  const normalized = [];
  for (const [index, segment] of segments.entries()) {
    const segmentId = segment.segmentId?.trim().toLowerCase();
    const sourceText = segment.sourceText?.trim();
    if (!segmentId || !UUID_PATTERN.test(segmentId) || ids.has(segmentId)) {
      return invalid("invalid_segment_id", "segment IDs must be unique UUIDs");
    }
    if (!sourceText || sourceText.length > 500) {
      return invalid(
        "invalid_segment_text",
        "segment sourceText is required and max 500 chars",
      );
    }
    ids.add(segmentId);
    normalized.push({
      segmentId,
      orderIndex: Number.isInteger(segment.orderIndex)
        ? segment.orderIndex!
        : index,
      sourceText,
    });
  }
  const clientRequestId = body.clientRequestId?.trim().toLowerCase();
  if (!clientRequestId || !UUID_PATTERN.test(clientRequestId)) {
    return invalid(
      "invalid_client_request_id",
      "clientRequestId must be a UUID",
    );
  }
  return {
    ok: true,
    segments: normalized,
    sourceLanguage: body.sourceLanguage?.trim() || "zh-Hant",
    targetLanguage: body.targetLanguage?.trim() || "en",
    categoryHint: body.categoryHint?.trim() || undefined,
    clientRequestId,
  };
}

export function buildCapturePreparationRequest(
  rawTranscript: string,
  sourceLanguage: string,
  targetLanguage: string,
): Record<string, unknown> {
  return {
    model: TRANSLATION_MODEL,
    messages: [
      {
        role: "system",
        content: [
          "You prepare spoken language-learning material.",
          "Remove only obvious standalone disfluencies and exact stutters.",
          "Never remove negation, numbers, names, facts, emotion, or meaningful particles.",
          "Split into ordered, independently learnable source-language segments.",
          "Do not translate and do not invent content.",
          "Return every meaningful proposition exactly once.",
          `Source language: ${sourceLanguage}. Target language: ${targetLanguage}.`,
        ].join("\n"),
      },
      { role: "user", content: rawTranscript },
    ],
    temperature: TRANSLATION_TEMPERATURE,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "capture_preparation",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          required: ["segments"],
          properties: {
            segments: {
              type: "array",
              minItems: 1,
              maxItems: 20,
              items: {
                type: "object",
                additionalProperties: false,
                required: [
                  "segmentId",
                  "orderIndex",
                  "originalText",
                  "sourceText",
                  "removedText",
                  "selected",
                ],
                properties: {
                  segmentId: { type: "string" },
                  orderIndex: { type: "integer" },
                  originalText: { type: "string" },
                  sourceText: { type: "string" },
                  removedText: { type: "array", items: { type: "string" } },
                  selected: { type: "boolean" },
                },
              },
            },
          },
        },
      },
    },
  };
}

export function buildBatchTranslationRequest(
  segments: Array<{ segmentId: string; sourceText: string }>,
  sourceLanguage: string,
  targetLanguage: string,
  categoryHint?: string,
): Record<string, unknown> {
  return {
    model: TRANSLATION_MODEL,
    messages: [
      {
        role: "system",
        content: [
          "You are a teaching-oriented spoken translation engine.",
          "Translate each source segment independently while preserving meaning and tone.",
          "Return exactly one item for every segmentId, with no extra items.",
          `Source language: ${sourceLanguage}. Target language: ${targetLanguage}.`,
          categoryHint ? `Category hint: ${categoryHint}.` : "",
        ].filter(Boolean).join("\n"),
      },
      { role: "user", content: JSON.stringify(segments) },
    ],
    temperature: TRANSLATION_TEMPERATURE,
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "batch_sentence_generation",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          required: ["items"],
          properties: {
            items: {
              type: "array",
              minItems: 1,
              maxItems: 5,
              items: {
                type: "object",
                additionalProperties: false,
                required: [
                  "segmentId",
                  "targetText",
                  "category",
                  "vocabulary",
                  "deconstruction",
                ],
                properties: {
                  segmentId: { type: "string" },
                  targetText: { type: "string" },
                  category: { type: "string" },
                  vocabulary: { type: "array", items: { type: "object" } },
                  deconstruction: { type: "array", items: { type: "object" } },
                },
              },
            },
          },
        },
      },
    },
  };
}

function invalid(
  code: string,
  message: string,
): { ok: false; status: number; code: string; message: string } {
  return { ok: false, status: 400, code, message };
}
