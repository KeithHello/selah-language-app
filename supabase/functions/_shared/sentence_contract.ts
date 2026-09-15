export const TRANSLATION_MODEL = "gpt-4o-mini";
export const TRANSLATION_TEMPERATURE = 0.7;

// These values are returned with every newly generated teaching result. They
// are part of the reuse contract: a client must not reuse a result when any
// one of the values is missing or differs from the current request.
export const GENERATION_PROMPT_VERSION = "v8.0";
export const GENERATION_SOURCE_LANGUAGE = "zh-Hant";
export const GENERATION_TARGET_LANGUAGE = "en";

// Teaching output contract shared by single-sentence, preparation and batch.
export const TEACHING_CATEGORIES = [
  "work",
  "friends",
  "vent",
  "heartfelt",
  "debate",
  "daily_life",
] as const;
export const MAX_TARGET_TEXT_LENGTH = 1000;
export const MAX_VOCABULARY_ITEMS = 3;
export const MAX_DECONSTRUCTION_ITEMS = 50;
export const VOCABULARY_STATES = [
  "new",
  "learning",
  "familiar",
  "owned",
] as const;

// Output token budgets. These are ceilings, not validated production values;
// they keep a truncated response from being mistaken for a complete result.
export const OUTPUT_TOKEN_BUDGET = {
  single: 2048,
  preparation: 4096,
  batch: 8192,
} as const;

export interface TeachingVocabularyItem {
  surfaceText: string;
  meaningInContext: string;
  suggestedHelpState: string;
}

export interface TeachingDeconstructionItem {
  surfaceText: string;
  meaning: string;
  type: string;
}

export interface TeachingOutput {
  targetText: string;
  category: string;
  vocabulary: TeachingVocabularyItem[];
  deconstruction: TeachingDeconstructionItem[];
}

export interface TeachingProvenance {
  model: string;
  promptVersion: string;
  sourceLanguage: string;
  targetLanguage: string;
}

function nonEmptyString(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) return null;
  return trimmed;
}

function normalizeCategory(
  value: unknown,
): { ok: true; value: string } | { ok: false; code: string } {
  // category was optional in older successful responses. Keep that omission
  // compatible while rejecting an explicitly invalid classification.
  if (value == null) return { ok: true, value: "daily_life" };
  if (
    typeof value !== "string" ||
    !(TEACHING_CATEGORIES as readonly string[]).includes(value)
  ) {
    return { ok: false, code: "invalid_category" };
  }
  return { ok: true, value };
}

function normalizeVocabulary(
  value: unknown,
): { ok: true; value: TeachingVocabularyItem[] } | { ok: false; code: string } {
  if (value == null) return { ok: true, value: [] };
  if (!Array.isArray(value)) return { ok: false, code: "invalid_vocabulary" };
  if (value.length > MAX_VOCABULARY_ITEMS) {
    return { ok: false, code: "too_many_vocabulary_items" };
  }
  const items: TeachingVocabularyItem[] = [];
  for (const candidate of value) {
    if (!candidate || typeof candidate !== "object") {
      return { ok: false, code: "invalid_vocabulary_item" };
    }
    const entry = candidate as Record<string, unknown>;
    const surfaceText = nonEmptyString(entry.surfaceText, 200);
    const meaningInContext = nonEmptyString(entry.meaningInContext, 1000);
    if (!surfaceText || !meaningInContext) {
      return { ok: false, code: "invalid_vocabulary_item" };
    }
    const suggestedHelpState = entry.suggestedHelpState == null
      ? "new"
      : nonEmptyString(entry.suggestedHelpState, 32);
    if (
      !suggestedHelpState ||
      !(VOCABULARY_STATES as readonly string[]).includes(suggestedHelpState)
    ) {
      return { ok: false, code: "invalid_vocabulary_item" };
    }
    items.push({ surfaceText, meaningInContext, suggestedHelpState });
  }
  return { ok: true, value: items };
}

function normalizeDeconstruction(
  value: unknown,
): { ok: true; value: TeachingDeconstructionItem[] } | {
  ok: false;
  code: string;
} {
  if (value == null) return { ok: true, value: [] };
  if (!Array.isArray(value)) {
    return { ok: false, code: "invalid_deconstruction" };
  }
  if (value.length > MAX_DECONSTRUCTION_ITEMS) {
    return { ok: false, code: "too_many_deconstruction_items" };
  }
  const items: TeachingDeconstructionItem[] = [];
  for (const candidate of value) {
    if (!candidate || typeof candidate !== "object") {
      return { ok: false, code: "invalid_deconstruction_item" };
    }
    const entry = candidate as Record<string, unknown>;
    const surfaceText = nonEmptyString(entry.surfaceText, 200);
    const meaning = nonEmptyString(entry.meaning, 1000);
    const type = entry.type == null ? "phrase" : nonEmptyString(entry.type, 32);
    if (!surfaceText || !meaning || !type) {
      return { ok: false, code: "invalid_deconstruction_item" };
    }
    items.push({ surfaceText, meaning, type });
  }
  return { ok: true, value: items };
}

