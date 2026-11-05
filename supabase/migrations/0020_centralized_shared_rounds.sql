-- One shared, server-authoritative round for every device.
--
-- 0014-0018 gave each accepted bet an "independent flight" that survived the
-- public crash, while spectators saw rounds capped below 2x. Two devices could
-- therefore display different multipliers for the same round. This migration
-- returns to a single source of truth:
--   * every device follows the same public round and the same multiplier;
--   * the crash point is generated server-side (house-edge distribution,
--     product ceiling 15x) and is never published before the crash;
--   * cashouts and automatic cashouts are settled against the round's
--     multiplier, and every bet still ACTIVE at the crash is LOST;
--   * server_now() lets clients align their animation clock on the server.

-- ---------------------------------------------------------------------
-- Crash point generation
-- ---------------------------------------------------------------------

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
  return greatest(1.00, least(v_m, 15.00));
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
    v_target := greatest(1.00, least(v_settings.next_manual_target_multiplier, 15.00));
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

-- ---------------------------------------------------------------------
-- Settlement against the shared round
-- ---------------------------------------------------------------------

create or replace function cashout_bet(p_bet_id uuid)
returns bets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_bet bets;
  v_round game_rounds;
  v_mult numeric;
  v_payout numeric(14, 2);
  v_balance numeric(14, 2);
begin
  select * into v_bet from bets
  where id = p_bet_id and user_id = v_uid
  for update;
  if not found then
    raise exception 'ACCESS DENIED: bet not found for this user';
  end if;
  if v_bet.status <> 'ACTIVE' then
    raise exception 'BET_NOT_ACTIVE';
  end if;

  select * into v_round from game_rounds where id = v_bet.round_id for update;
  if v_round.status <> 'RUNNING' or v_round.running_started_at is null then
    raise exception 'ROUND_NOT_RUNNING';
  end if;

  v_mult := current_multiplier(v_round.running_started_at);
  if v_mult >= v_round.target_multiplier then
    raise exception 'ROUND_CRASHED: too late to cash out';
  end if;

  v_payout := round(v_bet.amount * v_mult, 2);

  update bets
  set status = 'CASHED_OUT', cashout_multiplier = v_mult,
      payout = v_payout, cashed_out_at = clock_timestamp()
  where id = p_bet_id;

  update wallets set balance = balance + v_payout where user_id = v_uid
  returning balance into v_balance;

  insert into transactions (user_id, type, amount, balance_after, bet_id, round_id)
  values (v_uid, 'CASHOUT', v_payout, v_balance, p_bet_id, v_round.id);

  select * into v_bet from bets where id = p_bet_id;
  return v_bet;
end;
$$;

-- Pays every ACTIVE bet of the round whose automatic target is at most
-- p_current_multiplier, at exactly that automatic target.
create or replace function process_auto_cashouts(
  p_round_id uuid,
  p_current_multiplier numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bet record;
  v_payout numeric(14, 2);
  v_balance numeric(14, 2);
begin
  for v_bet in
    select * from bets
    where round_id = p_round_id
      and status = 'ACTIVE'
      and auto_cashout_multiplier is not null
      and auto_cashout_multiplier <= p_current_multiplier
    for update skip locked
  loop
    v_payout := round(v_bet.amount * v_bet.auto_cashout_multiplier, 2);

    update bets
    set status = 'CASHED_OUT', cashout_multiplier = v_bet.auto_cashout_multiplier,
        payout = v_payout, cashed_out_at = clock_timestamp()
    where id = v_bet.id and status = 'ACTIVE';

    if found then
      update wallets set balance = balance + v_payout
      where user_id = v_bet.user_id
      returning balance into v_balance;

      insert into transactions (user_id, type, amount, balance_after, bet_id, round_id)
      values (v_bet.user_id, 'CASHOUT', v_payout, v_balance, v_bet.id, p_round_id);
    end if;
  end loop;
end;
$$;

-- Normal crashes stop at the target; a forced crash (admin or watchdog)
-- stops at the multiplier actually reached. Every bet still ACTIVE loses.
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
    coalesce(v_round.target_multiplier, 15.00),
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

-- ---------------------------------------------------------------------
-- Heartbeat
-- ---------------------------------------------------------------------

create or replace function game_tick()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round record;
  v_settings record;
  v_mult numeric;
  v_remaining integer;
  v_started_at timestamptz;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('crashx-game-tick', 0)) then
    return;
  end if;

  select * into v_settings from game_settings where id = 1;
  select * into v_round
  from game_rounds
  order by created_at desc
  limit 1
  for update;

  if not found then
    perform create_next_round();
    return;
  end if;

  if v_round.status in ('WAITING', 'BETTING') then
    v_remaining := greatest(
      0,
      v_settings.betting_duration_seconds - floor(extract(epoch from (
        clock_timestamp() - coalesce(v_round.betting_started_at, v_round.created_at)
      )))::integer
    );

    if v_remaining <= 0 then
      v_started_at := clock_timestamp();
      update game_rounds
      set status = 'RUNNING', countdown = 0, running_started_at = v_started_at
      where id = v_round.id;

      -- Kept for client compatibility: every bet flies with its round.
      update bets
      set flight_started_at = v_started_at
      where round_id = v_round.id
        and status = 'ACTIVE'
        and flight_started_at is null;
    else
      update game_rounds
      set status = 'WAITING', countdown = v_remaining
      where id = v_round.id;
    end if;

  elsif v_round.status = 'RUNNING' then
    v_mult := current_multiplier(v_round.running_started_at);

    -- Automatic targets strictly below the crash point were reached
    -- before the crash and are paid even if they fall between two ticks.
    begin
      perform process_auto_cashouts(
        v_round.id,
        least(v_mult, v_round.target_multiplier - 0.01)
      );
    exception when others then
      raise warning 'AUTO_CASHOUT_FAILED: %', sqlerrm;
    end;

    if v_mult >= v_round.target_multiplier then
      perform crash_round(v_round.id);
    end if;

  elsif v_round.status = 'CRASHED' then
    if clock_timestamp() >= v_round.crashed_at + interval '1 second' then
      perform create_next_round();
    end if;

  elsif v_round.status = 'RESULT' then
    perform create_next_round();
  end if;
