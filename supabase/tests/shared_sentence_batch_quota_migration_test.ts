import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const SQL = await Deno.readTextFile(
  "supabase/migrations/010_shared_sentence_batch_quota.sql",
);

Deno.test("sentence and batch are summed together", () => {
  assertStringIncludes(SQL, "feature IN ('sentence', 'batch')");
  assertStringIncludes(SQL, "p_feature IN ('sentence', 'batch')");
  assertEquals(SQL.includes("db push"), false);
});

Deno.test("other feature pools continue to count only their own reservations", () => {
  assertStringIncludes(
    SQL,
    "p_feature NOT IN ('sentence', 'batch') AND feature = p_feature",
  );
});
