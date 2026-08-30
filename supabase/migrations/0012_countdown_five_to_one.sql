-- Correct the already-deployed countdown to match the reference: 5 → 1,
-- followed immediately by RUNNING. Zero is stored at the transition but is
-- never rendered because the status changes in the same database update.

update game_settings
set betting_duration_seconds = 5
where id = 1;

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

  insert into game_rounds
    (status, demo_mode, target_multiplier, betting_started_at, countdown)
  values
    ('WAITING', v_settings.demo_mode, v_target, clock_timestamp(), 5)
  returning * into v_round;
  return v_round;
end;
$$;

-- Normalize a round that may still be using the previous seven-second value.
update game_rounds
set countdown = least(coalesce(countdown, 5), 5),
    betting_started_at = clock_timestamp()
where id = (select id from game_rounds order by created_at desc limit 1)
  and status in ('WAITING', 'BETTING');

revoke execute on function create_next_round() from public, anon, authenticated;
