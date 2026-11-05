import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin_models.dart';
import '../../../providers/admin_providers.dart';
import '../admin_widgets.dart';

final _devicesProvider = FutureProvider.autoDispose<List<AdminDevice>>(
  (ref) => ref.watch(adminServiceProvider).fetchDevices(),
);

class DevicesSection extends ConsumerWidget {
  const DevicesSection({super.key, required this.account});

  final AdminAccount account;

  static const _actions = {
    'ACTIVE': 'Autoriser',
    'BLOCKED': 'Bloquer',
    'REVOKED': 'Révoquer',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(_devicesProvider);
    final canManage = account.can(AdminPermissions.manageDevices);

    return AdminSectionList(
      value: devices,
      onRefresh: () => ref.refresh(_devicesProvider.future),
      builder: () {
        final rows = devices.requireValue;
        if (rows.isEmpty) return const [AdminEmptyState('Aucun appareil.')];
        return [
          for (final device in rows)
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          device.deviceName ?? 'Appareil inconnu',
                          style: AppTextStyles.body,
                        ),
                      ),
                      AdminStatusChip(
                        device.status,
                        color: adminStatusColor(device.status),
                      ),
                    ],
                  ),
                  Text(
                    '${device.ownerLabel} · ${device.platform ?? '—'}',
                    style: AppTextStyles.bodyMuted,
                  ),
                  Text(
                    'Vu le ${device.lastSeen == null ? '—' : Formatters.dateTime(device.lastSeen!)}',
                    style: AppTextStyles.caption,
                  ),
                  if (canManage) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final entry in _actions.entries)
                          if (entry.key != device.status)
                            OutlinedButton(
                              onPressed: () async {
                                final done = await runAdminAction(
                                  context,
                                  () => ref
                                      .read(adminServiceProvider)
                                      .setDeviceStatus(device.id, entry.key),
                                  success: 'Appareil mis à jour.',
                                );
                                if (done) ref.invalidate(_devicesProvider);
                              },
                              child: Text(entry.value),
                            ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ];
      },
    );
  }
}
