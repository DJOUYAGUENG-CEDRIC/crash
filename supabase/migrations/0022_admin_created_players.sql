-- Player accounts are now created directly by staff (Edge Function
-- create-player): the admin chooses the login and password and hands them
-- to the player, who signs in immediately. Invitations are no longer
-- needed to open an account; the existing ones stay for history.
--
-- The device quota used to come from the originating invitation. It now
-- lives on the profile so accounts created without an invitation get one.

alter table profiles
  add column if not exists max_devices int not null default 1
  check (max_devices >= 1);

update profiles p
set max_devices = i.max_devices
from invitations i
where i.id = p.invitation_id;

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
  select max_devices into v_max_devices from profiles where id = new.user_id;

  select count(*) into v_active_count
  from authorized_devices
  where user_id = new.user_id and status = 'ACTIVE';

  if v_active_count >= coalesce(v_max_devices, 1) then
    raise exception 'ACCESS DENIED: device limit reached for this account';
  end if;

  return new;
end;
$$;

create or replace function handle_new_player()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
  v_invitation_id uuid;
  v_max_devices int;
  v_starting_balance numeric(14, 2) := 25000.00;
begin
  v_display_name := coalesce(new.raw_user_meta_data ->> 'display_name', 'Joueur');
  v_invitation_id := nullif(new.raw_user_meta_data ->> 'invitation_id', '')::uuid;
  v_max_devices := greatest(
    1,
    coalesce(nullif(new.raw_user_meta_data ->> 'max_devices', '')::int, 1)
  );

  insert into profiles (id, email, display_name, invitation_id, max_devices)
  values (new.id, new.email, v_display_name, v_invitation_id, v_max_devices);

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

-- Staff can raise or lower a player's device quota.
create or replace function admin_set_player_max_devices(p_user_id uuid, p_max_devices int)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_permission(auth.uid(), 'MANAGE_DEVICES') then
    raise exception 'ACCESS DENIED';
  end if;
  if p_max_devices is null or p_max_devices < 1 then
    raise exception 'INVALID_INPUT';
  end if;

  update profiles set max_devices = p_max_devices where id = p_user_id;
  if not found then
    raise exception 'PLAYER_NOT_FOUND';
  end if;

  perform log_admin_action(
    'SET_MAX_DEVICES', 'profiles', p_user_id::text,
    jsonb_build_object('max_devices', p_max_devices)
  );
end;
$$;

revoke execute on function admin_set_player_max_devices(uuid, int) from public, anon;
grant execute on function admin_set_player_max_devices(uuid, int) to authenticated;
