import 'package:crashx/models/enums.dart';
import 'package:crashx/providers/game_providers.dart';
import 'package:crashx/providers/wallet_providers.dart';
import 'package:crashx/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('shows the live virtual balance and recent multipliers', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith((ref) => Stream.value(sampleWallet(balance: 12500))),
          currentRoundProvider.overrideWith((ref) => Stream.value(sampleRound(status: RoundStatus.betting))),
          recentRoundsProvider.overrideWith(
            (ref) async => [
              sampleRound(id: 'r1', crashMultiplier: 1.42),
              sampleRound(id: 'r2', crashMultiplier: 3.10),
            ],
          ),
          recentTransactionsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('12'), findsWidgets); // balance formatted with a grouping separator
    expect(find.textContaining('FCFA'), findsWidgets);
    expect(find.text('1.42x'), findsOneWidget);
    expect(find.text('3.10x'), findsOneWidget);
    expect(find.text('JOUER'), findsOneWidget);
    expect(find.text('CRASH'), findsOneWidget);
  });

  testWidgets('shows a friendly empty state with no recent rounds yet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletProvider.overrideWith((ref) => Stream.value(sampleWallet(balance: 0))),
          currentRoundProvider.overrideWith((ref) => Stream.value(null)),
          recentRoundsProvider.overrideWith((ref) async => []),
          recentTransactionsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun tour récent pour le moment.'), findsOneWidget);
  });
}