/**
 * Validates and normalizes one teaching output object. A missing/empty/too-long
 * targetText or any explicitly supplied auxiliary field is invalid (the
 * caller must fail and keep the draft). Omitted auxiliary arrays remain
 * compatible with older successful responses and are treated as empty.
 */
export function normalizeTeachingOutput(
  raw: unknown,
): { ok: true; value: TeachingOutput } | { ok: false; code: string } {
  if (!raw || typeof raw !== "object") {
    return { ok: false, code: "not_an_object" };
  }
  const candidate = raw as Record<string, unknown>;
  const targetText = nonEmptyString(
    candidate.targetText,
    MAX_TARGET_TEXT_LENGTH,
  );
  if (!targetText) {
    return { ok: false, code: "invalid_target_text" };
  }
  const category = normalizeCategory(candidate.category);
  if (!category.ok) return category;
  const vocabulary = normalizeVocabulary(candidate.vocabulary);
  if (!vocabulary.ok) return vocabulary;
  const deconstruction = normalizeDeconstruction(candidate.deconstruction);
  if (!deconstruction.ok) return deconstruction;
  return {
    ok: true,
    value: {
      targetText,
      category: category.value,
      vocabulary: vocabulary.value,
      deconstruction: deconstruction.value,
    },
  };
}

export function isTruncatedCompletion(data: unknown): boolean {
  if (!data || typeof data !== "object") return false;
  const choice = (data as { choices?: unknown }).choices;
  if (!Array.isArray(choice) || choice.length === 0) return false;
  const first = choice[0] as { finish_reason?: unknown };
  return first?.finish_reason === "length";
}

export interface SentenceGenerationInput {
  sourceText?: string;
  sourceLanguage?: string;
  targetLanguage?: string;
  categoryHint?: string;
  clientRequestId?: string;
}

export type SentenceInputValidation =
  | {
    ok: true;
    sourceText: string;
    sourceLanguage: string;
    targetLanguage: string;
    clientRequestId: string;
  }
  | { ok: false; status: number; code: string; message: string };

export function validateSentenceGenerationInput(
  body: SentenceGenerationInput,
): SentenceInputValidation {
  const sourceText = body.sourceText?.trim();
  if (!sourceText) {
    return {
      ok: false,
      status: 400,
      code: "missing_source_text",
      message: "sourceText is required",
    };
  }
  if (sourceText.length > 500) {
    return {
      ok: false,
      status: 400,
      code: "text_too_long",
      message: "sourceText too long (max 500 chars)",
    };
  }
  const clientRequestId = body.clientRequestId?.trim().toLowerCase();
  if (!clientRequestId || !isUUID(clientRequestId)) {
    return {
      ok: false,
      status: 400,
      code: "invalid_client_request_id",
      message: "clientRequestId must be a UUID",
    };
  }
  const sourceLanguage = normalizedLanguage(
    body.sourceLanguage,
    GENERATION_SOURCE_LANGUAGE,
  );
  const targetLanguage = normalizedLanguage(
    body.targetLanguage,
    GENERATION_TARGET_LANGUAGE,
  );
  if (sourceLanguage == null || targetLanguage == null) {
    return {
      ok: false,
      status: 400,
      code: "invalid_language",
      message: "sourceLanguage and targetLanguage must be at most 20 chars",
    };
  }
  return {
    ok: true,
    sourceText,
    sourceLanguage,
    targetLanguage,
    clientRequestId,
  };
}

function normalizedLanguage(value: unknown, fallback: string): string | null {
  if (value == null) return fallback;
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (!normalized || normalized.length > 20) return null;
  return normalized;
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

export function buildTranslationRequest(
  systemPrompt: string,
  sourceText: string,
  maxOutputTokens: number = OUTPUT_TOKEN_BUDGET.single,
): Record<string, unknown> {
  return {
    model: TRANSLATION_MODEL,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: sourceText },
    ],
    temperature: TRANSLATION_TEMPERATURE,
    max_tokens: maxOutputTokens,
    response_format: { type: "json_object" },
  };
}
