// Edge Function: /v1/audio/download
// Authorized download gateway that streams private audio objects without leaking direct signed URLs.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  errorResponse,
  handleOptions,
  requireAuth,
} from "../_shared/cors.ts";
import { AUDIO_BUCKET, isAudioManifestAccessible } from "../_shared/audio.ts";
import { parseSingleByteRange } from "../_shared/resource_budget.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();
  if (req.method !== "GET") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  const auth = requireAuth(req);
  if (auth instanceof Response) return auth;
  const userId = auth;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return errorResponse("Service unavailable", 503, "audio_gateway_unavailable");
  }

  const url = new URL(req.url);
  const manifestId = url.searchParams.get("manifestId");
  if (!manifestId) {
    return errorResponse("manifestId is required", 400, "missing_manifest_id");
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: manifest, error: manifestError } = await supabase
    .from("audio_manifests")
    .select("*")
    .eq("id", manifestId)
    .maybeSingle();

  if (manifestError || !manifest) {
    return errorResponse("Audio not found", 404, "audio_not_found");
  }

  if (!isAudioManifestAccessible(manifest, userId)) {
    return errorResponse("Access denied", 403, "audio_forbidden");
  }

  if (manifest.generation_status !== "ready" || !manifest.storage_path) {
    return errorResponse("Audio not ready", 409, "audio_not_ready");
  }

  const rangeHeader = req.headers.get("Range");
  const rangeCheck = parseSingleByteRange(rangeHeader, manifest.byte_size || 1024 * 1024);
  if (!rangeCheck.valid) {
    return errorResponse("Requested range not satisfiable", 416, "range_not_satisfiable");
  }

  const { data: downloaded, error: downloadError } = await supabase.storage
    .from(AUDIO_BUCKET)
    .download(manifest.storage_path);

  if (downloadError || !downloaded) {
    console.error("Storage download failed", downloadError);
    return errorResponse("Audio stream unavailable", 500, "stream_unavailable");
  }

  const headers = new Headers({
    "Content-Type": "audio/mpeg",
    "Cache-Control": "private, max-age=3600",
    "Accept-Ranges": "bytes",
  });

  return new Response(downloaded, { status: 200, headers });
});
