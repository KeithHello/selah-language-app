// Edge Function: audio-generate - Input Validation Tests
// Run: deno test supabase/tests/audio_generate_test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  AUDIO_FORMAT,
  TTS_MODEL,
  TTS_SPEED,
  VOICE_MAP,
} from "../functions/_shared/audio.ts";
import {
  buildTTSRequest,
  validateAudioGenerationInput,
} from "../functions/_shared/audio_contract.ts";
import {
  shouldReuseInFlightGeneration,
} from "../functions/_shared/audio_generation_policy.ts";

// ============================================================
// Voice Map
// ============================================================

Deno.test("VOICE_MAP maps gentle-natural to nova", () => {
  assertEquals(VOICE_MAP["gentle-natural"], "nova");
});

Deno.test("VOICE_MAP maps clear-slow to sage", () => {
  assertEquals(VOICE_MAP["clear-slow"], "sage");
});

Deno.test("VOICE_MAP maps daily-bright to ash", () => {
  assertEquals(VOICE_MAP["daily-bright"], "ash");
});

// ============================================================
// TTS API Configuration
// ============================================================

Deno.test("Uses tts-1 model", () => {
  assertEquals(TTS_MODEL, "tts-1");
});

Deno.test("Uses mp3 format", () => {
  assertEquals(AUDIO_FORMAT, "mp3");
});

Deno.test("Default speed is 0.85", () => {
  assertEquals(TTS_SPEED, 0.85);
});

// ============================================================
// Input Validation
// ============================================================

Deno.test("Requires targetText", () => {
  const result = validateAudioGenerationInput({ sentenceId: "sentence-1" });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "missing_audio_input");
});

Deno.test("Validates targetText max length 1000", () => {
  const result = validateAudioGenerationInput({
    sentenceId: "sentence-1",
    targetText: "a".repeat(1001),
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "text_too_long");
});

Deno.test("Rejects unsupported voice profile", () => {
  const result = validateAudioGenerationInput({
    sentenceId: "sentence-1",
    targetText: "Hello",
    voiceProfile: "unknown",
  });
  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, "unsupported_voice_profile");
});

// ============================================================
// Output Structure
// ============================================================

Deno.test("Builds the OpenAI TTS request from validated input", () => {
  const result = validateAudioGenerationInput({
    sentenceId: " sentence-1 ",
    targetText: " Hello world ",
    voiceProfile: "gentle-natural",
  });
  assertEquals(result.ok, true);
  if (!result.ok) return;

  assertEquals(result.sentenceId, "sentence-1");
  assertEquals(result.targetText, "Hello world");
  assertEquals(buildTTSRequest(result.targetText, result.openaiVoice), {
    model: "tts-1",
    input: "Hello world",
    voice: "nova",
    response_format: "mp3",
    speed: 0.85,
  });
});

Deno.test(
  "Reuses queued and generating manifests to prevent duplicate provider calls",
  () => {
    assertEquals(shouldReuseInFlightGeneration("queued"), true);
    assertEquals(shouldReuseInFlightGeneration("generating"), true);
    assertEquals(shouldReuseInFlightGeneration("ready"), false);
    assertEquals(shouldReuseInFlightGeneration("failed"), false);
    assertEquals(shouldReuseInFlightGeneration(null), false);
  },
);
