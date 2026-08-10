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
