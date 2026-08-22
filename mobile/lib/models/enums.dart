// Mirrors of the Postgres enum types (supabase/migrations/0001). Kept as
// plain Dart enums with string (de)serialization — no code generation.

enum AccountStatus {
  active,
  blocked;

  static AccountStatus fromJson(String value) => switch (value) {
    'ACTIVE' => AccountStatus.active,
    'BLOCKED' => AccountStatus.blocked,
    _ => throw ArgumentError('Unknown AccountStatus: $value'),
  };
}

enum RoundStatus {
  waiting,
  betting,
  running,
  crashed,
  result;

  static RoundStatus fromJson(String value) => switch (value) {
    'WAITING' => RoundStatus.waiting,
    'BETTING' => RoundStatus.betting,
    'RUNNING' => RoundStatus.running,
    'CRASHED' => RoundStatus.crashed,
    'RESULT' => RoundStatus.result,
    _ => throw ArgumentError('Unknown RoundStatus: $value'),
  };
}

enum BetStatus {
  pending,
  active,
  cashedOut,
  lost,
  cancelled;

  static BetStatus fromJson(String value) => switch (value) {
    'PENDING' => BetStatus.pending,
    'ACTIVE' => BetStatus.active,
    'CASHED_OUT' => BetStatus.cashedOut,
    'LOST' => BetStatus.lost,
    'CANCELLED' => BetStatus.cancelled,
    _ => throw ArgumentError('Unknown BetStatus: $value'),
  };
}

enum TransactionType {
  bet,
  cashout,
  bonusDemo,
  adjustment;

  static TransactionType fromJson(String value) => switch (value) {
    'BET' => TransactionType.bet,
    'CASHOUT' => TransactionType.cashout,
    'BONUS_DEMO' => TransactionType.bonusDemo,
    'ADJUSTMENT' => TransactionType.adjustment,
    _ => throw ArgumentError('Unknown TransactionType: $value'),
  };
}
