-- =====================================================================
-- CRASHX DEMO — pgTAP tests for RLS + RPC access control
--
-- Run with the Supabase CLI (requires local Postgres, e.g. via
-- `supabase start`, which uses Docker for LOCAL DEV/TEST only — see
-- README "no Docker in v1" note, which is about the *production*
-- architecture, not the test toolchain):
--
--   supabase test db
--
-- Or directly against any Postgres that has this schema applied and
-- the pgtap extension available:
--
--   psql "$DATABASE_URL" -f supabase/tests/database/access_control.test.sql
--
-- This file is self-contained: it creates its own fixture users/rounds
-- and rolls everything back at the end, so it never pollutes real data.
-- =====================================================================

begin;

create extension if not exists pgtap;

select plan(18);

-- ---------------------------------------------------------------------
-- Test helpers: impersonate a given auth user, the way PostgREST does
-- via the JWT's `sub` claim, so RLS policies (which key off auth.uid())
-- are actually exercised instead of bypassed by table ownership.
-- ---------------------------------------------------------------------

create or replace function tests_authenticate_as(p_user_id uuid) returns void as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, true);
  perform set_config('role', 'authenticated', true);
  set local role authenticated;
end;
$$ language plpgsql;

create or replace function tests_clear_authentication() returns void as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  reset role;
end;
$$ language plpgsql;

-- ---------------------------------------------------------------------
-- Fixtures. Inserting into auth.users fires handle_new_player(), which
-- auto-creates a profiles + wallets (25000.00 starting balance) row for
-- each — including the admin fixtures, which is harmless (see the note
-- in seed.sql about the same behavior for the two real SUPER_ADMINs).
-- ---------------------------------------------------------------------

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'super1@test.local'),
  ('99999999-9999-9999-9999-999999999999', 'super2@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'sub1@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'sub2-no-grants@test.local'),
  ('44444444-4444-4444-4444-444444444444', 'player1@test.local'),
  ('55555555-5555-5555-5555-555555555555', 'player2@test.local');

insert into admin_users (id, role, display_name, created_by) values
  ('11111111-1111-1111-1111-111111111111', 'SUPER_ADMIN', 'Super 1', null),
  ('99999999-9999-9999-9999-999999999999', 'SUPER_ADMIN', 'Super 2', null),
  ('22222222-2222-2222-2222-222222222222', 'SOUS_ADMIN', 'Sub 1', '11111111-1111-1111-1111-111111111111'),
  ('33333333-3333-3333-3333-333333333333', 'SOUS_ADMIN', 'Sub 2 (no grants)', '11111111-1111-1111-1111-111111111111');

insert into admin_permissions (admin_id, permission, granted_by) values
  ('22222222-2222-2222-2222-222222222222', 'CONTROL_GAME', '11111111-1111-1111-1111-111111111111');

insert into game_rounds (id, status, demo_mode, target_multiplier) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'BETTING', 'AUTOMATIC', 3.00),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'WAITING', 'AUTOMATIC', 3.00);

-- ---------------------------------------------------------------------
-- RLS: players cannot see each other's private data
-- ---------------------------------------------------------------------

select tests_authenticate_as('44444444-4444-4444-4444-444444444444'); -- player1

select is(
  (select count(*)::int from wallets where user_id = '55555555-5555-5555-5555-555555555555'),
  0,
  'player1 cannot see player2''s wallet via RLS'
);

select is(
  (select count(*)::int from wallets where user_id = '44444444-4444-4444-4444-444444444444'),
  1,
  'player1 can see their own wallet'
);

-- ---------------------------------------------------------------------
-- A player cannot mutate their own profiles.status directly (spec §12:
-- a blocked user must not be able to self-unblock).
-- ---------------------------------------------------------------------

update profiles set status = 'BLOCKED' where id = '44444444-4444-4444-4444-444444444444';

select tests_clear_authentication();

select is(
  (select status::text from profiles where id = '44444444-4444-4444-4444-444444444444'),
  'ACTIVE',
  'a player cannot change their own profiles.status via direct UPDATE (no RLS UPDATE policy exists)'
);

-- ---------------------------------------------------------------------
-- A SOUS_ADMIN can never create or elevate an admin account, even by
-- calling the table directly instead of going through the dashboard
-- (spec §12: hiding the button is never enough).
-- ---------------------------------------------------------------------

select tests_authenticate_as('22222222-2222-2222-2222-222222222222'); -- sub1

select throws_like(
  $$insert into admin_users (id, role, created_by) values ('55555555-5555-5555-5555-555555555555','SOUS_ADMIN','22222222-2222-2222-2222-222222222222')$$,
  '%row-level security%',
  'a sub-admin cannot insert a new admin_users row'
);

