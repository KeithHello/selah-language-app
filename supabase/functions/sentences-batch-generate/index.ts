import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
} from "../_shared/cors.ts";
import { authorizeBillableIdentity } from "../_shared/anonymous_test_mode.ts";
import {
  BatchTranslationInput,
  buildBatchTranslationRequest,
  validateBatchTranslationInput,
} from "../_shared/capture_contract.ts";
import {
  GENERATION_PROMPT_VERSION,
  isTruncatedCompletion,
  normalizeTeachingOutput,
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
import { completePersonalGeneration } from "../_shared/personal_generation_completion.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";
const MINUTE_LIMIT = Math.max(
  1,
  Number.parseInt(Deno.env.get("SENTENCE_MINUTE_LIMIT") ?? "5", 10) || 5,
);
const DAILY_LIMIT = Math.max(
  1,
  Number.parseInt(Deno.env.get("SENTENCE_DAILY_LIMIT") ?? "20", 10) || 20,
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

interface BatchItem {
  segmentId: string;
  targetText: string;
  category: string;
  vocabulary: unknown[];
  deconstruction: unknown[];
}

interface RPCClient {
  rpc(name: string, args: Record<string, string>): Promise<unknown>;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }
  if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse(
      "Batch generation is not configured",
      503,
      "generation_service_unavailable",
    );
  }

  let body: BatchTranslationInput;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }
  const validation = validateBatchTranslationInput(body);
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
  const identity = authorizeBillableIdentity(req, controls);
  if (identity instanceof Response) return identity;
  const { userId, isAnonymous } = identity;
  const replayed: BatchItem[] = [];
  const claimedIDs: string[] = [];
  for (const segment of validation.segments) {
    const { data: raw, error } = await supabase.rpc(
      "claim_generation_request",
      {
        p_user_id: userId,
        p_operation_type: "sentence_generation",
        p_client_request_id: segment.segmentId,
        p_minute_limit: MINUTE_LIMIT,
        p_daily_limit: 1000000,
      },
    );
    if (error || !raw) {
      await failClaims(
        supabase as unknown as RPCClient,
        userId,
        claimedIDs,
      );
      return errorResponse(
        "Generation capacity unavailable",
        503,
        "generation_capacity_unavailable",
      );
    }
    const claim = raw as Claim;
    if (
      claim.decision === "rate_limited" || claim.decision === "quota_exceeded"
    ) {
      await failClaims(
        supabase as unknown as RPCClient,
        userId,
        claimedIDs,
      );
      return errorResponse(
        claim.decision === "rate_limited"
          ? "Too many generation requests"
          : "Daily generation quota exceeded",
        429,
        claim.decision,
      );
    }
    if (claim.decision === "in_progress") {
      await failClaims(
        supabase as unknown as RPCClient,
        userId,
        claimedIDs,
      );
      return errorResponse(
        "Request is still in progress",
        429,
        "request_in_progress",
      );
    }
    if (claim.decision === "replay" && claim.responsePayload) {
      replayed.push(claim.responsePayload as unknown as BatchItem);
    } else if (claim.decision === "claimed") {
      claimedIDs.push(segment.segmentId);
    }
  }

  const pending = validation.segments.filter((segment) =>
    claimedIDs.includes(segment.segmentId)
  );
  if (pending.length === 0) {
    await recordBusinessEvent(
      supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
      {
        userId,
        feature: "batch",
        clientRequestId: validation.clientRequestId,
        outcome: "reused",
        itemCount: replayed.length,
      },
    );
    return json({ items: replayed.sort(sortBySegment) });
  }

  const admission = await requestGenerationAdmission(
    supabase as unknown as Parameters<typeof requestGenerationAdmission>[0],
    {
      userId,
      clientRequestId: validation.clientRequestId,
      feature: "batch",
      units: { itemCount: pending.length },
      payloadHash: JSON.stringify(pending),
      isAnonymous,
      enforcementEnabled: controls.membershipEnforcementEnabled,
    },
  );
  if (!admission.allowed) {
    await failClaims(
      supabase as unknown as RPCClient,
      userId,
      claimedIDs,
    );
    return errorResponse(
      admission.errorMessage ?? "Feature limit reached",
      admission.errorCode === "rate_limited" ? 429 : 403,
      admission.errorCode ?? "service_budget_protected",
      admissionErrorDetails(admission, {
        feature: "batch",
        clientRequestId: validation.segments[0]?.segmentId ?? "batch",
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
        clientRequestId: validation.clientRequestId,
        feature: "batch",
        model: TRANSLATION_MODEL,
        itemCount: pending.length,
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
        body: JSON.stringify(buildBatchTranslationRequest(
          pending.map(({ segmentId, sourceText }) => ({
            segmentId,
            sourceText,
          })),
          validation.sourceLanguage,
          validation.targetLanguage,
          validation.categoryHint,
        )),
      },
    );
    if (!providerResponse.ok) {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: providerResponse.status,
        errorCode: "provider_failed",
        providerRequestId: providerResponse.headers.get("x-request-id"),
      });
      throw new Error("provider_failed");
    }
    const data = await providerResponse.json();
    const providerUsage = extractChatUsage(data);
    if (isTruncatedCompletion(data)) {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "provider_response_truncated",
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      throw new Error("provider_response_truncated");
    }
    const content = data.choices?.[0]?.message?.content;
    let parsed: { items?: unknown };
    try {
      parsed = typeof content === "string"
        ? JSON.parse(content) as { items?: unknown }
        : {};
    } catch {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "provider_invalid_json",
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      throw new Error("provider_invalid_json");
    }
    const items = normalizeItems(
      parsed.items,
      new Set(pending.map((segment) => segment.segmentId)),
    );
    if (items.length !== pending.length) {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 200,
        errorCode: "provider_items_mismatch",
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      throw new Error("provider_items_mismatch");
    }

    const enrichedItems = items.map((item) => ({
      ...item,
      model: TRANSLATION_MODEL,
      promptVersion: GENERATION_PROMPT_VERSION,
      sourceLanguage: validation.sourceLanguage,
      targetLanguage: validation.targetLanguage,
    }));
    let completionResult: Awaited<ReturnType<typeof completePersonalGeneration>>;
    try {
      completionResult = await completePersonalGeneration(
        supabase as unknown as Parameters<typeof completePersonalGeneration>[0],
        {
          userId,
          parentRequestId: validation.clientRequestId,
          reservationId: admission.reservationId ?? null,
          enforcementEnabled: controls.membershipEnforcementEnabled,
          items: enrichedItems.map((item) => ({
            requestId: item.segmentId,
            responsePayload: item,
          })),
        },
      );
    } catch {
      await usageRecorder.fail({
        deliveryStatus: "failed",
        httpStatus: 503,
        errorCode: "generation_completion_unavailable",
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: providerUsage,
      });
      throw new Error("completion_failed");
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
        feature: "batch",
        clientRequestId: validation.clientRequestId,
      outcome: "completed",
      itemCount: pending.length,
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
   return json({
     items: [...replayed, ...enrichedItems].sort(sortBySegment),
     ...(completionResult.trialState !== undefined
       ? { trialState: completionResult.trialState }
       : {}),
     ...(completionResult.trialStartedAt !== undefined
       ? { trialStartedAt: completionResult.trialStartedAt }
       : {}),
     ...(completionResult.trialExpiresAt !== undefined
       ? { trialExpiresAt: completionResult.trialExpiresAt }
       : {}),
   });
  } catch {
    if (admission.reservationId) {
      await settleGenerationAdmission(
        supabase as unknown as Parameters<typeof settleGenerationAdmission>[0],
        admission.reservationId,
        "unknown",
        undefined,
        admission.reservationScope ?? "membership",
      );
    }
    await failClaims(supabase as unknown as RPCClient, userId, claimedIDs);
    console.error("Batch sentence generation failed");
    return errorResponse("Batch generation failed", 502, "generation_failed");
  }
});

