import {
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const CONFIG_SOURCE = await Deno.readTextFile("supabase/config.toml");
const DEPLOY_SCRIPT_SOURCE = await Deno.readTextFile(
  "supabase/scripts/deploy-full.sh",
);

const EDGE_FUNCTIONS = [
  "sentences-generate",
  "sentences-prepare",
  "sentences-batch-generate",
  "audio-generate",
  "audio-download-url",
  "config-bootstrap",
  "events",
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
