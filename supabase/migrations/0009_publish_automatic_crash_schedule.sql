-- Publish the automatically generated target multiplier to the mobile app.
alter table game_rounds_public add column if not exists target_multiplier numeric(10, 2);

create or replace function sync_game_rounds_public()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into game_rounds_public (id, round_number, status, target_multiplier, crash_multiplier, betting_started_at, running_started_at, crashed_at, total_bets_amount, total_players, created_at)
  values (new.id, new.round_number, new.status, new.target_multiplier, case when new.status in ('CRASHED', 'RESULT') then new.crash_multiplier else null end, new.betting_started_at, new.running_started_at, new.crashed_at, new.total_bets_amount, new.total_players, new.created_at)
  on conflict (id) do update set
    status = excluded.status,
    target_multiplier = excluded.target_multiplier,
    crash_multiplier = excluded.crash_multiplier,
    betting_started_at = excluded.betting_started_at,
    running_started_at = excluded.running_started_at,
    crashed_at = excluded.crashed_at,
    total_bets_amount = excluded.total_bets_amount,
    total_players = excluded.total_players;
  return new;
end;
$$;

update game_rounds_public public_round
set target_multiplier = game_rounds.target_multiplier
from game_rounds
where game_rounds.id = public_round.id;
