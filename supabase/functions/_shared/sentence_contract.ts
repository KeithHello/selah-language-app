export const TRANSLATION_MODEL = "gpt-4o-mini";
export const TRANSLATION_TEMPERATURE = 0.7;

export interface SentenceGenerationInput {
  sourceText?: string;
  sourceLanguage?: string;
  targetLanguage?: string;
  categoryHint?: string;
  clientRequestId?: string;
}

export type SentenceInputValidation =
  | { ok: true; sourceText: string; clientRequestId: string }
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
  return { ok: true, sourceText, clientRequestId };
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

export function buildTranslationRequest(
  systemPrompt: string,
  sourceText: string,
): Record<string, unknown> {
  return {
    model: TRANSLATION_MODEL,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: sourceText },
    ],
    temperature: TRANSLATION_TEMPERATURE,
    response_format: { type: "json_object" },
  };
}
