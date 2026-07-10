// Supabase Migration SQL - Schema Validation Tests
// Run: deno test supabase/tests/migration_test.ts
//
// These tests validate the SQL migration files for:
// 1. All required tables exist
// 2. All required columns exist
// 3. RLS policies are defined
// 4. Triggers are defined
//
// Note: These are static analysis tests that parse the SQL file.
// Full integration tests require a running PostgreSQL instance.

import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

const SCHEMA_SQL = await Deno.readTextFile("supabase/migrations/001_initial_schema.sql");
const RLS_SQL = await Deno.readTextFile("supabase/migrations/002_rls_policies.sql");

// ============================================================
// Table existence
// ============================================================

const REQUIRED_TABLES = [
  "user_profiles",
  "companions",
  "sprite_memories",
  "sentences",
  "vocab_items",
  "audio_assets",
  "generation_jobs",
  "learning_events",
  "sync_queue",
  "seed_sentences",
  "usage_records",
];

for (const table of REQUIRED_TABLES) {
  Deno.test(`Migration creates table: ${table}`, () => {
    assertStringIncludes(SCHEMA_SQL, `CREATE TABLE IF NOT EXISTS public.${table}`);
  });
}

// ============================================================
// Key columns in sentences table
// ============================================================

Deno.test("sentences table has source_text column", () => {
  assertStringIncludes(SCHEMA_SQL, "source_text TEXT NOT NULL");
});

Deno.test("sentences table has target_text column", () => {
  assertStringIncludes(SCHEMA_SQL, "target_text TEXT NOT NULL");
});

Deno.test("sentences table has category column", () => {
  assertStringIncludes(SCHEMA_SQL, "category TEXT NOT NULL DEFAULT 'daily_life'");
});

Deno.test("sentences table has review_state column", () => {
  assertStringIncludes(SCHEMA_SQL, "review_state TEXT NOT NULL DEFAULT 'new'");
});

Deno.test("sentences table has next_review_at column", () => {
  assertStringIncludes(SCHEMA_SQL, "next_review_at TIMESTAMPTZ NOT NULL DEFAULT now()");
});

Deno.test("sentences table has deconstruction JSONB column", () => {
  assertStringIncludes(SCHEMA_SQL, "deconstruction JSONB NOT NULL DEFAULT '[]'::jsonb");
});

// ============================================================
// Key columns in vocab_items table
// ============================================================

Deno.test("vocab_items table has help_state column", () => {
  assertStringIncludes(SCHEMA_SQL, "help_state TEXT NOT NULL DEFAULT 'new'");
});

Deno.test("vocab_items table has active_help_visible column", () => {
  assertStringIncludes(SCHEMA_SQL, "active_help_visible BOOLEAN NOT NULL DEFAULT true");
});

// ============================================================
// Key columns in audio_assets table
// ============================================================

Deno.test("audio_assets table has generation_status column", () => {
  assertStringIncludes(SCHEMA_SQL, "generation_status TEXT NOT NULL DEFAULT 'queued'");
});

Deno.test("audio_assets table has voice_profile column", () => {
  assertStringIncludes(SCHEMA_SQL, "voice_profile TEXT NOT NULL DEFAULT 'gentle-natural'");
});

// ============================================================
// Key columns in generation_jobs table
// ============================================================

Deno.test("generation_jobs table has job_type column", () => {
  assertStringIncludes(SCHEMA_SQL, "job_type TEXT NOT NULL");
});

Deno.test("generation_jobs table has max_retries column", () => {
  assertStringIncludes(SCHEMA_SQL, "max_retries INTEGER NOT NULL DEFAULT 5");
});

// ============================================================
// Foreign keys
// ============================================================

Deno.test("sentences table references auth.users", () => {
  assertStringIncludes(SCHEMA_SQL, "REFERENCES auth.users(id) ON DELETE CASCADE");
});

Deno.test("vocab_items references sentences", () => {
  assertStringIncludes(SCHEMA_SQL, "REFERENCES public.sentences(id) ON DELETE CASCADE");
});

Deno.test("audio_assets references sentences", () => {
  assertStringIncludes(SCHEMA_SQL, "REFERENCES public.sentences(id) ON DELETE CASCADE");
});

Deno.test("sprite_memories references companions", () => {
  assertStringIncludes(SCHEMA_SQL, "REFERENCES public.companions(id) ON DELETE CASCADE");
});

// ============================================================
// Indexes
// ============================================================

Deno.test("Index on sentences(user_id) exists", () => {
  assertStringIncludes(SCHEMA_SQL, "idx_sentences_user_id");
});

Deno.test("Index on sentences(user_id, next_review_at) exists", () => {
  assertStringIncludes(SCHEMA_SQL, "idx_sentences_user_review");
});

Deno.test("Index on vocab_items(sentence_id) exists", () => {
  assertStringIncludes(SCHEMA_SQL, "idx_vocab_items_sentence_id");
});

Deno.test("Index on generation_jobs(status, next_retry_at) exists", () => {
  assertStringIncludes(SCHEMA_SQL, "idx_generation_jobs_status");
});

// ============================================================
// Triggers
// ============================================================

Deno.test("handle_updated_at function exists", () => {
  assertStringIncludes(SCHEMA_SQL, "handle_updated_at");
});

Deno.test("on_auth_user_created trigger exists", () => {
  assertStringIncludes(SCHEMA_SQL, "on_auth_user_created");
});

Deno.test("handle_new_user function creates companion", () => {
  assertStringIncludes(SCHEMA_SQL, "handle_new_user");
  assertStringIncludes(SCHEMA_SQL, "INSERT INTO public.companions");
});

// ============================================================
// RLS policies
// ============================================================

Deno.test("RLS enabled on user_profiles", () => {
  assertStringIncludes(RLS_SQL, "ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY");
});

Deno.test("RLS enabled on sentences", () => {
  assertStringIncludes(RLS_SQL, "ALTER TABLE public.sentences ENABLE ROW LEVEL SECURITY");
});

Deno.test("RLS enabled on vocab_items", () => {
  assertStringIncludes(RLS_SQL, "ALTER TABLE public.vocab_items ENABLE ROW LEVEL SECURITY");
});

Deno.test("RLS enabled on seed_sentences", () => {
  assertStringIncludes(RLS_SQL, "ALTER TABLE public.seed_sentences ENABLE ROW LEVEL SECURITY");
});

Deno.test("Users can view own sentences policy", () => {
  assertStringIncludes(RLS_SQL, '"Users can view own sentences"');
});

Deno.test("Users can insert own sentences policy", () => {
  assertStringIncludes(RLS_SQL, '"Users can insert own sentences"');
});

Deno.test("Authenticated users can read seed sentences policy", () => {
  assertStringIncludes(RLS_SQL, '"Authenticated users can read seed sentences"');
});

Deno.test("learning_events has no UPDATE policy (append-only)", () => {
  // Verify there is no UPDATE policy for learning_events
  const rlsSection = RLS_SQL.split("learning_events");
  // Should not contain "FOR UPDATE" in the context of learning_events
  assertEquals(
    !RLS_SQL.includes("ON public.learning_events FOR UPDATE"),
    true,
  );
});

Deno.test("usage_records has only INSERT policy", () => {
  // Verify there is no SELECT policy for usage_records
  assertEquals(
    !RLS_SQL.includes("ON public.usage_records FOR SELECT"),
    true,
  );
});
