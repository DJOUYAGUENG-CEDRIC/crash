import 'package:crashx/core/utils/bet_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BetValidation.clampAmount', () {
    test('leaves an in-range amount untouched', () {
      expect(BetValidation.clampAmount(500), 500);
    });

    test('clamps below the minimum up to the minimum', () {
      expect(BetValidation.clampAmount(10), BetValidation.minAmount);
    });

    test('clamps above the maximum down to the maximum', () {
      expect(BetValidation.clampAmount(999999999), BetValidation.maxAmount);
    });
  });

  group('BetValidation.isValidAutoCashout', () {
    test('null (disabled) is always valid', () {
      expect(BetValidation.isValidAutoCashout(null), isTrue);
    });

    test('exactly the minimum multiplier is valid', () {
      expect(BetValidation.isValidAutoCashout(1.01), isTrue);
    });

    test('below the minimum multiplier is invalid', () {
      expect(BetValidation.isValidAutoCashout(1.0), isFalse);
      expect(BetValidation.isValidAutoCashout(0.5), isFalse);
    });

    test('a large multiplier is valid', () {
      expect(BetValidation.isValidAutoCashout(50), isTrue);
    });
  });
}
