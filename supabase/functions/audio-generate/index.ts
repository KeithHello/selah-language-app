// Edge Function: /v1/audio/generate
// Generates TTS audio for an English sentence using OpenAI TTS.
// Returns audio as base64 (MVP) or a signed URL (future with object storage).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { CORS_HEADERS, json, errorResponse, handleOptions, requireAuth } from "../_shared/cors.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";

/**
 * Maps v8 user-facing voice profiles to OpenAI TTS voice IDs.
 * User sees: 溫柔自然 / 清晰慢速 / 日常輕快
 * Backend maps to: nova / sage / ash
 */
const VOICE_MAP: Record<string, string> = {
  "gentle-natural": "nova",
  "clear-slow": "sage",
  "daily-bright": "ash",
};

interface RequestBody {
  sentenceId: string;
  targetText: string;
  voiceProfile: string;
  reason?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleOptions();

  const authResult = requireAuth(req);
  if (authResult instanceof Response) return authResult;
  const userId = authResult;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405, "method_not_allowed");
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400, "invalid_body");
  }

  if (!body.targetText || body.targetText.trim().length === 0) {
    return errorResponse("targetText is required", 400, "missing_target_text");
  }

  if (body.targetText.length > 1000) {
    return errorResponse("targetText too long (max 1000 chars)", 400, "text_too_long");
  }

  const voiceProfile = body.voiceProfile ?? "gentle-natural";
  const openaiVoice = VOICE_MAP[voiceProfile] ?? "nova";
  const reason = body.reason ?? "initial_generation";

  try {
    const openaiResponse = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "tts-1",
        input: body.targetText,
        voice: openaiVoice,
        response_format: "mp3",
        speed: 0.85,
      }),
    });

    if (!openaiResponse.ok) {
      const errText = await openaiResponse.text();
      console.error("OpenAI TTS error:", openaiResponse.status, errText);
      return errorResponse("Audio generation failed", 502, "tts_failed");
    }

    const audioBuffer = await openaiResponse.arrayBuffer();
    const audioBase64 = btoa(String.fromCharCode(...new Uint8Array(audioBuffer)));

    // Record usage
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (supabaseUrl && supabaseKey) {
      const supabase = createClient(supabaseUrl, supabaseKey);
      await supabase.from("usage_records").insert({
        user_id: userId,
        operation_type: reason === "manual_regeneration" ? "audio_regeneration" : "audio_generation",
        estimated_units: 1,
        client_request_id: crypto.randomUUID(),
      });
    }

    return json({
      audio: {
        status: "ready",
        voiceProfile: voiceProfile,
        audioData: audioBase64,
        audioFormat: "mp3",
        durationMs: Math.ceil(body.targetText.split(" ").length / 2.5 * 1000),
      },
      usage: {
        operationType: reason,
        estimatedUnits: 1,
      },
    });
  } catch (err) {
    console.error("Audio generation error:", err);
    return errorResponse("Internal server error", 500, "internal_error");
  }
});
