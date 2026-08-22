-- =====================================================================
-- CRASHX DEMO — 0001_initial_schema.sql
-- Argent virtuel uniquement. Aucune donnée financière réelle.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- ENUM TYPES
-- ---------------------------------------------------------------------

create type account_status as enum ('ACTIVE', 'BLOCKED');

create type admin_role as enum ('SUPER_ADMIN', 'SOUS_ADMIN');

create type admin_permission as enum (
  'VIEW_DASHBOARD',
  'VIEW_USERS',
  'VIEW_STATISTICS',
  'VIEW_GAME',
  'CONTROL_GAME',
  'CONTROL_DEMO_MULTIPLIER',
  'VIEW_BETS',
  'MANAGE_USERS',
  'BLOCK_USERS',
  'MANAGE_DEVICES',
  'CREATE_INVITATIONS',
  'MANAGE_INVITATIONS',
  'VIEW_LOGS',
  'VIEW_SETTINGS'
);

create type round_status as enum ('WAITING', 'BETTING', 'RUNNING', 'CRASHED', 'RESULT');

create type demo_mode_type as enum ('AUTOMATIC', 'MANUAL');

create type bet_status as enum ('PENDING', 'ACTIVE', 'CASHED_OUT', 'LOST', 'CANCELLED');

create type transaction_type as enum ('BET', 'CASHOUT', 'BONUS_DEMO', 'ADJUSTMENT');

create type invitation_status as enum ('PENDING', 'USED', 'EXPIRED', 'REVOKED');

create type device_status as enum ('ACTIVE', 'BLOCKED', 'REVOKED');

-- ---------------------------------------------------------------------
-- profiles — extends auth.users, one row per player/admin
-- ---------------------------------------------------------------------

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  display_name text not null default 'Joueur',
  status account_status not null default 'ACTIVE',
  invitation_id uuid, -- fk added after invitations table exists
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_profiles_status on profiles (status);

-- ---------------------------------------------------------------------
-- admin_users — SUPER_ADMIN (exactly 2) and SOUS_ADMIN accounts
-- ---------------------------------------------------------------------

