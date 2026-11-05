import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/game_constants.dart';
import 'models/bet.dart';
import 'models/enums.dart';
import 'models/game_round.dart';
import 'core/theme/app_theme.dart';
import 'providers/game_providers.dart';
import 'providers/service_providers.dart';
import 'screens/crash/crash_screen.dart';
import 'services/game_service.dart';
import 'widgets/game_notice.dart';

void main() => runApp(const VisualReviewHost());

class VisualReviewHost extends StatefulWidget {
  const VisualReviewHost({super.key});

  @override
  State<VisualReviewHost> createState() => _VisualReviewHostState();
}

class _VisualReviewHostState extends State<VisualReviewHost> {
  final _rounds = StreamController<GameRound?>.broadcast();
  final _bets = StreamController<List<Bet>>.broadcast();
  Timer? _cycle;
  Timer? _countdownTimer;
  var _state = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showState(0));
    _cycle = Timer.periodic(const Duration(seconds: 9), (_) {
      _state = (_state + 1) % 4;
      _showState(_state);
    });
  }

  void _showState(int state) {
    _countdownTimer?.cancel();
    final now = DateTime.now();
    switch (state) {
      case 0:
        gameNoticeController.value = null;
        _bets.add(const []);
        var countdown = GameConstants.bettingDurationSeconds;
        _rounds.add(
          _round(
            RoundStatus.betting,
            bettingStartedAt: now,
            countdown: countdown,
          ),
        );
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          countdown--;
          if (countdown < 1) {
            timer.cancel();
            return;
          }
          _rounds.add(
            _round(
              RoundStatus.betting,
              bettingStartedAt: now,
              countdown: countdown,
            ),
          );
        });
        return;
      case 1:
        _bets.add([_bet(BetStatus.active)]);
        _rounds.add(
          _round(
            RoundStatus.running,
            runningStartedAt: now.subtract(const Duration(seconds: 5)),
          ),
        );
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          gameNoticeController.show('Votre pari est accepté !');
        });
        return;
      case 2:
        _bets.add(const []);
        _rounds.add(
          _round(
            RoundStatus.running,
            runningStartedAt: now.subtract(const Duration(seconds: 8)),
          ),
        );
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          gameNoticeController.show('Vous avez gagné : 1995 XAF');
        });
        return;
      case 3:
        gameNoticeController.value = null;
        _bets.add(const []);
        _rounds.add(
          _round(
            RoundStatus.crashed,
            runningStartedAt: now.subtract(const Duration(seconds: 11)),
            crashMultiplier: 2.18,
          ),
        );
        return;
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _countdownTimer?.cancel();
    _rounds.close();
    _bets.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        gameServiceProvider.overrideWithValue(_VisualGameService()),
        currentRoundProvider.overrideWith((ref) => _rounds.stream),
        myBetsForCurrentRoundProvider.overrideWith((ref) => _bets.stream),
        liveBetsForCurrentRoundProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const Scaffold(body: CrashScreen()),
      ),
    );
  }
}

class _VisualGameService extends GameService {
  @override
  Future<Bet> placeBet({
    required String roundId,
    required int slot,
    required double amount,
    double? autoCashoutMultiplier,
  }) async => _bet(BetStatus.pending);

  @override
  Future<Bet> cashout(String betId) async =>
      _bet(BetStatus.cashedOut, cashoutMultiplier: 1.89, payout: 1995);
}

GameRound _round(
  RoundStatus status, {
  DateTime? bettingStartedAt,
  DateTime? runningStartedAt,
  double? crashMultiplier,
  int? countdown,
}) {
  return GameRound(
    id: 'visual-round',
    roundNumber: 13307,
    status: status,
    crashMultiplier: crashMultiplier,
    countdown:
        countdown ??
        (status == RoundStatus.betting || status == RoundStatus.waiting
            ? 5
            : 0),
    bettingStartedAt: bettingStartedAt,
    runningStartedAt: runningStartedAt,
    crashedAt: status == RoundStatus.crashed ? DateTime.now() : null,
    totalBetsAmount: 0,
    totalPlayers: 0,
    createdAt: DateTime.now(),
  );
}

Bet _bet(BetStatus status, {double? cashoutMultiplier, double? payout}) {
  return Bet(
    id: 'visual-bet',
    roundId: 'visual-round',
    userId: 'visual-user',
    slot: 1,
    amount: 1300,
    status: status,
    autoCashoutMultiplier: null,
    cashoutMultiplier: cashoutMultiplier,
    payout: payout,
    placedAt: DateTime.now(),
    flightStartedAt: status == BetStatus.active || status == BetStatus.cashedOut
        ? DateTime.now().subtract(const Duration(seconds: 10))
        : null,
    cashedOutAt: null,
  );
}
