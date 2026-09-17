// Edge Function: /v1/speech/transcribe
// Transcribes a short browser recording.  The exported factory keeps provider
// and database boundaries injectable so contract tests never call the network.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
} from "../_shared/cors.ts";
import {
  authorizeBillableIdentity,
  getGatewayVerifiedIdentity,
} from "../_shared/anonymous_test_mode.ts";
import {
  buildSpeechTranscriptionForm,
  SPEECH_TRANSCRIPTION_MODEL,
  type SpeechTranscribeInput,
  validateSpeechTranscribeFormData,
} from "../_shared/speech_contract.ts";
import {
  createGenerationUsageTable,
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
} from "../_shared/service_controls.ts";

const DEFAULT_MINUTE_LIMIT = 2;
const DEFAULT_DAILY_LIMIT = 10;
const OPERATION_TYPE = "capture_preparation";

export interface SpeechRpcResult {
  data: unknown;
  error: unknown;
}

export interface SpeechSupabaseClient {
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
}

export interface SpeechHandlerDependencies {
  env?: Pick<typeof Deno.env, "get">;
  requireAuth?: (req: Request) => string | Response;
  authorizeIdentity?: typeof authorizeBillableIdentity;
  createSupabase?: (url: string, key: string) => SpeechSupabaseClient;
  fetch?: typeof fetch;
}

interface Claim {
  decision:
    | "claimed"
    | "replay"
    | "in_progress"
    | "rate_limited"
    | "quota_exceeded";
  retryAfterSeconds?: number;
  responsePayload?: Record<string, unknown> | null;
}

interface TranscriptionResponse {
  text?: unknown;
}

