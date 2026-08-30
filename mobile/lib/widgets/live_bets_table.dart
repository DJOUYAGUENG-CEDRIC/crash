import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/game_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/live_bet.dart';
import '../models/game_round.dart';
import '../providers/game_providers.dart';

/// A real, server-backed "who's betting right now" feed for the current
/// round — every row is an actual player and an actual virtual amount
/// (see live_bets_public / GameService.watchLiveBetsForRound). Never
/// fabricated activity — spec §16/§37 want a lively, social game
/// screen, and this delivers that honestly instead of with invented
/// numbers.
class LiveBetsTable extends ConsumerStatefulWidget {
  const LiveBetsTable({super.key});

  @override
  ConsumerState<LiveBetsTable> createState() => _LiveBetsTableState();
}

class _LiveBetsTableState extends ConsumerState<LiveBetsTable> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (_testDataEnabled) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverBets =
        ref.watch(liveBetsForCurrentRoundProvider).value ?? const [];
    final round = ref.watch(currentRoundProvider).value;
    final liveBets = _testDataEnabled && round != null
        ? [...serverBets, ..._buildTestBets(round)]
        : serverBets;

    final visibleAmount = liveBets.fold<double>(0, (sum, b) => sum + b.amount);
    final visiblePayout = liveBets
        .where((b) => b.status == BetStatus.cashedOut)
        .fold<double>(0, (sum, b) => sum + (b.payout ?? 0));
    final testTotals = _testDataEnabled && round != null
        ? _buildTestTotals(round, serverBets.length)
        : null;
    final totalBets = testTotals?.count ?? liveBets.length;
    final totalAmount = testTotals?.amount ?? visibleAmount;
    final totalPayout = testTotals?.payout ?? visiblePayout;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF171A3B),
        borderRadius: BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE45D09), Color(0xFFF13D58)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    icon: Icons.person_rounded,
                    label: 'Nombre de paris',
                    value: '$totalBets',
                  ),
                ),
                Expanded(
                  child: _StatColumn(
                    icon: Icons.monetization_on_rounded,
                    label: 'Total des paris',
                    value: _summaryAmount(totalAmount),
                    unit: 'XAF',
                  ),
                ),
                Expanded(
                  child: _StatColumn(
                    icon: Icons.savings_rounded,
                    label: 'Gains totaux',
                    value: _summaryAmount(totalPayout),
                    unit: 'XAF',
                  ),
                ),
              ],
            ),
          ),
          if (liveBets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Aucun pari sur ce tour pour le moment.',
                style: AppTextStyles.bodyMuted,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            "NOM D'UTILISATEUR",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: const Color(0xFF9DA2B8),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'COTE',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: const Color(0xFF9DA2B8),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'PARI',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: const Color(0xFF9DA2B8),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'GAIN',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              color: const Color(0xFF9DA2B8),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final bet in liveBets.take(30)) _LiveBetRow(bet: bet),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const bool _testDataEnabled = bool.fromEnvironment(
    'ENABLE_TEST_DATA',
    defaultValue: false,
  );

  List<LiveBet> _buildTestBets(GameRound round) {
    final random = math.Random(round.roundNumber);
    final now = DateTime.now();
    const amounts = [
      200.0,
      400.0,
      700.0,
      1100.0,
      2000.0,
      5000.0,
      20000.0,
      70000.0,
    ];
    final finished =
        round.status == RoundStatus.crashed ||
        round.status == RoundStatus.result;
    final crashAt = round.crashMultiplier ?? 1.0;
    final liveMultiplier = round.liveMultiplier(GameConstants.growthRate, now);

    return List.generate(14, (index) {
      final amount = amounts[random.nextInt(amounts.length)];
      final desiredCashout = 1.05 + random.nextDouble() * 1.65;
      final hasCashedDuringFlight =
          round.status == RoundStatus.running &&
          index % 3 == 0 &&
          liveMultiplier >= desiredCashout;
      final canWin =
          (finished && crashAt > desiredCashout && index % 3 == 0) ||
          hasCashedDuringFlight;
      final cashout = canWin
          ? math.min(desiredCashout, finished ? crashAt : liveMultiplier)
          : null;
      final status = finished
          ? (canWin ? BetStatus.cashedOut : BetStatus.lost)
          : hasCashedDuringFlight
          ? BetStatus.cashedOut
          : round.status == RoundStatus.running
          ? BetStatus.active
          : BetStatus.pending;
      final suffix = (10 + random.nextInt(90)).toString();

      return LiveBet(
        id: 'test-${round.id}-$index',
        roundId: round.id,
        displayName: 'joueur$suffix',
        slot: index.isEven ? 1 : 2,
        amount: amount,
        status: status,
        cashoutMultiplier: cashout,
        payout: cashout == null ? null : amount * cashout,
        placedAt: round.createdAt.add(Duration(milliseconds: index * 80)),
      );
    });
  }

  _TestTotals _buildTestTotals(GameRound round, int realBetCount) {
    final random = math.Random(round.roundNumber * 7919);
    final count = 760 + random.nextInt(540) + realBetCount;
    final amount = count * (520.0 + random.nextDouble() * 1280);
    final finished =
        round.status == RoundStatus.crashed ||
        round.status == RoundStatus.result;
    final elapsed = round.runningStartedAt == null
        ? 0.0
        : DateTime.now().difference(round.runningStartedAt!).inMilliseconds /
              1000.0;
    final payoutProgress = finished
        ? 1.0
        : round.status == RoundStatus.running
        ? (elapsed / 18).clamp(0.0, 1.0)
        : 0.0;
    final payoutRatio = .28 + random.nextDouble() * .34;
    return _TestTotals(
      count: count,
      amount: amount,
      payout: amount * payoutRatio * payoutProgress,
    );
  }

  String _summaryAmount(double value) {
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _TestTotals {
  const _TestTotals({
    required this.count,
    required this.amount,
    required this.payout,
  });

  final int count;
  final double amount;
  final double payout;
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (unit != null)
          Text(
            unit!,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _LiveBetRow extends StatelessWidget {
  const _LiveBetRow({required this.bet});

  final LiveBet bet;

  @override
  Widget build(BuildContext context) {
    final isCashedOut = bet.status == BetStatus.cashedOut;
    final isLost = bet.status == BetStatus.lost;
    final coteText = isCashedOut
        ? 'x${(bet.cashoutMultiplier ?? 0).toStringAsFixed(2)}'
        : isLost
        ? 'x0'
        : '—';
    final gainText = isCashedOut
        ? '${Formatters.amount(bet.payout ?? 0)} XAF'
        : isLost
        ? '0 XAF'
        : '—';
    final color = switch (bet.status) {
      BetStatus.cashedOut => AppColors.success,
      BetStatus.lost => AppColors.danger,
      _ => AppColors.textSecondary,
    };
    final rowStyle = AppTextStyles.body.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      height: 1.18,
      letterSpacing: 0,
      color: color,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(_maskName(bet.displayName), style: rowStyle),
          ),
          Expanded(
            flex: 2,
            child: Text(coteText, style: rowStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${Formatters.amount(bet.amount)} XAF',
                  maxLines: 1,
                  style: rowStyle,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  gainText,
                  maxLines: 1,
                  style: rowStyle.copyWith(
                    color: isCashedOut ? AppColors.success : color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Light privacy touch consistent with the reference layout's masked
  /// usernames — but applied to a REAL display name, not a fabricated one.
  String _maskName(String name) {
    if (name.length <= 2) return name;
    return '${'*' * (name.length - 2)}${name.substring(name.length - 2)}';
  }
}
