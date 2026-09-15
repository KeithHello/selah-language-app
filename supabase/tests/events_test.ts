// Edge Function: events - Validation Tests
// Run: deno test supabase/tests/events_test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  ALLOWED_EVENT_TYPES,
  sanitizeEventMetadata,
} from "../functions/_shared/event_contract.ts";

// ============================================================
// Event Type Whitelist
// ============================================================

Deno.test("Whitelist includes sentence_created", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("sentence_created"), true);
});

Deno.test("Whitelist includes listen_completed", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("listen_completed"), true);
});

Deno.test("Whitelist includes practice_rated", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("practice_rated"), true);
});

Deno.test("Whitelist includes vocab_added", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("vocab_added"), true);
});

Deno.test("Whitelist includes voice_selected", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("voice_selected"), true);
});

Deno.test("Whitelist includes memory_unlocked", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("memory_unlocked"), true);
});

Deno.test("Whitelist includes privacy-safe activity heartbeats", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("activity_heartbeat"), true);
});

Deno.test("Whitelist includes adaptive feedback survey events", () => {
  assertEquals(ALLOWED_EVENT_TYPES.has("feedback_invite_shown"), true);
  assertEquals(ALLOWED_EVENT_TYPES.has("feedback_invite_dismissed"), true);
  assertEquals(ALLOWED_EVENT_TYPES.has("feedback_submitted"), true);
  assertEquals(ALLOWED_EVENT_TYPES.has("feedback_plan_viewed"), true);
});

// ============================================================
// Privacy Protection
// ============================================================

Deno.test("Strips metadata values longer than 200 chars", () => {
  assertEquals(
    sanitizeEventMetadata("vocab_added", { word: "a".repeat(201) }),
    {},
  );
});

Deno.test("Only allows string/number/boolean in metadata", () => {
  assertEquals(
    sanitizeEventMetadata("sentence_created", {
      category: "work",
      origin: "user_recording",
      nested: { raw: "private" },
    }),
    { category: "work", origin: "user_recording" },
  );
});

// ============================================================
// Input Validation
// ============================================================

Deno.test("Drops metadata keys not whitelisted for the event", () => {
  assertEquals(
    sanitizeEventMetadata("practice_rated", {
      signal: "clear",
      raw_sentence_text: "private",
      category: "work",
    }),
    { signal: "clear" },
  );
});

Deno.test("Allows only numeric heartbeat slots and safe activity flags", () => {
  assertEquals(
    sanitizeEventMetadata("activity_heartbeat", {
      duration_ms: 30000,
      slot_start: 1788000000,
      visible: true,
      audio_playing: false,
      raw_text: "private",
    }),
    {
      duration_ms: 30000,
      slot_start: 1788000000,
      visible: true,
      audio_playing: false,
    },
  );
});

Deno.test("Keeps survey analytics to stable IDs and strips free text", () => {
  assertEquals(
    sanitizeEventMetadata("feedback_submitted", {
      survey_version: "2026-09-13-v1",
      stage: "engaged",
      display_locale: "ja",
      satisfaction: 5,
      scenario: "daily_conversation",
      improvement: "more_natural_phrasing",
      purchase_intent: "likely",
      plan_interest: "plus",
      comment: "private sentence text",
    }),
    {
      survey_version: "2026-09-13-v1",
      stage: "engaged",
      display_locale: "ja",
      satisfaction: 5,
      scenario: "daily_conversation",
      improvement: "more_natural_phrasing",
      purchase_intent: "likely",
      plan_interest: "plus",
    },
  );
});
