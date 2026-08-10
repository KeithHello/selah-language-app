import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  dryRunSummary,
  loadExecuteConfig,
  parseOptions,
} from "../scripts/remote_acceptance.ts";

const SCRIPT_SOURCE = await Deno.readTextFile(
  "supabase/scripts/remote_acceptance.ts",
);

Deno.test("remote acceptance defaults to a non-network dry run", () => {
  assertEquals(parseOptions([]), { execute: false, help: false });
  assertEquals(parseOptions(["--help"]), { execute: false, help: true });
  assertEquals(
    dryRunSummary()[0],
    "DRY RUN ONLY: no Supabase, OpenAI, Storage, or auth request will be made.",
  );
});

Deno.test("execute mode requires an explicit billable approval", () => {
  assertThrows(
    () =>
      loadExecuteConfig({
        SUPABASE_URL: "https://example.supabase.co",
        SUPABASE_PUBLISHABLE_KEY: "publishable",
        SUPABASE_TEST_EMAIL: "test@example.com",
        SUPABASE_TEST_PASSWORD: "password",
      }),
    Error,
    "REMOTE_ACCEPTANCE_ALLOW_BILLABLE=true",
  );
});

Deno.test("execute mode requires only test-account configuration", () => {
  assertEquals(
    loadExecuteConfig({
      REMOTE_ACCEPTANCE_ALLOW_BILLABLE: "true",
      SUPABASE_URL: "https://example.supabase.co/",
      SUPABASE_PUBLISHABLE_KEY: "publishable",
      SUPABASE_TEST_EMAIL: "test@example.com",
      SUPABASE_TEST_PASSWORD: "password",
    }),
    {
      supabaseURL: "https://example.supabase.co",
      publishableKey: "publishable",
      email: "test@example.com",
      password: "password",
    },
  );
});

Deno.test("runner covers the complete remote acceptance matrix", () => {
  for (
    const endpoint of [
      "config-bootstrap",
      "sentences-generate",
      "sentences-prepare",
      "sentences-batch-generate",
      "audio-generate",
      "audio-download-url",
    ]
  ) {
    assertStringIncludes(SCRIPT_SOURCE, endpoint);
  }
  assertStringIncludes(SCRIPT_SOURCE, "sentence-generation-replay");
  assertStringIncludes(SCRIPT_SOURCE, "capture-preparation-replay");
  assertStringIncludes(SCRIPT_SOURCE, "REMOTE_ACCEPTANCE_ALLOW_BILLABLE");
});

Deno.test("runner does not print credentials or raw transcript content", () => {
  assertEquals(SCRIPT_SOURCE.includes("console.log(config"), false);
  assertEquals(SCRIPT_SOURCE.includes("console.log(accessToken"), false);
  assertEquals(SCRIPT_SOURCE.includes("console.log(TEST_TRANSCRIPT"), false);
});
