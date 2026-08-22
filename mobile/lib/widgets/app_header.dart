import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../providers/wallet_providers.dart';
import 'demo_badge.dart';

/// Persistent header (spec §15): "☰ CRASHX 💰 {solde} FCFA" — the
/// hamburger opens the app drawer (spec §13), the balance reads live
/// from [walletProvider]. Used as the `appBar` of the main shell so it
/// stays visible across all 5 bottom-nav tabs.
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final balanceText = walletAsync.maybeWhen(
      data: (wallet) => wallet == null ? '—' : Formatters.amount(wallet.balance),
      orElse: () => '…',
    );

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppConstants.appName, style: AppTextStyles.heading1),
          const SizedBox(width: AppSpacing.sm),
          const DemoBadge(),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Text('$balanceText FCFA', style: AppTextStyles.balance),
            ],
          ),
        ),
      ],
    );
  }
}
