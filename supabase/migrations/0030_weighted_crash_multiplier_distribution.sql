-- Use a weighted distribution on every automatic round:
-- 80% small (1.00x-2.00x), 18% medium (2.01x-10.00x),
-- and 2% high (10.01x-70.00x). Keep the configured house edge as
-- an immediate 1.00x crash within the small-result share.

drop trigger if exists trg_set_eighth_round_high_target on game_rounds;
drop function if exists set_eighth_round_high_target();

create or replace function generate_crash_multiplier(p_house_edge_percent numeric)
returns numeric
language plpgsql
volatile
as $$
declare
  v_roll double precision := random();
  v_house_edge numeric := least(
    greatest(coalesce(p_house_edge_percent, 0), 0),
    80
  );
begin
  if v_roll < v_house_edge / 100.0 then
    return 1.00;
  elsif v_roll < 0.80 then
    return 1.01 + floor(random() * 100)::numeric / 100.00;
  elsif v_roll < 0.98 then
    return 2.01 + floor(random() * 800)::numeric / 100.00;
  else
    return 10.01 + floor(random() * 6000)::numeric / 100.00;
  end if;
end;
$$;

revoke execute on function generate_crash_multiplier(numeric)
  from public, anon, authenticated;
