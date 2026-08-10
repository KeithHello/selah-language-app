import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
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
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";
const CAPTURE_PREPARATION_MINUTE_LIMIT = Math.max(
  1,
  Number.parseInt(
    Deno.env.get("CAPTURE_PREPARATION_MINUTE_LIMIT") ?? "2",
    10,
  ) || 2,
);
const CAPTURE_PREPARATION_DAILY_LIMIT = Math.max(
  1,
  Number.parseInt(
    Deno.env.get("CAPTURE_PREPARATION_DAILY_LIMIT") ?? "10",
    10,
  ) || 10,
);

interface Claim {
  decision:
    | "claimed"
    | "replay"
    | "in_progress"
    | "rate_limited"
    | "quota_exceeded";
  responsePayload: Record<string, unknown> | null;
}

interface RPCClient {
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  const authResult = requireAuth(req);
  if (authResult instanceof Response) return authResult;
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }
  if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
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

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  let claimID: string | null = null;

  try {
    const { data: raw, error } = await supabase.rpc(
      "claim_generation_request",
      {
        p_user_id: authResult,
        p_operation_type: "capture_preparation",
        p_client_request_id: validation.clientRequestId,
        p_minute_limit: CAPTURE_PREPARATION_MINUTE_LIMIT,
        p_daily_limit: CAPTURE_PREPARATION_DAILY_LIMIT,
      },
    );
    if (error || !raw) {
      return errorResponse(
        "Preparation capacity unavailable",
        503,
        "preparation_capacity_unavailable",
      );
    }

    const claim = raw as Claim;
    if (claim.decision === "replay" && claim.responsePayload) {
      return json(claim.responsePayload);
    }
    if (claim.decision === "in_progress") {
      return errorResponse(
        "Request is still in progress",
        429,
        "request_in_progress",
      );
    }
    if (
      claim.decision === "rate_limited" ||
      claim.decision === "quota_exceeded"
    ) {
      return errorResponse(
        claim.decision === "rate_limited"
          ? "Too many preparation requests"
          : "Daily preparation quota exceeded",
        429,
        claim.decision,
      );
    }
    if (claim.decision !== "claimed") {
      return errorResponse(
        "Preparation capacity unavailable",
        503,
        "preparation_capacity_unavailable",
      );
    }
    claimID = validation.clientRequestId;

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
      throw new Error("preparation_failed");
    }
    const data = await providerResponse.json();
    const content = data.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) {
      throw new Error("preparation_empty");
    }

    const parsed = JSON.parse(content) as { segments?: unknown };
    const segments = normalizeSegments(parsed.segments);
    if (segments.length === 0) {
      throw new Error("preparation_no_segments");
    }
    const payload = {
      rawTranscript: validation.rawTranscript,
      normalizedTranscript: validation.rawTranscript,
      segments,
      preparationVersion: "ai-v1",
    };
    const { data: completed, error: completionError } = await supabase.rpc(
      "complete_generation_request",
      {
        p_user_id: authResult,
        p_operation_type: "capture_preparation",
        p_client_request_id: validation.clientRequestId,
        p_response_payload: payload,
      },
    );
    if (completionError || completed !== true) {
      throw new Error("preparation_completion_failed");
    }
    return json(payload);
  } catch (error) {
    if (claimID) {
      try {
        await failPreparationClaim(
          supabase as unknown as RPCClient,
          authResult,
          claimID,
        );
      } catch {
        console.error("Failed to release preparation claim");
      }
    }
    if (error instanceof Error && error.message === "preparation_empty") {
      return errorResponse(
        "Empty preparation response",
        502,
        "preparation_empty",
      );
    }
    if (error instanceof Error && error.message === "preparation_no_segments") {
      return errorResponse(
        "Preparation returned no segments",
        502,
        "preparation_no_segments",
      );
    }
    console.error("Capture preparation failed");
    return errorResponse("Preparation failed", 502, "preparation_failed");
  }
});

async function failPreparationClaim(
  supabase: RPCClient,
  userID: string,
  clientRequestID: string,
): Promise<void> {
  await supabase.rpc("fail_generation_request", {
    p_user_id: userID,
    p_operation_type: "capture_preparation",
    p_client_request_id: clientRequestID,
  });
}

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
