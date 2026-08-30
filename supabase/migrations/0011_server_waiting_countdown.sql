-- Server-authoritative pre-round countdown.
-- Realtime publishes countdown updates from game_rounds_public every second.

alter table game_rounds add column if not exists countdown smallint;
alter table game_rounds_public add column if not exists countdown smallint;

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

  insert into game_rounds (status, demo_mode, target_multiplier, betting_started_at, countdown)
  values ('WAITING', v_settings.demo_mode, v_target, clock_timestamp(), 5)
  returning * into v_round;
  return v_round;
end;
$$;

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
  if v_uid is null then raise exception 'ACCESS DENIED: authentication required'; end if;
  select * into v_round from game_rounds where id = p_round_id for update;
  if not found or v_round.status not in ('WAITING', 'BETTING') or coalesce(v_round.countdown, 0) <= 0 then
    raise exception 'ROUND_NOT_OPEN: bets are closed for this round';
  end if;
  select * into v_settings from game_settings where id = 1;
  if p_amount < v_settings.min_bet or p_amount > v_settings.max_bet then
    raise exception 'INVALID_AMOUNT: bet must be between % and %', v_settings.min_bet, v_settings.max_bet;
  end if;
  if p_auto_cashout is not null and p_auto_cashout < 1.01 then raise exception 'INVALID_AUTO_CASHOUT'; end if;
  select balance into v_balance from wallets where user_id = v_uid for update;
  if v_balance is null or v_balance < p_amount then raise exception 'INSUFFICIENT_FUNDS'; end if;
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
  v_remaining integer;
begin
  select * into v_settings from game_settings where id = 1;
  select * into v_round from game_rounds order by created_at desc limit 1 for update;
  if not found then perform create_next_round(); return; end if;

  if v_round.status in ('WAITING', 'BETTING') then
    v_remaining := greatest(0, v_settings.betting_duration_seconds -
      floor(extract(epoch from (clock_timestamp() - coalesce(v_round.betting_started_at, v_round.created_at))))::integer);
    if v_remaining <= 0 then
      update game_rounds
      set status = 'RUNNING', countdown = 0, running_started_at = clock_timestamp()
      where id = v_round.id;
    else
      update game_rounds set status = 'WAITING', countdown = v_remaining where id = v_round.id;
    end if;
  elsif v_round.status = 'RUNNING' then
    v_mult := current_multiplier(v_round.running_started_at);
    if v_mult >= v_round.target_multiplier then
      perform crash_round(v_round.id);
    else
      perform process_auto_cashouts(v_round.id, v_mult);
    end if;
  elsif v_round.status = 'CRASHED' then
    if extract(epoch from (clock_timestamp() - v_round.crashed_at)) >= 2 then
      perform create_next_round();
    end if;
  elsif v_round.status = 'RESULT' then
    perform create_next_round();
  end if;
end;
$$;

create or replace function sync_game_rounds_public()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into game_rounds_public
    (id, round_number, status, target_multiplier, crash_multiplier, countdown,
     betting_started_at, running_started_at, crashed_at, total_bets_amount, total_players, created_at)
  values
    (new.id, new.round_number, new.status, new.target_multiplier,
     case when new.status in ('CRASHED', 'RESULT') then new.crash_multiplier else null end,
     new.countdown, new.betting_started_at, new.running_started_at, new.crashed_at,
     new.total_bets_amount, new.total_players, new.created_at)
  on conflict (id) do update set
    status = excluded.status,
    target_multiplier = excluded.target_multiplier,
    crash_multiplier = excluded.crash_multiplier,
    countdown = excluded.countdown,
    betting_started_at = excluded.betting_started_at,
    running_started_at = excluded.running_started_at,
    crashed_at = excluded.crashed_at,
    total_bets_amount = excluded.total_bets_amount,
    total_players = excluded.total_players;
  return new;
end;
$$;

revoke execute on function create_next_round() from public, anon, authenticated;
revoke execute on function game_tick() from public, anon, authenticated;
grant execute on function game_tick() to service_role;
grant execute on function place_bet(uuid, smallint, numeric, numeric) to authenticated;
