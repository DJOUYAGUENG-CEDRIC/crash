-- =====================================================================
-- CRASHX DEMO — 0004_game_engine_functions.sql
-- Server-authoritative game engine. The Flutter client never computes
-- balances, payouts, or the crash point — it only animates what these
-- functions decide. All amounts are FCFA VIRTUELS (demo money only).
--
-- Growth curve: multiplier(t) = exp(GROWTH_RATE * t), t = seconds since
-- running_started_at. Shared constant with the Flutter animation layer
-- (see mobile/lib/core/constants/game_constants.dart) so what a player
-- sees matches what the server will accept at cashout time.
-- =====================================================================

create or replace function current_multiplier(p_running_started_at timestamptz)
returns numeric
language sql
stable
as $$
  select round(exp(0.06 * extract(epoch from (now() - p_running_started_at)))::numeric, 2);
$$;

-- DEMO-ONLY random crash point generator. Clearly not suitable for a
-- real-money product (see section 19 of the spec) — a future real
-- version must replace this with an auditable, provably-fair scheme.
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
  if v_m > 1000 then v_m := 1000; end if;
  if v_m < 1.00 then v_m := 1.00; end if;
  return v_m;
end;
$$;

-- ---------------------------------------------------------------------
-- place_bet — deducts the wallet and opens a bet slot (1 or 2)
-- ---------------------------------------------------------------------

create or replace function place_bet(
  p_round_id uuid,
  p_slot smallint,
  p_amount numeric,
  p_auto_cashout numeric default null
)
returns bets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_round game_rounds;
  v_settings game_settings;
  v_balance numeric(14, 2);
  v_bet bets;
begin
  if v_uid is null then
    raise exception 'ACCESS DENIED: authentication required';
  end if;

  select * into v_round from game_rounds where id = p_round_id for update;
  if not found or v_round.status <> 'BETTING' then
    raise exception 'ROUND_NOT_OPEN: bets are closed for this round';
  end if;

  select * into v_settings from game_settings where id = 1;

  if p_amount < v_settings.min_bet or p_amount > v_settings.max_bet then
    raise exception 'INVALID_AMOUNT: bet must be between % and %', v_settings.min_bet, v_settings.max_bet;
  end if;

  if p_auto_cashout is not null and p_auto_cashout < 1.01 then
    raise exception 'INVALID_AUTO_CASHOUT';
  end if;

  select balance into v_balance from wallets where user_id = v_uid for update;
  if v_balance is null or v_balance < p_amount then
    raise exception 'INSUFFICIENT_FUNDS';
  end if;

  update wallets set balance = balance - p_amount where user_id = v_uid;

  insert into bets (round_id, user_id, slot, amount, status, auto_cashout_multiplier)
  values (p_round_id, v_uid, p_slot, p_amount, 'ACTIVE', p_auto_cashout)
  returning * into v_bet;

  insert into transactions (user_id, type, amount, balance_after, bet_id, round_id)
  values (v_uid, 'BET', -p_amount, v_balance - p_amount, v_bet.id, p_round_id);

  update game_rounds
  set total_bets_amount = total_bets_amount + p_amount,
      total_players = (select count(distinct user_id) from bets where round_id = p_round_id)
  where id = p_round_id;

  return v_bet;
end;
$$;

-- ---------------------------------------------------------------------
-- cashout_bet — settles a single ACTIVE bet at the current multiplier
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
  select * into v_bet from bets where id = p_bet_id and user_id = v_uid for update;
  if not found then
    raise exception 'ACCESS DENIED: bet not found for this user';
  end if;
  if v_bet.status <> 'ACTIVE' then
    raise exception 'BET_NOT_ACTIVE';
  end if;

  select * into v_round from game_rounds where id = v_bet.round_id for update;
  if v_round.status <> 'RUNNING' then
    raise exception 'ROUND_NOT_RUNNING';
  end if;

  v_mult := current_multiplier(v_round.running_started_at);
  if v_mult >= v_round.target_multiplier then
    raise exception 'ROUND_CRASHED: too late to cash out';
  end if;

  v_payout := round(v_bet.amount * v_mult, 2);

  update bets
  set status = 'CASHED_OUT', cashout_multiplier = v_mult, payout = v_payout, cashed_out_at = now()
  where id = p_bet_id;

  update wallets set balance = balance + v_payout where user_id = v_uid
    returning balance into v_balance;

  insert into transactions (user_id, type, amount, balance_after, bet_id, round_id)
  values (v_uid, 'CASHOUT', v_payout, v_balance, p_bet_id, v_round.id);

  select * into v_bet from bets where id = p_bet_id;
  return v_bet;
