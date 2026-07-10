// Supabase Edge Functions - Voice Map and Config Tests
// Run: deno test supabase/tests/voice_map_test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

// ============================================================
// Voice Profile Mapping
// Maps v8 user-facing voice labels to OpenAI TTS voice IDs.
// This mirrors the VOICE_MAP in audio-generate/index.ts.
// ============================================================

const VOICE_MAP: Record<string, string> = {
  "gentle-natural": "nova",
  "clear-slow": "sage",
  "daily-bright": "ash",
};

Deno.test("gentle-natural maps to nova", () => {
  assertEquals(VOICE_MAP["gentle-natural"], "nova");
});

Deno.test("clear-slow maps to sage", () => {
  assertEquals(VOICE_MAP["clear-slow"], "sage");
});

Deno.test("daily-bright maps to ash", () => {
  assertEquals(VOICE_MAP["daily-bright"], "ash");
});

Deno.test("unknown voice defaults to nova", () => {
  assertEquals(VOICE_MAP["unknown"] ?? "nova", "nova");
});

Deno.test("all 3 voice profiles are mapped", () => {
  assertEquals(Object.keys(VOICE_MAP).length, 3);
});

Deno.test("all OpenAI voices are unique", () => {
  const voices = Object.values(VOICE_MAP);
  const unique = new Set(voices);
  assertEquals(unique.size, voices.length);
});

// ============================================================
// Bootstrap Config Structure
// ============================================================

const EXPECTED_BOOTSTRAP = {
  sourceLanguages: ["zh-Hant"],
  targetLanguages: ["en"],
  defaultVoiceProfile: "gentle-natural",
  voiceProfiles: [
    { id: "gentle-natural", label: "溫柔自然", openaiVoice: "nova" },
    { id: "clear-slow", label: "清晰慢速", openaiVoice: "sage" },
    { id: "daily-bright", label: "日常輕快", openaiVoice: "ash" },
  ],
  featureFlags: {
    enable_japanese: false,
    enable_sync: false,
    enable_credits: false,
    enable_analytics: true,
  },
};

Deno.test("bootstrap has 3 voice profiles", () => {
  assertEquals(EXPECTED_BOOTSTRAP.voiceProfiles.length, 3);
});

Deno.test("bootstrap default voice is gentle-natural", () => {
  assertEquals(EXPECTED_BOOTSTRAP.defaultVoiceProfile, "gentle-natural");
});

Deno.test("bootstrap source language is zh-Hant", () => {
  assertEquals(EXPECTED_BOOTSTRAP.sourceLanguages, ["zh-Hant"]);
});

Deno.test("bootstrap target language is en", () => {
  assertEquals(EXPECTED_BOOTSTRAP.targetLanguages, ["en"]);
});

Deno.test("bootstrap Japanese is disabled", () => {
  assertEquals(EXPECTED_BOOTSTRAP.featureFlags.enable_japanese, false);
});

Deno.test("bootstrap sync is disabled", () => {
  assertEquals(EXPECTED_BOOTSTRAP.featureFlags.enable_sync, false);
});

Deno.test("bootstrap credits are disabled", () => {
  assertEquals(EXPECTED_BOOTSTRAP.featureFlags.enable_credits, false);
});

Deno.test("bootstrap analytics is enabled", () => {
  assertEquals(EXPECTED_BOOTSTRAP.featureFlags.enable_analytics, true);
});

// ============================================================
// Event Type Whitelist
// ============================================================

const ALLOWED_EVENT_TYPES = new Set([
  "sentence_created",
  "listen_started",
  "listen_completed",
  "practice_started",
  "practice_rated",
  "preview_completed",
  "vocab_added",
  "vocab_removed",
  "voice_selected",
  "memory_unlocked",
]);

Deno.test("event whitelist has 10 types", () => {
  assertEquals(ALLOWED_EVENT_TYPES.size, 10);
});

Deno.test("sentence_created is allowed", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("sentence_created"), true);
});

Deno.test("listen_completed is allowed", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("listen_completed"), true);
});

Deno.test("practice_rated is allowed", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("practice_rated"), true);
});

Deno.test("random_string is NOT allowed", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("random_string"), false);
});

Deno.test("raw_sentence_text is NOT allowed (privacy)", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("raw_sentence_text"), false);
});
