import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_models.dart';
import 'supabase_service.dart';

/// Staff operations for the in-app admin area. Same queries and RPCs as
/// the web dashboard (admin/src/services/*.ts): reads are filtered by RLS,
/// writes go through SECURITY DEFINER functions that re-check every
/// permission and log to admin_logs. Nothing here is trusted client-side.
class AdminService {
  SupabaseClient get _client => SupabaseService.client;

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  static double _num(Object? value) => (value as num?)?.toDouble() ?? 0;

  /// Null when the signed-in account is not an active staff member.
  Future<AdminAccount?> fetchMyAdminAccount() async {
    final uid = _client.auth.currentSession?.user.id;
    if (uid == null) return null;

    final row = await _client
        .from('admin_users')
        .select('id, role, display_name, is_active')
        .eq('id', uid)
        .maybeSingle();
    if (row == null || row['is_active'] != true) return null;

    final role = row['role'] as String;
    var permissions = <String>{};
    if (role != 'SUPER_ADMIN') {
      final rows = await _client
          .from('admin_permissions')
          .select('permission')
          .eq('admin_id', uid);
      permissions = (rows as List)
          .map((r) => (r as Map<String, dynamic>)['permission'] as String)
          .toSet();
    }

    return AdminAccount(
      id: uid,
      role: role,
      displayName: row['display_name'] as String?,
      permissions: permissions,
    );
  }

  // -------------------------------------------------------------------
  // Dashboard
  // -------------------------------------------------------------------

  Future<DashboardOverview> fetchDashboardOverview() async {
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();

    final results = await Future.wait([
      _client
          .from('bets')
          .select('user_id, amount')
          .gte('placed_at', todayStart),
      _client
          .from('transactions')
          .select('amount')
          .eq('type', 'CASHOUT')
          .gte('created_at', todayStart),
      _client.from('profiles').select('id'),
      _client.from('authorized_devices').select('id').eq('status', 'ACTIVE'),
    ]);

    final bets = (results[0] as List).cast<Map<String, dynamic>>();
    final cashouts = (results[1] as List).cast<Map<String, dynamic>>();

    return DashboardOverview(
      activePlayersToday: bets.map((b) => b['user_id']).toSet().length,
      totalWageredToday: bets.fold(0, (sum, b) => sum + _num(b['amount'])),
      totalPaidOutToday: cashouts.fold(
        0,
        (sum, t) => sum + _num(t['amount']).abs(),
      ),
      registeredPlayers: (results[2] as List).length,
      activeDevices: (results[3] as List).length,
    );
  }

  // -------------------------------------------------------------------
  // Game
  // -------------------------------------------------------------------

  Future<GameSettings?> fetchGameSettings() async {
    final row = await _client
        .from('game_settings')
        .select()
        .eq('id', 1)
        .maybeSingle();
    return row == null ? null : GameSettings.fromJson(row);
  }

  Future<void> forceCrash() => _client.rpc('admin_force_crash');

  Future<void> updateGameSettings(GameSettings settings) {
    return _client.rpc(
      'update_game_operational_settings',
      params: {
        'p_betting_duration_seconds': settings.bettingDurationSeconds,
        'p_min_bet': settings.minBet,
        'p_max_bet': settings.maxBet,
        'p_house_edge_percent': settings.houseEdgePercent,
      },
    );
  }

  // -------------------------------------------------------------------
  // Players
  // -------------------------------------------------------------------

  Future<List<AdminPlayer>> fetchPlayers() async {
    final results = await Future.wait([
      _client.from('profiles').select().order('created_at', ascending: false),
      _client.from('wallets').select('user_id, balance'),
      _client.from('authorized_devices').select('user_id, last_seen'),
    ]);

    final balances = {
      for (final w in (results[1] as List).cast<Map<String, dynamic>>())
        w['user_id'] as String: _num(w['balance']),
    };
    final lastSeen = <String, DateTime>{};
    for (final d in (results[2] as List).cast<Map<String, dynamic>>()) {
      final userId = d['user_id'] as String;
      final seen = _date(d['last_seen']);
      if (seen == null) continue;
      final current = lastSeen[userId];
      if (current == null || seen.isAfter(current)) lastSeen[userId] = seen;
    }

    return (results[0] as List).cast<Map<String, dynamic>>().map((p) {
      final id = p['id'] as String;
      return AdminPlayer(
        id: id,
        email: p['email'] as String,
        displayName: p['display_name'] as String?,
        status: p['status'] as String,
        balance: balances[id] ?? 0,
        maxDevices: (p['max_devices'] as num?)?.toInt() ?? 1,
        lastDeviceActivity: lastSeen[id],
        createdAt: DateTime.parse(p['created_at'] as String),
      );
    }).toList();
  }

