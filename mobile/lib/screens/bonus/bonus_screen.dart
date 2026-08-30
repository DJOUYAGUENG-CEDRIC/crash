import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/wallet_transaction.dart';
import '../../providers/wallet_providers.dart';

/// Bonus tab. The only bonus mechanic that actually exists server-side is
/// the one-off welcome demo credit granted as a BONUS_DEMO transaction at
/// account activation — so that's what this screen shows, rather than a
/// wagering/unlock system with no backend support.
class BonusScreen extends ConsumerWidget {
  const BonusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recentTransactionsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Bonus', style: AppTextStyles.heading1),
            const SizedBox(height: AppSpacing.lg),
            const _WelcomeBonusCard(),
            const SizedBox(height: AppSpacing.xl),
            Text('Historique des bonus', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            transactionsAsync.when(
              data: (transactions) {
                final bonuses = transactions.where((t) => t.type == TransactionType.bonusDemo).toList();
                if (bonuses.isEmpty) {
                  return Text('Aucun bonus reçu pour le moment.', style: AppTextStyles.bodyMuted);
                }
                return Column(children: [for (final t in bonuses) _BonusRow(transaction: t)]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Impossible de charger vos bonus.', style: AppTextStyles.bodyMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBonusCard extends StatelessWidget {
  const _WelcomeBonusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryVariant]),
        borderRadius: AppRadius.lgRadius,
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bonus de bienvenue',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Un crédit vous a été offert à l'activation de votre compte pour découvrir CRASH — "
                  'aucune valeur réelle.',
                  style: AppTextStyles.bodyMuted.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BonusRow extends StatelessWidget {
  const _BonusRow({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
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
          const Icon(Icons.card_giftcard_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bonus', style: AppTextStyles.body),
                Text(Formatters.dateTime(transaction.createdAt), style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            '+${Formatters.amount(transaction.amount)} FCFA',
            style: AppTextStyles.body.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
