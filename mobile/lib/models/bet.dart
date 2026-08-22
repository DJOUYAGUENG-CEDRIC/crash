import 'enums.dart';

class Bet {
  final String id;
  final String roundId;
  final String userId;
  final int slot;
  final double amount;
  final BetStatus status;
  final double? autoCashoutMultiplier;
  final double? cashoutMultiplier;
  final double? payout;
  final DateTime placedAt;
  final DateTime? cashedOutAt;

  const Bet({
    required this.id,
    required this.roundId,
    required this.userId,
    required this.slot,
    required this.amount,
    required this.status,
    required this.autoCashoutMultiplier,
    required this.cashoutMultiplier,
    required this.payout,
    required this.placedAt,
    required this.cashedOutAt,
  });

  factory Bet.fromJson(Map<String, dynamic> json) => Bet(
    id: json['id'] as String,
    roundId: json['round_id'] as String,
    userId: json['user_id'] as String,
    slot: (json['slot'] as num).toInt(),
    amount: (json['amount'] as num).toDouble(),
    status: BetStatus.fromJson(json['status'] as String),
    autoCashoutMultiplier: (json['auto_cashout_multiplier'] as num?)?.toDouble(),
    cashoutMultiplier: (json['cashout_multiplier'] as num?)?.toDouble(),
    payout: (json['payout'] as num?)?.toDouble(),
    placedAt: DateTime.parse(json['placed_at'] as String),
    cashedOutAt: json['cashed_out_at'] == null ? null : DateTime.parse(json['cashed_out_at'] as String),
  );

  Bet copyWith({BetStatus? status, double? cashoutMultiplier, double? payout, DateTime? cashedOutAt}) => Bet(
    id: id,
    roundId: roundId,
    userId: userId,
    slot: slot,
    amount: amount,
    status: status ?? this.status,
    autoCashoutMultiplier: autoCashoutMultiplier,
    cashoutMultiplier: cashoutMultiplier ?? this.cashoutMultiplier,
    payout: payout ?? this.payout,
    placedAt: placedAt,
    cashedOutAt: cashedOutAt ?? this.cashedOutAt,
  );
}
