// Admin-side mirrors of the Supabase rows used by the in-app admin area.
// They map 1:1 to the tables/RPCs already used by the web dashboard
// (admin/src/types/database.ts). Every write still goes through the
// SECURITY DEFINER RPCs, which re-check permissions server-side.

class AdminPermissions {
  AdminPermissions._();

  static const viewDashboard = 'VIEW_DASHBOARD';
  static const viewUsers = 'VIEW_USERS';
  static const viewStatistics = 'VIEW_STATISTICS';
  static const viewGame = 'VIEW_GAME';
  static const controlGame = 'CONTROL_GAME';
  static const controlDemoMultiplier = 'CONTROL_DEMO_MULTIPLIER';
  static const viewBets = 'VIEW_BETS';
  static const manageUsers = 'MANAGE_USERS';
  static const blockUsers = 'BLOCK_USERS';
  static const manageDevices = 'MANAGE_DEVICES';
  static const createInvitations = 'CREATE_INVITATIONS';
  static const manageInvitations = 'MANAGE_INVITATIONS';
  static const viewLogs = 'VIEW_LOGS';
  static const viewSettings = 'VIEW_SETTINGS';

  static const all = [
    viewDashboard,
    viewUsers,
    viewStatistics,
    viewGame,
    controlGame,
    controlDemoMultiplier,
    viewBets,
    manageUsers,
    blockUsers,
    manageDevices,
    createInvitations,
    manageInvitations,
    viewLogs,
    viewSettings,
  ];

  static const labels = {
    viewDashboard: 'Voir le tableau de bord',
    viewUsers: 'Voir les utilisateurs',
    viewStatistics: 'Voir les statistiques',
    viewGame: 'Voir le jeu en direct',
    controlGame: 'Contrôler le jeu (arrêt, réglages)',
    controlDemoMultiplier: 'Contrôler le multiplicateur',
    viewBets: 'Voir les mises',
    manageUsers: 'Gérer les utilisateurs (ajuster le solde)',
    blockUsers: 'Bloquer / débloquer des utilisateurs',
    manageDevices: 'Gérer les appareils',
    createInvitations: 'Créer des comptes joueurs',
    manageInvitations: 'Gérer les invitations (ancien mode)',
    viewLogs: "Voir les journaux d'activité",
    viewSettings: 'Voir les paramètres',
  };
}

double _num(Object? value) => (value as num?)?.toDouble() ?? 0;

/// The signed-in staff account. Null in providers means "not an admin".
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.role,
    required this.displayName,
    required this.permissions,
  });

  final String id;
  final String role;
  final String? displayName;
  final Set<String> permissions;

  bool get isSuperAdmin => role == 'SUPER_ADMIN';

  bool can(String permission) =>
      isSuperAdmin || permissions.contains(permission);

  bool canAny(Iterable<String> permissions) => permissions.any(can);
}

class AdminPlayer {
  const AdminPlayer({
    required this.id,
    required this.email,
    required this.displayName,
    required this.status,
    required this.balance,
    required this.maxDevices,
    required this.lastDeviceActivity,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final String status;
  final double balance;
  final int maxDevices;
  final DateTime? lastDeviceActivity;
  final DateTime createdAt;

  bool get isBlocked => status == 'BLOCKED';
  String get label => displayName ?? email;
}

class AdminTransaction {
  const AdminTransaction({
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> json) =>
      AdminTransaction(
        type: json['type'] as String,
        amount: _num(json['amount']),
        balanceAfter: _num(json['balance_after']),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String type;
  final double amount;
  final double balanceAfter;
  final DateTime createdAt;
}

class AdminDevice {
  const AdminDevice({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.status,
    required this.lastSeen,
    required this.ownerLabel,
  });

  final String id;
  final String? deviceName;
  final String? platform;
  final String status;
  final DateTime? lastSeen;
  final String ownerLabel;
}

class SubAdmin {
  const SubAdmin({
    required this.id,
    required this.displayName,
    required this.isActive,
    required this.permissions,
    required this.createdAt,
  });

  final String id;
  final String? displayName;
  final bool isActive;
  final Set<String> permissions;
  final DateTime createdAt;
}

class AdminLogEntry {
  const AdminLogEntry({
    required this.action,
    required this.targetType,
    required this.adminLabel,
    required this.metadata,
    required this.createdAt,
  });

  final String action;
  final String? targetType;
  final String adminLabel;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
}

class GameSettings {
  const GameSettings({
    required this.bettingDurationSeconds,
    required this.minBet,
    required this.maxBet,
    required this.houseEdgePercent,
  });

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
    bettingDurationSeconds: (json['betting_duration_seconds'] as num).toInt(),
    minBet: _num(json['min_bet']),
    maxBet: _num(json['max_bet']),
    houseEdgePercent: _num(json['house_edge_percent']),
  );

  final int bettingDurationSeconds;
  final double minBet;
  final double maxBet;
  final double houseEdgePercent;
}

class AppSettings {
  const AppSettings({
    required this.currentVersion,
    required this.minimumSupportedVersion,
    required this.downloadUrl,
    required this.maintenanceMode,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    currentVersion: json['current_version'] as String,
    minimumSupportedVersion: json['minimum_supported_version'] as String,
    downloadUrl: json['download_url'] as String,
    maintenanceMode: json['maintenance_mode'] as bool,
  );

  final String currentVersion;
  final String minimumSupportedVersion;
  final String downloadUrl;
  final bool maintenanceMode;
}

class DashboardOverview {
  const DashboardOverview({
    required this.activePlayersToday,
    required this.totalWageredToday,
    required this.totalPaidOutToday,
    required this.registeredPlayers,
    required this.activeDevices,
  });

  final int activePlayersToday;
  final double totalWageredToday;
  final double totalPaidOutToday;
  final int registeredPlayers;
  final int activeDevices;
}

class DailyStatistics {
  const DailyStatistics({
    required this.day,
    required this.rounds,
    required this.wagered,
    required this.paidOut,
  });

  final DateTime day;
  final int rounds;
  final double wagered;
  final double paidOut;
}

class MultiplierBucket {
  const MultiplierBucket({required this.label, required this.count});

  final String label;
  final int count;
}

class TopPlayer {
  const TopPlayer({required this.label, required this.totalWagered});

  final String label;
  final double totalWagered;
}

class AdminStatistics {
  const AdminStatistics({
    required this.days,
    required this.buckets,
    required this.topPlayers,
  });

  final List<DailyStatistics> days;
  final List<MultiplierBucket> buckets;
  final List<TopPlayer> topPlayers;
}
