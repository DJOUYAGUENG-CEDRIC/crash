-- =====================================================================
-- CRASHX DEMO — 0007_live_bets_public.sql
-- A genuine live "who's betting right now" feed for the Crash screen —
-- real players, real virtual amounts, never fabricated data. bets.user_id
-- is not directly visible to other players (profiles RLS keeps display
-- names private), so this denormalizes just the display_name into a
-- safe public projection, the same pattern as game_rounds_public
-- (0006) — a real table kept in sync by a trigger, so Realtime can
-- actually fire on it (it cannot fire on a view).
-- =====================================================================

create table live_bets_public (
  id uuid primary key,
  round_id uuid not null references game_rounds (id) on delete cascade,
  display_name text not null,
  slot smallint not null,
  amount numeric(14, 2) not null,
  status bet_status not null,
  cashout_multiplier numeric(10, 2),
  payout numeric(14, 2),
  placed_at timestamptz not null
);

create index idx_live_bets_public_round_id on live_bets_public (round_id);

alter table live_bets_public enable row level security;

grant select on live_bets_public to authenticated;

create policy live_bets_public_select_all on live_bets_public
  for select using (true);

-- No client-facing INSERT/UPDATE policy: only sync_live_bets_public()
-- below writes here, running with owner rights (bypasses RLS).

create or replace function sync_live_bets_public()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
begin
  select display_name into v_display_name from profiles where id = new.user_id;

  insert into live_bets_public (
    id, round_id, display_name, slot, amount, status, cashout_multiplier, payout, placed_at
  )
  values (
    new.id, new.round_id, coalesce(v_display_name, 'Joueur'), new.slot, new.amount,
    new.status, new.cashout_multiplier, new.payout, new.placed_at
  )
  on conflict (id) do update set
    status = excluded.status,
    cashout_multiplier = excluded.cashout_multiplier,
    payout = excluded.payout;

  return new;
end;
$$;

create trigger trg_sync_live_bets_public
  after insert or update on bets
  for each row execute function sync_live_bets_public();

-- Backfill from whatever bets already exist.
insert into live_bets_public (id, round_id, display_name, slot, amount, status, cashout_multiplier, payout, placed_at)
select b.id, b.round_id, coalesce(p.display_name, 'Joueur'), b.slot, b.amount, b.status, b.cashout_multiplier, b.payout, b.placed_at
from bets b
left join profiles p on p.id = b.user_id
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'live_bets_public'
  ) then
    alter publication supabase_realtime add table live_bets_public;
  end if;
end $$;
