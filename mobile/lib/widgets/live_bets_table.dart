import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/live_bet.dart';
import '../providers/game_providers.dart';

/// A real, server-backed "who's betting right now" feed for the current
/// round — every row is an actual player and an actual virtual amount
/// (see live_bets_public / GameService.watchLiveBetsForRound). Never
/// fabricated activity — spec §16/§37 want a lively, social game
/// screen, and this delivers that honestly instead of with invented
/// numbers.
class LiveBetsTable extends ConsumerWidget {
  const LiveBetsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveBets = ref.watch(liveBetsForCurrentRoundProvider).value ?? const [];

    final totalBets = liveBets.length;
    final totalAmount = liveBets.fold<double>(0, (sum, b) => sum + b.amount);
    final totalPayout = liveBets
        .where((b) => b.status == BetStatus.cashedOut)
        .fold<double>(0, (sum, b) => sum + (b.payout ?? 0));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.crashRed]),
            ),
            child: Row(
              children: [
                Expanded(child: _StatColumn(label: 'Nombre de paris', value: '$totalBets')),
                Expanded(child: _StatColumn(label: 'Total des paris', value: '${Formatters.amount(totalAmount)} FCFA')),
                Expanded(child: _StatColumn(label: 'Gains totaux', value: '${Formatters.amount(totalPayout)} FCFA')),
              ],
            ),
          ),
          if (liveBets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Aucun pari sur ce tour pour le moment.', style: AppTextStyles.bodyMuted),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('JOUEUR', style: AppTextStyles.caption)),
                        Expanded(flex: 2, child: Text('COTE', style: AppTextStyles.caption, textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text('PARI', style: AppTextStyles.caption, textAlign: TextAlign.right)),
                        Expanded(flex: 2, child: Text('GAIN', style: AppTextStyles.caption, textAlign: TextAlign.right)),
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
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.body.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white70)),
      ],
    );
  }
}

class _LiveBetRow extends StatelessWidget {
  const _LiveBetRow({required this.bet});

  final LiveBet bet;

  @override
  Widget build(BuildContext context) {
    final isSettled = bet.status == BetStatus.cashedOut;
    final coteText = bet.cashoutMultiplier != null ? Formatters.multiplier(bet.cashoutMultiplier!) : '—';
    final gainText = bet.payout != null ? Formatters.amount(bet.payout!) : '—';
    final color = switch (bet.status) {
      BetStatus.cashedOut => AppColors.success,
      BetStatus.lost => AppColors.danger,
      _ => AppColors.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(_maskName(bet.displayName), style: AppTextStyles.body)),
          Expanded(
            flex: 2,
            child: Text(coteText, style: AppTextStyles.body.copyWith(color: color), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text(Formatters.amount(bet.amount), style: AppTextStyles.body, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isSettled ? gainText : '—',
              style: AppTextStyles.body.copyWith(color: isSettled ? AppColors.success : AppColors.textSecondary),
              textAlign: TextAlign.right,
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
