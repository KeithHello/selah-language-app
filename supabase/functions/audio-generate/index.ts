// Edge Function: /v1/audio/generate
// Generates (or reuses) private TTS audio and returns a short-lived signed URL.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { json, errorResponse, handleOptions, requireAuth } from "../_shared/cors.ts";
import {
  AUDIO_BUCKET,
  AUDIO_FORMAT,
  contentHash,
  estimatedDurationMs,
  SIGNED_URL_TTL_SECONDS,
  TTS_MODEL,
  TTS_SPEED,
  userScope,
  userStoragePath,
  VOICE_MAP,
  sha256,
} from "../_shared/audio.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

interface RequestBody {
  sentenceId: string;
  targetText: string;
  voiceProfile?: string;
  reason?: string;
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const authResult = requireAuth(req);
  if (authResult instanceof Response) return authResult;
  const userId = authResult;

  if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse("Audio service is not configured", 503, "audio_service_unavailable");
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }

  const targetText = body.targetText?.trim();
  if (!body.sentenceId || !targetText) {
    return errorResponse("sentenceId and targetText are required", 400, "missing_audio_input");
  }
  if (targetText.length > 1000) {
    return errorResponse("targetText too long (max 1000 chars)", 400, "text_too_long");
  }

  const voiceProfile = body.voiceProfile ?? "gentle-natural";
  const openaiVoice = VOICE_MAP[voiceProfile];
  if (!openaiVoice) {
    return errorResponse("Unsupported voice profile", 400, "unsupported_voice_profile");
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const hash = await contentHash(targetText, voiceProfile);
  const scopeKey = userScope(userId);

  const { data: existingRaw, error: existingError } = await supabase
    .from("audio_manifests")
    .select("*")
    .eq("scope_key", scopeKey)
    .eq("content_hash", hash)
    .maybeSingle();

  if (existingError) {
    console.error("Audio manifest lookup failed");
    return errorResponse("Audio manifest lookup failed", 500, "manifest_lookup_failed");
  }

  const existing = existingRaw as AudioManifest | null;
  if (existing?.generation_status === "ready" && existing.storage_path) {
    const { data: signed, error: signedError } = await supabase.storage
      .from(AUDIO_BUCKET)
      .createSignedUrl(existing.storage_path, SIGNED_URL_TTL_SECONDS);
    if (signedError || !signed?.signedUrl) {
      console.error("Signed URL creation failed");
      return errorResponse("Audio delivery unavailable", 503, "signed_url_failed");
    }

    await supabase.from("audio_manifests")
      .update({ last_accessed_at: new Date().toISOString() })
      .eq("id", existing.id);

    return json(responseFromManifest(existing, signed.signedUrl, true));
  }

  const storagePath = userStoragePath(userId, body.sentenceId, voiceProfile, hash);
  let manifest: AudioManifest;

  if (existing) {
    const { data, error } = await supabase
      .from("audio_manifests")
      .update({
        generation_status: "generating",
        error_code: null,
        storage_path: storagePath,
      })
      .eq("id", existing.id)
      .select("*")
      .single();
    if (error || !data) {
      return errorResponse("Audio generation state update failed", 500, "manifest_update_failed");
    }
    manifest = data as AudioManifest;
  } else {
    const { data, error } = await supabase
      .from("audio_manifests")
      .insert({
        owner_user_id: userId,
        sentence_id: body.sentenceId,
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

    if (error || !data) {
      console.error("Audio manifest insert failed");
      return errorResponse("Audio generation state creation failed", 500, "manifest_insert_failed");
    }
    manifest = data as AudioManifest;
  }

  try {
    const openaiResponse = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: TTS_MODEL,
        input: targetText,
        voice: openaiVoice,
        response_format: AUDIO_FORMAT,
        speed: TTS_SPEED,
      }),
    });

    if (!openaiResponse.ok) {
      console.error("OpenAI TTS failed", openaiResponse.status);
      await supabase.from("audio_manifests")
        .update({ generation_status: "failed", error_code: "tts_failed" })
        .eq("id", manifest.id);
      return errorResponse("Audio generation failed", 502, "tts_failed");
    }

    const audioBuffer = await openaiResponse.arrayBuffer();
    if (audioBuffer.byteLength < 512) {
      await supabase.from("audio_manifests")
        .update({ generation_status: "failed", error_code: "audio_too_small" })
        .eq("id", manifest.id);
      return errorResponse("Generated audio was invalid", 502, "audio_too_small");
    }

    const audioDigest = await sha256(audioBuffer);
    const { error: uploadError } = await supabase.storage
      .from(AUDIO_BUCKET)
      .upload(storagePath, new Uint8Array(audioBuffer), {
        contentType: "audio/mpeg",
        upsert: true,
      });

    if (uploadError) {
      console.error("Storage upload failed");
      await supabase.from("audio_manifests")
        .update({ generation_status: "failed", error_code: "storage_upload_failed" })
        .eq("id", manifest.id);
      return errorResponse("Audio storage failed", 503, "storage_upload_failed");
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
      .eq("id", manifest.id)
      .select("*")
      .single();

    if (readyError || !readyRaw) {
      return errorResponse("Audio metadata update failed", 500, "manifest_ready_update_failed");
    }
    const ready = readyRaw as AudioManifest;

    const { data: signed, error: signedError } = await supabase.storage
      .from(AUDIO_BUCKET)
      .createSignedUrl(storagePath, SIGNED_URL_TTL_SECONDS);
    if (signedError || !signed?.signedUrl) {
      return errorResponse("Audio generated but delivery URL failed", 503, "signed_url_failed");
    }

    await supabase.from("usage_records").insert({
      user_id: userId,
      operation_type: body.reason === "manual_regeneration" ? "audio_regeneration" : "audio_generation",
      estimated_units: 1,
      client_request_id: crypto.randomUUID(),
    });

    return json(responseFromManifest(ready, signed.signedUrl, false));
  } catch {
    console.error("Audio generation function failed");
    await supabase.from("audio_manifests")
      .update({ generation_status: "failed", error_code: "internal_error" })
      .eq("id", manifest.id);
    return errorResponse("Internal audio generation error", 500, "internal_error");
  }
});
