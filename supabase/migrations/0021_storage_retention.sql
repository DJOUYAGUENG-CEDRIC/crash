-- Keep the database inside the Supabase free-tier disk quota.
--
-- The game engine runs pg_cron jobs every second (game_tick) and every ten
-- seconds (watchdog). pg_cron writes one row per run into
-- cron.job_run_details and never deletes them: about 95 000 rows a day,
-- which is what fills the disk. Rounds nobody bet on are also kept forever
-- (several thousand a day). This migration purges both on a schedule.

create or replace function purge_storage_history()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Scheduler history: only useful for debugging recent runs.
  delete from cron.job_run_details
  where end_time < now() - interval '1 hour';

  -- Rounds without any bet carry no money history. Keep 15 days so the
  -- 14-day statistics stay complete.
  delete from game_rounds_public p
  where p.created_at < now() - interval '15 days'
    and not exists (select 1 from bets b where b.round_id = p.id);

  delete from game_rounds r
  where r.created_at < now() - interval '15 days'
    and r.status in ('CRASHED', 'RESULT')
    and not exists (select 1 from bets b where b.round_id = r.id)
    and not exists (select 1 from transactions t where t.round_id = r.id);
end;
$$;

revoke execute on function purge_storage_history() from public, anon, authenticated;

do $$
declare
  v_job_id bigint;
begin
  for v_job_id in
    select jobid from cron.job where jobname = 'crashx-storage-retention'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end;
$$;

select cron.schedule(
  'crashx-storage-retention',
  '*/15 * * * *',
  'select public.purge_storage_history();'
);

-- Free the space immediately on deployment.
select public.purge_storage_history();
