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

Widget _buildApp({required FakeGameService fakeGame, required GameRound? round, List<Bet> myBets = const []}) {
  return ProviderScope(
    overrides: [
      gameServiceProvider.overrideWithValue(fakeGame),
      currentRoundProvider.overrideWith((ref) => Stream.value(round)),
      recentRoundsProvider.overrideWith((ref) async => const []),
      myBetsForCurrentRoundProvider.overrideWith((ref) => Stream.value(myBets)),
    ],
    child: const MaterialApp(home: Scaffold(body: SizedBox(height: 900, child: CrashScreen()))),
  );
}

Finder _cashoutButtonFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is ElevatedButton && widget.child is Text && ((widget.child as Text).data ?? '').startsWith('ENCAISSER'),
);

void main() {
  testWidgets('ENCAISSER appears for an active bet once the round is running, and cashes out on tap', (
    tester,
  ) async {
    final activeBet = sampleBet(id: 'bet-42', slot: 1, amount: 500, status: BetStatus.active);
    final fakeGame = FakeGameService();

    await tester.pumpWidget(
      _buildApp(
        fakeGame: fakeGame,
        round: sampleRound(status: RoundStatus.running, runningStartedAt: DateTime.now()),
        myBets: [activeBet],
      ),
    );
    await tester.pump();

    expect(_cashoutButtonFinder(), findsOneWidget);

    // Note: the running round drives a continuous per-frame Ticker (the
    // live multiplier/curve), so pumpAndSettle would wait forever for it
    // to stop scheduling frames. A few explicit pumps are enough to flush
    // the tap, the async cashout() call, and the resulting rebuild.
    await tester.tap(_cashoutButtonFinder());
    await tester.pump();
    await tester.pump();

    expect(fakeGame.cashoutCalled, isTrue);
    expect(fakeGame.lastCashoutBetId, 'bet-42');
  });

  testWidgets('no ENCAISSER button while the bet is only pending (round not running yet)', (tester) async {
    final pendingBet = sampleBet(slot: 1, status: BetStatus.pending);
    final fakeGame = FakeGameService();

    await tester.pumpWidget(
      _buildApp(fakeGame: fakeGame, round: sampleRound(status: RoundStatus.betting), myBets: [pendingBet]),
    );
    // BETTING also drives its own continuous per-frame Ticker (the
    // elapsed-seconds counter), so a plain pump() is used here too.
    await tester.pump();

    expect(find.textContaining('ENCAISSER'), findsNothing);
    expect(find.textContaining('Mise en attente'), findsOneWidget);
  });

  testWidgets('a cashout server error shows a friendly French snackbar', (tester) async {
    final activeBet = sampleBet(id: 'bet-7', slot: 1, status: BetStatus.active);
    final fakeGame = FakeGameService(cashoutError: const PostgrestException(message: 'ROUND_CRASHED'));

    await tester.pumpWidget(
      _buildApp(
        fakeGame: fakeGame,
        round: sampleRound(status: RoundStatus.running, runningStartedAt: DateTime.now()),
        myBets: [activeBet],
      ),
    );
    await tester.pump();

    await tester.tap(_cashoutButtonFinder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Le tour a déjà crashé.'), findsOneWidget);
  });
}