create table admin_users (
  id uuid primary key references auth.users (id) on delete cascade,
  role admin_role not null,
  display_name text not null default 'Admin',
  created_by uuid references admin_users (id), -- null for the 2 root SUPER_ADMIN
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_admin_users_role on admin_users (role);

-- Enforce: at most 2 SUPER_ADMIN rows ever exist (bootstrap-only, no app path creates them).
create or replace function enforce_super_admin_cap()
returns trigger
language plpgsql
as $$
begin
  if new.role = 'SUPER_ADMIN' then
    if (select count(*) from admin_users where role = 'SUPER_ADMIN' and id <> new.id) >= 2 then
      raise exception 'ACCESS DENIED: maximum of 2 SUPER_ADMIN accounts allowed';
    end if;
  end if;
  return new;
end;
$$;

create trigger trg_enforce_super_admin_cap
  before insert or update on admin_users
  for each row execute function enforce_super_admin_cap();

-- ---------------------------------------------------------------------
-- admin_permissions — granular permissions granted to SOUS_ADMIN accounts
-- ---------------------------------------------------------------------

create table admin_permissions (
  admin_id uuid not null references admin_users (id) on delete cascade,
  permission admin_permission not null,
  granted_by uuid not null references admin_users (id),
  granted_at timestamptz not null default now(),
  primary key (admin_id, permission)
);

-- ---------------------------------------------------------------------
-- wallets — one virtual wallet per player
-- ---------------------------------------------------------------------

create table wallets (
  user_id uuid primary key references profiles (id) on delete cascade,
  balance numeric(14, 2) not null default 25000.00 check (balance >= 0),
  currency text not null default 'FCFA_VIRTUEL',
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- game_rounds — one row per crash round
-- ---------------------------------------------------------------------

create table game_rounds (
  id uuid primary key default gen_random_uuid(),
  round_number bigint generated always as identity,
  status round_status not null default 'WAITING',
  demo_mode demo_mode_type not null default 'AUTOMATIC',
  target_multiplier numeric(10, 2), -- set server-side; hidden from clients until crash
  crash_multiplier numeric(10, 2),  -- revealed result, null until CRASHED
  scheduled_by uuid references admin_users (id), -- set when demo_mode = MANUAL
  betting_started_at timestamptz,
  running_started_at timestamptz,
  crashed_at timestamptz,
  total_bets_amount numeric(14, 2) not null default 0,
  total_players int not null default 0,
  created_at timestamptz not null default now()
);

create index idx_game_rounds_status on game_rounds (status);
create index idx_game_rounds_created_at on game_rounds (created_at desc);

-- ---------------------------------------------------------------------
-- bets — up to 2 simultaneous bets per user per round (slot 1 / slot 2)
-- ---------------------------------------------------------------------

create table bets (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references game_rounds (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  slot smallint not null check (slot in (1, 2)),
  amount numeric(14, 2) not null check (amount > 0),
  status bet_status not null default 'PENDING',
  auto_cashout_multiplier numeric(10, 2) check (auto_cashout_multiplier is null or auto_cashout_multiplier >= 1.01),
  cashout_multiplier numeric(10, 2),
  payout numeric(14, 2),
  placed_at timestamptz not null default now(),
  cashed_out_at timestamptz,
  created_at timestamptz not null default now(),
  unique (round_id, user_id, slot)
);

create index idx_bets_round_id on bets (round_id);
create index idx_bets_user_id on bets (user_id);
create index idx_bets_status on bets (status);

-- ---------------------------------------------------------------------
-- transactions — full ledger of every wallet balance change
-- ---------------------------------------------------------------------

create table transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  type transaction_type not null,
  amount numeric(14, 2) not null, -- signed: negative for BET, positive for CASHOUT/BONUS
  balance_after numeric(14, 2) not null,
  bet_id uuid references bets (id),
  round_id uuid references game_rounds (id),
  created_by uuid references admin_users (id), -- set for ADJUSTMENT
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_transactions_user_id on transactions (user_id, created_at desc);
create index idx_transactions_type on transactions (type);

-- ---------------------------------------------------------------------
-- invitations — controls APK/account activation
-- ---------------------------------------------------------------------

create table invitations (
  id uuid primary key default gen_random_uuid(),
  token text not null unique,
  invited_name text not null,
  invited_email text,
  user_id uuid references profiles (id), -- set once the invitation is consumed
  created_by uuid not null references admin_users (id),
  expires_at timestamptz not null,
  used_at timestamptz,
  status invitation_status not null default 'PENDING',
  max_devices int not null default 1 check (max_devices >= 1),
  created_at timestamptz not null default now()
);

create index idx_invitations_token on invitations (token);
create index idx_invitations_status on invitations (status);

alter table profiles
  add constraint fk_profiles_invitation foreign key (invitation_id) references invitations (id);

-- ---------------------------------------------------------------------
-- authorized_devices — device binding, independent of the APK file itself
-- ---------------------------------------------------------------------

create table authorized_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  device_identifier text not null,
  device_name text not null default 'Appareil inconnu',
  platform text not null default 'android',
  status device_status not null default 'ACTIVE',
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, device_identifier)
);

create index idx_authorized_devices_user_id on authorized_devices (user_id);
create index idx_authorized_devices_status on authorized_devices (status);

-- ---------------------------------------------------------------------
-- admin_logs — full audit trail of every administrative action
-- ---------------------------------------------------------------------

create table admin_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references admin_users (id),
  action text not null,
  target_type text,
  target_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_admin_logs_admin_id on admin_logs (admin_id, created_at desc);
create index idx_admin_logs_action on admin_logs (action);

-- ---------------------------------------------------------------------
-- game_settings — singleton row controlling the demo game engine
-- ---------------------------------------------------------------------

create table game_settings (
  id smallint primary key default 1 check (id = 1),
  demo_mode demo_mode_type not null default 'AUTOMATIC',
  next_manual_target_multiplier numeric(10, 2),
  betting_duration_seconds int not null default 7,
  min_bet numeric(14, 2) not null default 100,
  max_bet numeric(14, 2) not null default 50000,
  house_edge_percent numeric(5, 2) not null default 3.00,
  updated_by uuid references admin_users (id),
  updated_at timestamptz not null default now()
);

insert into game_settings (id) values (1);

-- ---------------------------------------------------------------------
-- app_settings — singleton row controlling APK version gating
-- ---------------------------------------------------------------------

create table app_settings (
  id smallint primary key default 1 check (id = 1),
  current_version text not null default '1.0.0',
  minimum_supported_version text not null default '1.0.0',
  download_url text not null default '',
  maintenance_mode boolean not null default false,
  updated_by uuid references admin_users (id),
  updated_at timestamptz not null default now()
);

insert into app_settings (id) values (1);
