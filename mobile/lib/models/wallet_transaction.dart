import 'enums.dart';

/// Named WalletTransaction (not Transaction) to avoid any confusion with
/// Dart/Supabase's own transaction concepts.
class WalletTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final double balanceAfter;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) => WalletTransaction(
    id: json['id'] as String,
    type: TransactionType.fromJson(json['type'] as String),
    amount: (json['amount'] as num).toDouble(),
    balanceAfter: (json['balance_after'] as num).toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
