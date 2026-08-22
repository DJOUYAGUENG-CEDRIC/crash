-- =====================================================================
-- CRASHX DEMO — 0002_functions_and_triggers.sql
-- Helper functions used by RLS policies + housekeeping triggers.
-- All SECURITY DEFINER functions pin search_path to avoid hijacking.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Role / permission helpers (used throughout RLS policies)
-- ---------------------------------------------------------------------

create or replace function is_active_admin(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from admin_users
    where id = p_uid and is_active = true
  );
$$;

create or replace function is_super_admin(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from admin_users
    where id = p_uid and role = 'SUPER_ADMIN' and is_active = true
  );
$$;

create or replace function has_permission(p_uid uuid, p_permission admin_permission)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    is_super_admin(p_uid)
    or exists (
      select 1
      from admin_users au
      join admin_permissions ap on ap.admin_id = au.id
      where au.id = p_uid
        and au.role = 'SOUS_ADMIN'
        and au.is_active = true
        and ap.permission = p_permission
    );
$$;

-- ---------------------------------------------------------------------
-- updated_at housekeeping
-- ---------------------------------------------------------------------

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_profiles_updated_at before update on profiles
  for each row execute function set_updated_at();

create trigger trg_admin_users_updated_at before update on admin_users
  for each row execute function set_updated_at();

create trigger trg_wallets_updated_at before update on wallets
  for each row execute function set_updated_at();

create trigger trg_game_settings_updated_at before update on game_settings
  for each row execute function set_updated_at();

create trigger trg_app_settings_updated_at before update on app_settings
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- New player provisioning
-- Triggered after an Edge Function creates the auth.users row (see
-- functions/activate-invitation). Grants the welcome demo balance.
-- ---------------------------------------------------------------------

create or replace function handle_new_player()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
  v_invitation_id uuid;
  v_starting_balance numeric(14, 2) := 25000.00;
begin
  v_display_name := coalesce(new.raw_user_meta_data ->> 'display_name', 'Joueur');
  v_invitation_id := nullif(new.raw_user_meta_data ->> 'invitation_id', '')::uuid;

  insert into profiles (id, email, display_name, invitation_id)
  values (new.id, new.email, v_display_name, v_invitation_id);

  insert into wallets (user_id, balance)
  values (new.id, v_starting_balance);

  insert into transactions (user_id, type, amount, balance_after, metadata)
  values (
    new.id, 'BONUS_DEMO', v_starting_balance, v_starting_balance,
    jsonb_build_object('reason', 'welcome_bonus')
  );

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_player();