function normalizeItems(value: unknown, expectedIDs: Set<string>): BatchItem[] {
  if (!Array.isArray(value)) return [];
  const seen = new Set<string>();
  return value.flatMap((item) => {
    if (!item || typeof item !== "object") return [];
    const candidate = item as Record<string, unknown>;
    const segmentId = typeof candidate.segmentId === "string"
      ? candidate.segmentId.toLowerCase()
      : "";
    if (
      !expectedIDs.has(segmentId) || seen.has(segmentId)
    ) return [];
    const teaching = normalizeTeachingOutput({
      targetText: candidate.targetText,
      category: candidate.category,
      vocabulary: candidate.vocabulary,
      deconstruction: candidate.deconstruction,
    });
    if (!teaching.ok) return [];
    seen.add(segmentId);
    return [{
      segmentId,
      targetText: teaching.value.targetText,
      category: teaching.value.category,
      vocabulary: teaching.value.vocabulary,
      deconstruction: teaching.value.deconstruction,
    }];
  });
}

function sortBySegment(a: BatchItem, b: BatchItem): number {
  return a.segmentId.localeCompare(b.segmentId);
}

async function failClaims(
  client: RPCClient,
  userID: string,
  IDs: string[],
) {
  await Promise.all(
    IDs.map((clientRequestId) =>
      client.rpc("fail_generation_request", {
        p_user_id: userID,
        p_operation_type: "sentence_generation",
        p_client_request_id: clientRequestId,
      })
    ),
  );
}
