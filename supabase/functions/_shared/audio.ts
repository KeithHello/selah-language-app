export const AUDIO_BUCKET = "audio-assets";
export const TTS_MODEL = "azure-speech";
export const TTS_SPEED = 1;
export const AUDIO_FORMAT = "mp3";
export const AUDIO_LEVEL_REVISION = "azure-vol-v2";
export const SEED_AUDIO_REVISION = "azure-vol-v2";
export const SIGNED_URL_TTL_SECONDS = 60 * 10;

export const VOICE_MAP: Record<string, string> = {
  "gentle-natural": "en-US-JennyNeural",
  "clear-slow": "en-US-JennyNeural",
  "daily-bright": "en-US-GuyNeural",
  "elegant-british": "en-GB-SoniaNeural",
  "native-gentle": "zh-TW-HsiaoChenNeural",
  "native-clear": "zh-TW-HsiaoChenNeural",
  "native-bright": "zh-TW-HsiaoChenNeural",
  "native-calm": "zh-TW-HsiaoChenNeural",
};

export const VOICE_ACCENTS: Record<
  string,
  "en-US" | "en-GB" | "zh-TW" | "ja-JP"
> = {
  "gentle-natural": "en-US",
  "clear-slow": "en-US",
  "daily-bright": "en-US",
  "elegant-british": "en-GB",
  "native-gentle": "zh-TW",
  "native-clear": "zh-TW",
  "native-bright": "zh-TW",
  "native-calm": "zh-TW",
};

export function normalizeText(text: string): string {
  return text.trim().replace(/\s+/g, " ").toLowerCase();
}

export async function contentHash(
  targetText: string,
  voiceProfile: string,
  model = TTS_MODEL,
  speed = TTS_SPEED,
  format = AUDIO_FORMAT,
): Promise<string> {
  const canonical = [
    normalizeText(targetText),
    voiceProfile,
    model,
    speed,
    format,
    AUDIO_LEVEL_REVISION,
  ].join("|");
  const bytes = new TextEncoder().encode(canonical);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Hashes the spoken text independently from the provider identity.  The
 * provider, voice and speed are added by audioCacheKey so a route change can
 * never reuse an older provider's bytes.
 */
export async function textContentHash(
  text: string,
  spokenLanguage: string,
  format = AUDIO_FORMAT,
  levelRevision = AUDIO_LEVEL_REVISION,
): Promise<string> {
  const canonical = [
    spokenLanguage.trim().toLowerCase(),
    format,
    levelRevision,
    normalizeText(text),
  ]
    .join("|");
  const bytes = new TextEncoder().encode(canonical);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function sha256(data: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function userScope(userId: string): string {
  return `user:${userId}`;
}

export function userStoragePath(
  userId: string,
  sentenceId: string,
  voiceProfile: string,
  hash: string,
): string {
  return `users/${userId}/${sentenceId}/${voiceProfile}/${hash}.mp3`;
}

export function userStoragePathV2(
  userId: string,
  sentenceId: string,
  provider: string,
  providerVoice: string,
  speed: number,
  textHash: string,
): string {
  const safe = (value: string) => value.replace(/[^a-zA-Z0-9._@-]/g, "_");
  return `users/${userId}/${sentenceId}/${safe(provider)}/${
    safe(providerVoice)
  }/${safe(String(speed))}/${textHash}.mp3`;
}

export function seedScope(seedSentenceId: string): string {
  return `seed:${seedSentenceId}`;
}

export function seedStoragePath(
  seedSentenceId: string,
  voiceProfile: string,
  hash: string,
): string {
  return `seed/${seedSentenceId}/${voiceProfile}/${hash}.mp3`;
}

export function mp3DurationMs(byteLength: number): number {
  if (!Number.isSafeInteger(byteLength) || byteLength < 0) {
    throw new RangeError("byteLength must be a non-negative safe integer");
  }
  return Math.round(byteLength / 20);
}

export function isAudioManifestAccessible(
  manifest: { owner_user_id: string | null; seed_sentence_id: string | null },
  userId: string,
): boolean {
  return manifest.seed_sentence_id !== null ||
    manifest.owner_user_id === userId;
}
