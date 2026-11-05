import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin_models.dart';
import '../../../providers/admin_providers.dart';
import '../admin_widgets.dart';

final _statisticsProvider = FutureProvider.autoDispose<AdminStatistics>(
  (ref) => ref.watch(adminServiceProvider).fetchStatistics(),
);

final _dayFormat = DateFormat('dd/MM');

class StatisticsSection extends ConsumerWidget {
  const StatisticsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statistics = ref.watch(_statisticsProvider);

    return AdminSectionList(
      value: statistics,
      onRefresh: () => ref.refresh(_statisticsProvider.future),
      header: const [
        AdminSectionTitle('Statistiques', subtitle: '14 derniers jours.'),
      ],
      builder: () {
        final s = statistics.requireValue;
        final maxBucket = s.buckets.fold<int>(
          1,
          (m, b) => math.max(m, b.count),
        );
        return [
          Text('Par jour', style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.sm),
          AdminCard(
            child: Column(
              children: [
                const _DayRow(
                  day: 'Jour',
                  rounds: 'Manches',
                  wagered: 'Misé',
                  paid: 'Payé',
                  header: true,
                ),
                for (final d in s.days)
                  _DayRow(
                    day: _dayFormat.format(d.day),
                    rounds: '${d.rounds}',
                    wagered: Formatters.amount(d.wagered),
                    paid: Formatters.amount(d.paidOut),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Répartition des crashs', style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.sm),
          AdminCard(
            child: Column(
              children: [
                for (final b in s.buckets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(b.label, style: AppTextStyles.caption),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: AppRadius.pillRadius,
                            child: LinearProgressIndicator(
                              value: b.count / maxBucket,
                              minHeight: 10,
                              color: AppColors.primary,
                              backgroundColor: AppColors.surfaceElevated,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${b.count}',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Meilleurs joueurs (misé)', style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.sm),
          if (s.topPlayers.isEmpty)
            const AdminEmptyState('Aucune mise sur la période.')
          else
            AdminCard(
              child: Column(
                children: [
                  for (final p in s.topPlayers)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.label),
                      trailing: Text(Formatters.amount(p.totalWagered)),
                    ),
                ],
              ),
            ),
        ];
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.rounds,
    required this.wagered,
    required this.paid,
    this.header = false,
  });

  final String day;
  final String rounds;
  final String wagered;
  final String paid;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = header ? AppTextStyles.caption : AppTextStyles.body;
    Widget cell(String text, {int flex = 2}) => Expanded(
      flex: flex,
      child: Text(text, style: style, textAlign: TextAlign.right),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(day, style: style)),
          cell(rounds),
          cell(wagered, flex: 3),
          cell(paid, flex: 3),
        ],
      ),
    );
  }
}
