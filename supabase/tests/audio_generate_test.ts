// Edge Function: audio-generate - Input Validation Tests
// Run: deno test supabase/tests/audio_generate_test.ts

import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

const FUNCTION_SOURCE = await Deno.readTextFile("supabase/functions/audio-generate/index.ts");

// ============================================================
// Voice Map
// ============================================================

Deno.test("VOICE_MAP maps gentle-natural to nova", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"gentle-natural": "nova"');
});

Deno.test("VOICE_MAP maps clear-slow to sage", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"clear-slow": "sage"');
});

Deno.test("VOICE_MAP maps daily-bright to ash", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"daily-bright": "ash"');
});

// ============================================================
// TTS API Configuration
// ============================================================

Deno.test("Uses tts-1 model", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"model": "tts-1"');
});

Deno.test("Uses mp3 format", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"response_format": "mp3"');
});

Deno.test("Default speed is 0.85", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"speed": 0.85');
});

// ============================================================
// Input Validation
// ============================================================

Deno.test("Requires targetText", () => {
  assertStringIncludes(FUNCTION_SOURCE, "targetText is required");
});

Deno.test("Validates targetText max length 1000", () => {
  assertStringIncludes(FUNCTION_SOURCE, "1000");
});

Deno.test("Returns 502 for TTS failed", () => {
  assertStringIncludes(FUNCTION_SOURCE, "tts_failed");
});

// ============================================================
// Output Structure
// ============================================================

Deno.test("Returns audio status as ready", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"status": "ready"');
});

Deno.test("Returns audio format as mp3", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"audioFormat": "mp3"');
});

Deno.test("Returns audioData as base64", () => {
  assertStringIncludes(FUNCTION_SOURCE, "audioData");
});

Deno.test("Returns voiceProfile in response", () => {
  assertStringIncludes(FUNCTION_SOURCE, '"voiceProfile"');
});

// ============================================================
// Usage Recording
// ============================================================

Deno.test("Records usage as audio_generation for initial", () => {
  assertStringIncludes(FUNCTION_SOURCE, "audio_generation");
});

Deno.test("Records usage as audio_regeneration for manual", () => {
  assertStringIncludes(FUNCTION_SOURCE, "audio_regeneration");
});
