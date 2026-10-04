import { assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

const SQL = await Deno.readTextFile(
  "supabase/migrations/014_platform_budget_enforcement_and_admin_summary.sql",
);

Deno.test("public generation metering reserves the shared daily platform budget", () => {
  assertStringIncludes(
    SQL,
    "CREATE OR REPLACE FUNCTION public.record_generation_usage",
  );
  assertStringIncludes(
    SQL,
    "public.ensure_platform_daily_budget(v_budget_period_key)",
  );
  assertStringIncludes(SQL, "platform_daily_budget_exhausted");
  assertStringIncludes(SQL, "budget_period_key");
});

Deno.test("admin budget summary is authenticated and reports the daily ledger", () => {
  assertStringIncludes(SQL, "admin_platform_budget_summary");
  assertStringIncludes(SQL, "public.is_admin_member(p_admin_user_id)");
  assertStringIncludes(
    SQL,
    "GRANT EXECUTE ON FUNCTION public.admin_platform_budget_summary",
  );
  assertStringIncludes(SQL, "remainingNanoUsd");
  assertStringIncludes(SQL, "overrunNanoUsd");
});
