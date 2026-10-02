import {
  assert,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const SQL = await Deno.readTextFile(
  "supabase/migrations/011_user_research_profiles.sql",
);

Deno.test("research profile migration creates a dedicated server-only table", () => {
  assertStringIncludes(
    SQL,
    "CREATE TABLE IF NOT EXISTS public.user_research_profiles",
  );
  assertStringIncludes(SQL, "ENABLE ROW LEVEL SECURITY");
  assertStringIncludes(
    SQL,
    "REVOKE ALL ON public.user_research_profiles FROM PUBLIC, anon, authenticated",
  );
});

Deno.test("research profile migration mirrors the stable enum contract", () => {
  const enums: Record<string, string[]> = {
    learningGoal: [
      "work",
      "daily",
      "travel",
      "exam",
      "other",
      "prefer_not_say",
    ],
    englishLevel: [
      "starter",
      "reading_stronger",
      "conversational",
      "not_sure",
      "prefer_not_say",
    ],
    ageGroup: [
      "under_14",
      "age_14_17",
      "age_18_24",
      "age_25_34",
      "age_35_44",
      "age_45_plus",
      "prefer_not_say",
    ],
    lifeStage: [
      "student",
      "employee",
      "self_employed",
      "other",
      "prefer_not_say",
    ],
    gender: ["male", "female", "self_described", "prefer_not_say"],
  };
  for (const values of Object.values(enums)) {
    for (const value of values) {
      assertStringIncludes(SQL, "'" + value + "'");
    }
  }
  assertStringIncludes(SQL, "char_length(gender_description) <= 40");
});

Deno.test("research profile migration exposes the two owner-checked RPCs", () => {
  assertStringIncludes(SQL, "get_user_research_profile(p_user_id UUID)");
  assertStringIncludes(
    SQL,
    "update_user_research_profile(",
  );
  for (const operation of ["offer", "save", "skip", "withdraw"]) {
    assertStringIncludes(SQL, "'" + operation + "'");
  }
  assertStringIncludes(
    SQL,
    "auth.uid() IS NOT NULL AND auth.uid() <> p_user_id",
  );
});

Deno.test("research profile migration enforces consent, conflict and withdrawal", () => {
  assertStringIncludes(SQL, "profile_consent_required");
  assertStringIncludes(SQL, "profile_conflict");
  assertStringIncludes(SQL, "profile_invalid_input");
  assertStringIncludes(SQL, "prompt_state = 'withdrawn'");
  assertStringIncludes(SQL, "research_consent = false");
  assertStringIncludes(SQL, "gender_description = NULL");
  assertStringIncludes(SQL, "Draft only");
});

Deno.test("research profile migration grants RPC execution to the service role only", () => {
  const grantStatements = SQL.split(";")
    .filter((statement) => statement.includes("GRANT EXECUTE"))
    .join("\n");
  assert(grantStatements.includes("service_role"));
  assert(!grantStatements.includes("authenticated"));
  assert(!grantStatements.includes("anon"));
  assertStringIncludes(
    SQL,
    "REVOKE ALL ON FUNCTION public.get_user_research_profile(UUID)",
  );
});
