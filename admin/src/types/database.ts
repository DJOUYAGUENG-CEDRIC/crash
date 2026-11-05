// Hand-written mirror of the CRASHX Supabase Postgres schema.
// This file intentionally matches the schema 1:1 — do not add fields that
// don't exist server-side, and do not rename snake_case columns.

export type AccountStatus = 'ACTIVE' | 'BLOCKED';
export type AdminRole = 'SUPER_ADMIN' | 'SOUS_ADMIN';
export type AdminPermission =
  | 'VIEW_DASHBOARD'
  | 'VIEW_USERS'
  | 'VIEW_STATISTICS'
  | 'VIEW_GAME'
  | 'CONTROL_GAME'
  | 'CONTROL_DEMO_MULTIPLIER'
  | 'VIEW_BETS'
  | 'MANAGE_USERS'
  | 'BLOCK_USERS'
  | 'MANAGE_DEVICES'
  | 'CREATE_INVITATIONS'
  | 'MANAGE_INVITATIONS'
  | 'VIEW_LOGS'
  | 'VIEW_SETTINGS';
export type RoundStatus = 'WAITING' | 'BETTING' | 'RUNNING' | 'CRASHED' | 'RESULT';
export type DemoModeType = 'AUTOMATIC' | 'MANUAL';
export type BetStatus = 'PENDING' | 'ACTIVE' | 'CASHED_OUT' | 'LOST' | 'CANCELLED';
export type TransactionType = 'BET' | 'CASHOUT' | 'BONUS_DEMO' | 'ADJUSTMENT';
export type InvitationStatus = 'PENDING' | 'USED' | 'EXPIRED' | 'REVOKED';
export type DeviceStatus = 'ACTIVE' | 'BLOCKED' | 'REVOKED';

/** All 14 admin_permission values, in the canonical display order. */
export const ALL_PERMISSIONS: AdminPermission[] = [
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
  'VIEW_SETTINGS',
];

export const PERMISSION_LABELS: Record<AdminPermission, string> = {
  VIEW_DASHBOARD: "Voir le tableau de bord",
  VIEW_USERS: 'Voir les utilisateurs',
  VIEW_STATISTICS: 'Voir les statistiques',
  VIEW_GAME: 'Voir le jeu en direct',
  CONTROL_GAME: 'Contrôler le jeu (arrêt, réglages)',
  CONTROL_DEMO_MULTIPLIER: 'Contrôler le multiplicateur',
  VIEW_BETS: 'Voir les mises',
  MANAGE_USERS: 'Gérer les utilisateurs (ajuster le solde)',
  BLOCK_USERS: 'Bloquer / débloquer des utilisateurs',
  MANAGE_DEVICES: 'Gérer les appareils',
  CREATE_INVITATIONS: 'Créer des comptes joueurs',
  MANAGE_INVITATIONS: 'Gérer les invitations (ancien mode)',
  VIEW_LOGS: "Voir les journaux d'activité",
  VIEW_SETTINGS: 'Voir les paramètres',
};

export type ProfileRow = {
  id: string;
  email: string;
  display_name: string | null;
  status: AccountStatus;
  invitation_id: string | null;
  created_at: string;
  updated_at: string;
}

