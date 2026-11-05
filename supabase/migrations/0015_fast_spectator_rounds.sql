-- Spectators always see short public flights below 2x. A player's accepted
-- bet remains an independent flight and is therefore unaffected by this cap.

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
  return greatest(1.00, least(v_m, 1.99));
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

revoke execute on function generate_crash_multiplier(numeric)
from public, anon, authenticated;
revoke execute on function create_next_round()
from public, anon, authenticated;

-- End the pre-migration public round now. The next generated round will use
-- the new below-2x spectator target.
select public.crash_round(id)
from game_rounds
where status = 'RUNNING'
order by created_at desc
limit 1;
