-- Independent player flights. Public rounds never get blocked by one player.

alter table bets add column if not exists flight_started_at timestamptz;

create index if not exists idx_bets_personal_auto_cashout
on bets (auto_cashout_multiplier, flight_started_at)
where status = 'ACTIVE' and auto_cashout_multiplier is not null;

create or replace function current_multiplier(p_running_started_at timestamptz)
returns numeric language sql stable
as $$
  select least(
    round(exp(0.06 * extract(epoch from (now() - p_running_started_at)))::numeric, 2),
    100.00
  );
$$;

-- Spectator/public rounds are deliberately short. Independent player flights
-- are not limited by this target and can continue up to the product's 100x cap.
create or replace function generate_crash_multiplier(p_house_edge_percent numeric)
returns numeric language plpgsql volatile
as $$
declare
  v_r double precision := random();
  v_m numeric;
begin
  if v_r < (p_house_edge_percent / 100.0) then return 1.00; end if;
  v_m := (1.0 - p_house_edge_percent / 100.0) / (1.0 - v_r);
  v_m := floor(v_m * 100) / 100;
  return greatest(1.00, least(v_m, 1.99));
end;
$$;

create or replace function create_next_round()
returns game_rounds language plpgsql security definer set search_path = public
as $$
declare
  v_settings game_settings;
  v_round game_rounds;
  v_target numeric;
begin
  select * into v_settings from game_settings where id = 1 for update;
  if v_settings.demo_mode = 'MANUAL'
     and v_settings.next_manual_target_multiplier is not null then
    v_target := least(v_settings.next_manual_target_multiplier, 1.99);
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

update bets b
set flight_started_at = r.running_started_at
from game_rounds r
where b.round_id = r.id
  and b.status = 'ACTIVE'
  and b.flight_started_at is null
  and r.running_started_at is not null;

create or replace function cashout_bet(p_bet_id uuid)
returns bets language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_bet bets;
  v_mult numeric;
  v_payout numeric(14, 2);
  v_balance numeric(14, 2);
begin
  select * into v_bet from bets
  where id = p_bet_id and user_id = v_uid for update;
  if not found then raise exception 'ACCESS DENIED: bet not found for this user'; end if;
  if v_bet.status <> 'ACTIVE' then raise exception 'BET_NOT_ACTIVE'; end if;
  if v_bet.flight_started_at is null then raise exception 'BET_NOT_STARTED'; end if;

  v_mult := current_multiplier(v_bet.flight_started_at);
  v_payout := round(v_bet.amount * v_mult, 2);

  update bets
  set status = 'CASHED_OUT', cashout_multiplier = v_mult,
      payout = v_payout, cashed_out_at = clock_timestamp()
  where id = p_bet_id;

  update wallets set balance = balance + v_payout where user_id = v_uid
  returning balance into v_balance;
  insert into transactions (user_id, type, amount, balance_after, bet_id, round_id)
  values (v_uid, 'CASHOUT', v_payout, v_balance, p_bet_id, v_bet.round_id);

  select * into v_bet from bets where id = p_bet_id;
  return v_bet;
end;
$$;

