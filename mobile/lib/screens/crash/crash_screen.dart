import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/game_round.dart';
import '../../providers/game_providers.dart';
import '../../widgets/crash_curve_painter.dart';
import '../../widgets/demo_badge.dart';
import '../../widgets/live_bets_table.dart';
import '../../widgets/live_multiplier_builder.dart';
import '../../widgets/round_multiplier_strip.dart';
import '../../widgets/starfield_background.dart';
import 'bet_panel.dart';

/// The Crash tab (spec §17-§21) — the centerpiece screen: live animated
/// multiplier + curve, two independent bet slots.
class CrashScreen extends ConsumerWidget {
  const CrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = ref.watch(currentRoundProvider).value;
    final recentRounds = ref.watch(recentRoundsProvider).value ?? const [];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Crash', style: AppTextStyles.heading1),
                const DemoBadge(label: 'ARGENT '),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            RoundMultiplierStrip(rounds: recentRounds),
            const SizedBox(height: AppSpacing.lg),
            _GameStage(round: round),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 380) {
                  return const Column(
                    children: [
                      BetPanel(slot: 1),
                      SizedBox(height: AppSpacing.md),
                      BetPanel(slot: 2),
                    ],
                  );
                }
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: BetPanel(slot: 1)),
                    SizedBox(width: AppSpacing.md),
                    Expanded(child: BetPanel(slot: 2)),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const LiveBetsTable(),
          ],
        ),
      ),
    );
  }
}

class _GameStage extends StatelessWidget {
  const _GameStage({required this.round});

  final GameRound? round;

  @override
  Widget build(BuildContext context) {
    final status = round?.status;
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const StarfieldBackground(),
          switch (status) {
            null || RoundStatus.waiting => const _StageMessage(label: 'EN ATTENTE DU PROCHAIN TOUR'),
            RoundStatus.betting => _BettingStage(round: round!),
            RoundStatus.running => _RunningStage(round: round!),
            RoundStatus.crashed || RoundStatus.result => _CrashedStage(round: round!),
          },
        ],
      ),
    );
  }
}

class _StageMessage extends StatelessWidget {
  const _StageMessage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: AppTextStyles.heading2.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _BettingStage extends StatefulWidget {
  const _BettingStage({required this.round});

  final GameRound round;

  @override
  State<_BettingStage> createState() => _BettingStageState();
}

class _BettingStageState extends State<_BettingStage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final startedAt = widget.round.bettingStartedAt;
    if (startedAt == null) return;
    final next = DateTime.now().difference(startedAt).inSeconds;
    if (next != _elapsedSeconds) setState(() => _elapsedSeconds = next);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, color: AppColors.accent, size: 32),
        const SizedBox(height: AppSpacing.sm),
        Text('MISES OUVERTES', style: AppTextStyles.heading1.copyWith(color: AppColors.accent)),
        const SizedBox(height: AppSpacing.xs),
        Text('$_elapsedSeconds s', style: AppTextStyles.bodyMuted),
      ],
    );
  }
}

class _RunningStage extends StatelessWidget {
  const _RunningStage({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    return LiveMultiplierBuilder(
      round: round,
      builder: (context, multiplier) {
        final elapsedSeconds = round.runningStartedAt == null
            ? 0.0
            : DateTime.now().difference(round.runningStartedAt!).inMilliseconds / 1000.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: CrashCurvePainter(multiplier: multiplier, elapsedSeconds: elapsedSeconds, crashed: false),
            ),
            Center(
              child: Text(Formatters.multiplier(multiplier), style: AppTextStyles.multiplier),
            ),
          ],
        );
      },
    );
  }
}

class _CrashedStage extends StatelessWidget {
  const _CrashedStage({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final crashValue = round.crashMultiplier ?? 1.0;
    final elapsedSeconds = (round.runningStartedAt == null || round.crashedAt == null)
        ? 12.0
        : round.crashedAt!.difference(round.runningStartedAt!).inMilliseconds / 1000.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: CrashCurvePainter(multiplier: crashValue, elapsedSeconds: elapsedSeconds, crashed: true),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Formatters.multiplier(crashValue),
                style: AppTextStyles.multiplier.copyWith(color: AppColors.crashRed),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('CRASHÉ', style: AppTextStyles.heading2.copyWith(color: AppColors.crashRed)),
            ],
          ),
        ),
      ],
    );
  }
}
