import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/game_round.dart';
import '../../providers/game_providers.dart';

class CrashScheduleScreen extends ConsumerWidget {
  const CrashScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRound = ref.watch(currentRoundProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(currentRoundProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Crash prévu', style: AppTextStyles.heading1),
            const SizedBox(height: AppSpacing.lg),
            currentRound.when(
              data: (round) => _CurrentCrashCard(round: round),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(
                'Impossible de charger le tour en cours.',
                style: AppTextStyles.bodyMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentCrashCard extends StatelessWidget {
  const _CurrentCrashCard({required this.round});
  final GameRound? round;

  @override
  Widget build(BuildContext context) {
    if (round == null) {
      return Text('Aucun tour disponible.', style: AppTextStyles.bodyMuted);
    }
    final target = round!.targetMultiplier;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Text(
            'TOUR #${round!.roundNumber}',
            style: AppTextStyles.caption.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            target == null ? '—' : Formatters.multiplier(target),
            style: AppTextStyles.displayLarge.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            target == null
                ? 'Cote en préparation'
                : 'Crash environ ${_crashDuration(target)} après le décollage',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

String _crashDuration(double target) {
  if (target <= 1) return 'immédiat';
  final seconds = (math.log(target) / 0.06).ceil();
  final minutes = seconds ~/ 60;
  return minutes == 0 ? '${seconds}s' : '${minutes}min ${seconds % 60}s';
}
