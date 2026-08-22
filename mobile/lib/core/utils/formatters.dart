import 'package:intl/intl.dart';

/// Shared display formatters — keeps number/date presentation consistent
/// across every money-related and history label in the app.
class Formatters {
  Formatters._();

  static final NumberFormat _amount = NumberFormat.decimalPattern('fr_FR');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  /// e.g. 12500.0 -> "12 500"
  static String amount(double value) => _amount.format(value);

  /// e.g. 2.357 -> "2.36x"
  static String multiplier(double value) => '${value.toStringAsFixed(2)}x';

  /// e.g. -> "21/08/2026 14:05"
  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());
}
