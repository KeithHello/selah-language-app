import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { errorResponse, handleOptions, json } from "../_shared/cors.ts";
import { authorizeBillableIdentity } from "../_shared/anonymous_test_mode.ts";
import {
  buildCapturePreparationRequest,
  CapturePreparationInput,
  normalizePreparationSegments,
  validateCapturePreparationInput,
} from "../_shared/capture_contract.ts";
import {
  GENERATION_PROMPT_VERSION,
  isTruncatedCompletion,
  TRANSLATION_MODEL,
} from "../_shared/sentence_contract.ts";
import {
  createGenerationUsageTable,
  extractChatUsage,
  recordBusinessEvent,
  recordGenerationAttempt,
  type SupabaseLikeClient,
} from "../_shared/generation_usage_contract.ts";
import {
  admissionErrorDetails,
  requestGenerationAdmission,
  settleGenerationAdmission,
} from "../_shared/generation_admission.ts";
import {
  environmentFallback,
  readServiceControls,
  type ServiceControlsClient,
} from "../_shared/service_controls.ts";

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
  retryAfterSeconds?: number;
}

interface RPCClient {
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
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
  const controls = await readServiceControls(
    supabase as unknown as ServiceControlsClient,
    environmentFallback(),
  );
  if (!controls.generationEnabled) {
    return errorResponse(
      "Generation is temporarily paused",
      503,
      "service_paused",
    );
  }
  const identity = authorizeBillableIdentity(req);
  if (identity instanceof Response) return identity;
  const { userId } = identity;
  let claimID: string | null = null;

  try {
    const { data: raw, error } = await supabase.rpc(
      "claim_generation_request",
      {
        p_user_id: userId,
        p_operation_type: "text_preparation",
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
      await recordBusinessEvent(
        supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
        {
          userId,
          feature: "preparation",
          clientRequestId: validation.clientRequestId,
          outcome: "reused",
        },
      );
      return json(claim.responsePayload);
    }
    if (claim.decision === "in_progress") {
      return errorResponse(
        "Request is still in progress",
        429,
        "request_in_progress",
        { retryAfterSeconds: claim.retryAfterSeconds ?? 1 },
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
        { retryAfterSeconds: claim.retryAfterSeconds ?? 1 },
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

    const admission = await requestGenerationAdmission(
      supabase as unknown as Parameters<typeof requestGenerationAdmission>[0],
      {
        userId,
        clientRequestId: validation.clientRequestId,
        feature: "preparation",
        units: { itemCount: 1 },
        payloadHash: validation.rawTranscript,
        enforcementEnabled: controls.membershipEnforcementEnabled,
      },
    );
    if (!admission.allowed) {
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: "text_preparation",
        p_client_request_id: validation.clientRequestId,
      });
      return errorResponse(
        admission.errorMessage ?? "Feature limit reached",
        admission.errorCode === "rate_limited" ? 429 : 403,
        admission.errorCode ?? "service_budget_protected",
        admissionErrorDetails(admission, {
          feature: "preparation",
          clientRequestId: validation.clientRequestId,
        }),
      );
    }

    const usageRecorder = await recordGenerationAttempt(
      createGenerationUsageTable(
        supabase as unknown as SupabaseLikeClient,
      ),
      {
        userId,
        clientRequestId: validation.clientRequestId,
        feature: "preparation",
        model: TRANSLATION_MODEL,
      },
    );
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
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: providerResponse.status,
        errorCode: "preparation_failed",
        providerRequestId: providerResponse.headers.get("x-request-id"),
      });
      throw new Error("preparation_failed");
    }
    const data = await providerResponse.json();
    const providerUsage = extractChatUsage(data);
    if (isTruncatedCompletion(data)) {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "preparation_response_truncated",
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      throw new Error("preparation_response_truncated");
    }
    const content = data.choices?.[0]?.message?.content;
    if (typeof content !== "string" || !content.trim()) {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "preparation_empty",
        providerRequestId: providerResponse.headers.get("x-request-id"),
      });
      throw new Error("preparation_empty");
    }

    let parsed: { segments?: unknown };
    try {
      parsed = JSON.parse(content) as { segments?: unknown };
    } catch {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "preparation_invalid_json",
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      throw new Error("preparation_invalid_json");
    }
    const normalizedSegments = normalizePreparationSegments(parsed.segments);
    if (!normalizedSegments.ok) {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: `preparation_${normalizedSegments.code}`,
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      throw new Error(`preparation_${normalizedSegments.code}`);
    }
    const segments = normalizedSegments.segments;
    const payload = {
      rawTranscript: validation.rawTranscript,
      normalizedTranscript: validation.rawTranscript,
      segments,
      model: TRANSLATION_MODEL,
      promptVersion: GENERATION_PROMPT_VERSION,
      sourceLanguage: validation.sourceLanguage,
      targetLanguage: validation.targetLanguage,
      preparationVersion: "ai-v1",
    };
    const { data: completed, error: completionError } = await supabase.rpc(
      "complete_generation_request",
      {
        p_user_id: userId,
        p_operation_type: "text_preparation",
        p_client_request_id: validation.clientRequestId,
        p_response_payload: payload,
      },
    );
    if (completionError || completed !== true) {
      await usageRecorder.succeed({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "preparation_completion_failed",
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      throw new Error("preparation_completion_failed");
    }
    await usageRecorder.succeed({
      deliveryStatus: "succeeded",
      httpStatus: 200,
      providerRequestId: providerResponse.headers.get("x-request-id"),
      usage: providerUsage,
    });
    await recordBusinessEvent(
      supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
      {
        userId,
        feature: "preparation",
        clientRequestId: validation.clientRequestId,
        outcome: "completed",
        itemCount: segments.length,
      },
    );
    if (admission.reservationId) {
      await settleGenerationAdmission(
        supabase as unknown as Parameters<typeof settleGenerationAdmission>[0],
        admission.reservationId,
        "settled",
        undefined,
        admission.reservationScope ?? "membership",
      );
    }
    return json(payload);
  } catch (error) {
    if (claimID) {
      try {
        await failPreparationClaim(
          supabase as unknown as RPCClient,
          userId,
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
    if (
      error instanceof Error &&
      error.message === "preparation_response_truncated"
    ) {
      return errorResponse(
        "Preparation response was incomplete",
        502,
        "preparation_incomplete",
      );
    }
    if (
      error instanceof Error && error.message === "preparation_invalid_json"
    ) {
      return errorResponse(
        "Invalid preparation format",
        502,
        "preparation_format_error",
      );
    }
    if (error instanceof Error && error.message.startsWith("preparation_")) {
      return errorResponse(
        "Preparation response was incomplete",
        502,
        "preparation_invalid_output",
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
    p_operation_type: "text_preparation",
    p_client_request_id: clientRequestID,
  });
}
