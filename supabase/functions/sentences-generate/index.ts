// Edge Function: /v1/sentences/generate
// Generates English learning material from a user's source-language sentence.
// Calls GPT-4o-mini with the v8 translation system prompt.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
} from "../_shared/cors.ts";
import { authorizeBillableIdentity } from "../_shared/anonymous_test_mode.ts";
import {
  buildTranslationRequest,
  GENERATION_PROMPT_VERSION,
  isTruncatedCompletion,
  normalizeTeachingOutput,
  OUTPUT_TOKEN_BUDGET,
  SentenceGenerationInput,
  TRANSLATION_MODEL,
  validateSentenceGenerationInput,
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
import { completePersonalGeneration } from "../_shared/personal_generation_completion.ts";

const SYSTEM_PROMPT =
  `You are a teaching-oriented translation engine for the language learning app "Selah."

## Your Role
Your job is to help a language learner turn a sentence they actually said or typed in real life into natural spoken English they can understand, hear, practice, and eventually use in real conversations. The source language is supplied separately for each request; follow it exactly and never assume that the source is Chinese.

## Core Translation Rules

1. **Natural spoken English first.** The output must sound like something a real person would say out loud. Avoid textbook English, stiff grammar, or overly formal phrasing.

2. **Preserve intent and tone.** The user chose to say this sentence. The English must feel like "my sentence" - same meaning, same emotional tone, same level of casualness or seriousness.

3. **Slightly above current level, but usable.** Use vocabulary and phrasing that is reachable.

4. **Consistent phrasing.** If the user says a similar sentence tomorrow, translate it consistently.

## Vocabulary Candidates: Selection Rules

After translating, suggest up to 3 words or phrases that are worth the user's attention:
- **Scene-relevant only.** Suggest expressions useful for saying similar things.
- **Skip basic function words.** Do NOT suggest: I, you, the, a, is, am, are, it, this, that, and, or, but, in, on, at, to, for, of, with.
- **Prefer phrases over single words.** "get off on time" is better than "time" alone.
- **Max 3 candidates per sentence.**

## Category Classification

Classify into one of: work, friends, vent, heartfelt, debate, daily_life

## Output Format

Return ONLY valid JSON with this exact structure:

{
  "targetText": "natural English here",
  "category": "one of the six categories",
  "vocabulary": [
    { "surfaceText": "exact phrase", "meaningInContext": "context-specific meaning in the source language", "suggestedHelpState": "new" }
  ],
  "deconstruction": [
    { "surfaceText": "exact phrase", "meaning": "short meaning in the source language", "type": "phrase" }
  ]
}`;

function buildSystemPrompt(sourceLanguage: string): string {
  const sourceName = sourceLanguage === "ja"
    ? "Japanese"
    : sourceLanguage === "zh-Hant"
    ? "Traditional Chinese"
    : sourceLanguage;
  return `${SYSTEM_PROMPT}\n\nSource language: ${sourceName}. Target language: English. Write all explanations in the source language, while keeping targetText in natural English.`;
}

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";
const SENTENCE_MINUTE_LIMIT = Math.max(
  1,
  Number.parseInt(Deno.env.get("SENTENCE_MINUTE_LIMIT") ?? "5", 10) || 5,
);
const SENTENCE_DAILY_LIMIT = Math.max(
  1,
  Number.parseInt(Deno.env.get("SENTENCE_DAILY_LIMIT") ?? "20", 10) || 20,
);

interface GenerationClaim {
  decision:
    | "claimed"
    | "replay"
    | "in_progress"
    | "rate_limited"
    | "quota_exceeded";
  retryAfterSeconds: number;
  responsePayload: Record<string, unknown> | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse(
      "Translation service is not configured",
      503,
      "translation_service_unavailable",
    );
  }

  let body: SentenceGenerationInput;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }

  const validation = validateSentenceGenerationInput(body);
  if (!validation.ok) {
    return errorResponse(
      validation.message,
      validation.status,
      validation.code,
    );
  }
  const { sourceText, clientRequestId } = validation;
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
  const { data: claimRaw, error: claimError } = await supabase.rpc(
    "claim_generation_request",
    {
      p_user_id: userId,
      p_operation_type: "sentence_generation",
      p_client_request_id: clientRequestId,
      p_minute_limit: SENTENCE_MINUTE_LIMIT,
      p_daily_limit: SENTENCE_DAILY_LIMIT,
    },
  );
  if (claimError || !claimRaw) {
    console.error("Generation capacity claim failed");
    return errorResponse(
      "Generation capacity unavailable",
      503,
      "generation_capacity_unavailable",
    );
  }

  const claim = claimRaw as GenerationClaim;
  if (claim.decision === "replay" && claim.responsePayload) {
    await recordBusinessEvent(
      supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
      {
        userId,
        feature: "sentence",
        clientRequestId,
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
    );
  }
  if (claim.decision === "rate_limited") {
    return errorResponse(
      "Too many generation requests",
      429,
      "rate_limited",
      { retryAfterSeconds: claim.retryAfterSeconds ?? 1 },
    );
  }
  if (claim.decision === "quota_exceeded") {
    return errorResponse(
      "Daily generation quota exceeded",
      429,
      "quota_exceeded",
    );
  }

  const admission = await requestGenerationAdmission(
    supabase as unknown as Parameters<typeof requestGenerationAdmission>[0],
    {
      userId,
      clientRequestId,
      feature: "sentence",
      units: { itemCount: 1 },
      payloadHash: sourceText,
      enforcementEnabled: controls.membershipEnforcementEnabled,
    },
  );
  if (!admission.allowed) {
    await supabase.rpc("fail_generation_request", {
      p_user_id: userId,
      p_operation_type: "sentence_generation",
      p_client_request_id: clientRequestId,
    });
    return errorResponse(
      admission.errorMessage ?? "Feature limit reached",
      admission.errorCode === "rate_limited" ? 429 : 403,
      admission.errorCode ?? "service_budget_protected",
      admissionErrorDetails(admission, {
        feature: "sentence",
        clientRequestId,
      }),
    );
  }

  try {
    const usageRecorder = await recordGenerationAttempt(
      createGenerationUsageTable(
        supabase as unknown as SupabaseLikeClient,
      ),
      {
        userId,
        clientRequestId,
        feature: "sentence",
        model: TRANSLATION_MODEL,
      },
    );
    const settleUnknown = async () => {
      if (admission.reservationId) {
        await settleGenerationAdmission(
          supabase as unknown as Parameters<typeof settleGenerationAdmission>[0],
          admission.reservationId,
          "unknown",
          undefined,
          admission.reservationScope ?? "membership",
        );
      }
    };
    const openaiResponse = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify(
          buildTranslationRequest(
            buildSystemPrompt(validation.sourceLanguage),
            sourceText,
            OUTPUT_TOKEN_BUDGET.single,
          ),
        ),
      },
    );

    if (!openaiResponse.ok) {
      // Never log the provider response body: it may contain request-derived text or credentials.
      console.error("Translation provider failed", openaiResponse.status);
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: openaiResponse.status,
        errorCode: "translation_failed",
        providerRequestId: openaiResponse.headers.get("x-request-id"),
      });
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: "sentence_generation",
        p_client_request_id: clientRequestId,
      });
      await settleUnknown();
      return errorResponse(
        "Translation service unavailable",
        502,
        "translation_failed",
      );
    }

    const openaiData = await openaiResponse.json();
    const providerUsage = extractChatUsage(openaiData);
    if (isTruncatedCompletion(openaiData)) {
      console.error("Translation provider response was length-truncated");
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "translation_incomplete",
        providerRequestId: openaiResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: "sentence_generation",
        p_client_request_id: clientRequestId,
      });
      await settleUnknown();
      return errorResponse(
        "Translation response was incomplete",
        502,
        "translation_incomplete",
      );
    }
    const content = openaiData.choices?.[0]?.message?.content;

    if (!content) {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "translation_empty",
        providerRequestId: openaiResponse.headers.get("x-request-id"),
      });
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: "sentence_generation",
        p_client_request_id: clientRequestId,
      });
      await settleUnknown();
      return errorResponse(
        "Empty translation response",
        502,
        "translation_empty",
      );
    }

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(content);
    } catch {
      // Do not log generated content because it can include personal sentence material.
      console.error("Translation provider returned invalid JSON");
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "translation_format_error",
        providerRequestId: openaiResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: "sentence_generation",
        p_client_request_id: clientRequestId,
      });
      await settleUnknown();
      return errorResponse(
        "Invalid translation format",
        502,
        "translation_format_error",
      );
    }

    const normalized = normalizeTeachingOutput(parsed);
    if (!normalized.ok) {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "translation_invalid_output",
        providerRequestId: openaiResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: "sentence_generation",
        p_client_request_id: clientRequestId,
      });
      await settleUnknown();
      return errorResponse(
        "Invalid translation output",
        502,
        "translation_invalid_output",
      );
    }

    const responsePayload = {
      targetText: normalized.value.targetText,
      category: normalized.value.category,
      vocabulary: normalized.value.vocabulary,
      deconstruction: normalized.value.deconstruction,
      model: TRANSLATION_MODEL,
      promptVersion: GENERATION_PROMPT_VERSION,
      sourceLanguage: validation.sourceLanguage,
      targetLanguage: validation.targetLanguage,
    };
    let persistedPayload: Record<string, unknown> = responsePayload;
    try {
      const completionResult = await completePersonalGeneration(
        supabase as unknown as Parameters<typeof completePersonalGeneration>[0],
        {
          userId,
          parentRequestId: clientRequestId,
          reservationId: admission.reservationId ?? null,
          enforcementEnabled: controls.membershipEnforcementEnabled,
          items: [{
            requestId: clientRequestId,
            responsePayload,
          }],
        },
      );
      if (
        completionResult.trialState !== undefined ||
        completionResult.trialStartedAt !== undefined ||
        completionResult.trialExpiresAt !== undefined
      ) {
        persistedPayload = {
          ...responsePayload,
          ...(completionResult.trialState !== undefined
            ? { trialState: completionResult.trialState }
            : {}),
          ...(completionResult.trialStartedAt !== undefined
            ? { trialStartedAt: completionResult.trialStartedAt }
            : {}),
          ...(completionResult.trialExpiresAt !== undefined
            ? { trialExpiresAt: completionResult.trialExpiresAt }
            : {}),
        };
      }
    } catch {
      console.error("Generation request completion failed");
      await usageRecorder.succeed({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "generation_completion_unavailable",
        providerRequestId: openaiResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: "sentence_generation",
        p_client_request_id: clientRequestId,
      });
      if (admission.reservationId) {
        await settleGenerationAdmission(
          supabase as unknown as Parameters<typeof settleGenerationAdmission>[0],
          admission.reservationId,
          "unknown",
          undefined,
          admission.reservationScope ?? "membership",
        );
      }
      return errorResponse(
        "Generation completion unavailable",
        503,
        "generation_completion_unavailable",
      );
    }

    await usageRecorder.succeed({
      deliveryStatus: "succeeded",
      httpStatus: 200,
      providerRequestId: openaiResponse.headers.get("x-request-id"),
      usage: providerUsage,
    });
    if (admission.reservationId) {
      await settleGenerationAdmission(
        supabase as unknown as Parameters<typeof settleGenerationAdmission>[0],
        admission.reservationId,
        "settled",
        undefined,
        admission.reservationScope ?? "membership",
      );
    }
    await recordBusinessEvent(
      supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
      {
        userId,
        feature: "sentence",
        clientRequestId,
        outcome: "completed",
      },
    );
    return json(persistedPayload);
  } catch {
    console.error("Translation function failed");
    await supabase.rpc("fail_generation_request", {
      p_user_id: userId,
      p_operation_type: "sentence_generation",
      p_client_request_id: clientRequestId,
    });
    if (admission.reservationId) {
      await settleGenerationAdmission(
        supabase as unknown as Parameters<typeof settleGenerationAdmission>[0],
        admission.reservationId,
        "unknown",
        undefined,
        admission.reservationScope ?? "membership",
      );
    }
    return errorResponse("Internal server error", 500, "internal_error");
  }
});