export function createSpeechTranscribeHandler(
  dependencies: SpeechHandlerDependencies = {},
): (req: Request) => Promise<Response> {
  const env = dependencies.env ?? Deno.env;
  const authorize = dependencies.authorizeIdentity ??
    ((req, controls) => {
      if (dependencies.requireAuth) {
        const legacy = dependencies.requireAuth(req);
        if (legacy instanceof Response) return legacy;
        return {
          status: "allowed" as const,
          userId: legacy,
          isAnonymous: false,
        };
      }
      return authorizeBillableIdentity(req, controls);
    });
  const providerFetch = dependencies.fetch ?? fetch;
  const makeSupabase = dependencies.createSupabase ??
    ((url: string, key: string) =>
      createClient(url, key) as unknown as SpeechSupabaseClient);

  const minuteLimit = readPositiveInt(
    env.get("CAPTURE_PREPARATION_MINUTE_LIMIT"),
    DEFAULT_MINUTE_LIMIT,
  );
  const dailyLimit = readPositiveInt(
    env.get("CAPTURE_PREPARATION_DAILY_LIMIT"),
    DEFAULT_DAILY_LIMIT,
  );

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return handleOptions();
    if (req.method !== "POST") {
      return errorResponse("Method not allowed", 405, "method_not_allowed");
    }

    const openAIKey = env.get("OPENAI_API_KEY") ?? "";
    const supabaseURL = env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!openAIKey || !supabaseURL || !serviceRoleKey) {
      return errorResponse(
        "Speech transcription service is not configured",
        503,
        "transcription_service_unavailable",
      );
    }

    const legacyIdentity = dependencies.requireAuth?.(req);
    const earlyIdentity: { userId: string; isAnonymous: boolean } | Response | null = legacyIdentity !== undefined
      ? legacyIdentity instanceof Response
        ? legacyIdentity
        : { userId: legacyIdentity, isAnonymous: false }
      : getGatewayVerifiedIdentity(req);
    if (earlyIdentity instanceof Response) return earlyIdentity;
    if (!earlyIdentity) {
      return errorResponse("Unauthorized", 401, "unauthorized");
    }

    const contentType = req.headers.get("Content-Type") ?? "";
    if (!contentType.toLowerCase().startsWith("multipart/form-data")) {
      return errorResponse(
        "Content-Type must be multipart/form-data",
        400,
        "invalid_multipart",
      );
    }

    let form: FormData;
    try {
      form = await req.formData();
    } catch {
      return errorResponse("Invalid multipart form", 400, "invalid_multipart");
    }
    const validation = validateSpeechTranscribeFormData(form);
    if (!validation.ok) {
      return errorResponse(
        validation.message,
        validation.status,
        validation.code,
      );
    }

    const input = validation satisfies SpeechTranscribeInput & { ok: true };
    const supabase = makeSupabase(supabaseURL, serviceRoleKey);
    const controls = await readServiceControls(
      supabase as unknown as Parameters<typeof readServiceControls>[0],
      environmentFallback(env),
    );
    if (!controls.generationEnabled) {
      return errorResponse(
        "Generation is temporarily paused",
        503,
        "service_paused",
      );
    }
    const identity = authorize(req, controls);
    if (identity instanceof Response) return identity;
    const { userId, isAnonymous } = identity;
    let claimed = false;

    try {
      const claimResult = normalizeRpcResult(
        await supabase.rpc("claim_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: input.clientRequestId,
          p_minute_limit: minuteLimit,
          p_daily_limit: 1000000,
        }),
      );
      if (claimResult.error || !claimResult.data) {
        return errorResponse(
          "Speech transcription capacity unavailable",
          503,
          "transcription_capacity_unavailable",
        );
      }

      const claim = claimResult.data as Claim;
      if (claim.decision === "replay" && claim.responsePayload) {
        await recordBusinessEvent(
          supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
          {
            userId,
            feature: "transcription",
            clientRequestId: input.clientRequestId,
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
          "Too many speech transcription requests",
          429,
          "rate_limited",
        );
      }
      if (claim.decision === "quota_exceeded") {
        return errorResponse(
          "Daily speech transcription quota exceeded",
          429,
          "quota_exceeded",
        );
      }
      if (claim.decision !== "claimed") {
        return errorResponse(
          "Speech transcription capacity unavailable",
          503,
          "transcription_capacity_unavailable",
        );
      }
      claimed = true;

      const admission = await requestGenerationAdmission(
        supabase as unknown as Parameters<typeof requestGenerationAdmission>[0],
        {
          userId,
          clientRequestId: input.clientRequestId,
          feature: "transcription",
          units: { durationMs: input.durationMs },
          payloadHash: input.clientRequestId,
          isAnonymous,
          enforcementEnabled: controls.membershipEnforcementEnabled,
        },
      );
      if (!admission.allowed) {
        await releaseClaim(supabase, userId, input.clientRequestId);
        claimed = false;
        return errorResponse(
          admission.errorMessage ?? "Feature limit reached",
          admission.errorCode === "rate_limited" ? 429 : 403,
          admission.errorCode ?? "service_budget_protected",
          admissionErrorDetails(admission, {
            feature: "transcription",
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
          clientRequestId: input.clientRequestId,
          feature: "transcription",
          model: SPEECH_TRANSCRIPTION_MODEL,
          durationMs: input.durationMs,
        },
      );
      const providerResponse = await providerFetch(
        "https://api.openai.com/v1/audio/transcriptions",
        {
          method: "POST",
          headers: { Authorization: `Bearer ${openAIKey}` },
          // Do not set Content-Type: fetch adds the multipart boundary.
          body: buildSpeechTranscriptionForm(input),
        },
      );
      if (!providerResponse.ok) {
        console.error(
          "Speech transcription provider failed",
          providerResponse.status,
        );
        await usageRecorder.fail({
          deliveryStatus: "failed",
          httpStatus: providerResponse.status,
          errorCode: "transcription_failed",
          providerRequestId: providerResponse.headers.get("x-request-id"),
        });
        await releaseClaim(supabase, userId, input.clientRequestId);
        claimed = false;
        return errorResponse(
          "Speech transcription failed",
          502,
          "transcription_failed",
        );
      }

      let providerData: TranscriptionResponse;
      try {
        providerData = await providerResponse.json() as TranscriptionResponse;
      } catch {
        await usageRecorder.fail({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "transcription_invalid_response",
          providerRequestId: providerResponse.headers.get("x-request-id"),
        });
        await releaseClaim(supabase, userId, input.clientRequestId);
        claimed = false;
        return errorResponse(
          "Speech transcription returned invalid data",
          502,
          "transcription_invalid_response",
        );
      }
      const text = typeof providerData.text === "string"
        ? providerData.text.trim()
        : "";
      if (!text) {
        await usageRecorder.fail({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "transcription_empty",
          providerRequestId: providerResponse.headers.get("x-request-id"),
        });
        await releaseClaim(supabase, userId, input.clientRequestId);
        claimed = false;
        return errorResponse(
          "Speech transcription returned no text",
          502,
          "transcription_empty",
        );
      }

      const payload = {
        text,
        language: input.language,
        durationMs: input.durationMs,
      };
      const completion = normalizeRpcResult(
        await supabase.rpc("complete_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: input.clientRequestId,
          p_response_payload: payload,
        }),
      );
      if (completion.error || completion.data !== true) {
        await usageRecorder.succeed({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "transcription_completion_unavailable",
          providerRequestId: providerResponse.headers.get("x-request-id"),
        });
        await releaseClaim(supabase, userId, input.clientRequestId);
        claimed = false;
        return errorResponse(
          "Speech transcription completion unavailable",
          503,
          "transcription_completion_unavailable",
        );
      }
      claimed = false;
      await usageRecorder.succeed({
        deliveryStatus: "succeeded",
        httpStatus: 200,
        providerRequestId: providerResponse.headers.get("x-request-id"),
        usage: {
          usageSource: "request_estimate",
          durationMs: input.durationMs,
        },
      });
      await recordBusinessEvent(
        supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
        {
          userId,
          feature: "transcription",
          clientRequestId: input.clientRequestId,
          outcome: "completed",
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
    } catch {
      if (claimed) {
        await releaseClaim(supabase, userId, input.clientRequestId);
        claimed = false;
      }
      console.error("Speech transcription function failed");
      return errorResponse(
        "Speech transcription failed",
        502,
        "transcription_failed",
      );
    }
  };
}

async function failClaim(
  supabase: SpeechSupabaseClient,
  userId: string,
  clientRequestId: string,
): Promise<void> {
  await supabase.rpc("fail_generation_request", {
    p_user_id: userId,
    p_operation_type: OPERATION_TYPE,
    p_client_request_id: clientRequestId,
  });
}

async function releaseClaim(
  supabase: SpeechSupabaseClient,
  userId: string,
  clientRequestId: string,
): Promise<void> {
  try {
    await failClaim(supabase, userId, clientRequestId);
  } catch {
    console.error("Failed to release speech transcription claim");
  }
}

function readPositiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function normalizeRpcResult(value: unknown): SpeechRpcResult {
  if (
    value && typeof value === "object" && "data" in value && "error" in value
  ) {
    const result = value as { data: unknown; error: unknown };
    return { data: result.data, error: result.error };
  }
  return { data: value, error: null };
}

// Supabase invokes the default production entry.  Keeping this call below the
// exported factory means importing the module in Deno tests never auto-starts
// a server through a test-only dependency graph.
if (import.meta.main) {
  Deno.serve(createSpeechTranscribeHandler());
}

export { SPEECH_TRANSCRIPTION_MODEL };
