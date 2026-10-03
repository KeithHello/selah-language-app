import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const SQL = await Deno.readTextFile(
  "supabase/migrations/012_usage_metering.sql",
);
const auditFunctionStart = SQL.indexOf(
  "CREATE OR REPLACE FUNCTION public.record_generation_usage(",
);
const auditFunctionEnd = SQL.indexOf("CREATE INDEX", auditFunctionStart);
const AUDIT_FUNCTION = SQL.slice(auditFunctionStart, auditFunctionEnd);

Deno.test("records audit-only usage without quotas or platform budget", () => {
  assertStringIncludes(SQL, "record_generation_usage");
  assertStringIncludes(SQL, "membership_reservations");
  assertStringIncludes(SQL, "'reserved'");
  assertStringIncludes(SQL, "NULL");
  assertStringIncludes(SQL, "TO service_role");
});

Deno.test("audit-only usage is not attached to the active membership", () => {
  assertEquals(
    AUDIT_FUNCTION.includes("SELECT id INTO v_membership_id"),
    false,
  );
  assertStringIncludes(AUDIT_FUNCTION, "        NULL,");
});

Deno.test("settles audit-only usage without touching platform budget", () => {
  assertStringIncludes(
    SQL,
    "IF v_reservation.budget_period_key IS NULL THEN",
  );
  assertStringIncludes(SQL, "UPDATE public.membership_reservations");
});
