begin;

create extension if not exists pgtap with schema extensions;

select plan(27);

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

select * from finish();
rollback;
