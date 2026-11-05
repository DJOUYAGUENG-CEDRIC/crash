-- Last-resort watchdog for a stalled public game loop. The regular one-second
-- game_tick remains responsible for normal play; this job only repairs states
-- that have remained impossible or stale well beyond their expected duration.

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
  v_crash_multiplier numeric;
begin
  if not pg_try_advisory_xact_lock(
    hashtextextended('crashx-game-tick', 0)
  ) then
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
    -- A countdown should normally transition after the configured duration.
    -- Give the regular heartbeat 15 extra seconds before repairing it.
    if clock_timestamp() >=
       coalesce(v_round.betting_started_at, v_round.created_at)
       + make_interval(
           secs => greatest(v_settings.betting_duration_seconds, 1) + 15
         ) then
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
    -- At the 15x product ceiling a legitimate flight lasts about 45 seconds.
    -- Seventy-five seconds therefore leaves ample grace before forcing a
    -- visibly frozen public round to its crash state.
    if v_round.running_started_at is null
       or clock_timestamp() >=
          v_round.running_started_at + interval '75 seconds' then
      v_crash_multiplier := case
        when v_round.running_started_at is null then 1.00
        else least(
          15.00,
          greatest(
            1.00,
            coalesce(
              current_multiplier(v_round.running_started_at),
              v_round.target_multiplier,
              1.00
            )
          )
        )
      end;

      update game_rounds
      set status = 'CRASHED',
          crash_multiplier = v_crash_multiplier,
          crashed_at = clock_timestamp()
      where id = v_round.id
        and status = 'RUNNING';
    end if;

  elsif v_round.status = 'CRASHED' then
    -- Missing timestamps and stale crash screens must both advance.
    if v_round.crashed_at is null
       or clock_timestamp() >= v_round.crashed_at + interval '10 seconds' then
      perform create_next_round();
    end if;

  elsif v_round.status = 'RESULT' then
    perform create_next_round();
  end if;
end;
$$;

revoke execute on function repair_stalled_game_loop()
from public, anon, authenticated;
grant execute on function repair_stalled_game_loop() to service_role;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid from cron.job
    where jobname = 'crashx-game-watchdog'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

select cron.schedule(
  'crashx-game-watchdog',
  '10 seconds',
  'select public.repair_stalled_game_loop();'
);

-- Repair immediately when this migration is deployed.
select public.repair_stalled_game_loop();
