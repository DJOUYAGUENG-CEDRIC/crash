import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/server_clock.dart';
import '../models/bet.dart';
import '../models/game_round.dart';
import '../models/live_bet.dart';
import 'supabase_service.dart';

/// All game state comes from the server. This service never computes a
/// balance, payout, or crash point — see supabase/migrations/0004.
class GameService {
  SupabaseClient get _client => SupabaseService.client;

  /// Live view of the current round. Reads game_rounds_public, which
  /// hides target_multiplier always and crash_multiplier until the
  /// round has actually crashed (see 0003_rls_policies.sql).
  Stream<GameRound?> watchCurrentRound() {
    final controller = StreamController<GameRound?>();
    GameRound? latest;
    var polling = false;

    void publish(List<Map<String, dynamic>> rows, {bool force = true}) {
      final next = rows.isEmpty ? null : GameRound.fromJson(rows.first);
      final changed =
          latest?.id != next?.id ||
          latest?.status != next?.status ||
          latest?.countdown != next?.countdown ||
          latest?.crashMultiplier != next?.crashMultiplier;
      latest = next;
      if (!controller.isClosed && (force || changed)) controller.add(next);
    }

    // Every device animates from the server's running_started_at, so align
    // this device's clock on the server before the first round arrives.
    unawaited(ServerClock.sync(_client));

    final realtimeSubscription = _client
        .from('game_rounds_public')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .listen(publish, onError: controller.addError);

    // Realtime normally delivers every transition immediately. Polling is a
    // lightweight fallback for phones that briefly lose any event, including
    // the transition from countdown to flight or from flight to crash.
    final watchdog = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (polling) return;
      polling = true;
      try {
        final rows = await _client
            .from('game_rounds_public')
            .select()
            .order('created_at', ascending: false)
            .limit(1);
        publish((rows as List).cast<Map<String, dynamic>>(), force: false);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      } finally {
        polling = false;
      }
    });

    controller.onCancel = () async {
      watchdog.cancel();
      await realtimeSubscription.cancel();
      await controller.close();
    };
    return controller.stream;
  }

  Future<List<GameRound>> fetchRecentRounds({int limit = 20}) async {
    final rows = await _client
        .from('game_rounds_public')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => GameRound.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// The signed-in player's bets on the shared current round only.
  Stream<List<Bet>> watchMyBetsForRound(String roundId, String userId) {
    return _client
        .from('bets')
        .stream(primaryKey: ['id'])
        .eq('round_id', roundId)
        .map(
          (rows) => rows
              .map(Bet.fromJson)
              .where((bet) => bet.userId == userId)
              .toList(),
        );
  }

  Future<Bet> placeBet({
    required String roundId,
    required int slot,
    required double amount,
    double? autoCashoutMultiplier,
  }) async {
    final row = await _client.rpc(
      'place_bet',
      params: {
        'p_round_id': roundId,
        'p_slot': slot,
        'p_amount': amount,
        'p_auto_cashout': autoCashoutMultiplier,
      },
    );
    return Bet.fromJson(row as Map<String, dynamic>);
  }

  Future<Bet> cashout(String betId) async {
    final row = await _client.rpc('cashout_bet', params: {'p_bet_id': betId});
    return Bet.fromJson(row as Map<String, dynamic>);
  }

  /// Real, server-populated "who's betting right now" feed for the
  /// given round — see live_bets_public in
  /// supabase/migrations/0007_live_bets_public.sql. Never fabricated.
  Stream<List<LiveBet>> watchLiveBetsForRound(String roundId) {
    return _client
        .from('live_bets_public')
        .stream(primaryKey: ['id'])
        .eq('round_id', roundId)
        .order('placed_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map((r) => LiveBet.fromJson(r)).toList());
  }

  Future<List<Bet>> fetchMyBetHistory(String userId, {int limit = 50}) async {
    final rows = await _client
        .from('bets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => Bet.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
