-- Raise the virtual game's multiplier ceiling to 70x and guarantee a
-- randomly selected 30x-70x target on every eighth round.

alter table bets
  drop constraint if exists bets_auto_cashout_maximum_check;

update bets
set auto_cashout_multiplier = 70.00
where auto_cashout_multiplier > 70.00
  and status in ('PENDING', 'ACTIVE');

alter table bets
  add constraint bets_auto_cashout_maximum_check
  check (
    auto_cashout_multiplier is null or auto_cashout_multiplier <= 70.00
  );

create or replace function current_multiplier(p_running_started_at timestamptz)
returns numeric
language sql
stable
as $$
  select least(
    round(exp(0.06 * extract(epoch from (now() - p_running_started_at)))::numeric, 2),
    70.00
  );
$$;

create or replace function generate_crash_multiplier(p_house_edge_percent numeric)
returns numeric
language plpgsql
volatile
as $$
declare
  v_r double precision := random();
  v_m numeric;
begin
  if v_r < (p_house_edge_percent / 100.0) then
    return 1.00;
  end if;

  v_m := (1.0 - p_house_edge_percent / 100.0) / (1.0 - v_r);
  v_m := floor(v_m * 100) / 100;
  return greatest(1.00, least(v_m, 70.00));
end;
$$;

create or replace function create_next_round()
returns game_rounds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_settings game_settings;
  v_round game_rounds;
  v_target numeric;
begin
  select * into v_settings from game_settings where id = 1 for update;

  if v_settings.demo_mode = 'MANUAL'
     and v_settings.next_manual_target_multiplier is not null then
    v_target := greatest(1.00, least(v_settings.next_manual_target_multiplier, 70.00));
    update game_settings set next_manual_target_multiplier = null where id = 1;
  else
    v_target := generate_crash_multiplier(v_settings.house_edge_percent);
  end if;

  insert into game_rounds
    (status, demo_mode, target_multiplier, betting_started_at, countdown)
  values
    ('WAITING', v_settings.demo_mode, v_target, clock_timestamp(),
     v_settings.betting_duration_seconds)
  returning * into v_round;
  return v_round;
end;
$$;

create or replace function crash_round(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round game_rounds;
  v_crash_multiplier numeric;
begin
  select * into v_round from game_rounds
  where id = p_round_id and status = 'RUNNING'
  for update;
  if not found then
    return;
  end if;

  v_crash_multiplier := greatest(1.00, least(
    coalesce(v_round.target_multiplier, 70.00),
    coalesce(current_multiplier(v_round.running_started_at), 1.00)
  ));

  update game_rounds
  set status = 'CRASHED', crash_multiplier = v_crash_multiplier,
      crashed_at = clock_timestamp()
  where id = p_round_id;

  update bets
  set status = 'LOST', payout = 0
  where round_id = p_round_id and status = 'ACTIVE';
end;
$$;

create or replace function set_eighth_round_high_target()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.round_number % 8 = 0 then
    new.target_multiplier :=
      30.00 + floor(random() * 4001)::numeric / 100.00;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_eighth_round_high_target on game_rounds;
create trigger trg_set_eighth_round_high_target
  before insert on game_rounds
  for each row execute function set_eighth_round_high_target();

revoke all on function set_eighth_round_high_target() from public, anon, authenticated;

create or replace function schedule_demo_round(
  p_mode demo_mode_type,
  p_target_multiplier numeric default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not has_permission(auth.uid(), 'CONTROL_DEMO_MULTIPLIER') then
    raise exception 'ACCESS DENIED';
  end if;

  if p_mode = 'MANUAL'
     and (
       p_target_multiplier is null
       or p_target_multiplier < 1.00
       or p_target_multiplier > 70.00
     ) then
    raise exception 'INVALID_TARGET_MULTIPLIER';
  end if;

  update game_settings
  set demo_mode = p_mode,
      next_manual_target_multiplier = case
        when p_mode = 'MANUAL' then p_target_multiplier
        else null
      end,
      updated_by = auth.uid()
  where id = 1;

  perform log_admin_action(
    'CHANGE_DEMO_MULTIPLIER',
    'game_settings',
    '1',
    jsonb_build_object('mode', p_mode, 'target_multiplier', p_target_multiplier)
  );
end;
$$;
