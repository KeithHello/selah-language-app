import { AUDIO_FORMAT, TTS_MODEL, TTS_SPEED } from "./audio.ts";
import { type AudioRoute, resolveAudioRoute } from "./audio_routing.ts";

export interface AudioGenerationInput {
  contractVersion?: number;
  sentenceId?: string;
  text?: string;
  targetText?: string;
  audioRole?: "source" | "target";
  sourceLanguage?: string;
  targetLanguage?: string;
  accent?: string;
  voiceProfile?: string;
  reason?: string;
  clientRequestId?: string;
}

export type AudioInputValidation =
  | {
    ok: true;
    sentenceId: string;
    text: string;
    targetText: string;
    voiceProfile: string;
    openaiVoice: string;
    audioRole: "source" | "target";
    sourceLanguage: string | null;
    targetLanguage: string;
    accent: string;
    route: AudioRoute;
    clientRequestId: string;
  }
  | { ok: false; status: number; code: string; message: string };

export function validateAudioGenerationInput(
  body: AudioGenerationInput,
): AudioInputValidation {
  const sentenceId = body.sentenceId?.trim();
  const text = (body.text ?? body.targetText)?.trim();
  if (!sentenceId || !text) {
    return {
      ok: false,
      status: 400,
      code: "missing_audio_input",
      message: "sentenceId and text are required",
    };
  }
  if (text.length > 1000) {
    return {
      ok: false,
      status: 400,
      code: "text_too_long",
      message: "text too long (max 1000 chars)",
    };
  }

  const legacyRequest = body.contractVersion !== 2 && !body.audioRole;
  const audioRole = legacyRequest ? "target" : body.audioRole;
  const route = resolveAudioRoute({
    audioRole,
    sourceLanguage: body.sourceLanguage,
    targetLanguage: body.targetLanguage ?? "en",
    accent: body.accent,
    voiceProfile: body.voiceProfile,
  });
  if (!route.ok) {
    return {
      ok: false,
      status: 400,
      code: route.code,
      message: route.message,
    };
  }

  const clientRequestId = body.clientRequestId?.trim().toLowerCase();
  if (!clientRequestId || !isUUID(clientRequestId)) {
    return {
      ok: false,
      status: 400,
      code: "invalid_client_request_id",
      message: "clientRequestId must be a UUID",
    };
  }

  return {
    ok: true,
    sentenceId,
    text,
    targetText: text,
    voiceProfile: route.route.voiceProfile,
    openaiVoice: route.route.provider === "openai"
      ? route.route.providerVoice
      : "",
    audioRole: route.route.audioRole,
    sourceLanguage: body.sourceLanguage?.trim() || null,
    targetLanguage: body.targetLanguage?.trim() || "en",
    accent: route.route.accent,
    route: route.route,
    clientRequestId,
  };
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

export function buildTTSRequest(
  targetText: string,
  openaiVoice: string,
): Record<string, unknown> {
  return {
    model: TTS_MODEL,
    input: targetText,
    voice: openaiVoice,
    response_format: AUDIO_FORMAT,
    speed: TTS_SPEED,
  };
}
