import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const migration = readFileSync(
  new URL(
    "../migrations/013_platform_budget_auto_provision.sql",
    import.meta.url,
  ),
  "utf8",
);

function functionBody(name) {
  const start = migration.indexOf(`CREATE OR REPLACE FUNCTION public.${name}(`);
  assert.notStrictEqual(start, -1, `missing function ${name}`);
  const bodyStart = migration.indexOf("AS $$", start);
  const end = migration.indexOf("$$;", bodyStart);
  assert.ok(bodyStart > start && end > bodyStart, `invalid body for ${name}`);
  return migration.slice(start, end + 3);
}

test("platform settings provide a nonnegative 5 USD daily budget default", () => {
  assert.match(
    migration,
    /ADD COLUMN IF NOT EXISTS default_daily_budget_nano_usd/,
  );
  assert.match(
    migration,
    /default_daily_budget_nano_usd\s+BIGINT NOT NULL\s+DEFAULT 5000000000/,
  );
  assert.match(migration, /CHECK\s*\(default_daily_budget_nano_usd\s*>=\s*0\)/);
});

test("daily budget helper serializes first creation and fails closed without settings", () => {
  const body = functionBody("ensure_platform_daily_budget");
  assert.match(
    body,
    /pg_advisory_xact_lock\(\s*hashtextextended\(p_period_key, 0\)/,
  );
  assert.match(
    body,
    /SELECT default_daily_budget_nano_usd[\s\S]*?FROM public\.platform_settings[\s\S]*?id = 'global'/,
  );
  assert.match(body, /INSERT INTO public\.platform_budget_ledgers/);
  assert.match(body, /ON CONFLICT \(period_key\) DO NOTHING/);
  assert.match(body, /service_budget_protected[\s\S]*?P0009/);
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\.ensure_platform_daily_budget\(TEXT\)[\s\S]*?FROM PUBLIC, anon, authenticated, service_role/,
  );
});

test("member and anonymous reservations share automatic provisioning and retain budget caps", () => {
  for (
    const name of [
      "reserve_generation_allowance",
      "reserve_platform_generation_allowance",
    ]
  ) {
    const body = functionBody(name);
    assert.match(body, /ensure_platform_daily_budget\(v_budget_period_key\)/);
    assert.match(
      body,
      /committed_nano_usd\s*\+\s*v_budget\.reserved_nano_usd\s*\+\s*p_nano_usd\s*>\s*v_budget\.budget_nano_usd/,
    );
    assert.match(body, /UPDATE public\.platform_budget_ledgers/);
    assert.match(
      body,
      /reserved_nano_usd\s*=\s*reserved_nano_usd\s*\+\s*p_nano_usd/,
    );
  }
});
