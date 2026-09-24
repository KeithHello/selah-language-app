import {
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const CONFIG_SOURCE = await Deno.readTextFile("supabase/config.toml");
const DEPLOY_SCRIPT_SOURCE = await Deno.readTextFile(
  "supabase/scripts/deploy-full.sh",
);
const ACCOUNT_E2E_DEPLOY_SCRIPT_SOURCE = await Deno.readTextFile(
  "supabase/scripts/deploy-account-e2e-fixes.ps1",
);

const EDGE_FUNCTIONS = [
  "sentences-generate",
  "sentences-prepare",
  "sentences-batch-generate",
  "audio-generate",
  "audio-download-url",
  "speech-transcribe",
  "config-bootstrap",
  "events",
  "admin-summary",
  "admin-cost-sync",
];

Deno.test("Supabase config registers every Edge Function", () => {
  for (const functionName of EDGE_FUNCTIONS) {
    assertStringIncludes(CONFIG_SOURCE, `[functions.${functionName}]`);
  }
});

Deno.test("deployment script deploys every Edge Function", () => {
  for (const functionName of EDGE_FUNCTIONS) {
    assertStringIncludes(
      DEPLOY_SCRIPT_SOURCE,
      `supabase functions deploy ${functionName}`,
    );
  }
});

Deno.test("account E2E deployment helper includes all affected functions", () => {
  for (
    const functionName of [
      "sentences-batch-generate",
      "events",
      "user-research-profile",
    ]
  ) {
    assertStringIncludes(ACCOUNT_E2E_DEPLOY_SCRIPT_SOURCE, `"${functionName}"`);
  }
  assertStringIncludes(
    ACCOUNT_E2E_DEPLOY_SCRIPT_SOURCE,
    "..\\functions\\$functionName\\index.ts",
  );
});

Deno.test("account E2E deployment helper cannot mutate database or secrets", () => {
  for (
    const forbiddenCommand of [
      "db push",
      "secrets set",
      "seed_import.ts",
    ]
  ) {
    if (ACCOUNT_E2E_DEPLOY_SCRIPT_SOURCE.includes(forbiddenCommand)) {
      throw new Error(
        `Scoped deployment helper must not run ${forbiddenCommand}.`,
      );
    }
  }
});
