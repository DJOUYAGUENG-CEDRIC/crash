#!/usr/bin/env bash
# CRASHX — copy all data from the old Supabase project to a new one.
#
# Prerequisites (see supabase/DEMENAGEMENT.md):
#   * the NEW project has pg_cron enabled and every migration applied
#     (npx supabase link --project-ref <new> && npx supabase db push);
#   * PostgreSQL client tools whose major version is >= both servers
#     (pg_dump refuses to dump a newer server);
#   * both connection strings, "Session pooler" format from
#     Dashboard → Connect (works without IPv6):
#       postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
#
# Usage (Git Bash):
#   OLD_DB_URL='postgresql://...' NEW_DB_URL='postgresql://...' \
#     bash supabase/scripts/migrate-to-new-project.sh
#
# The old project is only read (works while it is in read-only mode).
# Logins, passwords, balances, bets, history and staff accounts are copied;
# pg_cron run history is not (it is what filled the old disk).

set -euo pipefail

: "${OLD_DB_URL:?Set OLD_DB_URL to the old project's connection string}"
: "${NEW_DB_URL:?Set NEW_DB_URL to the new project's connection string}"
PG_BIN="${PG_BIN:-/c/Program Files/PostgreSQL/17/bin}"
OUT_DIR="${OUT_DIR:-./crashx-migration-$(date +%Y%m%d-%H%M%S)}"

PSQL="$PG_BIN/psql"
PG_DUMP="$PG_BIN/pg_dump"
for tool in "$PSQL" "$PG_DUMP"; do
  if [ ! -x "$tool" ] && [ ! -x "$tool.exe" ]; then
    echo "Introuvable : $tool — installez les outils clients PostgreSQL ou définissez PG_BIN." >&2
    exit 1
  fi
done

mkdir -p "$OUT_DIR"
echo "Fichiers de travail : $OUT_DIR"

server_major() {
  "$PSQL" "$1" -XAtqc "select current_setting('server_version_num')::int / 10000"
}
client_major=$("$PG_DUMP" --version | grep -oE '[0-9]+' | head -1)
old_major=$(server_major "$OLD_DB_URL")
new_major=$(server_major "$NEW_DB_URL")
echo "Client PostgreSQL $client_major · ancien serveur $old_major · nouveau serveur $new_major"
if [ "$client_major" -lt "$old_major" ] || [ "$client_major" -lt "$new_major" ]; then
  echo "Les outils clients ($client_major) sont plus anciens qu'un serveur." >&2
  echo "Installez PostgreSQL $((old_major > new_major ? old_major : new_major)) (outils clients) et relancez avec PG_BIN=..." >&2
  exit 1
fi

# The new project must already have the schema (migrations) applied.
if [ "$("$PSQL" "$NEW_DB_URL" -XAtqc "select to_regclass('public.game_rounds') is not null")" != "t" ]; then
  echo "Le nouveau projet n'a pas le schéma CRASHX : lancez d'abord 'npx supabase db push'." >&2
  exit 1
fi

echo "1/5 Export des comptes (auth.users, auth.identities)…"
"$PG_DUMP" "$OLD_DB_URL" --data-only --no-owner --no-privileges \
  --table=auth.users --table=auth.identities \
  --file="$OUT_DIR/auth.sql"

echo "2/5 Export des données du jeu (schéma public)…"
"$PG_DUMP" "$OLD_DB_URL" --data-only --no-owner --no-privileges \
  --schema=public \
  --file="$OUT_DIR/public.sql"

echo "3/5 Arrêt du moteur et vidage des tables du nouveau projet…"
"$PSQL" "$NEW_DB_URL" -X -v ON_ERROR_STOP=1 <<'SQL'
update cron.job set active = false where jobname like 'crashx-%';

do $$
declare
  v_tables text;
begin
  select string_agg(format('public.%I', tablename), ', ')
  into v_tables
  from pg_tables
  where schemaname = 'public';
  if v_tables is not null then
    execute 'truncate table ' || v_tables || ' restart identity cascade';
  end if;
end;
$$;

-- A fresh project has no player yet; refuse to overwrite one that does.
do $$
begin
  if exists (select 1 from auth.users) then
    raise exception 'Le nouveau projet contient déjà des comptes : import annulé.';
  end if;
end;
$$;
SQL

echo "4/5 Import (une seule transaction, triggers désactivés)…"
"$PSQL" "$NEW_DB_URL" -X -v ON_ERROR_STOP=1 --single-transaction \
  --command 'set session_replication_role = replica' \
  --file="$OUT_DIR/auth.sql" \
  --file="$OUT_DIR/public.sql"

echo "5/5 Redémarrage du moteur de jeu et vérification…"
"$PSQL" "$NEW_DB_URL" -X -v ON_ERROR_STOP=1 --single-transaction <<'SQL'
-- The old project may predate migrations 0020-0022: replay their data
-- fixes on the imported rows.

-- 0022: device quota now lives on the profile.
update profiles p
set max_devices = i.max_devices
from invitations i
where i.id = p.invitation_id;

-- 0020: bets left ACTIVE on finished rounds (old independent flights)
-- are refunded.
do $$
declare
  v_bet record;
  v_balance numeric(14, 2);
begin
  for v_bet in
    select b.* from bets b
    join game_rounds r on r.id = b.round_id
    where b.status = 'ACTIVE' and r.status in ('CRASHED', 'RESULT')
  loop
    update bets set status = 'CANCELLED', payout = 0 where id = v_bet.id;
    update wallets set balance = balance + v_bet.amount
    where user_id = v_bet.user_id
    returning balance into v_balance;
    insert into transactions
      (user_id, type, amount, balance_after, bet_id, round_id, metadata)
    values
      (v_bet.user_id, 'ADJUSTMENT', v_bet.amount, v_balance, v_bet.id,
       v_bet.round_id, jsonb_build_object('reason', 'shared_rounds_migration_refund'));
  end loop;
end;
$$;

update cron.job set active = true where jobname like 'crashx-%';
SQL
"$PSQL" "$NEW_DB_URL" -X -v ON_ERROR_STOP=1 -c 'select public.game_tick();'

count_query="select
  (select count(*) from auth.users)   as comptes,
  (select count(*) from profiles)     as joueurs,
  (select count(*) from admin_users)  as admins,
  (select count(*) from wallets)      as portefeuilles,
  (select count(*) from bets)         as mises,
  (select count(*) from transactions) as transactions"
echo "Ancien projet :"
"$PSQL" "$OLD_DB_URL" -X -c "$count_query"
echo "Nouveau projet :"
"$PSQL" "$NEW_DB_URL" -X -c "$count_query"

echo "Terminé. Les deux tableaux doivent être identiques, à part d'éventuelles transactions de remboursement (anciens vols personnels)."
