import {
  assert,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const SQL = await Deno.readTextFile(
  "supabase/migrations/008_sentence_language_provenance.sql",
);

Deno.test("sentence provenance migration adds all four nullable columns", () => {
  assertStringIncludes(SQL, "ADD COLUMN IF NOT EXISTS source_language TEXT");
  assertStringIncludes(SQL, "ADD COLUMN IF NOT EXISTS target_language TEXT");
  assertStringIncludes(SQL, "ADD COLUMN IF NOT EXISTS generation_model TEXT");
  assertStringIncludes(SQL, "ADD COLUMN IF NOT EXISTS prompt_version TEXT");
  assert(!SQL.includes("SET NOT NULL"));
});

Deno.test("sentence provenance migration accepts supported language codes", () => {
  assertStringIncludes(SQL, "'zh-Hant'");
  assertStringIncludes(SQL, "'zh-Hans'");
  assertStringIncludes(SQL, "'ja'");
  assertStringIncludes(SQL, "target_language IS NULL OR target_language = 'en'");
});

Deno.test("sentence provenance migration does not infer legacy language", () => {
  assert(!/UPDATE\s+public\.sentences/i.test(SQL));
  assert(!/INSERT\s+INTO\s+public\.sentences/i.test(SQL));
  assertStringIncludes(SQL, "Existing rows intentionally remain NULL");
});
