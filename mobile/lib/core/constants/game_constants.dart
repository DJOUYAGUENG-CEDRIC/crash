/// Shared game-engine constants. GROWTH_RATE must stay in sync with
/// current_multiplier() in supabase/migrations/0004_game_engine_functions.sql
/// — the server is authoritative for cashouts, this is only used to
/// *animate* the multiplier client-side between realtime updates.
class GameConstants {
  GameConstants._();

  static const double growthRate = 0.06;
  static const double maxMultiplier = 15.0;
  static const int bettingDurationSeconds = 7;

  static const List<double> quickBetAmounts = [
    200,
    700,
    2000,
    5000,
    20000,
    70000,
  ];

  static const double minAutoCashoutMultiplier = 1.01;
  static const double maxAutoCashoutMultiplier = maxMultiplier;

  /// Player-facing round phase, mirrors the Postgres `round_status` enum.
  static const List<String> roundStatuses = [
    'WAITING',
    'BETTING',
    'RUNNING',
    'CRASHED',
    'RESULT',
  ];
}
