// Static contract checks for the local membership migration draft.
// These checks intentionally avoid a database connection.  The migration is
// not applied to remote environments in this stage.

import {
  assert,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

const SQL = await Deno.readTextFile(
  "supabase/migrations/006_membership_cost_control.sql",
);
const ANON_SQL = await Deno.readTextFile(
  "supabase/migrations/007_anonymous_platform_budget.sql",
);
const ALL_SQL = `${SQL}\n${ANON_SQL}`;

function functionBody(name: string): string {
  const start = SQL.indexOf(`CREATE OR REPLACE FUNCTION public.${name}`);
  assert(start >= 0, `missing function ${name}`);
  const end = SQL.indexOf("$$;", start);
  assert(end > start, `unterminated function ${name}`);
  return SQL.slice(start, end);
}

Deno.test("defines safe platform service controls and operator separation", () => {
  assertStringIncludes(SQL, "CREATE TABLE IF NOT EXISTS public.platform_settings");
  assertStringIncludes(SQL, "membership_enforcement_enabled BOOLEAN NOT NULL DEFAULT false");
  assertStringIncludes(SQL, "trial_signups_enabled BOOLEAN NOT NULL DEFAULT false");
  assertStringIncludes(SQL, "membership_sales_enabled BOOLEAN NOT NULL DEFAULT false");
  assertStringIncludes(SQL, "generation_enabled BOOLEAN NOT NULL DEFAULT true");
  assertStringIncludes(SQL, "CREATE TABLE IF NOT EXISTS public.admin_operators");
  assertStringIncludes(SQL, "CREATE OR REPLACE FUNCTION public.is_admin_operator");
  assertStringIncludes(SQL, "admin_operators");
});

Deno.test("service-control RPCs are versioned, locked, and auditable", () => {
  const readBody = functionBody("get_platform_service_controls");
  const writeBody = functionBody("set_platform_service_controls");
  assertStringIncludes(readBody, "FROM public.platform_settings");
  assertStringIncludes(writeBody, "FOR UPDATE");
  assertStringIncludes(writeBody, "is_admin_operator");
  assertStringIncludes(writeBody, "p_expected_version");
  assertStringIncludes(writeBody, "controls_version_conflict");
  assertStringIncludes(writeBody, "service_control");
  assertStringIncludes(SQL, "GRANT EXECUTE ON FUNCTION public.get_platform_service_controls()");
  assertStringIncludes(SQL, "GRANT EXECUTE ON FUNCTION public.set_platform_service_controls");
});

Deno.test("trial activation requires a persisted successful personal result", () => {
  const body = functionBody("activate_trial_with_result");
  assertStringIncludes(body, "generation_requests");
  assertStringIncludes(body, "sentence_generation");
  assertStringIncludes(body, "succeeded");
  assertStringIncludes(body, "membership_enforcement_enabled");
  assertStringIncludes(body, "membership_mode_disabled");
  assertStringIncludes(body, "168 hours");
  assertStringIncludes(body, "FOR UPDATE");
  assertStringIncludes(body, "system_trial");
  assertStringIncludes(SQL, "GRANT EXECUTE ON FUNCTION public.activate_trial_with_result");
});

Deno.test("admin membership actions are idempotent and audited in one RPC", () => {
  assertStringIncludes(SQL, "CREATE TABLE IF NOT EXISTS public.admin_membership_action_requests");
  const body = functionBody("admin_apply_membership_action");
  for (const action of [
    "grant_membership",
    "compensate_membership",
    "revoke_grant",
    "replay_order",
    "record_manual_payment",
  ]) {
    assertStringIncludes(body, action);
  }
  assertStringIncludes(body, "admin_membership_action_requests");
  assertStringIncludes(body, "admin_audit_logs");
  assertStringIncludes(body, "FOR UPDATE");
  assertStringIncludes(body, "3990");
  assertStringIncludes(body, "status IN ('reserved', 'dispatch_claimed', 'settled', 'unknown')");
  assertStringIncludes(body, "v_base_start");
  assertStringIncludes(body, "add_calendar_months_utc(v_base_start, v_i)");
  assertStringIncludes(body, "missing_transaction_id");
  assertStringIncludes(body, "NULLIF(btrim(COALESCE(p_transaction_id, v_order.channel_transaction_id)), '')");
  assertStringIncludes(SQL, "GRANT EXECUTE ON FUNCTION public.admin_apply_membership_action");
});

Deno.test("sensitive membership tables are not writable by browser roles", () => {
  for (const table of [
    "platform_settings",
    "admin_operators",
    "admin_membership_action_requests",
    "user_memberships",
    "membership_orders",
    "membership_reservations",
    "platform_budget_ledgers",
    "admin_audit_logs",
  ]) {
    assertStringIncludes(SQL, `ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY`);
    assertStringIncludes(
      SQL,
      `REVOKE ALL ON TABLE public.${table} FROM anon, authenticated`,
    );
  }
});

Deno.test("generation reservation and settlement paths serialize and validate inputs", () => {
  const reserveBody = functionBody("reserve_generation_allowance");
  const settleBody = functionBody("settle_generation_allowance");
  assertStringIncludes(reserveBody, "pg_advisory_xact_lock");
  assertStringIncludes(reserveBody, "platform_budget_ledgers");
  assertStringIncludes(reserveBody, "reserved_nano_usd");
  assertStringIncludes(reserveBody, "budget_period_key");
  assertStringIncludes(reserveBody, "p_payload_hash");
  assertStringIncludes(reserveBody, "request_conflict");
  assertStringIncludes(settleBody, "dispatch_claimed");
  assertStringIncludes(settleBody, "released_unsent");
  assertStringIncludes(settleBody, "unknown");
  assertStringIncludes(settleBody, "reservation_already_final");
  assertStringIncludes(settleBody, "committed_nano_usd");
  assertStringIncludes(settleBody, "FOR UPDATE");
});

Deno.test("membership summary and payment reconciliation are server-owned", () => {
  const summaryBody = functionBody("get_user_membership_summary");
  const paymentBody = functionBody("apply_verified_payment");
  assertStringIncludes(summaryBody, "auth.uid()");
  assertStringIncludes(summaryBody, "v_next_started_at");
  assertStringIncludes(summaryBody, "v_next_source");
  assertStringIncludes(paymentBody, "refunded");
  assertStringIncludes(paymentBody, "channel_transaction_id");
  assertStringIncludes(paymentBody, "p_verified_at IS NULL");
  assertStringIncludes(paymentBody, "pg_advisory_xact_lock");
  assertStringIncludes(paymentBody, "add_calendar_months_utc");
  assertStringIncludes(SQL, "idx_membership_orders_channel_transaction");
  assertStringIncludes(SQL, "REVOKE SELECT ON TABLE public.user_memberships FROM authenticated");
  assertStringIncludes(SQL, "REVOKE SELECT ON TABLE public.membership_orders FROM authenticated");
});

Deno.test("anonymous testing is closed by default but protected by platform budget", () => {
  assertStringIncludes(
    ANON_SQL,
    "ADD COLUMN IF NOT EXISTS anonymous_test_mode_enabled BOOLEAN",
  );
  assertStringIncludes(
    ANON_SQL,
    "ALTER COLUMN anonymous_test_mode_enabled SET DEFAULT false",
  );
  assertStringIncludes(
    ANON_SQL,
    "ALTER COLUMN anonymous_test_mode_enabled SET NOT NULL",
  );
  assertStringIncludes(
    ANON_SQL,
    "CREATE TABLE IF NOT EXISTS public.platform_generation_reservations",
  );
  const reserveStart = ANON_SQL.indexOf(
    "CREATE OR REPLACE FUNCTION public.reserve_platform_generation_allowance",
  );
  const reserveEnd = ANON_SQL.indexOf("$$;", reserveStart);
  const reserveBody = ANON_SQL.slice(reserveStart, reserveEnd);
  assertStringIncludes(reserveBody, "platform_budget_ledgers");
  assertStringIncludes(reserveBody, "rate_limited");
  assertStringIncludes(reserveBody, "service_budget_protected");
  assertStringIncludes(reserveBody, "reserved_nano_usd");
  assertStringIncludes(ANON_SQL, "settle_platform_generation_allowance");
  assertStringIncludes(
    ALL_SQL,
    "REVOKE ALL ON TABLE public.platform_generation_reservations FROM anon, authenticated",
  );
  assertStringIncludes(
    ANON_SQL,
    "REVOKE ALL ON FUNCTION public.reserve_platform_generation_allowance",
  );
  assertStringIncludes(
    ANON_SQL,
    "REVOKE ALL ON FUNCTION public.settle_platform_generation_allowance",
  );
  const writeStart = ANON_SQL.indexOf(
    "CREATE OR REPLACE FUNCTION public.set_platform_service_controls",
  );
  const writeEnd = ANON_SQL.indexOf("$$;", writeStart);
  const writeBody = ANON_SQL.slice(writeStart, writeEnd);
  assert(writeStart >= 0, "missing updated service-control write RPC");
  assertStringIncludes(
    writeBody,
    "p_anonymous_test_mode_enabled BOOLEAN",
  );
  assertStringIncludes(writeBody, "2026-09-17-v1");
  assertStringIncludes(writeBody, "is_admin_operator");
  assertStringIncludes(
    ANON_SQL,
    "REVOKE ALL ON FUNCTION public.set_platform_service_controls",
  );
});