-- Public crashes only control shared scenery and future betting windows.
-- They never turn a player's independent ACTIVE bet into a loss.
create or replace function crash_round(p_round_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare
  v_crash_multiplier numeric;
begin
  select greatest(target_multiplier, current_multiplier(running_started_at))
  into v_crash_multiplier
  from game_rounds where id = p_round_id and status = 'RUNNING';

  update game_rounds
  set status = 'CRASHED', crash_multiplier = v_crash_multiplier,
      crashed_at = clock_timestamp()
  where id = p_round_id and status = 'RUNNING';
end;
$$;

create or replace function process_personal_auto_cashouts()
returns void language plpgsql security definer set search_path = public
as $$
declare
  v_bet record;
  v_mult numeric;
  v_payout numeric(14, 2);
  v_balance numeric(14, 2);
begin
  for v_bet in
    select * from bets
    where status = 'ACTIVE'
      and flight_started_at is not null
      and auto_cashout_multiplier is not null
    for update skip locked
  loop
    v_mult := current_multiplier(v_bet.flight_started_at);
    if v_bet.auto_cashout_multiplier <= v_mult then
      v_payout := round(v_bet.amount * v_bet.auto_cashout_multiplier, 2);
      update bets
      set status = 'CASHED_OUT', cashout_multiplier = v_bet.auto_cashout_multiplier,
          payout = v_payout, cashed_out_at = clock_timestamp()
      where id = v_bet.id and status = 'ACTIVE';

      if found then
        update wallets set balance = balance + v_payout
        where user_id = v_bet.user_id returning balance into v_balance;
        insert into transactions
          (user_id, type, amount, balance_after, bet_id, round_id)
        values
          (v_bet.user_id, 'CASHOUT', v_payout, v_balance, v_bet.id, v_bet.round_id);
      end if;
    end if;
  end loop;
end;
$$;

create or replace function game_tick()
returns void language plpgsql security definer set search_path = public
as $$
declare
  v_round game_rounds;
  v_settings game_settings;
  v_mult numeric;
  v_remaining integer;
  v_started_at timestamptz;
begin
  select * into v_settings from game_settings where id = 1;
  select * into v_round from game_rounds
  order by created_at desc limit 1 for update;
  if not found then perform create_next_round(); return; end if;

  if v_round.status in ('WAITING', 'BETTING') then
    v_remaining := greatest(0, v_settings.betting_duration_seconds -
      floor(extract(epoch from (
        clock_timestamp() - coalesce(v_round.betting_started_at, v_round.created_at)
      )))::integer);
    if v_remaining <= 0 then
      v_started_at := clock_timestamp();
      update game_rounds
      set status = 'RUNNING', countdown = 0, running_started_at = v_started_at
      where id = v_round.id;
      update bets set flight_started_at = v_started_at
      where round_id = v_round.id and status = 'ACTIVE'
        and flight_started_at is null;
    else
      update game_rounds set status = 'WAITING', countdown = v_remaining
      where id = v_round.id;
    end if;
  elsif v_round.status = 'RUNNING' then
    v_mult := current_multiplier(v_round.running_started_at);
    if v_mult >= v_round.target_multiplier then perform crash_round(v_round.id); end if;
  elsif v_round.status = 'CRASHED' then
    if extract(epoch from (clock_timestamp() - v_round.crashed_at)) >= 2 then
      perform create_next_round();
    end if;
  elsif v_round.status = 'RESULT' then
    perform create_next_round();
  end if;

  -- One malformed automatic bet must never freeze the public game engine.
  begin
    perform process_personal_auto_cashouts();
  exception when others then
    raise warning 'PERSONAL_AUTO_CASHOUT_FAILED: %', sqlerrm;
  end;
end;
$$;

create or replace function admin_force_crash()
returns void language plpgsql security definer set search_path = public
as $$
declare v_round game_rounds;
begin
  if not has_permission(auth.uid(), 'CONTROL_GAME') then raise exception 'ACCESS DENIED'; end if;
  select * into v_round from game_rounds where status = 'RUNNING'
  order by created_at desc limit 1;
  if not found then raise exception 'NO_RUNNING_ROUND'; end if;
  perform crash_round(v_round.id);
  perform log_admin_action(
    'CONTROL_GAME', 'game_rounds', v_round.id::text,
    jsonb_build_object('action', 'force_crash')
  );
end;
$$;

create or replace function sync_game_rounds_public()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into game_rounds_public
    (id, round_number, status, target_multiplier, crash_multiplier, countdown,
     betting_started_at, running_started_at, crashed_at,
     total_bets_amount, total_players, created_at)
  values
    (new.id, new.round_number, new.status, null,
     case when new.status in ('CRASHED', 'RESULT') then new.crash_multiplier else null end,
     new.countdown, new.betting_started_at, new.running_started_at, new.crashed_at,
     new.total_bets_amount, new.total_players, new.created_at)
  on conflict (id) do update set
    status = excluded.status, target_multiplier = null,
    crash_multiplier = excluded.crash_multiplier, countdown = excluded.countdown,
    betting_started_at = excluded.betting_started_at,
    running_started_at = excluded.running_started_at,
    crashed_at = excluded.crashed_at,
    total_bets_amount = excluded.total_bets_amount,
    total_players = excluded.total_players;
  return new;
end;
$$;

update game_rounds_public set target_multiplier = null;

revoke execute on function current_multiplier(timestamptz) from public, anon, authenticated;
revoke execute on function generate_crash_multiplier(numeric) from public, anon, authenticated;
revoke execute on function create_next_round() from public, anon, authenticated;
revoke execute on function crash_round(uuid) from public, anon, authenticated;
revoke execute on function process_personal_auto_cashouts() from public, anon, authenticated;
revoke execute on function game_tick() from public, anon, authenticated;
grant execute on function game_tick() to service_role;
grant execute on function cashout_bet(uuid) to authenticated;
grant execute on function admin_force_crash() to authenticated;

-- Recover immediately if the previous global-protection implementation left
-- production on a RUNNING round at 100x. This bypasses automatic cashouts so
-- one malformed legacy bet cannot roll back the recovery transaction.
select public.crash_round(id)
from game_rounds
where status = 'RUNNING'
order by created_at desc
limit 1;
