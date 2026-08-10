import { AUDIO_FORMAT, TTS_MODEL, TTS_SPEED, VOICE_MAP } from "./audio.ts";

export interface AudioGenerationInput {
  sentenceId?: string;
  targetText?: string;
  voiceProfile?: string;
  reason?: string;
  clientRequestId?: string;
}

export type AudioInputValidation =
  | {
    ok: true;
    sentenceId: string;
    targetText: string;
    voiceProfile: string;
    openaiVoice: string;
    clientRequestId: string;
  }
  | { ok: false; status: number; code: string; message: string };

export function validateAudioGenerationInput(
  body: AudioGenerationInput,
): AudioInputValidation {
  const sentenceId = body.sentenceId?.trim();
  const targetText = body.targetText?.trim();
  if (!sentenceId || !targetText) {
    return {
      ok: false,
      status: 400,
      code: "missing_audio_input",
      message: "sentenceId and targetText are required",
    };
  }
  if (targetText.length > 1000) {
    return {
      ok: false,
      status: 400,
      code: "text_too_long",
      message: "targetText too long (max 1000 chars)",
    };
  }

  const voiceProfile = body.voiceProfile ?? "gentle-natural";
  const openaiVoice = VOICE_MAP[voiceProfile];
  if (!openaiVoice) {
    return {
      ok: false,
      status: 400,
      code: "unsupported_voice_profile",
      message: "Unsupported voice profile",
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
    targetText,
    voiceProfile,
    openaiVoice,
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
