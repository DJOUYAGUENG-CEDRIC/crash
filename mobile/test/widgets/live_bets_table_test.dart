import 'package:crashx/models/enums.dart';
import 'package:crashx/models/live_bet.dart';
import 'package:crashx/providers/game_providers.dart';
import 'package:crashx/widgets/live_bets_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

LiveBet _liveBet({
  required String id,
  required BetStatus status,
  double? cashoutMultiplier,
  double? payout,
}) {
  return LiveBet(
    id: id,
    roundId: 'round-1',
    displayName: 'joueur$id',
    slot: 1,
    amount: 100,
    status: status,
    cashoutMultiplier: cashoutMultiplier,
    payout: payout,
    placedAt: DateTime.utc(2026, 1, 1),
  );
}

Widget _table({required RoundStatus roundStatus, required List<LiveBet> bets}) {
  return ProviderScope(
    overrides: [
      currentRoundProvider.overrideWith(
        (ref) => Stream.value(sampleRound(status: roundStatus)),
      ),
      liveBetsForCurrentRoundProvider.overrideWith((ref) => Stream.value(bets)),
    ],
    child: const MaterialApp(home: Scaffold(body: LiveBetsTable())),
  );
}

Color _rowBackground(WidgetTester tester, String betId) {
  final row = tester.widget<Container>(find.byKey(Key('live-bet-row-$betId')));
  return (row.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('keeps every player row green before the crash', (tester) async {
    await tester.pumpWidget(
      _table(
        roundStatus: RoundStatus.running,
        bets: [
          _liveBet(id: 'active', status: BetStatus.active),
          _liveBet(
            id: 'cashed',
            status: BetStatus.cashedOut,
            cashoutMultiplier: 1.5,
            payout: 150,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(_rowBackground(tester, 'active'), const Color(0x142ECC71));
    expect(_rowBackground(tester, 'cashed'), const Color(0x142ECC71));
  });

  testWidgets('shows winners green and losing players red after a crash', (
    tester,
  ) async {
    await tester.pumpWidget(
      _table(
        roundStatus: RoundStatus.crashed,
        bets: [
          _liveBet(
            id: 'winner',
            status: BetStatus.cashedOut,
            cashoutMultiplier: 1.5,
            payout: 150,
          ),
          _liveBet(id: 'loser', status: BetStatus.lost),
        ],
      ),
    );
    await tester.pump();

    expect(_rowBackground(tester, 'winner'), const Color(0x142ECC71));
    expect(_rowBackground(tester, 'loser'), const Color(0x14FF4D4D));
    expect(find.text('0 XAF'), findsOneWidget);
  });
}
