import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin_models.dart';
import '../../../providers/admin_providers.dart';
import '../../../services/admin_service.dart';
import '../admin_widgets.dart';

final _logsPageProvider = FutureProvider.autoDispose
    .family<List<AdminLogEntry>, int>(
      (ref, page) => ref.watch(adminServiceProvider).fetchLogsPage(page),
    );

class LogsSection extends ConsumerStatefulWidget {
  const LogsSection({super.key});

  @override
  ConsumerState<LogsSection> createState() => _LogsSectionState();
}

class _LogsSectionState extends ConsumerState<LogsSection> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(_logsPageProvider(_page));

    return AdminSectionList(
      value: logs,
      onRefresh: () => ref.refresh(_logsPageProvider(_page).future),
      builder: () {
        final rows = logs.requireValue;
        return [
          if (rows.isEmpty) const AdminEmptyState('Aucune entrée.'),
          for (final log in rows)
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.action, style: AppTextStyles.body),
                  Text(
                    '${log.adminLabel} · ${Formatters.dateTime(log.createdAt)}',
                    style: AppTextStyles.caption,
                  ),
                  if (log.metadata != null && log.metadata!.isNotEmpty)
                    Text(
                      log.metadata.toString(),
                      style: AppTextStyles.bodyMuted,
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                child: const Text('PRÉCÉDENT'),
              ),
              Text('Page ${_page + 1}', style: AppTextStyles.caption),
              TextButton(
                onPressed: rows.length < AdminService.logsPageSize
                    ? null
                    : () => setState(() => _page++),
                child: const Text('SUIVANT'),
              ),
            ],
          ),
        ];
      },
    );
  }
}
