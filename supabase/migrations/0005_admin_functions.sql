-- =====================================================================
-- CRASHX DEMO — 0005_admin_functions.sql
-- Admin/Super-admin RPC surface + device/version activation gate.
-- Every function re-checks permissions in code (never trusts the UI),
-- so calling these directly over PostgREST gives the exact same
-- guarantees as the dashboard. This is the enforcement layer required
-- by spec section 12: hiding a button is never treated as security.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Internal audit logger. admin_id is always the caller — an admin can
-- never write a log entry under someone else's name.
-- ---------------------------------------------------------------------

create or replace function log_admin_action(
  p_action text,
  p_target_type text default null,
  p_target_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into admin_logs (admin_id, action, target_type, target_id, metadata)
  values (auth.uid(), p_action, p_target_type, p_target_id, p_metadata);
end;
$$;

-- ---------------------------------------------------------------------
-- Sub-admin lifecycle — SUPER_ADMIN only. Note there is deliberately no
-- function here that can create or touch a SUPER_ADMIN row: the two
-- root accounts are bootstrapped once outside the app (see seed.sql).
-- ---------------------------------------------------------------------

create or replace function admin_deactivate_sub(p_admin_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin(auth.uid()) then
    raise exception 'ACCESS DENIED';
  end if;

  update admin_users set is_active = false
  where id = p_admin_id and role = 'SOUS_ADMIN';

  if not found then
    raise exception 'ACCESS DENIED: target is not a sub-account';
  end if;

  perform log_admin_action('DEACTIVATE_SUB_ADMIN', 'admin_users', p_admin_id::text);
end;
$$;

create or replace function admin_reactivate_sub(p_admin_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin(auth.uid()) then
    raise exception 'ACCESS DENIED';
  end if;

  update admin_users set is_active = true
  where id = p_admin_id and role = 'SOUS_ADMIN';

  if not found then
    raise exception 'ACCESS DENIED: target is not a sub-account';
  end if;

  perform log_admin_action('REACTIVATE_SUB_ADMIN', 'admin_users', p_admin_id::text);
end;
$$;

create or replace function admin_update_sub(p_admin_id uuid, p_display_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin(auth.uid()) then
    raise exception 'ACCESS DENIED';
  end if;
  if length(trim(p_display_name)) = 0 or length(p_display_name) > 60 then
    raise exception 'INVALID_DISPLAY_NAME';
  end if;

  update admin_users set display_name = p_display_name
  where id = p_admin_id and role = 'SOUS_ADMIN';

  if not found then
    raise exception 'ACCESS DENIED: target is not a sub-account';
  end if;

  perform log_admin_action('UPDATE_SUB_ADMIN', 'admin_users', p_admin_id::text,
    jsonb_build_object('display_name', p_display_name));
end;
$$;

create or replace function admin_delete_sub(p_admin_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin(auth.uid()) then
    raise exception 'ACCESS DENIED';
  end if;

  delete from admin_users where id = p_admin_id and role = 'SOUS_ADMIN';

  if not found then
    raise exception 'ACCESS DENIED: target is not a sub-account';
  end if;

  perform log_admin_action('DELETE_SUB_ADMIN', 'admin_users', p_admin_id::text);
end;
$$;

-- Replaces the full permission set of a sub-account in one transaction.
-- CREATE_ADMIN / CREATE_SUPER_ADMIN / MODIFY_ADMIN_ROLE are not valid
-- values of admin_permission at all (see the enum in 0001), so there is
-- no permission string a SUPER_ADMIN could grant that would let a
-- sub-admin create or promote another account.
create or replace function set_sub_admin_permissions(p_admin_id uuid, p_permissions admin_permission[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target_role admin_role;
begin
  if not is_super_admin(auth.uid()) then
    raise exception 'ACCESS DENIED';
  end if;

  select role into v_target_role from admin_users where id = p_admin_id;
  if v_target_role is distinct from 'SOUS_ADMIN' then
    raise exception 'ACCESS DENIED: target is not a sub-account';
  end if;

  delete from admin_permissions where admin_id = p_admin_id;

  insert into admin_permissions (admin_id, permission, granted_by)
  select p_admin_id, unnest(p_permissions), auth.uid();

  perform log_admin_action('UPDATE_PERMISSIONS', 'admin_users', p_admin_id::text,
    jsonb_build_object('permissions', to_jsonb(p_permissions)));
end;
$$;

-- ---------------------------------------------------------------------
-- Self-service: the only column of profiles a regular user may ever
-- change, and only their own row (see the comment on profiles' RLS in
-- 0003_rls_policies.sql for why this can't just be an UPDATE policy).
-- ---------------------------------------------------------------------

create or replace function update_display_name(p_display_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'ACCESS DENIED';
  end if;
  if length(trim(p_display_name)) = 0 or length(p_display_name) > 60 then
    raise exception 'INVALID_DISPLAY_NAME';
  end if;

  update profiles set display_name = p_display_name where id = auth.uid();
end;
$$;

-- ---------------------------------------------------------------------
-- User management
-- ---------------------------------------------------------------------

create or replace function admin_block_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_permission(auth.uid(), 'BLOCK_USERS') then
    raise exception 'ACCESS DENIED';
  end if;

  update profiles set status = 'BLOCKED' where id = p_user_id;
  perform log_admin_action('BLOCK_USER', 'profiles', p_user_id::text);
end;
$$;

create or replace function admin_unblock_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_permission(auth.uid(), 'BLOCK_USERS') then
    raise exception 'ACCESS DENIED';
  end if;

  update profiles set status = 'ACTIVE' where id = p_user_id;
  perform log_admin_action('UNBLOCK_USER', 'profiles', p_user_id::text);
end;
$$;

create or replace function admin_adjust_balance(p_user_id uuid, p_amount numeric, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance numeric(14, 2);
begin
  if not has_permission(auth.uid(), 'MANAGE_USERS') then
    raise exception 'ACCESS DENIED';
  end if;

  update wallets set balance = greatest(0, balance + p_amount) where user_id = p_user_id
    returning balance into v_balance;

  if not found then
    raise exception 'USER_NOT_FOUND';
  end if;

  insert into transactions (user_id, type, amount, balance_after, created_by, metadata)
  values (p_user_id, 'ADJUSTMENT', p_amount, v_balance, auth.uid(), jsonb_build_object('reason', p_reason));

  perform log_admin_action('ADJUST_BALANCE', 'wallets', p_user_id::text,
    jsonb_build_object('amount', p_amount, 'reason', p_reason));
end;
$$;

-- ---------------------------------------------------------------------
-- Device management
-- ---------------------------------------------------------------------

create or replace function admin_set_device_status(p_device_id uuid, p_status device_status)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old device_status;
begin
  if not has_permission(auth.uid(), 'MANAGE_DEVICES') then
    raise exception 'ACCESS DENIED';
  end if;

  select status into v_old from authorized_devices where id = p_device_id;
  if not found then
    raise exception 'DEVICE_NOT_FOUND';
  end if;

  update authorized_devices set status = p_status where id = p_device_id;

  perform log_admin_action('SET_DEVICE_STATUS', 'authorized_devices', p_device_id::text,
    jsonb_build_object('old_status', v_old, 'new_status', p_status));
end;
$$;

-- ---------------------------------------------------------------------
-- Invitations
-- ---------------------------------------------------------------------

create or replace function create_invitation(
  p_invited_name text,
  p_invited_email text default null,
  p_expires_hours int default 24,
  p_max_devices int default 1
)
returns invitations
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_invitation invitations;
begin
  if not has_permission(auth.uid(), 'CREATE_INVITATIONS') then
    raise exception 'ACCESS DENIED';
  end if;

  insert into invitations (token, invited_name, invited_email, created_by, expires_at, max_devices)
  values (
    encode(gen_random_bytes(16), 'hex'),
    p_invited_name,
    p_invited_email,
    auth.uid(),
    now() + make_interval(hours => p_expires_hours),
    p_max_devices
  )
  returning * into v_invitation;

  perform log_admin_action('CREATE_INVITATION', 'invitations', v_invitation.id::text,
    jsonb_build_object('invited_name', p_invited_name, 'expires_hours', p_expires_hours));

  return v_invitation;
end;
$$;

create or replace function revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_permission(auth.uid(), 'MANAGE_INVITATIONS') then
    raise exception 'ACCESS DENIED';
  end if;

  update invitations set status = 'REVOKED'
  where id = p_invitation_id and status = 'PENDING';

  if not found then
    raise exception 'INVITATION_NOT_REVOCABLE';
  end if;

  perform log_admin_action('REVOKE_INVITATION', 'invitations', p_invitation_id::text);
end;
$$;

-- ---------------------------------------------------------------------
-- Game control
-- ---------------------------------------------------------------------

create or replace function admin_force_crash()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round game_rounds;
begin
  if not has_permission(auth.uid(), 'CONTROL_GAME') then
    raise exception 'ACCESS DENIED';
  end if;

  select * into v_round from game_rounds where status = 'RUNNING' order by created_at desc limit 1;
  if not found then
    raise exception 'NO_RUNNING_ROUND';
  end if;

  perform crash_round(v_round.id);
  perform log_admin_action('CONTROL_GAME', 'game_rounds', v_round.id::text, jsonb_build_object('action', 'force_crash'));
end;
$$;

create or replace function schedule_demo_round(p_mode demo_mode_type, p_target_multiplier numeric default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_permission(auth.uid(), 'CONTROL_DEMO_MULTIPLIER') then
    raise exception 'ACCESS DENIED';
  end if;

  if p_mode = 'MANUAL' and (p_target_multiplier is null or p_target_multiplier < 1.00) then
    raise exception 'INVALID_TARGET_MULTIPLIER';
  end if;

  update game_settings
  set demo_mode = p_mode,
      next_manual_target_multiplier = case when p_mode = 'MANUAL' then p_target_multiplier else null end,
      updated_by = auth.uid()
  where id = 1;

  perform log_admin_action('CHANGE_DEMO_MULTIPLIER', 'game_settings', '1',
    jsonb_build_object('mode', p_mode, 'target_multiplier', p_target_multiplier));
end;
$$;

create or replace function update_game_operational_settings(
  p_betting_duration_seconds int,
  p_min_bet numeric,
  p_max_bet numeric,
  p_house_edge_percent numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_permission(auth.uid(), 'CONTROL_GAME') then
    raise exception 'ACCESS DENIED';
  end if;

  update game_settings
  set betting_duration_seconds = p_betting_duration_seconds,
      min_bet = p_min_bet,
      max_bet = p_max_bet,
      house_edge_percent = p_house_edge_percent,
      updated_by = auth.uid()
  where id = 1;

  perform log_admin_action('UPDATE_GAME_SETTINGS', 'game_settings', '1',
    jsonb_build_object('betting_duration_seconds', p_betting_duration_seconds, 'min_bet', p_min_bet, 'max_bet', p_max_bet, 'house_edge_percent', p_house_edge_percent));
end;
$$;

-- ---------------------------------------------------------------------
-- App version / maintenance control — SUPER_ADMIN only (no granular
-- permission for this exists in section 11's list on purpose).
-- ---------------------------------------------------------------------

create or replace function update_app_settings(
  p_current_version text,
  p_minimum_supported_version text,
  p_download_url text,
  p_maintenance_mode boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not is_super_admin(auth.uid()) then
    raise exception 'ACCESS DENIED';
  end if;

  update app_settings
  set current_version = p_current_version,
      minimum_supported_version = p_minimum_supported_version,
      download_url = p_download_url,
      maintenance_mode = p_maintenance_mode,
      updated_by = auth.uid()
  where id = 1;

  perform log_admin_action('UPDATE_APP_SETTINGS', 'app_settings', '1',
    jsonb_build_object('current_version', p_current_version, 'minimum_supported_version', p_minimum_supported_version, 'maintenance_mode', p_maintenance_mode));
end;
$$;

-- ---------------------------------------------------------------------
-- Activation gate — called by the Flutter app on launch/resume.
-- Enforces: account active, app version allowed, device authorized.
-- Registering a brand-new device is subject to enforce_device_quota().
-- ---------------------------------------------------------------------

create type activation_result as (
  allowed boolean,
  reason text,
  current_version text,
  minimum_supported_version text,
  download_url text
);

create or replace function semver_lt(a text, b text)
returns boolean
language sql
immutable
as $$
  select (string_to_array(a, '.')::int[]) < (string_to_array(b, '.')::int[]);
$$;

create or replace function check_activation(
  p_device_identifier text,
  p_device_name text,
  p_platform text,
  p_app_version text
)
returns activation_result
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_profile profiles;
  v_settings app_settings;
  v_device authorized_devices;
begin
  if v_uid is null then
    return row(false, 'NOT_AUTHENTICATED', null, null, null)::activation_result;
  end if;

  select * into v_settings from app_settings where id = 1;

  if semver_lt(p_app_version, v_settings.minimum_supported_version) then
    return row(false, 'UPDATE_REQUIRED', v_settings.current_version, v_settings.minimum_supported_version, v_settings.download_url)::activation_result;
  end if;

  if v_settings.maintenance_mode then
    return row(false, 'MAINTENANCE', v_settings.current_version, v_settings.minimum_supported_version, v_settings.download_url)::activation_result;
  end if;

  select * into v_profile from profiles where id = v_uid;
  if not found or v_profile.status <> 'ACTIVE' then
    return row(false, 'ACCOUNT_BLOCKED', v_settings.current_version, v_settings.minimum_supported_version, v_settings.download_url)::activation_result;
  end if;

  select * into v_device from authorized_devices where user_id = v_uid and device_identifier = p_device_identifier;

  if not found then
    begin
      insert into authorized_devices (user_id, device_identifier, device_name, platform)
      values (v_uid, p_device_identifier, p_device_name, p_platform)
      returning * into v_device;
    exception when raise_exception then
      return row(false, 'DEVICE_LIMIT_REACHED', v_settings.current_version, v_settings.minimum_supported_version, v_settings.download_url)::activation_result;
    end;
  else
    if v_device.status <> 'ACTIVE' then
      return row(false, 'DEVICE_REVOKED', v_settings.current_version, v_settings.minimum_supported_version, v_settings.download_url)::activation_result;
    end if;
    update authorized_devices set last_seen = now() where id = v_device.id;
  end if;

  return row(true, 'OK', v_settings.current_version, v_settings.minimum_supported_version, v_settings.download_url)::activation_result;
end;
$$;

-- ---------------------------------------------------------------------
-- Grants: every function above checks its own permission, so all of
-- them are safe to expose to `authenticated`. semver_lt is a pure
-- helper, harmless to expose.
-- ---------------------------------------------------------------------

grant execute on function update_display_name(text) to authenticated;
grant execute on function admin_deactivate_sub(uuid) to authenticated;
grant execute on function admin_reactivate_sub(uuid) to authenticated;
grant execute on function admin_update_sub(uuid, text) to authenticated;
grant execute on function admin_delete_sub(uuid) to authenticated;
grant execute on function set_sub_admin_permissions(uuid, admin_permission[]) to authenticated;
grant execute on function admin_block_user(uuid) to authenticated;
grant execute on function admin_unblock_user(uuid) to authenticated;
grant execute on function admin_adjust_balance(uuid, numeric, text) to authenticated;
grant execute on function admin_set_device_status(uuid, device_status) to authenticated;
grant execute on function create_invitation(text, text, int, int) to authenticated;
grant execute on function revoke_invitation(uuid) to authenticated;
grant execute on function admin_force_crash() to authenticated;
grant execute on function schedule_demo_round(demo_mode_type, numeric) to authenticated;
grant execute on function update_game_operational_settings(int, numeric, numeric, numeric) to authenticated;
grant execute on function update_app_settings(text, text, text, boolean) to authenticated;
grant execute on function semver_lt(text, text) to authenticated, anon;
grant execute on function check_activation(text, text, text, text) to authenticated;

-- log_admin_action is internal only. Postgres grants EXECUTE to PUBLIC
-- by default on function creation, which must be revoked explicitly —
-- otherwise any admin (even a low-privilege SOUS_ADMIN) could call it
-- directly to insert fabricated, free-form entries into admin_logs and
-- undermine the audit trail. It stays reachable from the functions
-- above only because SECURITY DEFINER calls run as the function owner,
-- which is unaffected by this revoke.
revoke execute on function log_admin_action(text, text, text, jsonb) from public, anon, authenticated;
