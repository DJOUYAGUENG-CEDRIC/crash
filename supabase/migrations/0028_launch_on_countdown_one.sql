-- Start the flight as soon as the countdown reaches 1.
-- The client displays 7 -> 1; do not hold on 1 for an additional tick.

update game_settings
set betting_duration_seconds = 7
where id = 1;

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

    if v_remaining <= 1 then
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

revoke execute on function game_tick() from public, anon, authenticated;
grant execute on function game_tick() to service_role;
