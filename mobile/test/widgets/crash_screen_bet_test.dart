import 'package:crashx/core/utils/formatters.dart';
import 'package:crashx/models/bet.dart';
import 'package:crashx/models/enums.dart';
import 'package:crashx/models/game_round.dart';
import 'package:crashx/providers/game_providers.dart';
import 'package:crashx/providers/service_providers.dart';
import 'package:crashx/screens/crash/crash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/fakes.dart';

// Note: both the BETTING and RUNNING stages of CrashScreen drive a
// continuous per-frame Ticker (the elapsed-seconds counter / the live
// multiplier+curve). `pumpAndSettle()` waits for no more frames to be
// scheduled, which never happens with a perpetual Ticker running — so
// every test below uses explicit `pump()` calls instead.

Widget _buildApp({
  required FakeGameService fakeGame,
  required GameRound? round,
  List<Bet> myBets = const [],
}) {
  return ProviderScope(
    overrides: [
      gameServiceProvider.overrideWithValue(fakeGame),
      currentRoundProvider.overrideWith((ref) => Stream.value(round)),
      recentRoundsProvider.overrideWith((ref) async => const []),
      myBetsForCurrentRoundProvider.overrideWith((ref) => Stream.value(myBets)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SizedBox(height: 900, child: CrashScreen())),
    ),
  );
}

void main() {
  testWidgets(
    'PLACER UN PARI places the default quick amount while betting is open',
    (tester) async {
      final fakeGame = FakeGameService();
      await tester.pumpWidget(
        _buildApp(
          fakeGame: fakeGame,
          round: sampleRound(status: RoundStatus.betting),
        ),
      );
      await tester.pump();

      final miserButtons = find.widgetWithText(
        ElevatedButton,
        'PLACER UN PARI',
      );
      expect(miserButtons, findsNWidgets(2));

      await tester.tap(miserButtons.first);
      await tester.pump();
      await tester.pump();

      expect(fakeGame.placeBetCalled, isTrue);
      expect(fakeGame.lastBetSlot, 1);
      expect(
        fakeGame.lastBetAmount,
        200,
      ); // GameConstants.quickBetAmounts.first
    },
  );

  testWidgets(
    'tapping a quick amount chip then MISER sends the chosen amount',
    (tester) async {
      final fakeGame = FakeGameService();
      await tester.pumpWidget(
        _buildApp(
          fakeGame: fakeGame,
          round: sampleRound(status: RoundStatus.betting),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(Formatters.amount(2000)).first);
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'PLACER UN PARI').first,
      );
      await tester.pump();
      await tester.pump();

      expect(fakeGame.lastBetAmount, 2000);
    },
  );

  testWidgets('automatic play places a bet when betting is open', (
    tester,
  ) async {
    final fakeGame = FakeGameService();
    await tester.pumpWidget(
      _buildApp(
        fakeGame: fakeGame,
        round: sampleRound(status: RoundStatus.betting),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('ACTIVER LE JEU\nAUTOMATIQUE').first);
    await tester.pump();
    await tester.pump();

    expect(fakeGame.placeBetCalled, isTrue);
    expect(fakeGame.lastBetSlot, 1);
    expect(fakeGame.lastBetAmount, 200);
    expect(fakeGame.lastAutoCashout, 2);
  });

  testWidgets('bet button is disabled outside the betting phase', (
    tester,
  ) async {
    final fakeGame = FakeGameService();
    await tester.pumpWidget(
      _buildApp(
        fakeGame: fakeGame,
        round: sampleRound(
          status: RoundStatus.running,
          runningStartedAt: DateTime.now(),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'TOUR EN COURS').first,
    );
    expect(button.onPressed, isNull);
    expect(fakeGame.placeBetCalled, isFalse);
  });

  testWidgets('a server rejection shows a friendly French snackbar', (
    tester,
  ) async {
    final fakeGame = FakeGameService(
      placeBetError: const PostgrestException(message: 'INSUFFICIENT_FUNDS'),
    );
    await tester.pumpWidget(
      _buildApp(
        fakeGame: fakeGame,
        round: sampleRound(status: RoundStatus.betting),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'PLACER UN PARI').first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Solde insuffisant.'), findsOneWidget);
  });
}