select throws_like(
  $$insert into admin_permissions (admin_id, permission, granted_by) values ('22222222-2222-2222-2222-222222222222','MANAGE_USERS','22222222-2222-2222-2222-222222222222')$$,
  '%row-level security%',
  'a sub-admin cannot self-grant a permission'
);

select tests_clear_authentication();

-- Independent of RLS: the trigger-level cap must hold even for a
-- superuser/service-role caller.
select throws_like(
  $$insert into admin_users (id, role, created_by) values ('55555555-5555-5555-5555-555555555555','SUPER_ADMIN', null)$$,
  '%ACCESS DENIED%',
  'a third SUPER_ADMIN can never be created, even bypassing RLS'
);

-- ---------------------------------------------------------------------
-- place_bet: server-side validation
-- ---------------------------------------------------------------------

select tests_authenticate_as('44444444-4444-4444-4444-444444444444'); -- player1, balance 25000.00

select throws_like(
  $$select place_bet('aaaaaaaa-0000-0000-0000-000000000002'::uuid, 1::smallint, 1000::numeric, null::numeric)$$,
  '%ROUND_NOT_OPEN%',
  'place_bet rejects a round that is not in BETTING'
);

select throws_like(
  $$select place_bet('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 1::smallint, 30000::numeric, null::numeric)$$,
  '%INSUFFICIENT_FUNDS%',
  'place_bet rejects a bet exceeding the wallet balance'
);

select lives_ok(
  $$select place_bet('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 1::smallint, 1000::numeric, null::numeric)$$,
  'place_bet succeeds with a valid amount on an open round'
);

select is(
  (select balance from wallets where user_id = '44444444-4444-4444-4444-444444444444'),
  24000.00,
  'the wallet balance is decreased by exactly the bet amount'
);

select (place_bet('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 2::smallint, 1000::numeric, null::numeric)).id as bet_id \gset

-- ---------------------------------------------------------------------
-- cashout_bet: ownership + round-state validation
-- ---------------------------------------------------------------------

select tests_authenticate_as('55555555-5555-5555-5555-555555555555'); -- player2

select throws_like(
  'select cashout_bet(' || :'bet_id' || '::uuid)',
  '%ACCESS DENIED%',
  'player2 cannot cash out player1''s bet'
);

select tests_clear_authentication();

update game_rounds
  set status = 'RUNNING', running_started_at = now() - interval '1 second'
  where id = 'aaaaaaaa-0000-0000-0000-000000000001';

select tests_authenticate_as('44444444-4444-4444-4444-444444444444'); -- player1

select lives_ok(
  'select cashout_bet(' || :'bet_id' || '::uuid)',
  'player1 can cash out their own active bet while the round is running'
);

select throws_like(
  'select cashout_bet(' || :'bet_id' || '::uuid)',
  '%BET_NOT_ACTIVE%',
  'the same bet cannot be cashed out twice'
);

-- ---------------------------------------------------------------------
-- Admin RPCs re-check permissions in code, not just via RLS
-- ---------------------------------------------------------------------

select tests_authenticate_as('33333333-3333-3333-3333-333333333333'); -- sub2, no grants

select throws_like(
  $$select admin_force_crash()$$,
  '%ACCESS DENIED%',
  'a sub-admin without CONTROL_GAME cannot force-crash a round'
);

select tests_clear_authentication();

-- ---------------------------------------------------------------------
-- check_activation(): device quota + version gate + account status
-- ---------------------------------------------------------------------

select tests_authenticate_as('44444444-4444-4444-4444-444444444444'); -- player1

select ok(
  (select allowed from check_activation('device-A', 'Test Phone', 'android', '1.0.0')),
  'first device activation succeeds'
);

select is(
  (select reason from check_activation('device-B', 'Other Phone', 'android', '1.0.0')),
  'DEVICE_LIMIT_REACHED',
  'a second device is rejected once the default device quota (1) is reached'
);

select is(
  (select reason from check_activation('device-C', 'Old Phone', 'android', '0.9.0')),
  'UPDATE_REQUIRED',
  'an app version below minimum_supported_version is rejected'
);

select tests_clear_authentication();
update profiles set status = 'BLOCKED' where id = '44444444-4444-4444-4444-444444444444';
select tests_authenticate_as('44444444-4444-4444-4444-444444444444');

select is(
  (select reason from check_activation('device-D', 'Phone', 'android', '1.0.0')),
  'ACCOUNT_BLOCKED',
  'a blocked account is denied activation'
);

select tests_clear_authentication();

select * from finish();

rollback;
