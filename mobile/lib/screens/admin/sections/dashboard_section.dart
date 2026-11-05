import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin_models.dart';
import '../../../providers/admin_providers.dart';
import '../admin_widgets.dart';

final _overviewProvider = FutureProvider.autoDispose<DashboardOverview>(
  (ref) => ref.watch(adminServiceProvider).fetchDashboardOverview(),
);

class DashboardSection extends ConsumerWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(_overviewProvider);
    return AdminSectionList(
      value: overview,
      onRefresh: () => ref.refresh(_overviewProvider.future),
      header: const [
        AdminSectionTitle(
          "Aujourd'hui",
          subtitle: 'Activité depuis minuit (argent virtuel).',
        ),
      ],
      builder: () {
        final o = overview.requireValue;
        return [
          _StatTile(
            label: 'Joueurs actifs',
            value: '${o.activePlayersToday}',
            icon: Icons.people_outline,
          ),
          _StatTile(
            label: 'Total misé',
            value:
                '${Formatters.amount(o.totalWageredToday)} ${AppConstants.currencyLabel}',
            icon: Icons.trending_up,
          ),
          _StatTile(
            label: 'Total payé',
            value:
                '${Formatters.amount(o.totalPaidOutToday)} ${AppConstants.currencyLabel}',
            icon: Icons.payments_outlined,
          ),
          _StatTile(
            label: 'Joueurs inscrits',
            value: '${o.registeredPlayers}',
            icon: Icons.badge_outlined,
          ),
          _StatTile(
            label: 'Appareils actifs',
            value: '${o.activeDevices}',
            icon: Icons.phone_android_outlined,
          ),
        ];
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.bodyMuted)),
          Text(value, style: AppTextStyles.heading2),
        ],
      ),
    );
  }
}
