// Edge Function: /v1/audio-download-url
// Refreshes a signed download URL for an existing audio manifest without TTS work.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  json,
  requireAuth,
} from "../_shared/cors.ts";
import {
  AUDIO_BUCKET,
  isAudioManifestAccessible,
  SIGNED_URL_TTL_SECONDS,
} from "../_shared/audio.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

interface RequestBody {
  manifestId: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const authResult = requireAuth(req);
  if (authResult instanceof Response) return authResult;
  const userId = authResult;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse(
      "Audio service is not configured",
      503,
      "audio_service_unavailable",
    );
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }

  if (!body.manifestId) {
    return errorResponse("manifestId is required", 400, "missing_manifest_id");
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: manifest, error } = await supabase
    .from("audio_manifests")
    .select(
      "id, owner_user_id, seed_sentence_id, voice_profile, storage_path, sha256, byte_size, duration_ms, generation_status, error_code",
    )
    .eq("id", body.manifestId)
    .maybeSingle();

  if (error) {
    return errorResponse(
      "Audio manifest lookup failed",
      500,
      "manifest_lookup_failed",
    );
  }
  if (!manifest || !isAudioManifestAccessible(manifest, userId)) {
    return errorResponse("Audio asset not found", 404, "audio_not_found");
  }
  if (manifest.generation_status !== "ready" || !manifest.storage_path) {
    return json({
      status: manifest.generation_status,
      voiceProfile: manifest.voice_profile,
      manifestId: manifest.id,
      errorCode: manifest.error_code,
    });
  }

  const { data: signed, error: signedError } = await supabase.storage
    .from(AUDIO_BUCKET)
    .createSignedUrl(manifest.storage_path, SIGNED_URL_TTL_SECONDS);

  if (signedError || !signed?.signedUrl) {
    return errorResponse(
      "Audio delivery unavailable",
      503,
      "signed_url_failed",
    );
  }

  await supabase.from("audio_manifests")
    .update({ last_accessed_at: new Date().toISOString() })
    .eq("id", manifest.id);

  return json({
    status: "ready",
    voiceProfile: manifest.voice_profile,
    manifestId: manifest.id,
    downloadUrl: signed.signedUrl,
    storagePath: manifest.storage_path,
    sha256: manifest.sha256,
    byteSize: manifest.byte_size,
    durationMs: manifest.duration_ms,
    cacheHit: true,
  });
});
