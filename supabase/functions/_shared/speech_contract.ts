/**
 * Contract shared by the browser recorder and the speech-transcribe function.
 *
 * The browser sends a multipart form because audio is binary.  Keep this
 * module free of Supabase/OpenAI imports so it can be exercised without a
 * network or a running Edge Function.
 */

export const SPEECH_TRANSCRIPTION_MODEL = "gpt-4o-mini-transcribe";
export const MAX_SPEECH_FILE_BYTES = 10 * 1024 * 1024;
export const MAX_SPEECH_DURATION_MS = 180_000;

/** MIME types emitted by the web MediaRecorder implementations we support. */
export const SUPPORTED_SPEECH_MIME_TYPES = new Set([
  "audio/webm",
  "audio/mp4",
  "audio/ogg",
  "audio/wav",
  "audio/x-wav",
]);

export interface SpeechTranscribeInput {
  file: File;
  clientRequestId: string;
  language: string;
  durationMs: number;
  mimeType: string;
  extension: "webm" | "mp4" | "ogg" | "wav";
}

export type SpeechInputValidation =
  | { ok: true } & SpeechTranscribeInput
  | { ok: false; status: number; code: string; message: string };

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LANGUAGE_PATTERN = /^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/;

/**
 * Validate and normalize a multipart form received from a browser recorder.
 * MIME is checked from File.type; a filename alone is never accepted as the
 * content type because clients can forge extensions.
 */
export function validateSpeechTranscribeFormData(
  form: FormData,
): SpeechInputValidation {
  const entry = form.get("file");
  if (!(entry instanceof File)) {
    return invalid("missing_audio_file", "file is required");
  }

  const mimeType = normalizeMimeType(entry.type);
  const extension = extensionForMime(mimeType);
  if (!extension) {
    return invalid(
      "unsupported_audio_type",
      "file must be WebM, MP4, Ogg, or WAV audio",
    );
  }
  if (entry.size > MAX_SPEECH_FILE_BYTES) {
    return invalid(
      "audio_file_too_large",
      `audio file too large (max ${MAX_SPEECH_FILE_BYTES} bytes)`,
    );
  }
  if (entry.size < 1) {
    return invalid("empty_audio_file", "audio file must not be empty");
  }

  const rawRequestId = form.get("clientRequestId");
  if (typeof rawRequestId !== "string") {
    return invalid(
      "invalid_client_request_id",
      "clientRequestId must be a UUID",
    );
  }
  const clientRequestId = rawRequestId.trim().toLowerCase();
  if (!UUID_PATTERN.test(clientRequestId)) {
    return invalid(
      "invalid_client_request_id",
      "clientRequestId must be a UUID",
    );
  }

  const rawDuration = form.get("durationMs");
  if (typeof rawDuration !== "string" || !/^\d+$/.test(rawDuration.trim())) {
    return invalid(
      "invalid_duration",
      "durationMs must be a positive integer in milliseconds",
    );
  }
  const durationMs = Number(rawDuration.trim());
  if (!Number.isSafeInteger(durationMs) || durationMs < 1) {
    return invalid(
      "invalid_duration",
      "durationMs must be a positive integer in milliseconds",
    );
  }
  if (durationMs > MAX_SPEECH_DURATION_MS) {
    return invalid(
      "audio_duration_too_long",
      `audio duration too long (max ${MAX_SPEECH_DURATION_MS} ms)`,
    );
  }

  const rawLanguage = form.get("language");
  const language = typeof rawLanguage === "string" && rawLanguage.trim()
    ? rawLanguage.trim()
    : "zh";
  if (language.length > 20 || !LANGUAGE_PATTERN.test(language)) {
    return invalid(
      "invalid_language",
      "language must be a valid language code",
    );
  }

  return {
    ok: true,
    file: entry,
    clientRequestId,
    language,
    durationMs,
    mimeType,
    extension,
  };
}

/** Backwards-compatible name for callers that use the endpoint name. */
export const validateSpeechTranscribeInput = validateSpeechTranscribeFormData;
export const validateSpeechTranscriptionInput =
  validateSpeechTranscribeFormData;

export function buildSpeechTranscriptionForm(
  input: SpeechTranscribeInput,
): FormData {
  const body = new FormData();
  // Use a canonical extension derived from the validated MIME type.  A client
  // supplied filename may contain a misleading extension or path fragments.
  body.append("file", input.file, `capture.${input.extension}`);
  body.set("model", SPEECH_TRANSCRIPTION_MODEL);
  body.set("language", input.language);
  body.set("response_format", "json");
  return body;
}

export function normalizeMimeType(value: string): string {
  return value.split(";", 1)[0].trim().toLowerCase();
}

function extensionForMime(
  mimeType: string,
): SpeechTranscribeInput["extension"] | null {
  if (!SUPPORTED_SPEECH_MIME_TYPES.has(mimeType)) return null;
  if (mimeType === "audio/webm") return "webm";
  if (mimeType === "audio/mp4") return "mp4";
  if (mimeType === "audio/ogg") return "ogg";
  return "wav";
}

function invalid(
  code: string,
  message: string,
): { ok: false; status: number; code: string; message: string } {
  return { ok: false, status: 400, code, message };
}
