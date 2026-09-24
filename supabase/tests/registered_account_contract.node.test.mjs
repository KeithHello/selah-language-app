import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

const root = new URL("../", import.meta.url);
const migration = await readFile(
  new URL("migrations/009_registered_accounts_pro_and_rate_limits.sql", root),
  "utf8",
);
const config = await readFile(new URL("config.toml", root), "utf8");
const batch = await readFile(
  new URL("functions/sentences-batch-generate/index.ts", root),
  "utf8",
);
const prepare = await readFile(
  new URL("functions/sentences-prepare/index.ts", root),
  "utf8",
);
const speech = await readFile(
  new URL("functions/speech-transcribe/index.ts", root),
  "utf8",
);
const adminActions = await readFile(
  new URL("functions/admin-membership-actions/index.ts", root),
  "utf8",
);
const adminUserDetail = await readFile(
  new URL("../SelahFlutter/lib/web/ui/admin_user_detail.dart", root),
  "utf8",
);
const cors = await readFile(
  new URL("functions/_shared/cors.ts", root),
  "utf8",
);

test("local Supabase Auth no longer creates anonymous users", () => {
  assert.match(config, /enable_anonymous_sign_ins\s*=\s*false/);
});

test("registered account migration rejects old anonymous RLS identities and supports Pro", () => {
  const identityFunction = migration.match(
    /CREATE OR REPLACE FUNCTION public\.request_has_registered_identity\(\)[\s\S]*?AS \$\$([\s\S]*?)\$\$;/,
  );
  assert.ok(identityFunction);
  assert.match(identityFunction[1], /auth\.uid\(\)\s+IS NOT NULL/);
  assert.match(identityFunction[1], /is_anonymous/);
  assert.match(migration, /'pro'/);
  assert.match(migration, /90000/);
  assert.match(migration, /10800000/);
  assert.match(migration, /admin_grant_membership_plan/);
  assert.match(migration, /pg_advisory_xact_lock/);
  assert.match(migration, /admin_audit_logs/);
});

test("speech and text preparation have independent rate limit operation types", () => {
  assert.match(speech, /OPERATION_TYPE\s*=\s*"speech_transcription"/);
  assert.match(prepare, /p_operation_type:\s*"text_preparation"/);
  assert.match(speech, /p_operation_type:\s*OPERATION_TYPE/);
});

test("batch request rate is claimed once while sentence claims retain item IDs", () => {
  assert.match(batch, /p_operation_type:\s*"batch_generation"/);
  assert.match(batch, /p_operation_type:\s*"sentence_generation"/);
  assert.match(batch, /ITEM_CLAIM_MINUTE_LIMIT/);
  assert.match(batch, /retryAfterSeconds/);
  assert.equal(
    (batch.match(/rpc\(\s*"claim_generation_request"/g) ?? []).length,
    2,
  );
  assert.match(batch, /p_operation_type:\s*"batch_generation"/);
});

test("administrators can grant Pro through an audited plan-aware RPC", () => {
  assert.match(adminActions, /admin_grant_membership_plan/);
  assert.match(adminActions, /p_plan:\s*plan/);
  assert.match(adminActions, /invalid_plan/);
  assert.match(
    adminUserDetail,
    /DropdownMenuItem\(value: 'pro', child: Text\('Pro'\)\)/,
  );
  assert.match(adminUserDetail, /'plan': _selectedPlan/);
});

test("429 responses preserve the retry delay for the client", () => {
  assert.match(cors, /headers\["Retry-After"\]/);
  assert.match(cors, /retryAfterSeconds/);
});
