import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/game_round.dart';
import '../../providers/game_providers.dart';
import '../../providers/wallet_providers.dart';
import '../../widgets/round_multiplier_strip.dart';

/// Home tab (spec §16): dense, minimal empty space. There is exactly one
/// game in CrashX, so this screen showcases Crash itself — recent
/// multipliers, live round teaser and a prominent play CTA — rather than
/// inventing a "popular games" carousel that has nothing else to show.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final roundAsync = ref.watch(currentRoundProvider);
    final recentRoundsAsync = ref.watch(recentRoundsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentRoundsProvider);
          ref.invalidate(recentTransactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _BalanceCard(balance: walletAsync.value?.balance),
            const SizedBox(height: AppSpacing.lg),
            const _PromoBanner(),
            const SizedBox(height: AppSpacing.lg),
            _PlayCard(round: roundAsync.value),
            const SizedBox(height: AppSpacing.xl),
            Text('Derniers multiplicateurs', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            RoundMultiplierStrip(rounds: recentRoundsAsync.value ?? const []),
            const SizedBox(height: AppSpacing.xl),
            _StatsRow(roundsToday: recentRoundsAsync.value?.length ?? 0),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final double? balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryVariant],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgRadius,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.currencyLabel,
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  balance == null ? '…' : '${Formatters.amount(balance!)} FCFA',
                  style: AppTextStyles.displayLarge.copyWith(
                    fontSize: 30,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 36,
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.rocket_launch_rounded,
            color: AppColors.accent,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Tentez le prochain gros multiplicateur — misez, regardez la courbe grimper, encaissez au bon moment.',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayCard extends StatelessWidget {
  const _PlayCard({required this.round});

  final GameRound? round;

  @override
  Widget build(BuildContext context) {
    final status = round?.status;
    final statusLabel = switch (status) {
      RoundStatus.betting => 'MISES OUVERTES',
      RoundStatus.running => 'TOUR EN COURS',
      RoundStatus.crashed => 'TOUR TERMINÉ',
      RoundStatus.result => 'PROCHAIN TOUR BIENTÔT',
      RoundStatus.waiting => 'EN ATTENTE',
      null => 'CHARGEMENT…',
    };

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        borderRadius: AppRadius.lgRadius,
        onTap: () => context.go('/crash'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: AppColors.primaryVariant,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CRASH', style: AppTextStyles.heading1),
                    const SizedBox(height: AppSpacing.xs),
                    Text(statusLabel, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => context.go('/crash'),
                child: const Text('JOUER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.roundsToday});

  final int roundsToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(label: 'Tours récents', value: '$roundsToday'),
        ),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: _StatTile(label: 'Mode', value: ''),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.heading1),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
