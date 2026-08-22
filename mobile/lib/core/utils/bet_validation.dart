import '../constants/game_constants.dart';

/// Client-side validation helpers for the bet panel's inputs. The server
/// remains the ultimate authority (see GameService.placeBet's thrown
/// error codes in game_service.dart) — these only give instant,
/// offline-friendly feedback before a request is even sent, and keep the
/// clamping/validation logic out of the widget so it's independently
/// testable.
class BetValidation {
  BetValidation._();

  static const double minAmount = 100;
  static const double maxAmount = 1000000;

  /// Clamps a raw amount into the acceptable client-side range.
  static double clampAmount(double value) => value.clamp(minAmount, maxAmount).toDouble();

  /// Whether [value] is an acceptable auto-cashout multiplier. `null`
  /// means "auto-cashout disabled", which is always valid.
  static bool isValidAutoCashout(double? value) {
    if (value == null) return true;
    return value >= GameConstants.minAutoCashoutMultiplier;
  }
}
