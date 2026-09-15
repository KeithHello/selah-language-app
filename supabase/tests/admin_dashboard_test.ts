// Admin dashboard SQL contract tests.
// Run: deno test supabase/tests/admin_dashboard_test.ts

import { assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

const SQL = await Deno.readTextFile(
  "supabase/migrations/005_admin_usage_dashboard.sql",
);

Deno.test("creates an explicit administrator allowlist", () => {
  assertStringIncludes(SQL, "CREATE TABLE IF NOT EXISTS public.admin_members");
  assertStringIncludes(SQL, "ON DELETE CASCADE");
});

Deno.test("creates provider attempts and daily vendor cost snapshots", () => {
  assertStringIncludes(SQL, "public.generation_usage_attempts");
  assertStringIncludes(SQL, "public.generation_business_events");
  assertStringIncludes(SQL, "public.provider_cost_snapshots");
  assertStringIncludes(SQL, "provider_request_id VARCHAR(200)");
});

Deno.test("keeps analytics and billing tables away from browser roles", () => {
  assertStringIncludes(SQL, "ENABLE ROW LEVEL SECURITY");
  assertStringIncludes(
    SQL,
    "REVOKE ALL ON TABLE public.generation_usage_attempts FROM anon, authenticated",
  );
  assertStringIncludes(
    SQL,
    "REVOKE ALL ON TABLE public.provider_cost_snapshots FROM anon, authenticated",
  );
  assertStringIncludes(
    SQL,
    "REVOKE ALL ON TABLE public.admin_members FROM anon, authenticated",
  );
});

Deno.test("exposes service-role-only dashboard and detail functions", () => {
  assertStringIncludes(SQL, "admin_dashboard_summary");
  assertStringIncludes(SQL, "admin_generation_attempts");
  assertStringIncludes(SQL, "is_admin_member");
  assertStringIncludes(
    SQL,
    "GRANT EXECUTE ON FUNCTION public.admin_dashboard_summary",
  );
});

Deno.test("deduplicates heartbeat duration by user and aligned time slot", () => {
  assertStringIncludes(
    SQL,
    "COUNT(DISTINCT (user_id, (metadata ->> 'slot_start')::numeric))",
  );
});
