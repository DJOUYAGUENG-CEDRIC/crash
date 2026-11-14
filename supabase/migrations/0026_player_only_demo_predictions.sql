-- Exact demo predictions require an authenticated, active player account.
-- Do not apply to a real-money environment.

drop policy if exists demo_round_predictions_select_all
  on demo_round_predictions;

create policy demo_round_predictions_select_active_players
  on demo_round_predictions
  for select
  to authenticated
  using (
    exists (
      select 1
      from profiles
      where profiles.id = auth.uid()
        and profiles.status = 'ACTIVE'
    )
  );

revoke select on demo_round_predictions from public, anon;
grant select on demo_round_predictions to authenticated;
