-- =====================================================================
-- CRASHX DEMO — 0003_rls_policies.sql
-- Row Level Security. Default-deny: RLS is enabled on every table and
-- only the policies below open specific, narrow access. Every balance /
-- bet / round / permission mutation that is NOT covered by a policy
-- here can only happen through the SECURITY DEFINER RPC functions in
-- 0004/0005, which re-check permissions in code. The Flutter and React
-- clients never use the service_role key, so this file is the real
-- boundary of trust.
-- =====================================================================

alter table profiles enable row level security;
alter table admin_users enable row level security;
alter table admin_permissions enable row level security;
alter table wallets enable row level security;
alter table game_rounds enable row level security;
alter table bets enable row level security;
alter table transactions enable row level security;
alter table invitations enable row level security;
alter table authorized_devices enable row level security;
alter table admin_logs enable row level security;
alter table game_settings enable row level security;
alter table app_settings enable row level security;

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------

create policy profiles_select_own on profiles
  for select using (id = auth.uid());

create policy profiles_select_admin on profiles
  for select using (has_permission(auth.uid(), 'VIEW_USERS'));

-- No UPDATE policy at all: row-level RLS cannot restrict which
-- *columns* a client changes, and this row includes the security-
-- relevant `status` field. A user updating "just their display name"
-- through a raw .update() call would also be able to set status back
-- to ACTIVE. Every mutation therefore goes through a SECURITY DEFINER
-- RPC instead: update_display_name() for the owner, admin_block_user()
-- / admin_unblock_user() for admins (see 0005_admin_functions.sql).
-- No client-side INSERT/DELETE either: rows are created by handle_new_player().

-- ---------------------------------------------------------------------
-- admin_users
-- ---------------------------------------------------------------------

create policy admin_users_select_self on admin_users
  for select using (id = auth.uid());

create policy admin_users_select_super on admin_users
  for select using (is_super_admin(auth.uid()));

-- A SUPER_ADMIN may create SOUS_ADMIN accounts only. Role is fixed to
-- SOUS_ADMIN in the WITH CHECK clause so this policy can never be used
-- to insert a SUPER_ADMIN row, no matter what the client sends.
create policy admin_users_insert_sub_by_super on admin_users
  for insert
  with check (
    is_super_admin(auth.uid())
    and role = 'SOUS_ADMIN'
    and created_by = auth.uid()
  );

-- No raw UPDATE policy: admin_deactivate_sub() / admin_reactivate_sub()
-- / admin_update_sub() (0005) are the only ways to change a sub-account,
-- each hard-restricted to role = 'SOUS_ADMIN' targets and each logged.

create policy admin_users_delete_sub_by_super on admin_users
  for delete using (is_super_admin(auth.uid()) and role = 'SOUS_ADMIN');

-- ---------------------------------------------------------------------
-- admin_permissions
-- ---------------------------------------------------------------------

create policy admin_permissions_select_self on admin_permissions
  for select using (admin_id = auth.uid());

create policy admin_permissions_select_super on admin_permissions
  for select using (is_super_admin(auth.uid()));

-- No raw INSERT/DELETE policy: set_sub_admin_permissions() (0005) is
-- the only way to change a sub-admin's permissions. It replaces the
-- full set atomically and logs the before/after, which piecemeal
-- direct .insert()/.delete() calls could not guarantee.

-- ---------------------------------------------------------------------
-- wallets — read-only to clients; every write goes through RPCs.
-- ---------------------------------------------------------------------

create policy wallets_select_own on wallets
  for select using (user_id = auth.uid());

create policy wallets_select_admin on wallets
  for select using (has_permission(auth.uid(), 'VIEW_USERS') or has_permission(auth.uid(), 'VIEW_STATISTICS'));

-- ---------------------------------------------------------------------
-- game_rounds — raw table (with target/crash multiplier) is admin-only.
-- Players read through the game_rounds_public view created below.
-- ---------------------------------------------------------------------

create policy game_rounds_select_admin on game_rounds
  for select using (has_permission(auth.uid(), 'VIEW_GAME'));

-- ---------------------------------------------------------------------
-- bets
-- ---------------------------------------------------------------------

create policy bets_select_own on bets
  for select using (user_id = auth.uid());

create policy bets_select_admin on bets
  for select using (has_permission(auth.uid(), 'VIEW_BETS'));

-- ---------------------------------------------------------------------
-- transactions
-- ---------------------------------------------------------------------

create policy transactions_select_own on transactions
  for select using (user_id = auth.uid());

create policy transactions_select_admin on transactions
  for select using (has_permission(auth.uid(), 'VIEW_USERS') or has_permission(auth.uid(), 'VIEW_STATISTICS'));

