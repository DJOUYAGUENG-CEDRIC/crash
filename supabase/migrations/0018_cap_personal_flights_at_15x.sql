-- Personal flights may survive a public crash, but their multiplier must
-- stop at the product limit of 15x.

create or replace function current_multiplier(p_running_started_at timestamptz)
returns numeric
language sql
stable
as $$
  select least(
    round(
      exp(0.06 * extract(epoch from (now() - p_running_started_at)))::numeric,
      2
    ),
    15.00
  );
$$;

-- Existing automatic targets above the new ceiling would otherwise never
-- settle. Bring them down to the highest reachable multiplier.
update bets
set auto_cashout_multiplier = 15.00
where auto_cashout_multiplier > 15.00
  and status in ('PENDING', 'ACTIVE');

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'bets_auto_cashout_maximum_check'
      and conrelid = 'public.bets'::regclass
  ) then
    alter table bets
    add constraint bets_auto_cashout_maximum_check
    check (
      auto_cashout_multiplier is null or auto_cashout_multiplier <= 15.00
    );
  end if;
end;
$$;

revoke execute on function current_multiplier(timestamptz)
from public, anon, authenticated;
