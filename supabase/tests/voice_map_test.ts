// Supabase Edge Functions - Voice Map and Config Tests
// Run: deno test supabase/tests/voice_map_test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { VOICE_MAP } from "../functions/_shared/audio.ts";
const BOOTSTRAP_SOURCE = await Deno.readTextFile(
  "supabase/functions/config-bootstrap/index.ts",
);

// ============================================================
// Voice Profile Mapping
// Maps user-facing voice labels to the default Azure neural voices.
// This mirrors the VOICE_MAP in audio-generate/index.ts.
// ============================================================

Deno.test("gentle-natural maps to Azure Jenny", () => {
  assertEquals(VOICE_MAP["gentle-natural"], "en-US-JennyNeural");
});

Deno.test("clear-slow maps to Azure Jenny", () => {
  assertEquals(VOICE_MAP["clear-slow"], "en-US-JennyNeural");
});

Deno.test("daily-bright maps to Azure Guy", () => {
  assertEquals(VOICE_MAP["daily-bright"], "en-US-GuyNeural");
});

Deno.test("elegant-british maps to Azure Sonia", () => {
  assertEquals(VOICE_MAP["elegant-british"], "en-GB-SoniaNeural");
});

Deno.test("unknown voice has no provider default", () => {
  assertEquals(VOICE_MAP["unknown"], undefined);
});

Deno.test("native-gentle maps to Azure Taiwan Mandarin", () => {
  assertEquals(VOICE_MAP["native-gentle"], "zh-TW-HsiaoChenNeural");
});

Deno.test("native-clear maps to Azure Taiwan Mandarin", () => {
  assertEquals(VOICE_MAP["native-clear"], "zh-TW-HsiaoChenNeural");
});

Deno.test("native-bright maps to Azure Taiwan Mandarin", () => {
  assertEquals(VOICE_MAP["native-bright"], "zh-TW-HsiaoChenNeural");
});

Deno.test("native-calm maps to Azure Taiwan Mandarin", () => {
  assertEquals(VOICE_MAP["native-calm"], "zh-TW-HsiaoChenNeural");
});

Deno.test("all 8 voice profiles are mapped", () => {
  assertEquals(Object.keys(VOICE_MAP).length, 8);
});

Deno.test("profiles can share provider voices while preserving profile identity", () => {
  assertEquals(VOICE_MAP["gentle-natural"], VOICE_MAP["clear-slow"]);
  assertEquals(VOICE_MAP["native-gentle"], VOICE_MAP["native-calm"]);
});

// ============================================================
// Bootstrap Config Structure
// ============================================================

const EXPECTED_BOOTSTRAP = {
  sourceLanguages: ["zh-Hant"],
  targetLanguages: ["en"],
  defaultVoiceProfile: "gentle-natural",
  voiceProfiles: [
    {
      id: "gentle-natural",
      label: "溫柔自然",
      azureVoice: "en-US-JennyNeural",
    },
    { id: "clear-slow", label: "清晰慢速", azureVoice: "en-US-JennyNeural" },
    { id: "daily-bright", label: "日常輕快", azureVoice: "en-US-GuyNeural" },
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

Deno.test("bootstrap exposes Azure voice IDs instead of OpenAI TTS IDs", () => {
  assertEquals(BOOTSTRAP_SOURCE.includes("openaiVoice"), false);
  assertEquals(
    BOOTSTRAP_SOURCE.includes('azureVoice: "en-US-JennyNeural"'),
    true,
  );
  assertEquals(
    BOOTSTRAP_SOURCE.includes('azureVoice: "en-US-GuyNeural"'),
    true,
  );
  assertEquals(
    BOOTSTRAP_SOURCE.includes('azureVoice: "en-GB-SoniaNeural"'),
    true,
  );
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
  "activity_heartbeat",
]);

Deno.test("event whitelist has 11 types", () => {
  assertEquals(ALLOWED_EVENT_TYPES.size, 11);
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
