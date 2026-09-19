// Edge Function: /v1/audio/generate
// Generates (or reuses) private TTS audio and returns a short-lived signed URL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { errorResponse, handleOptions, json } from "../_shared/cors.ts";
import {
  authorizeBillableIdentity,
  getGatewayVerifiedIdentity,
} from "../_shared/anonymous_test_mode.ts";
import {
  AUDIO_BUCKET,
  AUDIO_FORMAT,
  estimatedDurationMs,
  sha256,
  SIGNED_URL_TTL_SECONDS,
  textContentHash,
  userScope,
  userStoragePathV2,
} from "../_shared/audio.ts";
import {
  AudioGenerationInput,
  buildTTSRequest,
  validateAudioGenerationInput,
} from "../_shared/audio_contract.ts";
import { audioCacheKey, type AudioRoute } from "../_shared/audio_routing.ts";
import { buildAzureSpeechRequest } from "../_shared/azure_speech.ts";
import {
  AUDIO_GENERATION_TTL_MS,
  AUDIO_PROVIDER_MAX_ATTEMPTS,
  AUDIO_PROVIDER_RETRY_BASE_DELAY_MS,
  AUDIO_TTS_TIMEOUT_MS,
  AUDIO_UPLOAD_MAX_ATTEMPTS,
  AUDIO_UPLOAD_RETRY_BASE_DELAY_MS,
  isLikelyMp3Audio,
  isRecoverableAudioStatus,
  shouldRetryProviderResponse,
  shouldReuseInFlightGeneration,
} from "../_shared/audio_generation_policy.ts";
import {
  createGenerationUsageTable,
  type GenerationUsageRecorder,
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

const OPERATION_TYPE = "audio_generation";
const DEFAULT_MINUTE_LIMIT = 10;
const DEFAULT_DAILY_LIMIT = 100;

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

interface MutationResult<T> {
  data: T | null;
  error: unknown;
}

interface AudioManifestQueryBuilder {
  select(columns?: string): AudioManifestQueryBuilder;
  eq(key: string, value: unknown): AudioManifestQueryBuilder;
  neq(key: string, value: unknown): AudioManifestQueryBuilder;
  in(key: string, values: readonly unknown[]): AudioManifestQueryBuilder;
  lt(key: string, value: unknown): AudioManifestQueryBuilder;
  update(values: Record<string, unknown>): AudioManifestQueryBuilder;
  insert(values: Record<string, unknown>): AudioManifestQueryBuilder;
  maybeSingle(): Promise<MutationResult<AudioManifest>>;
  single(): Promise<MutationResult<AudioManifest>>;
}

interface AudioStorageFileApi {
  download(path: string): Promise<MutationResult<Blob>>;
  upload(
    path: string,
    body: Uint8Array,
    options: Record<string, unknown>,
  ): Promise<{ error: unknown }>;
  createSignedUrl(
    path: string,
    ttl: number,
  ): Promise<MutationResult<{ signedUrl: string }>>;
}

export interface AudioSupabaseClient {
  rpc(name: string, args: Record<string, unknown>): Promise<unknown>;
  from(table: string): AudioManifestQueryBuilder;
  storage: { from(bucket: string): AudioStorageFileApi };
}

export interface AudioHandlerDependencies {
  env?: Pick<typeof Deno.env, "get">;
  requireAuth?: (req: Request) => string | Response;
  authorizeIdentity?: typeof authorizeBillableIdentity;
  createSupabase?: (url: string, key: string) => AudioSupabaseClient;
  fetch?: typeof fetch;
  sleep?: (delayMs: number) => Promise<void>;
}

interface AudioManifest {
  id: string;
  owner_user_id: string | null;
  sentence_id: string | null;
  seed_sentence_id: string | null;
  voice_profile: string;
  content_hash: string;
  storage_path: string | null;
  tts_model: string;
  speed: number;
  audio_format: string;
  byte_size: number;
  duration_ms: number;
  sha256: string | null;
  generation_status: "queued" | "generating" | "ready" | "failed";
  error_code: string | null;
  updated_at?: string | null;
}

function responseFromManifest(
  manifest: AudioManifest,
  downloadUrl: string | null,
  cacheHit: boolean,
  route?: AudioRoute,
): Record<string, unknown> {
  return {
    status: manifest.generation_status,
    voiceProfile: manifest.voice_profile,
    manifestId: manifest.id,
    downloadUrl,
    storagePath: manifest.storage_path,
    sha256: manifest.sha256,
    byteSize: manifest.byte_size,
    durationMs: manifest.duration_ms,
    cacheHit,
    errorCode: manifest.error_code,
    provider: route?.provider ??
      (manifest.tts_model.startsWith("azure-speech/") ? "azure" : "openai"),
    providerVoice: route?.providerVoice ?? null,
    accent: route?.accent ?? null,
    cacheKeyVersion: "v2",
  };
}

function normalizeRpcResult(value: unknown): MutationResult<unknown> {
  if (
    value && typeof value === "object" && "data" in value && "error" in value
  ) {
    const result = value as { data: unknown; error: unknown };
    return { data: result.data, error: result.error };
  }
  return { data: value, error: null };
}

function readPositiveInt(value: string | undefined, fallback: number): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function isPostgrestNoRow(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error &&
    (error as { code?: unknown }).code === "PGRST116";
}

function isPostgrestConflict(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error &&
    (error as { code?: unknown }).code === "23505";
}

export function createAudioGenerateHandler(
  dependencies: AudioHandlerDependencies = {},
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
  const sleep = dependencies.sleep ??
    ((delayMs: number) =>
      new Promise((resolve) => setTimeout(resolve, delayMs)));
  const makeSupabase = dependencies.createSupabase ??
    ((url: string, key: string) =>
      createClient(url, key) as unknown as AudioSupabaseClient);

  const minuteLimit = readPositiveInt(
    env.get("AUDIO_MINUTE_LIMIT"),
    DEFAULT_MINUTE_LIMIT,
  );
  const dailyLimit = readPositiveInt(
    env.get("AUDIO_DAILY_LIMIT"),
    DEFAULT_DAILY_LIMIT,
  );

  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return handleOptions();
    if (req.method !== "POST") {
      return errorResponse("Method not allowed", 405, "method_not_allowed");
    }

    const supabaseURL = env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseURL || !serviceRoleKey) {
      return errorResponse(
        "Audio service is not configured",
        503,
        "audio_service_unavailable",
      );
    }

    const legacyIdentity = dependencies.requireAuth?.(req);
    const earlyIdentity:
      | { userId: string; isAnonymous: boolean }
      | Response
      | null = legacyIdentity !== undefined
        ? legacyIdentity instanceof Response
          ? legacyIdentity
          : { userId: legacyIdentity, isAnonymous: false }
        : getGatewayVerifiedIdentity(req);
    if (earlyIdentity instanceof Response) return earlyIdentity;
    if (!earlyIdentity) {
      return errorResponse("Unauthorized", 401, "unauthorized");
    }

    let body: AudioGenerationInput;
    try {
      body = await req.json();
    } catch {
      return errorResponse("Invalid JSON body", 400, "invalid_body");
    }

    const validation = validateAudioGenerationInput(body);
    if (!validation.ok) {
      return errorResponse(
        validation.message,
        validation.status,
        validation.code,
      );
    }
    const {
      sentenceId,
      text,
      voiceProfile,
      route,
      clientRequestId,
    } = validation;

    const openAIKey = env.get("OPENAI_API_KEY") ?? "";
    const azureKey = env.get("AZURE_SPEECH_KEY") ?? "";
    const azureRegion = env.get("AZURE_SPEECH_REGION") ?? "";
    if (route.provider === "openai" && !openAIKey) {
      return errorResponse(
        "OpenAI audio service is not configured",
        503,
        "audio_provider_unavailable",
      );
    }
    if (route.provider === "azure" && (!azureKey || !azureRegion)) {
      return errorResponse(
        "Azure audio service is not configured",
        503,
        "audio_provider_unavailable",
      );
    }

    const supabase = makeSupabase(supabaseURL, serviceRoleKey);
    const { userId, isAnonymous } = earlyIdentity;
    const textHash = await textContentHash(text, route.language, AUDIO_FORMAT);
    const hash = audioCacheKey({
      provider: route.provider,
      providerVoice: route.providerVoice,
      speed: route.speed,
      textHash,
    });
    const scopeKey = userScope(userId);
    const storagePath = userStoragePathV2(
      userId,
      sentenceId,
      route.provider,
      route.providerVoice,
      route.speed,
      textHash,
    );
    const nowIso = () => new Date().toISOString();

    async function lookupManifest(): Promise<AudioManifest | Response | null> {
      const result = await supabase.from("audio_manifests")
        .select("*")
        .eq("scope_key", scopeKey)
        .eq("content_hash", hash)
        .maybeSingle();
      if (result.error) {
        console.error("Audio manifest lookup failed");
        return errorResponse(
          "Audio manifest lookup failed",
          500,
          "manifest_lookup_failed",
        );
      }
      return result.data;
    }

    async function signAndRespond(
      manifest: AudioManifest,
      cacheHit: boolean,
    ): Promise<Response> {
      if (!manifest.storage_path) {
        return errorResponse("Audio asset not found", 404, "audio_not_found");
      }

      const signed = await supabase.storage.from(AUDIO_BUCKET)
        .createSignedUrl(manifest.storage_path, SIGNED_URL_TTL_SECONDS);
      if (signed.error || !signed.data?.signedUrl) {
        console.error("Signed URL creation failed");
        return errorResponse(
          "Audio delivery unavailable",
          503,
          "signed_url_failed",
        );
      }

      await supabase.from("audio_manifests")
        .update({ last_accessed_at: nowIso() })
        .eq("id", manifest.id);

      await recordBusinessEvent(
        supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
        {
          userId,
          feature: "tts",
          clientRequestId,
          outcome: "reused",
        },
      );

      return json(
        responseFromManifest(manifest, signed.data.signedUrl, cacheHit, route),
      );
    }

    async function updateManifest(
      manifestId: string,
      values: Record<string, unknown>,
    ): Promise<AudioManifest | null> {
      const result = await supabase.from("audio_manifests")
        .update(values)
        .eq("id", manifestId)
        .select("*")
        .single();
      return result.error ? null : result.data;
    }

    async function recoverStoredAudio(
      manifest: AudioManifest,
    ): Promise<Response | null> {
      if (!manifest.storage_path) return null;

      const downloaded = await supabase.storage.from(AUDIO_BUCKET)
        .download(manifest.storage_path);
      if (downloaded.error || !downloaded.data) return null;

      const audioBuffer = await downloaded.data.arrayBuffer();
      if (!isLikelyMp3Audio(audioBuffer)) return null;
      if (
        manifest.sha256 &&
        (manifest.sha256 !== await sha256(audioBuffer) ||
          (manifest.byte_size &&
            manifest.byte_size !== audioBuffer.byteLength))
      ) {
        return null;
      }

      const recovered = await updateManifest(manifest.id, {
        generation_status: "ready",
        error_code: null,
        storage_path: manifest.storage_path,
        byte_size: audioBuffer.byteLength,
        duration_ms: estimatedDurationMs(text),
        sha256: await sha256(audioBuffer),
        last_accessed_at: nowIso(),
      });
      if (!recovered) {
        const current = await lookupManifest();
        if (current instanceof Response) return current;
        if (current?.generation_status === "ready") {
          return signAndRespond(current, true);
        }
        return json(responseFromManifest(manifest, null, true, route), 202);
      }

      return signAndRespond(recovered, true);
    }

    let existing = await lookupManifest();
    if (existing instanceof Response) return existing;

    if (existing?.generation_status === "ready" && existing.storage_path) {
      return signAndRespond(existing, true);
    }

    if (existing && isRecoverableAudioStatus(existing.generation_status)) {
      const recovered = await recoverStoredAudio(existing);
      if (recovered) return recovered;
    }

    if (
      shouldReuseInFlightGeneration(
        existing?.generation_status ?? null,
        existing?.updated_at,
      )
    ) {
      return json(responseFromManifest(existing!, null, true, route), 202);
    }

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

    const claimResult = normalizeRpcResult(
      await supabase.rpc("claim_generation_request", {
        p_user_id: userId,
        p_operation_type: OPERATION_TYPE,
        p_client_request_id: clientRequestId,
        p_minute_limit: minuteLimit,
        p_daily_limit: dailyLimit,
      }),
    );
    if (claimResult.error || !claimResult.data) {
      console.error("Audio capacity claim failed");
      return errorResponse(
        "Audio generation capacity unavailable",
        503,
        "generation_capacity_unavailable",
      );
    }

    const claim = claimResult.data as GenerationClaim;
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
    if (claim.decision === "rate_limited") {
      return errorResponse("Too many audio requests", 429, "rate_limited");
    }
    if (claim.decision === "quota_exceeded") {
      return errorResponse("Daily audio quota exceeded", 429, "quota_exceeded");
    }
    if (claim.decision !== "claimed") {
      return errorResponse(
        "Audio generation capacity unavailable",
        503,
        "generation_capacity_unavailable",
      );
    }

    const admission = await requestGenerationAdmission(
      supabase as unknown as Parameters<typeof requestGenerationAdmission>[0],
      {
        userId,
        clientRequestId,
        feature: "tts",
        units: { characters: [...text].length },
        payloadHash: hash,
        isAnonymous,
        enforcementEnabled: controls.membershipEnforcementEnabled,
      },
    );
    if (!admission.allowed) {
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: OPERATION_TYPE,
        p_client_request_id: clientRequestId,
      });
      return errorResponse(
        admission.errorMessage ?? "Feature limit reached",
        admission.errorCode === "rate_limited" ? 429 : 403,
        admission.errorCode ?? "service_budget_protected",
        admissionErrorDetails(admission, {
          feature: "tts",
          clientRequestId,
        }),
      );
    }

    const settleAdmission = async (
      status: "settled" | "released_unsent" | "unknown",
    ): Promise<void> => {
      if (!admission.reservationId) return;
      await settleGenerationAdmission(
        supabase as unknown as Parameters<typeof settleGenerationAdmission>[0],
        admission.reservationId,
        status,
        undefined,
        admission.reservationScope ?? "membership",
      );
    };

    let manifest: AudioManifest | null = null;
    const claimCutoff = new Date(Date.now() - AUDIO_GENERATION_TTL_MS)
      .toISOString();

    if (existing) {
      const claimed = await supabase.from("audio_manifests")
        .update({
          generation_status: "generating",
          error_code: null,
          storage_path: storagePath,
        })
        .eq("id", existing.id)
        .in("generation_status", ["queued", "generating", "failed"])
        .lt("updated_at", claimCutoff)
        .select("*")
        .single();

      if (!claimed.error && claimed.data) {
        manifest = claimed.data;
      } else if (isPostgrestNoRow(claimed.error)) {
        existing = await lookupManifest();
        if (existing instanceof Response) return existing;
        if (existing?.generation_status === "ready" && existing.storage_path) {
          return signAndRespond(existing, true);
        }
        return json(responseFromManifest(existing!, null, true, route), 202);
      } else {
        console.error("Audio manifest state update failed");
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
        await settleAdmission("released_unsent");
        return errorResponse(
          "Audio generation state update failed",
          500,
          "manifest_update_failed",
        );
      }
    } else {
      const inserted = await supabase.from("audio_manifests")
        .insert({
          owner_user_id: userId,
          sentence_id: sentenceId,
          seed_sentence_id: null,
          scope_key: scopeKey,
          voice_profile: voiceProfile,
          content_hash: hash,
          storage_path: storagePath,
          tts_model: route.providerModel,
          speed: route.speed,
          audio_format: AUDIO_FORMAT,
          generation_status: "generating",
        })
        .select("*")
        .single();

      if (!inserted.error && inserted.data) {
        manifest = inserted.data;
      } else if (isPostgrestConflict(inserted.error)) {
        existing = await lookupManifest();
        if (existing instanceof Response) return existing;
        if (existing?.generation_status === "ready" && existing.storage_path) {
          return signAndRespond(existing, true);
        }
        return json(responseFromManifest(existing!, null, true, route), 202);
      } else {
        console.error("Audio manifest insert failed");
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
        await settleAdmission("released_unsent");
        return errorResponse(
          "Audio generation state creation failed",
          500,
          "manifest_insert_failed",
        );
      }
    }

    const activeManifest = manifest;
    if (!activeManifest) {
      return errorResponse(
        "Audio generation state unavailable",
        500,
        "manifest_claim_failed",
      );
    }

    let usageRecorder: GenerationUsageRecorder | null = null;
    let providerResponse: Response | null = null;
    let providerRequestId: string | null = null;
    let providerWasAttempted = false;
    const usageTable = createGenerationUsageTable(
      supabase as unknown as SupabaseLikeClient,
    );

    const failRequest = async (
      message: string,
      status: number,
      code: string,
      manifestStatus: "generating" | "failed" = "failed",
      settlement: "released_unsent" | "unknown" = providerWasAttempted
        ? "unknown"
        : "released_unsent",
    ): Promise<Response> => {
      await supabase.from("audio_manifests")
        .update({
          generation_status: manifestStatus,
          error_code: code,
        })
        .eq("id", activeManifest.id);
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: OPERATION_TYPE,
        p_client_request_id: clientRequestId,
      });
      await settleAdmission(settlement);
      return errorResponse(message, status, code);
    };

    try {
      for (
        let attempt = 1;
        attempt <= AUDIO_PROVIDER_MAX_ATTEMPTS;
        attempt += 1
      ) {
        usageRecorder = await recordGenerationAttempt(usageTable, {
          userId,
          clientRequestId,
          feature: "tts",
          model: route.providerModel,
          inputCharacters: [...text].length,
          usageSource: route.provider === "azure"
            ? "unknown"
            : "request_estimate",
        });

        let response: Response;
        try {
          providerWasAttempted = true;
          if (route.provider === "azure") {
            const request = buildAzureSpeechRequest(
              text,
              route,
              azureKey,
              azureRegion,
            );
            response = await providerFetch(request.url, {
              ...request.init,
              signal: AbortSignal.timeout(AUDIO_TTS_TIMEOUT_MS),
            });
          } else {
            response = await providerFetch(
              "https://api.openai.com/v1/audio/speech",
              {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": `Bearer ${openAIKey}`,
                },
                body: JSON.stringify(
                  buildTTSRequest(text, route.providerVoice),
                ),
                signal: AbortSignal.timeout(AUDIO_TTS_TIMEOUT_MS),
              },
            );
          }
        } catch {
          await usageRecorder.unknown({
            deliveryStatus: "failed",
            errorCode: "provider_timeout",
          });
          if (attempt < AUDIO_PROVIDER_MAX_ATTEMPTS) {
            await sleep(AUDIO_PROVIDER_RETRY_BASE_DELAY_MS * attempt);
            continue;
          }
          return await failRequest(
            "Audio provider timed out",
            504,
            "provider_timeout",
            "generating",
            "unknown",
          );
        }

        providerRequestId = response.headers.get("x-request-id") ??
          response.headers.get("x-ms-request-id");
        if (!response.ok) {
          await usageRecorder.fail({
            deliveryStatus: "failed",
            httpStatus: response.status,
            errorCode: "tts_failed",
            providerRequestId,
          });
          if (
            attempt < AUDIO_PROVIDER_MAX_ATTEMPTS &&
            shouldRetryProviderResponse(response.status)
          ) {
            await sleep(AUDIO_PROVIDER_RETRY_BASE_DELAY_MS * attempt);
            continue;
          }
          const status = response.status === 429 ? 429 : 502;
          return await failRequest(
            response.status === 429
              ? "Audio provider is busy, please retry later"
              : "Audio generation failed",
            status,
            response.status === 429 ? "provider_rate_limited" : "tts_failed",
            "failed",
            response.status >= 400 && response.status < 500 &&
              response.status !== 429
              ? "released_unsent"
              : "unknown",
          );
        }
        providerResponse = response;
        break;
      }

      if (!providerResponse || !usageRecorder) {
        return await failRequest(
          "Audio generation failed",
          502,
          "tts_failed",
        );
      }

      const audioBuffer = await providerResponse.arrayBuffer();
      if (!isLikelyMp3Audio(audioBuffer)) {
        await usageRecorder.succeed({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "audio_invalid",
          providerRequestId,
        });
        return await failRequest(
          "Generated audio was not a usable MP3",
          502,
          "audio_invalid",
          "failed",
          "unknown",
        );
      }

      const audioDigest = await sha256(audioBuffer);
      let uploadError: unknown = null;
      for (
        let attempt = 1;
        attempt <= AUDIO_UPLOAD_MAX_ATTEMPTS;
        attempt += 1
      ) {
        const uploadResult = await supabase.storage.from(AUDIO_BUCKET)
          .upload(storagePath, new Uint8Array(audioBuffer), {
            contentType: "audio/mpeg",
            upsert: true,
          });
        if (!uploadResult.error) {
          uploadError = null;
          break;
        }
        uploadError = uploadResult.error;
        if (attempt < AUDIO_UPLOAD_MAX_ATTEMPTS) {
          await sleep(AUDIO_UPLOAD_RETRY_BASE_DELAY_MS * 2 ** (attempt - 1));
        }
      }

      if (uploadError) {
        console.error("Storage upload failed after bounded retries");
        await usageRecorder.succeed({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "storage_upload_failed",
          providerRequestId,
        });
        await supabase.from("audio_manifests")
          .update({
            generation_status: "generating",
            error_code: "storage_upload_unknown",
          })
          .eq("id", activeManifest.id);
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
        await settleAdmission("unknown");
        return errorResponse(
          "Audio storage failed",
          503,
          "storage_upload_failed",
        );
      }

      const { data: readyRaw, error: readyError } = await supabase
        .from("audio_manifests")
        .update({
          generation_status: "ready",
          error_code: null,
          byte_size: audioBuffer.byteLength,
          duration_ms: estimatedDurationMs(text),
          sha256: audioDigest,
          last_accessed_at: new Date().toISOString(),
        })
        .eq("id", activeManifest.id)
        .neq("generation_status", "ready")
        .select("*")
        .single();

      if (isPostgrestNoRow(readyError)) {
        const current = await lookupManifest();
        if (current instanceof Response) return current;
        if (current?.generation_status === "ready" && current.storage_path) {
          return signAndRespond(current, true);
        }
      }

      if (readyError || !readyRaw) {
        console.error("Audio manifest ready update failed");
        await usageRecorder.succeed({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "manifest_ready_update_failed",
          providerRequestId,
        });
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
        await settleAdmission("unknown");
        return errorResponse(
          "Audio metadata update failed",
          500,
          "manifest_ready_update_failed",
        );
      }
      const ready = readyRaw as AudioManifest;

      const signed = await supabase.storage
        .from(AUDIO_BUCKET)
        .createSignedUrl(storagePath, SIGNED_URL_TTL_SECONDS);
      if (signed.error || !signed.data?.signedUrl) {
        await usageRecorder.succeed({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "signed_url_failed",
          providerRequestId,
        });
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
        await settleAdmission("unknown");
        return errorResponse(
          "Audio generated but delivery URL failed",
          503,
          "signed_url_failed",
        );
      }

      const responsePayload = responseFromManifest(
        ready,
        signed.data.signedUrl,
        false,
        route,
      );
      const completion = normalizeRpcResult(
        await supabase.rpc("complete_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
          p_response_payload: responsePayload,
        }),
      );
      if (completion.error || completion.data !== true) {
        console.error("Audio request completion failed");
        await usageRecorder.succeed({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "generation_completion_unavailable",
          providerRequestId,
        });
        await settleAdmission("unknown");
        return errorResponse(
          "Audio completion unavailable",
          503,
          "generation_completion_unavailable",
        );
      }

      await usageRecorder.succeed({
        deliveryStatus: "succeeded",
        httpStatus: 200,
        providerRequestId,
      });
      await recordBusinessEvent(
        supabase as unknown as Parameters<typeof recordBusinessEvent>[0],
        {
          userId,
          feature: "tts",
          clientRequestId,
          outcome: "completed",
        },
      );
      await settleAdmission("settled");
      return json(responsePayload);
    } catch {
      console.error("Audio generation function failed");
      await usageRecorder?.unknown({
        deliveryStatus: "failed",
        errorCode: "generation_result_unknown",
      });
      await supabase.from("audio_manifests")
        .update({
          generation_status: "generating",
          error_code: "generation_result_unknown",
        })
        .eq("id", activeManifest.id);
      await supabase.rpc("fail_generation_request", {
        p_user_id: userId,
        p_operation_type: OPERATION_TYPE,
        p_client_request_id: clientRequestId,
      });
      await settleAdmission("unknown");
      return errorResponse(
        "Internal audio generation error",
        500,
        "internal_error",
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createAudioGenerateHandler());
}
