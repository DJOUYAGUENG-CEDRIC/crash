import 'dart:math' as math;

import 'package:crashx/models/enums.dart';
import 'package:crashx/models/game_round.dart';
import 'package:flutter_test/flutter_test.dart';

GameRound _round({required RoundStatus status, DateTime? runningStartedAt, double? crashMultiplier}) {
  return GameRound(
    id: 'round-1',
    roundNumber: 1,
    status: status,
    crashMultiplier: crashMultiplier,
    bettingStartedAt: null,
    runningStartedAt: runningStartedAt,
    crashedAt: null,
    totalBetsAmount: 0,
    totalPlayers: 0,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('GameRound.liveMultiplier', () {
    const growthRate = 0.06;

    test('is 1.0 the instant the round starts running (t=0)', () {
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final round = _round(status: RoundStatus.running, runningStartedAt: now);
      expect(round.liveMultiplier(growthRate, now), closeTo(1.0, 1e-9));
    });

    test('matches e^(rate*t) at a known elapsed time (mirrors the server formula)', () {
      final start = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final round = _round(status: RoundStatus.running, runningStartedAt: start);
      final tenSecondsLater = start.add(const Duration(seconds: 10));

      final result = round.liveMultiplier(growthRate, tenSecondsLater);
      final expected = math.exp(growthRate * 10); // ~1.8221188...

      expect(result, closeTo(expected, 1e-9));
      expect(result, greaterThan(1.0));
    });

    test('is monotonically increasing over time while running', () {
      final start = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final round = _round(status: RoundStatus.running, runningStartedAt: start);

      final at5s = round.liveMultiplier(growthRate, start.add(const Duration(seconds: 5)));
      final at15s = round.liveMultiplier(growthRate, start.add(const Duration(seconds: 15)));

      expect(at15s, greaterThan(at5s));
    });

    test('is 1.0 when the round is not running, regardless of the clock', () {
      final round = _round(status: RoundStatus.betting, runningStartedAt: null);
      expect(round.liveMultiplier(growthRate, DateTime.now()), 1.0);
    });

    test('is 1.0 when running but runningStartedAt is somehow null', () {
      final round = _round(status: RoundStatus.running, runningStartedAt: null);
      expect(round.liveMultiplier(growthRate, DateTime.now()), 1.0);
    });

    test('is 1.0 for a crashed round (liveMultiplier is only meaningful while running)', () {
      final start = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final round = _round(status: RoundStatus.crashed, runningStartedAt: start, crashMultiplier: 3.45);
      expect(round.liveMultiplier(growthRate, start.add(const Duration(seconds: 20))), 1.0);
    });
  });
}
