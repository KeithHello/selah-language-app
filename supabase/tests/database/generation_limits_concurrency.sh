#!/usr/bin/env bash
set -euo pipefail

db_url="postgresql://postgres:postgres@127.0.0.1:54322/postgres"
output_dir="${RUNNER_TEMP:-/tmp}/selah-generation-claims"
mkdir -p "$output_dir"

psql "$db_url" -v ON_ERROR_STOP=1 <<'SQL'
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values
(
  '10000000-0000-4000-8000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'budget-concurrency-a@example.com',
  '',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
),
(
  '10000000-0000-4000-8000-000000000004',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'budget-concurrency-b@example.com',
  '',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
)
on conflict (id) do nothing;

insert into public.user_memberships (
  id, user_id, plan, status, source, started_at, expires_at
) values
(
  '10000000-0000-4000-8000-000000000303',
  '10000000-0000-4000-8000-000000000003',
  'monthly', 'active', 'paid', now() - interval '1 day', now() + interval '30 days'
),
(
  '10000000-0000-4000-8000-000000000304',
  '10000000-0000-4000-8000-000000000004',
  'monthly', 'active', 'paid', now() - interval '1 day', now() + interval '30 days'
)
on conflict (id) do nothing;

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values (
  '10000000-0000-4000-8000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'concurrency-test@example.com',
  '',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
) on conflict (id) do nothing;
SQL

period_key="platform:day:$(date -u +%F)"
test "$(psql "$db_url" -Atc "select count(*) from public.platform_budget_ledgers where period_key = '$period_key';")" -eq 0

psql "$db_url" -v ON_ERROR_STOP=1 -Atc "
  select public.reserve_generation_allowance(
    '10000000-0000-4000-8000-000000000003',
    '30000000-0000-4000-8000-000000000101',
    'tts', 1, 100, 'budget-concurrency-a'
  )->>'reservationId';
" > "$output_dir/budget-a.txt" &
psql "$db_url" -v ON_ERROR_STOP=1 -Atc "
  select public.reserve_generation_allowance(
    '10000000-0000-4000-8000-000000000004',
    '30000000-0000-4000-8000-000000000102',
    'tts', 1, 100, 'budget-concurrency-b'
  )->>'reservationId';
" > "$output_dir/budget-b.txt" &
wait

test -s "$output_dir/budget-a.txt"
test -s "$output_dir/budget-b.txt"
test "$(psql "$db_url" -Atc "select count(*) from public.platform_budget_ledgers where period_key = '$period_key';")" -eq 1
test "$(psql "$db_url" -Atc "select reserved_nano_usd from public.platform_budget_ledgers where period_key = '$period_key';")" -eq 200
test "$(psql "$db_url" -Atc "select count(*) from public.membership_reservations where client_request_id in ('30000000-0000-4000-8000-000000000101', '30000000-0000-4000-8000-000000000102');")" -eq 2

echo "Concurrent first-day reservations: 2 reservations, 1 daily ledger row, 200 nano-USD reserved"

for index in $(seq 1 8); do
  request_id=$(printf '30000000-0000-4000-8000-%012d' "$index")
  psql "$db_url" -v ON_ERROR_STOP=1 -Atc "
    select public.claim_generation_request(
      '10000000-0000-4000-8000-000000000002',
      'sentence_generation',
      '${request_id}',
      1,
      100
    )->>'decision';
  " > "$output_dir/claim-${index}.txt" &
done
wait

claimed=$(grep -hxc 'claimed' "$output_dir"/*.txt | awk '{ total += $1 } END { print total + 0 }')
limited=$(grep -hxc 'rate_limited' "$output_dir"/*.txt | awk '{ total += $1 } END { print total + 0 }')

test "$claimed" -eq 1
test "$limited" -eq 7
test "$(psql "$db_url" -Atc "
  select count(*)
  from public.usage_records
  where user_id = '10000000-0000-4000-8000-000000000002';
")" -eq 1

echo "Concurrent claims: 1 claimed, 7 rate-limited, 1 usage row"
