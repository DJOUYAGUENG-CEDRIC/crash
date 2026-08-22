import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/bet.dart';
import '../../models/enums.dart';
import '../../models/game_round.dart';
import '../../providers/game_providers.dart';

/// Historique tab (spec §27): recent global rounds, and the player's own
/// bet history with the resulting gain/loss for each bet.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentRoundsAsync = ref.watch(recentRoundsProvider);
    final myBetsAsync = ref.watch(myBetHistoryProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentRoundsProvider);
          ref.invalidate(myBetHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Derniers tours', style: AppTextStyles.heading1),
            const SizedBox(height: AppSpacing.sm),
            recentRoundsAsync.when(
              data: (rounds) {
                final crashed = rounds.where((r) => r.crashMultiplier != null).toList();
                if (crashed.isEmpty) {
                  return Text('Aucun tour récent.', style: AppTextStyles.bodyMuted);
                }
                return Column(children: [for (final r in crashed) _RoundRow(round: r)]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Impossible de charger les tours.', style: AppTextStyles.bodyMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Mon historique de mises', style: AppTextStyles.heading1),
            const SizedBox(height: AppSpacing.sm),
            myBetsAsync.when(
              data: (bets) {
                if (bets.isEmpty) {
                  return Text('Aucune mise pour le moment.', style: AppTextStyles.bodyMuted);
                }
                return Column(children: [for (final b in bets) _BetHistoryRow(bet: b)]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Impossible de charger votre historique.', style: AppTextStyles.bodyMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final value = round.crashMultiplier ?? 0;
    final color = value >= 2.0 ? AppColors.success : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Text('Tour #${round.roundNumber}', style: AppTextStyles.bodyMuted),
          const Spacer(),
          Text(
            Formatters.multiplier(value),
            style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _BetHistoryRow extends StatelessWidget {
  const _BetHistoryRow({required this.bet});

  final Bet bet;

  @override
  Widget build(BuildContext context) {
    final payout = bet.payout ?? 0;
    final netResult = bet.status == BetStatus.cashedOut ? payout - bet.amount : -bet.amount;
    final isWin = bet.status == BetStatus.cashedOut;
    final resultLabel = bet.status == BetStatus.cashedOut
        ? Formatters.multiplier(bet.cashoutMultiplier ?? 0)
        : bet.status == BetStatus.lost
        ? 'Perdu'
        : bet.status == BetStatus.cancelled
        ? 'Annulé'
        : 'En cours';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Formatters.dateTime(bet.placedAt), style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                Text('${Formatters.amount(bet.amount)} FCFA misés', style: AppTextStyles.body),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                resultLabel,
                style: AppTextStyles.body.copyWith(
                  color: isWin ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (bet.status == BetStatus.cashedOut || bet.status == BetStatus.lost) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${netResult >= 0 ? '+' : ''}${Formatters.amount(netResult)} FCFA',
                  style: AppTextStyles.caption.copyWith(color: isWin ? AppColors.success : AppColors.danger),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
