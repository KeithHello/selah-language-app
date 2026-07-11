export const AUDIO_BUCKET = "audio-assets";
export const TTS_MODEL = "tts-1";
export const TTS_SPEED = 0.85;
export const AUDIO_FORMAT = "mp3";
export const SIGNED_URL_TTL_SECONDS = 60 * 10;

export const VOICE_MAP: Record<string, string> = {
  "gentle-natural": "nova",
  "clear-slow": "sage",
  "daily-bright": "ash",
  "elegant-british": "shimmer",
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
  const canonical = [normalizeText(targetText), voiceProfile, model, speed, format].join("|");
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

export function estimatedDurationMs(targetText: string): number {
  const words = targetText.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(500, Math.ceil((words / 2.5) * 1000));
}

export function isAudioManifestAccessible(
  manifest: { owner_user_id: string | null; seed_sentence_id: string | null },
  userId: string,
): boolean {
  return manifest.seed_sentence_id !== null || manifest.owner_user_id === userId;
}
