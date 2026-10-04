begin;

create extension if not exists pgtap with schema extensions;

select plan(35);

select has_table('public', 'generation_requests', 'request ledger exists');
select has_function(
  'public',
  'claim_generation_request',
  array['uuid', 'text', 'uuid', 'integer', 'integer'],
  'atomic claim function exists'
);
select has_function(
  'public',
  'complete_generation_request',
  array['uuid', 'text', 'uuid', 'jsonb'],
  'completion function exists'
);
select has_function(
  'public',
  'record_generation_usage',
  array['uuid', 'uuid', 'text', 'integer', 'bigint', 'text'],
  'audit-only usage recorder exists'
);
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
  '10000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'quota-test@example.com',
  '',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

insert into public.user_memberships (
  id,
  user_id,
  plan,
  status,
  source,
  started_at,
  expires_at
) values (
  '10000000-0000-4000-8000-000000000300',
  '10000000-0000-4000-8000-000000000001',
  'monthly',
  'active',
  'paid',
  now() - interval '1 day',
  now() + interval '30 days'
);

select is(
  public.record_generation_usage(
    '10000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    'sentence',
    3,
    100,
    'audit-only-test'
  )->>'enforced',
  'false',
  'free-mode generation is recorded without enforcing an allowance'
);

select is(
  (
    select membership_id
      from public.membership_reservations
     where client_request_id = '40000000-0000-4000-8000-000000000001'
  ),
  null::uuid,
  'audit-only usage is not attached to an active membership'
);

select is(
  (
    select coalesce(sum(units_reserved), 0)::integer
      from public.membership_reservations
     where membership_id = '10000000-0000-4000-8000-000000000300'
       and status in ('reserved', 'dispatch_claimed', 'settled', 'unknown')
  ),
  0,
  'usage accumulated while enforcement is off is excluded from member quota'
);

select is(
  (
    select count(*)::integer
      from public.membership_reservations
     where user_id = '10000000-0000-4000-8000-000000000001'
       and client_request_id = '40000000-0000-4000-8000-000000000001'
  ),
  1,
  'audit-only usage remains available in the ledger'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000001',
    2,
    3
  )->>'decision',
  'claimed',
  'first request claims capacity'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000001',
    2,
    3
  )->>'decision',
  'in_progress',
  'same in-flight request does not claim twice'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000002',
    2,
    3
  )->>'decision',
  'claimed',
  'second request uses remaining minute capacity'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000003',
    2,
    3
  )->>'decision',
  'rate_limited',
  'minute limit rejects the next request'
);

select ok(
  public.complete_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000001',
    '{"targetText":"I am tired."}'::jsonb
  ),
  'claimed request can be completed'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000001',
    2,
    3
  )->>'decision',
  'replay',
  'completed request is replayed'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000001',
    2,
    3
  )->'responsePayload'->>'targetText',
  'I am tired.',
  'replay returns the stored response'
);

update public.usage_records
set created_at = now() - interval '2 minutes'
where user_id = '10000000-0000-4000-8000-000000000001';

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000003',
    2,
    3
  )->>'decision',
  'claimed',
  'capacity returns after the minute window'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'sentence_generation',
    '20000000-0000-4000-8000-000000000004',
    2,
    3
  )->>'decision',
  'quota_exceeded',
  'daily limit remains enforced'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'capture_preparation',
    '20000000-0000-4000-8000-000000000010',
    1,
    2
  )->>'decision',
  'claimed',
  'capture preparation uses its own operation quota'
);

select ok(
  public.complete_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'capture_preparation',
    '20000000-0000-4000-8000-000000000010',
    '{"segments":[]}'::jsonb
  ),
  'capture preparation request can be completed'
);

select is(
  public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'capture_preparation',
    '20000000-0000-4000-8000-000000000010',
    1,
    2
  )->>'decision',
  'replay',
  'completed capture preparation request is replayed'
);

select is(
  (select count(*)::integer from public.generation_requests),
  4,
  'rejected requests do not create ledger rows'
);

select is(
  (select count(*)::integer from public.usage_records),
  4,
  'only successful claims consume usage attempts'
);

