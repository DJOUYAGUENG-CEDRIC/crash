-- Refine the automatic crash distribution while keeping the 70x product cap:
-- 70% small (1.00x-2.00x), 23% medium (2.01x-10.00x),
-- 4% (10.01x-15.00x), 2% (15.00x-30.00x), and 1% (30.00x-40.00x).
-- The configured house-edge share remains an immediate 1.00x crash within
-- the 70% small-result band.

create or replace function generate_crash_multiplier(p_house_edge_percent numeric)
returns numeric
language plpgsql
volatile
as $$
declare
  v_roll double precision := random();
  v_house_edge numeric := least(
    greatest(coalesce(p_house_edge_percent, 0), 0),
    70
  );
begin
  if v_roll < v_house_edge / 100.0 then
    return 1.00;
  elsif v_roll < 0.70 then
    return 1.01 + floor(random() * 100)::numeric / 100.00;
  elsif v_roll < 0.93 then
    return 2.01 + floor(random() * 800)::numeric / 100.00;
  elsif v_roll < 0.97 then
    return 10.01 + floor(random() * 500)::numeric / 100.00;
  elsif v_roll < 0.99 then
    return 15.00 + floor(random() * 1501)::numeric / 100.00;
  else
    return 30.00 + floor(random() * 1001)::numeric / 100.00;
  end if;
end;
$$;

revoke execute on function generate_crash_multiplier(numeric)
  from public, anon, authenticated;
