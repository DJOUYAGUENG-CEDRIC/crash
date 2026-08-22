import 'package:crashx/models/enums.dart';
import 'package:crashx/providers/game_providers.dart';
import 'package:crashx/screens/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('lists recent rounds and the player\'s own bet history with gain/loss', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentRoundsProvider.overrideWith(
            (ref) async => [sampleRound(id: 'r1', roundNumber: 10, crashMultiplier: 4.20)],
          ),
          myBetHistoryProvider.overrideWith(
            (ref) async => [
              sampleBet(
                id: 'won',
                amount: 200,
                status: BetStatus.cashedOut,
                cashoutMultiplier: 2.5,
                payout: 500,
              ),
              sampleBet(id: 'lost', amount: 150, status: BetStatus.lost),
            ],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tour #10'), findsOneWidget);
    expect(find.text('4.20x'), findsOneWidget);

    expect(find.text('2.50x'), findsOneWidget); // cashed-out bet's multiplier
    expect(find.text('+300 FCFA'), findsOneWidget); // 500 payout - 200 staked
    expect(find.text('Perdu'), findsOneWidget);
    expect(find.text('-150 FCFA'), findsOneWidget);
  });

  testWidgets('shows friendly empty states with no data yet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentRoundsProvider.overrideWith((ref) async => []),
          myBetHistoryProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun tour récent.'), findsOneWidget);
    expect(find.text('Aucune mise pour le moment.'), findsOneWidget);
  });
}
