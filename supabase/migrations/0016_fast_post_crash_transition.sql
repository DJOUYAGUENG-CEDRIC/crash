-- Match the public round transition to the 900 ms explosion animation.
-- With the one-second cron heartbeat, the next countdown starts on the first
-- tick after the explosion instead of leaving a frozen CRASHED screen.

create or replace function game_tick()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Use generic records so the function does not depend on PostgreSQL
  -- resolving table row types while compiling the migration.
  v_round record;
  v_settings record;
  v_mult numeric;
  v_remaining integer;
  v_started_at timestamptz;
begin
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
    if v_mult >= v_round.target_multiplier then
      perform crash_round(v_round.id);
    end if;
  elsif v_round.status = 'CRASHED' then
    if extract(epoch from (clock_timestamp() - v_round.crashed_at)) >= 1 then
      perform create_next_round();
    end if;
  elsif v_round.status = 'RESULT' then
    perform create_next_round();
  end if;

  begin
    perform process_personal_auto_cashouts();
  exception when others then
    raise warning 'PERSONAL_AUTO_CASHOUT_FAILED: %', sqlerrm;
  end;
end;
$$;

revoke execute on function game_tick() from public, anon, authenticated;
grant execute on function game_tick() to service_role;

-- If deployment happens while an old crash screen is waiting, advance it now.
select public.game_tick();