select throws_ok(
  $$select public.claim_generation_request(
    '10000000-0000-4000-8000-000000000001',
    'unsupported_operation',
    '20000000-0000-4000-8000-000000000099',
    1,
    1
  )$$,
  '22023',
  'Unsupported generation operation',
  'unsupported operations are rejected'
);

update public.platform_settings
   set default_daily_budget_nano_usd = 0
 where id = 'global';

select throws_ok(
  $$select public.reserve_generation_allowance(
    '10000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000020',
    'tts',
    2,
    100,
    'member-zero-budget'
  )$$,
  'P0009',
  'service_budget_protected',
  'zero default budget blocks reservations'
);

select is(
  (
    select count(*)::integer
      from public.platform_budget_ledgers
     where period_key = 'platform:day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD')
  ),
  0,
  'failed zero-budget reservation leaves no partial daily ledger row'
);

update public.platform_settings
   set default_daily_budget_nano_usd = 5000000000
 where id = 'global';

select is(
  public.reserve_generation_allowance(
    '10000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000021',
    'tts',
    2,
    100,
    'member-auto-budget'
  )->>'status',
  'reserved',
  'member reservation provisions the missing daily ledger'
);

select is(
  (
    select budget_nano_usd
      from public.platform_budget_ledgers
     where period_key = 'platform:day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD')
  ),
  5000000000::bigint,
  'new daily ledger uses the configured default budget'
);

select is(
  (
    select reserved_nano_usd
      from public.platform_budget_ledgers
     where period_key = 'platform:day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD')
  ),
  100::bigint,
  'member request is atomically included in the daily reservation total'
);

update public.platform_budget_ledgers
   set committed_nano_usd = budget_nano_usd - reserved_nano_usd
 where period_key = 'platform:day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD');

select throws_ok(
  $$select public.reserve_generation_allowance(
    '10000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000022',
    'tts',
    1,
    1,
    'member-budget-exhausted'
  )$$,
  'P0009',
  'service_budget_protected',
  'member reservation remains blocked when the daily budget is exhausted'
);

select is(
  (
    select count(*)::integer
      from public.membership_reservations
     where client_request_id = '40000000-0000-4000-8000-000000000022'
  ),
  0,
  'budget rejection creates no member reservation'
);

delete from public.membership_reservations
 where client_request_id = '40000000-0000-4000-8000-000000000021';
delete from public.platform_budget_ledgers
 where period_key = 'platform:day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD');

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
  '10000000-0000-4000-8000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'platform-budget-test@example.com',
  '',
  now(),
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
);

select is(
  public.reserve_platform_generation_allowance(
    '10000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000023',
    'tts',
    3,
    200,
    'anonymous-auto-budget'
  )->>'status',
  'reserved',
  'anonymous reservation provisions the missing daily ledger'
);

select is(
  (
    select budget_nano_usd
      from public.platform_budget_ledgers
     where period_key = 'platform:day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD')
  ),
  5000000000::bigint,
  'anonymous reservation uses the same configured default budget'
);

select is(
  (
    select reserved_nano_usd
      from public.platform_budget_ledgers
     where period_key = 'platform:day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD')
  ),
  200::bigint,
  'anonymous request is atomically included in the daily reservation total'
);

update public.platform_budget_ledgers
   set committed_nano_usd = budget_nano_usd - reserved_nano_usd
 where period_key = 'platform:day:' || to_char(now() at time zone 'UTC', 'YYYY-MM-DD');

select throws_ok(
  $$select public.reserve_platform_generation_allowance(
    '10000000-0000-4000-8000-000000000003',
    '40000000-0000-4000-8000-000000000024',
    'tts',
    1,
    1,
    'anonymous-budget-exhausted'
  )$$,
  'P0009',
  'service_budget_protected',
  'anonymous reservation remains blocked when the daily budget is exhausted'
);

select is(
  (
    select count(*)::integer
      from public.platform_generation_reservations
     where client_request_id = '40000000-0000-4000-8000-000000000024'
  ),
  0,
  'budget rejection creates no anonymous reservation'
);

select * from finish();
rollback;