export type AdminUserRow = {
  id: string;
  role: AdminRole;
  display_name: string | null;
  created_by: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export type AdminPermissionRow = {
  admin_id: string;
  permission: AdminPermission;
  granted_by: string;
  granted_at: string;
}

export type WalletRow = {
  user_id: string;
  balance: number;
  currency: string;
  updated_at: string;
}

export type GameRoundRow = {
  id: string;
  round_number: number;
  status: RoundStatus;
  demo_mode: DemoModeType;
  target_multiplier: number | null;
  crash_multiplier: number | null;
  scheduled_by: string | null;
  betting_started_at: string | null;
  running_started_at: string | null;
  crashed_at: string | null;
  total_bets_amount: number;
  total_players: number;
  created_at: string;
}

export type BetRow = {
  id: string;
  round_id: string;
  user_id: string;
  slot: 1 | 2;
  amount: number;
  status: BetStatus;
  auto_cashout_multiplier: number | null;
  cashout_multiplier: number | null;
  payout: number | null;
  placed_at: string;
  cashed_out_at: string | null;
  created_at: string;
}

export type TransactionRow = {
  id: string;
  user_id: string;
  type: TransactionType;
  amount: number;
  balance_after: number;
  bet_id: string | null;
  round_id: string | null;
  created_by: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
}

export type InvitationRow = {
  id: string;
  token: string;
  invited_name: string;
  invited_email: string | null;
  user_id: string | null;
  created_by: string;
  expires_at: string;
  used_at: string | null;
  status: InvitationStatus;
  max_devices: number;
  created_at: string;
}

export type AuthorizedDeviceRow = {
  id: string;
  user_id: string;
  device_identifier: string;
  device_name: string | null;
  platform: string | null;
  status: DeviceStatus;
  first_seen: string;
  last_seen: string;
  created_at: string;
}

export type AdminLogRow = {
  id: string;
  admin_id: string;
  action: string;
  target_type: string | null;
  target_id: string | null;
  metadata: Record<string, unknown> | null;
  created_at: string;
}

export type GameSettingsRow = {
  id: number;
  demo_mode: DemoModeType;
  next_manual_target_multiplier: number | null;
  betting_duration_seconds: number;
  min_bet: number;
  max_bet: number;
  house_edge_percent: number;
  updated_by: string | null;
  updated_at: string;
}

export type DemoRoundPredictionRow = {
  round_id: string;
  round_number: number;
  status: RoundStatus;
  target_multiplier: number;
  crash_multiplier: number | null;
  created_at: string;
  updated_at: string;
}

export type AppSettingsRow = {
  id: number;
  current_version: string;
  minimum_supported_version: string;
  download_url: string;
  maintenance_mode: boolean;
  updated_by: string | null;
  updated_at: string;
}

// ---------------------------------------------------------------------------
// supabase-js Database typing
// ---------------------------------------------------------------------------

type TableDef<Row> = {
  Row: Row;
  Insert: Partial<Row>;
  Update: Partial<Row>;
  Relationships: [];
};

export interface Database {
  public: {
    Tables: {
      profiles: TableDef<ProfileRow>;
      admin_users: TableDef<AdminUserRow>;
      admin_permissions: TableDef<AdminPermissionRow>;
      wallets: TableDef<WalletRow>;
      game_rounds: TableDef<GameRoundRow>;
      bets: TableDef<BetRow>;
      transactions: TableDef<TransactionRow>;
      invitations: TableDef<InvitationRow>;
      authorized_devices: TableDef<AuthorizedDeviceRow>;
      admin_logs: TableDef<AdminLogRow>;
      game_settings: TableDef<GameSettingsRow>;
      demo_round_predictions: TableDef<DemoRoundPredictionRow>;
      app_settings: TableDef<AppSettingsRow>;
    };
    Views: Record<string, never>;
    Functions: {
      update_display_name: { Args: { p_display_name: string }; Returns: void };
      admin_deactivate_sub: { Args: { p_admin_id: string }; Returns: void };
      admin_reactivate_sub: { Args: { p_admin_id: string }; Returns: void };
      admin_update_sub: { Args: { p_admin_id: string; p_display_name: string }; Returns: void };
      admin_delete_sub: { Args: { p_admin_id: string }; Returns: void };
      set_sub_admin_permissions: {
        Args: { p_admin_id: string; p_permissions: AdminPermission[] };
        Returns: void;
      };
      admin_block_user: { Args: { p_user_id: string }; Returns: void };
      admin_unblock_user: { Args: { p_user_id: string }; Returns: void };
      admin_adjust_balance: {
        Args: { p_user_id: string; p_amount: number; p_reason: string };
        Returns: void;
      };
      admin_set_device_status: {
        Args: { p_device_id: string; p_status: DeviceStatus };
        Returns: void;
      };
      create_invitation: {
        Args: {
          p_invited_name: string;
          p_invited_email?: string | null;
          p_expires_hours?: number;
          p_max_devices?: number;
        };
        Returns: InvitationRow;
      };
      revoke_invitation: { Args: { p_invitation_id: string }; Returns: void };
      admin_force_crash: { Args: Record<string, never>; Returns: void };
      update_game_operational_settings: {
        Args: {
          p_betting_duration_seconds: number;
          p_min_bet: number;
          p_max_bet: number;
          p_house_edge_percent: number;
        };
        Returns: void;
      };
      update_app_settings: {
        Args: {
          p_current_version: string;
          p_minimum_supported_version: string;
          p_download_url: string;
          p_maintenance_mode: boolean;
        };
        Returns: void;
      };
    };
    Enums: {
      account_status: AccountStatus;
      admin_role: AdminRole;
      admin_permission: AdminPermission;
      round_status: RoundStatus;
      demo_mode_type: DemoModeType;
      bet_status: BetStatus;
      transaction_type: TransactionType;
      invitation_status: InvitationStatus;
      device_status: DeviceStatus;
    };
  };
}
