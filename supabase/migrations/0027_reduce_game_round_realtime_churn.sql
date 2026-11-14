-- Keep the public predictor row in sync on meaningful round changes only.
-- game_tick updates the WAITING countdown every second; copying those writes
-- to demo_round_predictions needlessly wakes every predictor client.

create index if not exists idx_demo_round_predictions_latest
  on demo_round_predictions (round_number desc, created_at desc);

create or replace function sync_demo_round_predictions()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.target_multiplier is null then
    delete from demo_round_predictions where round_id = new.id;
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.round_number is not distinct from new.round_number
     and old.status is not distinct from new.status
     and old.target_multiplier is not distinct from new.target_multiplier
     and old.crash_multiplier is not distinct from new.crash_multiplier
     and old.created_at is not distinct from new.created_at then
    return new;
  end if;

  insert into demo_round_predictions (
    round_id, round_number, status, target_multiplier,
    crash_multiplier, created_at, updated_at
  )
  values (
    new.id, new.round_number, new.status, new.target_multiplier,
    new.crash_multiplier, new.created_at, clock_timestamp()
  )
  on conflict (round_id) do update set
    round_number = excluded.round_number,
    status = excluded.status,
    target_multiplier = excluded.target_multiplier,
    crash_multiplier = excluded.crash_multiplier,
    updated_at = excluded.updated_at
  where demo_round_predictions.round_number is distinct from excluded.round_number
     or demo_round_predictions.status is distinct from excluded.status
     or demo_round_predictions.target_multiplier is distinct from excluded.target_multiplier
     or demo_round_predictions.crash_multiplier is distinct from excluded.crash_multiplier
     or demo_round_predictions.created_at is distinct from excluded.created_at;

  return new;
end;
$$;

drop trigger if exists trg_sync_demo_round_predictions on game_rounds;

create trigger trg_sync_demo_round_predictions
  after insert or update of
    round_number, status, target_multiplier, crash_multiplier, created_at
  on game_rounds
  for each row execute function sync_demo_round_predictions();

revoke all on function sync_demo_round_predictions() from public, anon, authenticated;
