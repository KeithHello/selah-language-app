export type AudioGenerationStatus =
  | "queued"
  | "generating"
  | "ready"
  | "failed";

export const AUDIO_GENERATION_TTL_MS = 5 * 60 * 1_000;
export const AUDIO_TTS_TIMEOUT_MS = 15 * 1_000;
export const AUDIO_PROVIDER_MAX_ATTEMPTS = 2;
export const AUDIO_PROVIDER_RETRY_BASE_DELAY_MS = 250;
export const AUDIO_UPLOAD_MAX_ATTEMPTS = 3;
export const AUDIO_UPLOAD_RETRY_BASE_DELAY_MS = 200;

export function shouldRetryProviderResponse(status: number | null): boolean {
  return status === null || status === 408 || status === 429 ||
    (status >= 500 && status <= 599);
}

export function shouldReuseInFlightGeneration(
  status: AudioGenerationStatus | null,
  updatedAt?: string | null,
  now: Date | string | number = new Date(),
  ttlMs: number = AUDIO_GENERATION_TTL_MS,
): boolean {
  if (status !== "queued" && status !== "generating") return false;
  if (!updatedAt) return false;

  const updatedTime = new Date(updatedAt).getTime();
  const nowTime = new Date(now).getTime();
  if (!Number.isFinite(updatedTime) || !Number.isFinite(nowTime)) return false;
  return updatedTime >= nowTime - ttlMs;
}

export function isRecoverableAudioStatus(
  status: AudioGenerationStatus | null,
): boolean {
  return status === "queued" || status === "generating" ||
    status === "failed";
}

export function isLikelyMp3Audio(buffer: ArrayBuffer): boolean {
  if (buffer.byteLength < 512) return false;

  const bytes = new Uint8Array(buffer);
  if (bytes[0] === 0x49 && bytes[1] === 0x44 && bytes[2] === 0x33) {
    return true;
  }

  const scanLimit = Math.min(bytes.length - 1, 64);
  for (let index = 0; index < scanLimit; index += 1) {
    if (bytes[index] === 0xff && (bytes[index + 1] & 0xe0) === 0xe0) {
      return true;
    }
  }
  return false;
}
