import 'dart:math' as math;

import '../core/constants/game_constants.dart';
import 'enums.dart';

/// Mirrors `game_rounds_public` (never the raw `game_rounds` table —
/// players must never receive target_multiplier or a pre-crash
/// crash_multiplier, see supabase/migrations/0003_rls_policies.sql).
class GameRound {
  final String id;
  final int roundNumber;
  final RoundStatus status;
  final double? targetMultiplier;
  final double? crashMultiplier;
  final int? countdown;
  final DateTime? bettingStartedAt;
  final DateTime? runningStartedAt;
  final DateTime? crashedAt;
  final double totalBetsAmount;
  final int totalPlayers;
  final DateTime createdAt;

  const GameRound({
    required this.id,
    required this.roundNumber,
    required this.status,
    this.targetMultiplier,
    required this.crashMultiplier,
    this.countdown,
    required this.bettingStartedAt,
    required this.runningStartedAt,
    required this.crashedAt,
    required this.totalBetsAmount,
    required this.totalPlayers,
    required this.createdAt,
  });

  factory GameRound.fromJson(Map<String, dynamic> json) => GameRound(
    id: json['id'] as String,
    roundNumber: (json['round_number'] as num).toInt(),
    status: RoundStatus.fromJson(json['status'] as String),
    targetMultiplier: _boundedMultiplier(json['target_multiplier'] as num?),
    crashMultiplier: _boundedMultiplier(json['crash_multiplier'] as num?),
    countdown: _boundedCountdown(json['countdown'] as num?),
    bettingStartedAt: json['betting_started_at'] == null
        ? null
        : DateTime.parse(json['betting_started_at'] as String),
    runningStartedAt: json['running_started_at'] == null
        ? null
        : DateTime.parse(json['running_started_at'] as String),
    crashedAt: json['crashed_at'] == null
        ? null
        : DateTime.parse(json['crashed_at'] as String),
    totalBetsAmount: (json['total_bets_amount'] as num).toDouble(),
    totalPlayers: (json['total_players'] as num).toInt(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  /// Client-side animation only — the server (current_multiplier() in
  /// 0004_game_engine_functions.sql) is authoritative for cashouts.
  /// Uses the same GROWTH_RATE constant so the displayed value tracks
  /// what the server will actually accept.
  double liveMultiplier(double growthRate, DateTime now) {
    if (status != RoundStatus.running || runningStartedAt == null) return 1.0;
    final elapsedSeconds =
        now.difference(runningStartedAt!).inMilliseconds / 1000.0;
    final calculated = math.exp(growthRate * elapsedSeconds);
    final target = targetMultiplier;
    return math.min(
      calculated,
      target == null
          ? GameConstants.maxMultiplier
          : math.min(target, GameConstants.maxMultiplier),
    );
  }
}

double? _boundedMultiplier(num? value) {
  if (value == null) return null;
  return value.toDouble().clamp(1.0, GameConstants.maxMultiplier);
}

int? _boundedCountdown(num? value) {
  if (value == null) return null;
  return value
      .toInt()
      .clamp(0, GameConstants.bettingDurationSeconds)
      .toInt();
}