-- ---------------------------------------------------------------------
-- invitations
-- ---------------------------------------------------------------------

create policy invitations_select_admin on invitations
  for select using (has_permission(auth.uid(), 'VIEW_USERS') or has_permission(auth.uid(), 'CREATE_INVITATIONS') or has_permission(auth.uid(), 'MANAGE_INVITATIONS'));

-- No raw INSERT policy either: create_invitation() (0005) is the only
-- way to create one, so the token is always cryptographically random
-- (never client-supplied) and every creation hits admin_logs.

-- No raw UPDATE policy: revoke_invitation() (0005) is the only way to
-- change an invitation's status, so a MANAGE_INVITATIONS admin cannot
-- silently rewrite token/expires_at/max_devices through a direct
-- .update() call, and every revoke is guaranteed to hit admin_logs.

-- No public/anon table access: the invite landing page reads through
-- the get-invitation Edge Function (service role), never straight RLS,
-- so the page can never enumerate tokens or scrape invitee lists.

-- ---------------------------------------------------------------------
-- authorized_devices
-- ---------------------------------------------------------------------

create policy authorized_devices_select_own on authorized_devices
  for select using (user_id = auth.uid());

create policy authorized_devices_select_admin on authorized_devices
  for select using (has_permission(auth.uid(), 'MANAGE_DEVICES') or has_permission(auth.uid(), 'VIEW_USERS'));

-- No raw INSERT policy: check_activation() (0005) is the only way a
-- device gets registered, so account-status/version/quota checks
-- always run first — a client can't self-register a device directly
-- and skip those gates. enforce_device_quota() below still applies as
-- a second layer inside that function.

-- No raw UPDATE policy: admin_set_device_status() (0005) is the only
-- way to authorize/block/revoke a device, guaranteeing an admin_logs
-- entry for every change instead of a silent direct .update().

-- ---------------------------------------------------------------------
-- admin_logs — write-only through log_admin_action(), never by clients.
-- ---------------------------------------------------------------------

create policy admin_logs_select_by_permission on admin_logs
  for select using (has_permission(auth.uid(), 'VIEW_LOGS'));

-- ---------------------------------------------------------------------
-- game_settings — contains next_manual_target_multiplier, which must
-- never reach a player client (it would reveal the crash point).
-- ---------------------------------------------------------------------

create policy game_settings_select_by_permission on game_settings
  for select using (has_permission(auth.uid(), 'VIEW_SETTINGS') or has_permission(auth.uid(), 'CONTROL_GAME') or has_permission(auth.uid(), 'CONTROL_DEMO_MULTIPLIER'));

-- ---------------------------------------------------------------------
-- app_settings — version gate must be readable before login, so anon
-- and authenticated can both read it. Only SUPER_ADMIN can change it.
-- ---------------------------------------------------------------------

create policy app_settings_select_all on app_settings
  for select using (true);

-- No raw UPDATE policy: update_app_settings() (0005) is the only way
-- to change version/maintenance settings, so every change is logged.

-- ---------------------------------------------------------------------
-- Device quota enforcement (max_devices from the originating invitation)
-- ---------------------------------------------------------------------

create or replace function enforce_device_quota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max_devices int;
  v_active_count int;
begin
  select coalesce(i.max_devices, 1) into v_max_devices
  from profiles p
  left join invitations i on i.id = p.invitation_id
  where p.id = new.user_id;

  select count(*) into v_active_count
  from authorized_devices
  where user_id = new.user_id and status = 'ACTIVE';

  if v_active_count >= coalesce(v_max_devices, 1) then
    raise exception 'ACCESS DENIED: device limit reached for this account';
  end if;

  return new;
end;
$$;

create trigger trg_enforce_device_quota
  before insert on authorized_devices
  for each row execute function enforce_device_quota();

-- ---------------------------------------------------------------------
-- Public view of game_rounds: hides target_multiplier always, and
-- hides crash_multiplier until the round has actually crashed.
-- ---------------------------------------------------------------------

-- Intentionally NOT security_invoker: this view is the safe, pre-filtered
-- public projection of game_rounds (crash_multiplier hidden pre-crash,
-- target_multiplier never exposed at all), so it must run with the view
-- owner's rights to bypass the admin-only RLS on the base table and be
-- readable by every player watching the round live.
create view game_rounds_public as
  select
    id,
    round_number,
    status,
    case when status in ('CRASHED', 'RESULT') then crash_multiplier else null end as crash_multiplier,
    betting_started_at,
    running_started_at,
    crashed_at,
    total_bets_amount,
    total_players,
    created_at
  from game_rounds;

grant select on game_rounds_public to authenticated, anon;
