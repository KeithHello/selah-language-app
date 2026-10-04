import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL(
    "../migrations/014_platform_budget_enforcement_and_admin_summary.sql",
    import.meta.url,
  ),
  "utf8",
);

test("public-mode reservations enforce and settle against the daily ledger", () => {
  assert.match(
    migration,
    /CREATE OR REPLACE FUNCTION public\.record_generation_usage/,
  );
  assert.match(
    migration,
    /public\.ensure_platform_daily_budget\(v_budget_period_key\)/,
  );
  assert.match(migration, /platform_daily_budget_exhausted/);
  assert.match(
    migration,
    /reserved_nano_usd = reserved_nano_usd \+ v_nano_usd/,
  );
  assert.match(
    migration,
    /budget_period_key\s*\n\s*\) VALUES/,
  );
});

test("budget denials are internally distinct from configuration failures", () => {
  assert.match(migration, /platform_daily_budget_unavailable/);
  assert.match(migration, /platform_daily_budget_exhausted/);
  assert.match(migration, /public\.reserve_generation_allowance\(/);
  assert.match(migration, /public\.reserve_platform_generation_allowance\(/);
});

test("the daily platform snapshot is restricted to administrator service calls", () => {
  assert.match(migration, /public\.is_admin_member\(p_admin_user_id\)/);
  assert.match(migration, /'remainingNanoUsd'/);
  assert.match(migration, /'overrunNanoUsd'/);
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\.admin_platform_budget_summary\(UUID\)/,
  );
  assert.match(
    migration,
    /GRANT EXECUTE ON FUNCTION public\.admin_platform_budget_summary\(UUID\)/,
  );
  assert.match(migration, /TO service_role/);
});