end;
$$;

-- The watchdog now settles forced crashes through crash_round(), so bets
-- of a stalled round are resolved exactly like a normal crash.
create or replace function repair_stalled_game_loop()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round game_rounds;
  v_settings game_settings;
  v_started_at timestamptz;
begin
  if not pg_try_advisory_xact_lock(hashtextextended('crashx-game-tick', 0)) then
    return;
  end if;

  select * into v_settings from game_settings where id = 1;
  select * into v_round
  from game_rounds
  order by created_at desc
  limit 1
  for update;

  if not found then
    perform create_next_round();
    return;
  end if;

  if v_round.status in ('WAITING', 'BETTING') then
    if clock_timestamp() >=
       coalesce(v_round.betting_started_at, v_round.created_at)
       + make_interval(secs => greatest(v_settings.betting_duration_seconds, 1) + 15) then
      v_started_at := clock_timestamp();
      update game_rounds
      set status = 'RUNNING', countdown = 0, running_started_at = v_started_at
      where id = v_round.id
        and status in ('WAITING', 'BETTING');

      update bets
      set flight_started_at = v_started_at
      where round_id = v_round.id
        and status = 'ACTIVE'
        and flight_started_at is null;
    end if;

  elsif v_round.status = 'RUNNING' then
    -- A 15x flight lasts about 45 seconds; 75 seconds leaves ample grace.
    if v_round.running_started_at is null then
      update game_rounds set running_started_at = clock_timestamp()
      where id = v_round.id;
      perform crash_round(v_round.id);
    elsif clock_timestamp() >= v_round.running_started_at + interval '75 seconds' then
      perform crash_round(v_round.id);
    end if;

  elsif v_round.status = 'CRASHED' then
    if v_round.crashed_at is null
       or clock_timestamp() >= v_round.crashed_at + interval '10 seconds' then
      perform create_next_round();
    end if;

  elsif v_round.status = 'RESULT' then
    perform create_next_round();
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- Shared clock for client animation
-- ---------------------------------------------------------------------

create or replace function server_now()
returns timestamptz
language sql
volatile
as $$
  select clock_timestamp();
$$;

grant execute on function server_now() to anon, authenticated;

-- ---------------------------------------------------------------------
-- Retire independent flights
-- ---------------------------------------------------------------------

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid from cron.job where jobname = 'crashx-personal-auto-cashouts'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

drop function if exists process_personal_auto_cashouts();
drop index if exists idx_bets_personal_auto_cashout;

-- Bets left ACTIVE on an already finished round were accepted under the
-- independent-flight rules. Refund them rather than deciding an outcome
-- retroactively.
do $$
declare
  v_bet record;
  v_balance numeric(14, 2);
begin
  for v_bet in
    select b.* from bets b
    join game_rounds r on r.id = b.round_id
    where b.status = 'ACTIVE' and r.status in ('CRASHED', 'RESULT')
    for update of b
  loop
    update bets set status = 'CANCELLED', payout = 0 where id = v_bet.id;

    update wallets set balance = balance + v_bet.amount
    where user_id = v_bet.user_id
    returning balance into v_balance;

    insert into transactions
      (user_id, type, amount, balance_after, bet_id, round_id, metadata)
    values
      (v_bet.user_id, 'ADJUSTMENT', v_bet.amount, v_balance, v_bet.id,
       v_bet.round_id, jsonb_build_object('reason', 'shared_rounds_migration_refund'));
  end loop;
end;
$$;

revoke execute on function generate_crash_multiplier(numeric) from public, anon, authenticated;
revoke execute on function create_next_round() from public, anon, authenticated;
revoke execute on function crash_round(uuid) from public, anon, authenticated;
revoke execute on function process_auto_cashouts(uuid, numeric) from public, anon, authenticated;
revoke execute on function game_tick() from public, anon, authenticated;
revoke execute on function repair_stalled_game_loop() from public, anon, authenticated;
grant execute on function game_tick() to service_role;
grant execute on function repair_stalled_game_loop() to service_role;
grant execute on function cashout_bet(uuid) to authenticated;
