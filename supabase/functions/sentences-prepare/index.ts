import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  buildCapturePreparationRequest,
  CapturePreparationInput,
  validateCapturePreparationInput,
} from "../_shared/capture_contract.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  const authResult = requireAuth(req);
  if (authResult instanceof Response) return authResult;
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }
  if (!OPENAI_API_KEY) {
    return errorResponse(
      "Preparation service is not configured",
      503,
      "preparation_service_unavailable",
    );
  }

  let body: CapturePreparationInput;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }
  const validation = validateCapturePreparationInput(body);
  if (!validation.ok) {
    return errorResponse(
      validation.message,
      validation.status,
      validation.code,
    );
  }

  try {
    const providerResponse = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify(
          buildCapturePreparationRequest(
            validation.rawTranscript,
            validation.sourceLanguage,
            validation.targetLanguage,
          ),
        ),
      },
    );
    if (!providerResponse.ok) {
      console.error(
        "Capture preparation provider failed",
        providerResponse.status,
      );
      return errorResponse(
        "Preparation service unavailable",
        502,
        "preparation_failed",
      );
    }
    const data = await providerResponse.json();
    const content = data.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) {
      return errorResponse(
        "Empty preparation response",
        502,
        "preparation_empty",
      );
    }

    const parsed = JSON.parse(content) as { segments?: unknown };
    const segments = normalizeSegments(parsed.segments);
    if (segments.length === 0) {
      return errorResponse(
        "Preparation returned no segments",
        502,
        "preparation_no_segments",
      );
    }
    return json({
      rawTranscript: validation.rawTranscript,
      normalizedTranscript: validation.rawTranscript,
      segments,
      preparationVersion: "ai-v1",
    });
  } catch {
    console.error("Capture preparation failed");
    return errorResponse("Preparation failed", 502, "preparation_failed");
  }
});

function normalizeSegments(value: unknown): Array<Record<string, unknown>> {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 20).flatMap((item, index) => {
    if (!item || typeof item !== "object") return [];
    const candidate = item as Record<string, unknown>;
    const originalText = typeof candidate.originalText === "string"
      ? candidate.originalText.trim()
      : "";
    const sourceText = typeof candidate.sourceText === "string"
      ? candidate.sourceText.trim()
      : "";
    if (!sourceText || sourceText.length > 500) return [];
    const removedText = Array.isArray(candidate.removedText)
      ? candidate.removedText.filter((item): item is string =>
        typeof item === "string"
      )
      : [];
    return [{
      segmentId: crypto.randomUUID(),
      orderIndex: index,
      originalText: originalText || sourceText,
      sourceText,
      removedText,
      selected: index < 5,
    }];
  });
}
