-- Restore the server-authoritative pre-round countdown to 7 -> 1.
-- This supersedes 0012_countdown_five_to_one.sql.

update game_settings
set betting_duration_seconds = 7
where id = 1;

update game_rounds
set countdown = least(coalesce(countdown, 7), 7)
where status in ('WAITING', 'BETTING');
