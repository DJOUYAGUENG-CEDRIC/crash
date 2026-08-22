import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/game_round.dart';

/// Horizontal strip of recent crash-round results, color-coded: red-ish
/// below 2x, green-ish at/above 2x. Reused on Home and on the Crash
/// screen (spec §16/§17) so both share the exact same visual language.
class RoundMultiplierStrip extends StatelessWidget {
  const RoundMultiplierStrip({super.key, required this.rounds});

  final List<GameRound> rounds;

  @override
  Widget build(BuildContext context) {
    final crashed = rounds.where((r) => r.crashMultiplier != null).toList();

    if (crashed.isEmpty) {
      return Text('Aucun tour récent pour le moment.', style: AppTextStyles.bodyMuted);
    }

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: crashed.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => _MultiplierChip(value: crashed[index].crashMultiplier!),
      ),
    );
  }
}

class _MultiplierChip extends StatelessWidget {
  const _MultiplierChip({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final isHigh = value >= 2.0;
    final color = isHigh ? AppColors.success : AppColors.danger;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        Formatters.multiplier(value),
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
