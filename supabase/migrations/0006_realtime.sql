-- =====================================================================
-- CRASHX DEMO — 0006_realtime.sql
-- Supabase Realtime (postgres_changes) only fires for physical tables
-- that are (a) added to the supabase_realtime publication and (b)
-- readable by the subscribing role under RLS — it cannot fire for a
-- VIEW, because view rows have no WAL entries of their own. This
-- migration converts game_rounds_public from a view into a real table
-- kept in sync by a trigger, and enables Realtime on every table the
-- clients subscribe to (game_rounds for admins, game_rounds_public for
-- players, bets, wallets).
-- =====================================================================

drop view if exists game_rounds_public;

create table game_rounds_public (
  id uuid primary key,
  round_number bigint not null,
  status round_status not null,
  crash_multiplier numeric(10, 2),
  betting_started_at timestamptz,
  running_started_at timestamptz,
  crashed_at timestamptz,
  total_bets_amount numeric(14, 2) not null,
  total_players int not null,
  created_at timestamptz not null
);

alter table game_rounds_public enable row level security;

grant select on game_rounds_public to authenticated, anon;

create policy game_rounds_public_select_all on game_rounds_public
  for select using (true);

-- No client-facing INSERT/UPDATE policy: only sync_game_rounds_public()
-- below writes to this table, and it runs as a SECURITY DEFINER-style
-- trigger (owner rights), which bypasses RLS regardless.

create or replace function sync_game_rounds_public()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into game_rounds_public (
    id, round_number, status, crash_multiplier,
    betting_started_at, running_started_at, crashed_at,
    total_bets_amount, total_players, created_at
  )
  values (
    new.id, new.round_number, new.status,
    case when new.status in ('CRASHED', 'RESULT') then new.crash_multiplier else null end,
    new.betting_started_at, new.running_started_at, new.crashed_at,
    new.total_bets_amount, new.total_players, new.created_at
  )
  on conflict (id) do update set
    status = excluded.status,
    crash_multiplier = excluded.crash_multiplier,
    betting_started_at = excluded.betting_started_at,
    running_started_at = excluded.running_started_at,
    crashed_at = excluded.crashed_at,
    total_bets_amount = excluded.total_bets_amount,
    total_players = excluded.total_players;

  return new;
end;
$$;

create trigger trg_sync_game_rounds_public
  after insert or update on game_rounds
  for each row execute function sync_game_rounds_public();

-- Backfill any rounds that already exist so the public table isn't
-- empty for rounds created before this migration ran.
insert into game_rounds_public (
  id, round_number, status, crash_multiplier,
  betting_started_at, running_started_at, crashed_at,
  total_bets_amount, total_players, created_at
)
select
  id, round_number, status,
  case when status in ('CRASHED', 'RESULT') then crash_multiplier else null end,
  betting_started_at, running_started_at, crashed_at,
  total_bets_amount, total_players, created_at
from game_rounds
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Enable Realtime. Idempotent-safe: adding a table twice raises an
-- error, so guard each with a check against the publication contents.
-- ---------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_rounds_public'
  ) then
    alter publication supabase_realtime add table game_rounds_public;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_rounds'
  ) then
    alter publication supabase_realtime add table game_rounds;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'bets'
  ) then
    alter publication supabase_realtime add table bets;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'wallets'
  ) then
    alter publication supabase_realtime add table wallets;
  end if;
end $$;
