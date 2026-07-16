begin;

create extension if not exists pgtap with schema extensions;

select plan(15);

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
  (select count(*)::integer from public.generation_requests),
  3,
  'rejected requests do not create ledger rows'
);

select is(
  (select count(*)::integer from public.usage_records),
  3,
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
