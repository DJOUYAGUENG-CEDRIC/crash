-- Exact round targets are intentionally public for the CRASHX virtual-money
-- demo. Never apply this migration to a real-money game.

create table demo_round_predictions (
  round_id uuid primary key references game_rounds (id) on delete cascade,
  round_number bigint not null,
  status round_status not null,
  target_multiplier numeric(10, 2) not null,
  crash_multiplier numeric(10, 2),
  created_at timestamptz not null,
  updated_at timestamptz not null default now()
);

comment on table demo_round_predictions is
  'Public exact round targets for the CRASHX virtual-money demo only.';

create index idx_demo_round_predictions_created_at
  on demo_round_predictions (created_at desc);

alter table demo_round_predictions enable row level security;
revoke all on demo_round_predictions from public, anon, authenticated;
grant select on demo_round_predictions to anon, authenticated;

create policy demo_round_predictions_select_all on demo_round_predictions
  for select using (true);

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
    updated_at = excluded.updated_at;

  return new;
end;
$$;

create trigger trg_sync_demo_round_predictions
  after insert or update on game_rounds
  for each row execute function sync_demo_round_predictions();

revoke all on function sync_demo_round_predictions() from public, anon, authenticated;

insert into demo_round_predictions (
  round_id, round_number, status, target_multiplier,
  crash_multiplier, created_at
)
select
  id, round_number, status, target_multiplier, crash_multiplier, created_at
from game_rounds
where target_multiplier is not null
on conflict (round_id) do update set
  round_number = excluded.round_number,
  status = excluded.status,
  target_multiplier = excluded.target_multiplier,
  crash_multiplier = excluded.crash_multiplier;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'demo_round_predictions'
  ) then
    alter publication supabase_realtime add table demo_round_predictions;
  end if;
end $$;
