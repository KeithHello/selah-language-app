// Edge Function: /v1/audio/generate
// Generates (or reuses) private TTS audio and returns a short-lived signed URL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  AUDIO_BUCKET,
  AUDIO_FORMAT,
  contentHash,
  estimatedDurationMs,
  sha256,
  SIGNED_URL_TTL_SECONDS,
  TTS_MODEL,
  TTS_SPEED,
  userScope,
  userStoragePath,
} from "../_shared/audio.ts";
import {
  AudioGenerationInput,
  buildTTSRequest,
  validateAudioGenerationInput,
} from "../_shared/audio_contract.ts";
import {
  AUDIO_GENERATION_TTL_MS,
  AUDIO_TTS_TIMEOUT_MS,
  AUDIO_UPLOAD_MAX_ATTEMPTS,
  AUDIO_UPLOAD_RETRY_BASE_DELAY_MS,
  isLikelyMp3Audio,
  isRecoverableAudioStatus,
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
  const authenticate = dependencies.requireAuth ?? requireAuth;
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

    const authResult = authenticate(req);
    if (authResult instanceof Response) return authResult;
    const userId = authResult;

    const openAIKey = env.get("OPENAI_API_KEY") ?? "";
    const supabaseURL = env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!openAIKey || !supabaseURL || !serviceRoleKey) {
      return errorResponse(
        "Audio service is not configured",
        503,
        "audio_service_unavailable",
      );
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
      targetText,
      voiceProfile,
      openaiVoice,
      clientRequestId,
    } = validation;

    const supabase = makeSupabase(supabaseURL, serviceRoleKey);
    const hash = await contentHash(targetText, voiceProfile);
    const scopeKey = userScope(userId);
    const storagePath = userStoragePath(
      userId,
      sentenceId,
      voiceProfile,
      hash,
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
        responseFromManifest(manifest, signed.data.signedUrl, cacheHit),
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
        duration_ms: estimatedDurationMs(targetText),
        sha256: await sha256(audioBuffer),
        last_accessed_at: nowIso(),
      });
      if (!recovered) {
        const current = await lookupManifest();
        if (current instanceof Response) return current;
        if (current?.generation_status === "ready") {
          return signAndRespond(current, true);
        }
        return json(responseFromManifest(manifest, null, true), 202);
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
      return json(responseFromManifest(existing!, null, true), 202);
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

    const claimResult = normalizeRpcResult(
      await supabase.rpc("claim_generation_request", {
        p_user_id: userId,
        p_operation_type: OPERATION_TYPE,
        p_client_request_id: clientRequestId,
        p_minute_limit: minuteLimit,
        p_daily_limit: 1000000,
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
        units: { characters: [...targetText].length },
        payloadHash: hash,
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
        return json(responseFromManifest(existing!, null, true), 202);
      } else {
        console.error("Audio manifest state update failed");
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
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
          tts_model: TTS_MODEL,
          speed: TTS_SPEED,
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
        return json(responseFromManifest(existing!, null, true), 202);
      } else {
        console.error("Audio manifest insert failed");
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
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
    try {
      usageRecorder = await recordGenerationAttempt(
        createGenerationUsageTable(
          supabase as unknown as SupabaseLikeClient,
        ),
        {
          userId,
          clientRequestId,
          feature: "tts",
          model: TTS_MODEL,
          inputCharacters: [...targetText].length,
        },
      );
      const openaiResponse = await providerFetch(
        "https://api.openai.com/v1/audio/speech",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${openAIKey}`,
          },
          body: JSON.stringify(buildTTSRequest(targetText, openaiVoice)),
          signal: AbortSignal.timeout(AUDIO_TTS_TIMEOUT_MS),
        },
      );

      if (!openaiResponse.ok) {
        console.error("OpenAI TTS failed", openaiResponse.status);
        await usageRecorder.fail({
          deliveryStatus: "failed",
          httpStatus: openaiResponse.status,
          errorCode: "tts_failed",
          providerRequestId: openaiResponse.headers.get("x-request-id"),
        });
        await supabase.from("audio_manifests")
          .update({ generation_status: "failed", error_code: "tts_failed" })
          .eq("id", activeManifest.id);
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
        return errorResponse("Audio generation failed", 502, "tts_failed");
      }

      const audioBuffer = await openaiResponse.arrayBuffer();
      if (!isLikelyMp3Audio(audioBuffer)) {
        await usageRecorder.succeed({
          deliveryStatus: "failed",
          httpStatus: 200,
          errorCode: "audio_invalid",
          providerRequestId: openaiResponse.headers.get("x-request-id"),
        });
        await supabase.from("audio_manifests")
          .update({
            generation_status: "failed",
            error_code: "audio_invalid",
          })
          .eq("id", activeManifest.id);
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
        return errorResponse(
          "Generated audio was not a usable MP3",
          502,
          "audio_invalid",
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
          providerRequestId: openaiResponse.headers.get("x-request-id"),
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
          duration_ms: estimatedDurationMs(targetText),
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
          providerRequestId: openaiResponse.headers.get("x-request-id"),
        });
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
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
          providerRequestId: openaiResponse.headers.get("x-request-id"),
        });
        await supabase.rpc("fail_generation_request", {
          p_user_id: userId,
          p_operation_type: OPERATION_TYPE,
          p_client_request_id: clientRequestId,
        });
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
          providerRequestId: openaiResponse.headers.get("x-request-id"),
        });
        return errorResponse(
          "Audio completion unavailable",
          503,
          "generation_completion_unavailable",
        );
      }

      await usageRecorder.succeed({
        deliveryStatus: "succeeded",
        httpStatus: 200,
        providerRequestId: openaiResponse.headers.get("x-request-id"),
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
    if (admission.reservationId) {
      await settleGenerationAdmission(
        supabase as unknown as Parameters<typeof settleGenerationAdmission>[0],
        admission.reservationId,
        "settled",
      );
    }
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
