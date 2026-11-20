-- Make results above 2x uncommon and results above 10x very rare, while
-- preserving the 70x product ceiling and configured instant-crash share.
-- Probabilities per automatic round: 90% at/below 2x, 9% from 2.01x-10x,
-- 0.9% from 10.01x-30x, and 0.1% from 30.01x-70x.

create or replace function generate_crash_multiplier(p_house_edge_percent numeric)
returns numeric
language plpgsql
volatile
as $$
declare
  v_roll double precision := random();
  v_house_edge numeric := least(
    greatest(coalesce(p_house_edge_percent, 0), 0),
    90
  );
begin
  if v_roll < v_house_edge / 100.0 then
    return 1.00;
  elsif v_roll < 0.90 then
    return 1.01 + floor(random() * 100)::numeric / 100.00;
  elsif v_roll < 0.99 then
    return 2.01 + floor(random() * 800)::numeric / 100.00;
  elsif v_roll < 0.999 then
    return 10.01 + floor(random() * 2000)::numeric / 100.00;
  else
    return 30.01 + floor(random() * 4000)::numeric / 100.00;
  end if;
end;
$$;

revoke execute on function generate_crash_multiplier(numeric)
  from public, anon, authenticated;
