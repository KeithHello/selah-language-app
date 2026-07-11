import { assert, assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AUDIO_BUCKET,
  contentHash,
  estimatedDurationMs,
  isAudioManifestAccessible,
  normalizeText,
  seedScope,
  seedStoragePath,
  userScope,
  userStoragePath,
  VOICE_MAP,
} from "../functions/_shared/audio.ts";

Deno.test("audio bucket is private bucket identifier", () => {
  assertEquals(AUDIO_BUCKET, "audio-assets");
});

Deno.test("normalization collapses whitespace and ignores casing", () => {
  assertEquals(normalizeText("  Hello   WORLD \n"), "hello world");
});

Deno.test("content hash is stable for semantically identical input", async () => {
  const first = await contentHash("Hello   world", "gentle-natural");
  const second = await contentHash(" hello world ", "gentle-natural");
  assertEquals(first, second);
  assertEquals(first.length, 64);
});

Deno.test("content hash changes for voice and text changes", async () => {
  const base = await contentHash("Hello world", "gentle-natural");
  assertNotEquals(base, await contentHash("Hello world", "clear-slow"));
  assertNotEquals(base, await contentHash("Hello there", "gentle-natural"));
});

Deno.test("user storage paths isolate users", () => {
  const hash = "a".repeat(64);
  const first = userStoragePath("user-a", "sentence-1", "gentle-natural", hash);
  const second = userStoragePath("user-b", "sentence-1", "gentle-natural", hash);
  assertEquals(first, `users/user-a/sentence-1/gentle-natural/${hash}.mp3`);
  assertNotEquals(first, second);
  assertEquals(userScope("user-a"), "user:user-a");
});

Deno.test("seed storage paths use seed namespace", () => {
  const hash = "b".repeat(64);
  assertEquals(seedScope("seed-01"), "seed:seed-01");
  assertEquals(
    seedStoragePath("seed-01", "daily-bright", hash),
    `seed/seed-01/daily-bright/${hash}.mp3`,
  );
});

Deno.test("manifest access permits seed and owning user only", () => {
  assert(isAudioManifestAccessible({ owner_user_id: null, seed_sentence_id: "seed-01" }, "any-user"));
  assert(isAudioManifestAccessible({ owner_user_id: "owner", seed_sentence_id: null }, "owner"));
  assert(!isAudioManifestAccessible({ owner_user_id: "owner", seed_sentence_id: null }, "other-user"));
});

Deno.test("all user-facing profiles map to supported OpenAI TTS voices", () => {
  assertEquals(VOICE_MAP["gentle-natural"], "nova");
  assertEquals(VOICE_MAP["clear-slow"], "sage");
  assertEquals(VOICE_MAP["daily-bright"], "ash");
  assertEquals(VOICE_MAP["elegant-british"], "shimmer");
});

Deno.test("estimated duration remains positive", () => {
  assertEquals(estimatedDurationMs("hello"), 500);
  assert(estimatedDurationMs("this is a longer English sentence for playback") > 500);
});
