-- Keep the public game loop fast and deterministic under concurrent load.
-- Automatic cashouts run in a separate transaction so a large bet queue can
-- never delay publication of the next countdown.

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
  -- A slow previous cron invocation must never overlap this one. Without this
  -- guard, two workers can both observe CRASHED and create duplicate rounds.
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

-- Replace potentially missing or misconfigured jobs with one-second jobs.
do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid from cron.job
    where jobname in ('crashx-game-tick', 'crashx-personal-auto-cashouts')
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

select cron.schedule(
  'crashx-game-tick',
  '1 second',
  'select public.game_tick();'
);

select cron.schedule(
  'crashx-personal-auto-cashouts',
  '1 second',
  $job$
    select public.process_personal_auto_cashouts();
  $job$
);

-- Recover immediately if deployment occurs on a stale crash screen.
select public.game_tick();

