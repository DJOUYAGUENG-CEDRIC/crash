import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';
import '../providers/wallet_providers.dart';

/// Persistent header (spec §15): "☰ CRASHX 💰 {solde} FCFA" — the
/// hamburger opens the app drawer (spec §13), the balance reads live
/// from [walletProvider]. Used as the `appBar` of the main shell so it
/// stays visible across all 5 bottom-nav tabs.
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.showBalance = true,
    this.showBackButton = false,
    this.onBack,
  });

  final bool showBalance;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = showBalance ? ref.watch(walletProvider) : null;
    final balanceText = walletAsync?.maybeWhen(
      data: (wallet) =>
          wallet == null ? '—' : Formatters.amount(wallet.balance),
      orElse: () => '…',
    );

    final balancePill = Container(
      height: 38,
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1624),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${balanceText ?? ''} F',
                maxLines: 1,
                style: AppTextStyles.balance.copyWith(fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 30,
            height: 30,
            child: Material(
              color: const Color(0xFF39C96B),
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () {},
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: true,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Retour',
              onPressed: onBack,
            )
          : null,
      title: showBalance ? balancePill : null,
      actions: showBalance
          ? const [
              Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(Icons.workspace_premium_outlined, size: 27),
              ),
            ]
          : const [],
    );
  }
}
