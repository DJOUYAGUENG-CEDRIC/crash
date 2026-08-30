-- Manual target selection is retired. New targets are generated server-side.
update game_settings
set demo_mode = 'AUTOMATIC',
    next_manual_target_multiplier = null;

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
  v_target := generate_crash_multiplier(v_settings.house_edge_percent);

  insert into game_rounds (status, demo_mode, target_multiplier)
  values ('WAITING', 'AUTOMATIC', v_target)
  returning * into v_round;
  return v_round;
end;
$$;

-- The obsolete RPC remains only for migration compatibility and cannot be called.
revoke execute on function schedule_demo_round(demo_mode_type, numeric) from public, anon, authenticated;
