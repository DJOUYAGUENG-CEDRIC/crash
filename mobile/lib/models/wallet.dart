class Wallet {
  final String userId;
  final double balance;
  final String currency;

  const Wallet({
    required this.userId,
    required this.balance,
    required this.currency,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
    userId: json['user_id'] as String,
    balance: (json['balance'] as num).toDouble(),
    currency: json['currency'] as String,
  );
}
