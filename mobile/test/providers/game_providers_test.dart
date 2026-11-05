import 'dart:async';

import 'package:crashx/models/bet.dart';
import 'package:crashx/models/enums.dart';
import 'package:crashx/models/game_round.dart';
import 'package:crashx/providers/auth_providers.dart';
import 'package:crashx/providers/game_providers.dart';
import 'package:crashx/providers/service_providers.dart';
import 'package:crashx/services/game_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

class _CountingGameService extends GameService {
  int betSubscriptions = 0;

  @override
  Stream<List<Bet>> watchMyBetsForRound(String roundId, String userId) {
    betSubscriptions++;
    return Stream.value(const []);
  }
}

void main() {
  test('status updates do not restart the player bet stream', () async {
    final rounds = StreamController<GameRound>();
    final game = _CountingGameService();
    final container = ProviderContainer(
      overrides: [
        gameServiceProvider.overrideWithValue(game),
        currentUserIdProvider.overrideWithValue('user-1'),
        currentRoundProvider.overrideWith((ref) => rounds.stream),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await rounds.close();
    });

    final subscription = container.listen(
      myBetsForCurrentRoundProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    rounds.add(sampleRound(id: 'round-1', status: RoundStatus.waiting));
    await pumpEventQueue();
    expect(game.betSubscriptions, 1);

    rounds.add(
      sampleRound(
        id: 'round-1',
        status: RoundStatus.running,
        runningStartedAt: DateTime.now(),
      ),
    );
    rounds.add(
      sampleRound(
        id: 'round-1',
        status: RoundStatus.crashed,
        crashMultiplier: 1.5,
      ),
    );
    await pumpEventQueue();
    expect(game.betSubscriptions, 1);

    rounds.add(sampleRound(id: 'round-2', status: RoundStatus.waiting));
    await pumpEventQueue();
    expect(game.betSubscriptions, 2);
  });
}
