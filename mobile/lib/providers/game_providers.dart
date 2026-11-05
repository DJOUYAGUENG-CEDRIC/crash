import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bet.dart';
import '../models/game_round.dart';
import '../models/live_bet.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

final currentRoundProvider = StreamProvider<GameRound?>((ref) {
  return ref.watch(gameServiceProvider).watchCurrentRound();
});

/// Only changes when a genuinely new round is created. Status/countdown
/// updates for the same round must not restart dependent realtime streams.
final currentRoundIdProvider = Provider<String?>((ref) {
  return ref.watch(currentRoundProvider.select((round) => round.value?.id));
});

final recentRoundsProvider = FutureProvider<List<GameRound>>((ref) {
  return ref.watch(gameServiceProvider).fetchRecentRounds();
});

/// The signed-in player's bets on the shared current round.
final myBetsForCurrentRoundProvider = StreamProvider<List<Bet>>((ref) {
  final roundId = ref.watch(currentRoundIdProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (roundId == null || userId == null) return Stream.value(const []);
  return ref.watch(gameServiceProvider).watchMyBetsForRound(roundId, userId);
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
