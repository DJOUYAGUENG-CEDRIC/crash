-- =====================================================================
-- CRASHX DEMO — seed.sql
-- Run this ONCE, manually, from the Supabase SQL Editor (or `supabase
-- db execute`) AFTER the migrations in supabase/migrations/ have been
-- applied. This file is intentionally not part of the automatic
-- migration chain: it performs the one-time SUPER_ADMIN bootstrap,
-- which must never be reachable from the app itself (spec section 9).
-- =====================================================================

-- ---------------------------------------------------------------------
-- STEP 1 — Create the two SUPER_ADMIN auth accounts.
--
-- Do this in the Supabase Dashboard, NOT here:
--   Authentication → Users → Add user → Create new user
--   - Email: (super admin 1 email)
--   - Password: (set a strong password, share it out of band)
--   - Auto Confirm User: ON
-- Repeat for the second SUPER_ADMIN.
--
-- This keeps the two most powerful credentials in the project out of
-- any file, chat log, or repository, satisfying "aucun bouton public
-- Créer un Super Admin" — there simply is no code path that creates
-- one; it is a manual, one-time dashboard action by the project owner.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- STEP 2 — Link those two accounts as SUPER_ADMIN.
-- Replace the two emails below, then run this block once.
-- ---------------------------------------------------------------------

do $$
declare
  v_email_1 text := 'super_admin_1@example.com'; -- TODO replace
  v_email_2 text := 'super_admin_2@example.com'; -- TODO replace
  v_id_1 uuid;
  v_id_2 uuid;
begin
  select id into v_id_1 from auth.users where email = v_email_1;
  select id into v_id_2 from auth.users where email = v_email_2;

  if v_id_1 is null or v_id_2 is null then
    raise exception 'Create both SUPER_ADMIN users in the Dashboard first, then update the emails in this script.';
  end if;

  -- profiles/wallets already exist for these users via the
  -- handle_new_player trigger, that's harmless — they are simply
  -- never surfaced as players in the mobile app's own account flows.
  insert into admin_users (id, role, display_name, created_by)
  values (v_id_1, 'SUPER_ADMIN', 'Super Admin 1', null)
  on conflict (id) do nothing;

  insert into admin_users (id, role, display_name, created_by)
  values (v_id_2, 'SUPER_ADMIN', 'Super Admin 2', null)
  on conflict (id) do nothing;
end $$;

-- ---------------------------------------------------------------------
-- STEP 3 — Schedule the game engine heartbeat.
--
-- Requires the pg_cron extension (Database → Extensions → pg_cron).
-- pg_cron ≥ 1.4 supports sub-minute schedules using a plain "N seconds"
-- string. If your project's pg_cron version rejects this syntax, fall
-- back to calling supabase/functions/game-tick from an external
-- scheduler (e.g. a free cron-ping service) every 10-15 seconds
-- instead — game_tick() is idempotent, it just makes phase transitions
-- less snappy.
--
-- 1 second (not more) matters here specifically for RUNNING rounds:
-- the client animates the multiplier continuously from
-- running_started_at, but the server only actually notices a round has
-- crossed target_multiplier on the next tick — a slower tick means a
-- wider window where the client's live number can visibly overshoot
-- the crash_multiplier that gets revealed a moment later.
-- ---------------------------------------------------------------------

create extension if not exists pg_cron;

select cron.schedule('crashx-game-tick', '1 second', $$select public.game_tick();$$);

-- ---------------------------------------------------------------------
-- Done. Verify with:
--   select * from admin_users;
--   select * from cron.job;
-- ---------------------------------------------------------------------