end;
$$;

-- ---------------------------------------------------------------------
-- Round lifecycle (invoked by game_tick(), see below)
-- ---------------------------------------------------------------------

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

  if v_settings.demo_mode = 'MANUAL' and v_settings.next_manual_target_multiplier is not null then
    v_target := v_settings.next_manual_target_multiplier;
    update game_settings set next_manual_target_multiplier = null where id = 1;
  else
    v_target := generate_crash_multiplier(v_settings.house_edge_percent);
  end if;

  insert into game_rounds (status, demo_mode, target_multiplier)
  values ('WAITING', v_settings.demo_mode, v_target)
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
begin
  update game_rounds
  set status = 'CRASHED', crash_multiplier = target_multiplier, crashed_at = now()
  where id = p_round_id and status = 'RUNNING';

  update bets
  set status = 'LOST', payout = 0
  where round_id = p_round_id and status = 'ACTIVE';
end;
$$;

-- Auto cashout sweep: settles every ACTIVE bet whose configured
-- auto_cashout_multiplier has been reached by the current multiplier.
create or replace function process_auto_cashouts(p_round_id uuid, p_current_multiplier numeric)
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
    for update
  loop
    v_payout := round(v_bet.amount * v_bet.auto_cashout_multiplier, 2);

    update bets
    set status = 'CASHED_OUT', cashout_multiplier = v_bet.auto_cashout_multiplier,
        payout = v_payout, cashed_out_at = now()
    where id = v_bet.id;

    update wallets set balance = balance + v_payout where user_id = v_bet.user_id
      returning balance into v_balance;

    insert into transactions (user_id, type, amount, balance_after, bet_id, round_id)
    values (v_bet.user_id, 'CASHOUT', v_payout, v_balance, v_bet.id, p_round_id);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- game_tick — the single authoritative heartbeat of the game engine.
-- Meant to be invoked roughly once per second by a pg_cron job (see
-- seed.sql). Advances whatever round currently exists by one step;
-- idempotent and safe to call more often than needed.
-- ---------------------------------------------------------------------

create or replace function game_tick()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round game_rounds;
  v_settings game_settings;
  v_mult numeric;
begin
  select * into v_settings from game_settings where id = 1;

  select * into v_round from game_rounds order by created_at desc limit 1 for update;

  if not found then
    perform create_next_round();
    return;
  end if;

  if v_round.status = 'WAITING' then
    update game_rounds set status = 'BETTING', betting_started_at = now() where id = v_round.id;

  elsif v_round.status = 'BETTING' then
    if extract(epoch from (now() - v_round.betting_started_at)) >= v_settings.betting_duration_seconds then
      update game_rounds set status = 'RUNNING', running_started_at = now() where id = v_round.id;
    end if;

  elsif v_round.status = 'RUNNING' then
    v_mult := current_multiplier(v_round.running_started_at);
    if v_mult >= v_round.target_multiplier then
      perform crash_round(v_round.id);
    else
      perform process_auto_cashouts(v_round.id, v_mult);
    end if;

  elsif v_round.status = 'CRASHED' then
    if extract(epoch from (now() - v_round.crashed_at)) >= 3 then
      update game_rounds set status = 'RESULT' where id = v_round.id;
    end if;

  elsif v_round.status = 'RESULT' then
    perform create_next_round();
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- Lock down execution. Postgres grants EXECUTE to PUBLIC by default,
-- which would let any authenticated client call these over PostgREST
-- RPC directly (e.g. crash_round(any_round_id) to force a crash, or
-- game_tick() to fast-forward the game). Only place_bet/cashout_bet
-- are meant to be called by the Flutter app; everything else is
-- internal, driven only by pg_cron running as the table owner.
-- ---------------------------------------------------------------------

revoke execute on function current_multiplier(timestamptz) from public, anon, authenticated;
revoke execute on function generate_crash_multiplier(numeric) from public, anon, authenticated;
revoke execute on function create_next_round() from public, anon, authenticated;
revoke execute on function crash_round(uuid) from public, anon, authenticated;
revoke execute on function process_auto_cashouts(uuid, numeric) from public, anon, authenticated;
revoke execute on function game_tick() from public, anon, authenticated;

grant execute on function place_bet(uuid, smallint, numeric, numeric) to authenticated;
grant execute on function cashout_bet(uuid) to authenticated;

-- The pg_cron job (runs as postgres) and the game-tick Edge Function
-- fallback (runs with the service_role key) both need to call the
-- engine directly.
grant execute on function game_tick() to service_role;
