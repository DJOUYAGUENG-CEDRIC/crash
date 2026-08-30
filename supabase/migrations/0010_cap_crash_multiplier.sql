-- Keep every generated and published crash multiplier within the product limit.
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
  v_m := least(100.00, greatest(1.00, v_m));
  return v_m;
end;
$$;

-- Existing rounds that have not started yet must respect the new limit too.
update game_rounds
set target_multiplier = least(target_multiplier, 100.00)
where status in ('WAITING', 'BETTING')
  and target_multiplier > 100.00;
