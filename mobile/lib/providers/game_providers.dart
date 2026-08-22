import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bet.dart';
import '../models/game_round.dart';
import '../models/live_bet.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

final currentRoundProvider = StreamProvider<GameRound?>((ref) {
  return ref.watch(gameServiceProvider).watchCurrentRound();
});

final recentRoundsProvider = FutureProvider<List<GameRound>>((ref) {
  return ref.watch(gameServiceProvider).fetchRecentRounds();
});

/// The signed-in player's own bets (slot 1 / slot 2) for whichever
/// round is currently live. Empty stream while no round is active yet.
final myBetsForCurrentRoundProvider = StreamProvider<List<Bet>>((ref) {
  final round = ref.watch(currentRoundProvider).value;
  final userId = ref.watch(currentUserIdProvider);
  if (round == null || userId == null) return Stream.value(const []);
  return ref.watch(gameServiceProvider).watchMyBetsForRound(round.id, userId);
});

final myBetHistoryProvider = FutureProvider<List<Bet>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(gameServiceProvider).fetchMyBetHistory(userId);
});

/// Real live "who's betting" feed for whichever round is currently
/// active — see GameService.watchLiveBetsForRound.
final liveBetsForCurrentRoundProvider = StreamProvider<List<LiveBet>>((ref) {
  final round = ref.watch(currentRoundProvider).value;
  if (round == null) return Stream.value(const []);
  return ref.watch(gameServiceProvider).watchLiveBetsForRound(round.id);
});