  Future<List<AdminTransaction>> fetchPlayerTransactions(String userId) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .map((r) => AdminTransaction.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Creates a player login through the create-player Edge Function.
  /// [login] is an e-mail or a simple identifier (see PlayerLogin).
  Future<void> createPlayer({
    required String login,
    required String password,
    required String displayName,
    int maxDevices = 1,
  }) async {
    await _client.functions.invoke(
      'create-player',
      body: {
        'action': 'create',
        'login': login,
        'password': password,
        'display_name': displayName,
        'max_devices': maxDevices,
      },
    );
  }

  Future<void> setPlayerPassword(String userId, String password) async {
    await _client.functions.invoke(
      'create-player',
      body: {'action': 'set_password', 'user_id': userId, 'password': password},
    );
  }

  Future<void> setPlayerMaxDevices(String userId, int maxDevices) {
    return _client.rpc(
      'admin_set_player_max_devices',
      params: {'p_user_id': userId, 'p_max_devices': maxDevices},
    );
  }

  Future<void> blockPlayer(String userId) =>
      _client.rpc('admin_block_user', params: {'p_user_id': userId});

  Future<void> unblockPlayer(String userId) =>
      _client.rpc('admin_unblock_user', params: {'p_user_id': userId});

  Future<void> adjustBalance(String userId, double amount, String reason) {
    return _client.rpc(
      'admin_adjust_balance',
      params: {'p_user_id': userId, 'p_amount': amount, 'p_reason': reason},
    );
  }

  // -------------------------------------------------------------------
  // Devices
  // -------------------------------------------------------------------

  Future<List<AdminDevice>> fetchDevices() async {
    final results = await Future.wait([
      _client
          .from('authorized_devices')
          .select()
          .order('last_seen', ascending: false),
      _client.from('profiles').select('id, display_name, email'),
    ]);
    final owners = {
      for (final p in (results[1] as List).cast<Map<String, dynamic>>())
        p['id'] as String:
            (p['display_name'] as String?) ?? (p['email'] as String),
    };
    return (results[0] as List).cast<Map<String, dynamic>>().map((d) {
      return AdminDevice(
        id: d['id'] as String,
        deviceName: d['device_name'] as String?,
        platform: d['platform'] as String?,
        status: d['status'] as String,
        lastSeen: _date(d['last_seen']),
        ownerLabel: owners[d['user_id']] ?? 'Utilisateur',
      );
    }).toList();
  }

  Future<void> setDeviceStatus(String deviceId, String status) {
    return _client.rpc(
      'admin_set_device_status',
      params: {'p_device_id': deviceId, 'p_status': status},
    );
  }

  // -------------------------------------------------------------------
  // Sub-admins (SUPER_ADMIN only, enforced server-side)
  // -------------------------------------------------------------------

  Future<List<SubAdmin>> fetchSubAdmins() async {
    final results = await Future.wait([
      _client
          .from('admin_users')
          .select()
          .eq('role', 'SOUS_ADMIN')
          .order('created_at', ascending: false),
      _client.from('admin_permissions').select('admin_id, permission'),
    ]);
    final permissions = <String, Set<String>>{};
    for (final p in (results[1] as List).cast<Map<String, dynamic>>()) {
      permissions
          .putIfAbsent(p['admin_id'] as String, () => <String>{})
          .add(p['permission'] as String);
    }
    return (results[0] as List).cast<Map<String, dynamic>>().map((a) {
      final id = a['id'] as String;
      return SubAdmin(
        id: id,
        displayName: a['display_name'] as String?,
        isActive: a['is_active'] as bool,
        permissions: permissions[id] ?? const {},
        createdAt: DateTime.parse(a['created_at'] as String),
      );
    }).toList();
  }

  Future<void> createSubAdmin({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _client.functions.invoke(
      'create-sub-admin',
      body: {'email': email, 'password': password, 'display_name': displayName},
    );
  }

  Future<void> setSubAdminPermissions(String adminId, Set<String> permissions) {
    return _client.rpc(
      'set_sub_admin_permissions',
      params: {'p_admin_id': adminId, 'p_permissions': permissions.toList()},
    );
  }

  Future<void> deactivateSubAdmin(String adminId) =>
      _client.rpc('admin_deactivate_sub', params: {'p_admin_id': adminId});

  Future<void> reactivateSubAdmin(String adminId) =>
      _client.rpc('admin_reactivate_sub', params: {'p_admin_id': adminId});

  Future<void> deleteSubAdmin(String adminId) =>
      _client.rpc('admin_delete_sub', params: {'p_admin_id': adminId});

  // -------------------------------------------------------------------
  // Statistics
  // -------------------------------------------------------------------

  static const _statisticsDays = 14;
  static const _statisticsRowLimit = 3000;
  static const _bucketDefinitions = [
    ('1.00–1.49x', 1.0, 1.5),
    ('1.50–1.99x', 1.5, 2.0),
    ('2.00–2.99x', 2.0, 3.0),
    ('3.00–4.99x', 3.0, 5.0),
    ('5.00–9.99x', 5.0, 10.0),
    ('10x+', 10.0, double.infinity),
  ];

  Future<AdminStatistics> fetchStatistics() async {
    final now = DateTime.now();
    final firstDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: _statisticsDays - 1));
    final since = firstDay.toUtc().toIso8601String();

    final results = await Future.wait([
      _client
          .from('game_rounds_public')
          .select('created_at, status, crash_multiplier')
          .gte('created_at', since)
          .limit(_statisticsRowLimit),
      _client
          .from('bets')
          .select('user_id, amount, placed_at')
          .gte('placed_at', since)
          .limit(_statisticsRowLimit),
      _client
          .from('transactions')
          .select('amount, created_at')
          .eq('type', 'CASHOUT')
          .gte('created_at', since)
          .limit(_statisticsRowLimit),
      _client.from('profiles').select('id, display_name, email'),
    ]);

    DateTime dayOf(Object? iso) {
      final local = DateTime.parse(iso as String).toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    final days = [
      for (var i = 0; i < _statisticsDays; i++)
        DateTime(firstDay.year, firstDay.month, firstDay.day + i),
    ];
    final rounds = {for (final d in days) d: 0};
    final wagered = {for (final d in days) d: 0.0};
    final paid = {for (final d in days) d: 0.0};
    final buckets = {for (final b in _bucketDefinitions) b.$1: 0};

    for (final r in (results[0] as List).cast<Map<String, dynamic>>()) {
      final day = dayOf(r['created_at']);
      if (rounds.containsKey(day)) rounds[day] = rounds[day]! + 1;
      final crash = (r['crash_multiplier'] as num?)?.toDouble();
      if (crash == null) continue;
      for (final b in _bucketDefinitions) {
        if (crash >= b.$2 && crash < b.$3) {
          buckets[b.$1] = buckets[b.$1]! + 1;
          break;
        }
      }
    }

    final wageredByUser = <String, double>{};
    for (final b in (results[1] as List).cast<Map<String, dynamic>>()) {
      final day = dayOf(b['placed_at']);
      final amount = _num(b['amount']);
      if (wagered.containsKey(day)) wagered[day] = wagered[day]! + amount;
      final userId = b['user_id'] as String;
      wageredByUser[userId] = (wageredByUser[userId] ?? 0) + amount;
    }

    for (final t in (results[2] as List).cast<Map<String, dynamic>>()) {
      final day = dayOf(t['created_at']);
      if (paid.containsKey(day)) {
        paid[day] = paid[day]! + _num(t['amount']).abs();
      }
    }

    final names = {
      for (final p in (results[3] as List).cast<Map<String, dynamic>>())
        p['id'] as String:
            (p['display_name'] as String?) ?? (p['email'] as String),
    };
    final topPlayers =
        wageredByUser.entries
            .map(
              (e) => TopPlayer(
                label: names[e.key] ?? 'Utilisateur',
                totalWagered: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalWagered.compareTo(a.totalWagered));

    return AdminStatistics(
      days: [
        for (final d in days.reversed)
          DailyStatistics(
            day: d,
            rounds: rounds[d]!,
            wagered: wagered[d]!,
            paidOut: paid[d]!,
          ),
      ],
      buckets: [
        for (final b in _bucketDefinitions)
          MultiplierBucket(label: b.$1, count: buckets[b.$1]!),
      ],
      topPlayers: topPlayers.take(10).toList(),
    );
  }

  // -------------------------------------------------------------------
  // Logs
  // -------------------------------------------------------------------

  static const logsPageSize = 25;

  Future<List<AdminLogEntry>> fetchLogsPage(int page) async {
    final from = page * logsPageSize;
    final logs =
        (await _client
                    .from('admin_logs')
                    .select()
                    .order('created_at', ascending: false)
                    .range(from, from + logsPageSize - 1)
                as List)
            .cast<Map<String, dynamic>>();

    final adminIds = logs.map((l) => l['admin_id'] as String).toSet().toList();
    var names = <String, String?>{};
    if (adminIds.isNotEmpty) {
      final admins = await _client
          .from('admin_users')
          .select('id, display_name')
          .inFilter('id', adminIds);
      names = {
        for (final a in (admins as List).cast<Map<String, dynamic>>())
          a['id'] as String: a['display_name'] as String?,
      };
    }

    return logs
        .map(
          (l) => AdminLogEntry(
            action: l['action'] as String,
            targetType: l['target_type'] as String?,
            adminLabel: names[l['admin_id']] ?? 'Administrateur',
            metadata: l['metadata'] as Map<String, dynamic>?,
            createdAt: DateTime.parse(l['created_at'] as String),
          ),
        )
        .toList();
  }

  // -------------------------------------------------------------------
  // App settings
  // -------------------------------------------------------------------

  Future<AppSettings?> fetchAppSettings() async {
    final row = await _client
        .from('app_settings')
        .select()
        .eq('id', 1)
        .maybeSingle();
    return row == null ? null : AppSettings.fromJson(row);
  }

  Future<void> updateAppSettings(AppSettings settings) {
    return _client.rpc(
      'update_app_settings',
      params: {
        'p_current_version': settings.currentVersion,
        'p_minimum_supported_version': settings.minimumSupportedVersion,
        'p_download_url': settings.downloadUrl,
        'p_maintenance_mode': settings.maintenanceMode,
      },
    );
  }
}
