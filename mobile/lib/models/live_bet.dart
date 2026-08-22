import 'enums.dart';

/// Mirrors `live_bets_public` — a real, server-populated feed of who is
/// actually betting on the current round. Never fabricated data.
class LiveBet {
  final String id;
  final String roundId;
  final String displayName;
  final int slot;
  final double amount;
  final BetStatus status;
  final double? cashoutMultiplier;
  final double? payout;
  final DateTime placedAt;

  const LiveBet({
    required this.id,
    required this.roundId,
    required this.displayName,
    required this.slot,
    required this.amount,
    required this.status,
    required this.cashoutMultiplier,
    required this.payout,
    required this.placedAt,
  });

  factory LiveBet.fromJson(Map<String, dynamic> json) => LiveBet(
    id: json['id'] as String,
    roundId: json['round_id'] as String,
    displayName: json['display_name'] as String,
    slot: (json['slot'] as num).toInt(),
    amount: (json['amount'] as num).toDouble(),
    status: BetStatus.fromJson(json['status'] as String),
    cashoutMultiplier: (json['cashout_multiplier'] as num?)?.toDouble(),
    payout: (json['payout'] as num?)?.toDouble(),
    placedAt: DateTime.parse(json['placed_at'] as String),
  );
}
