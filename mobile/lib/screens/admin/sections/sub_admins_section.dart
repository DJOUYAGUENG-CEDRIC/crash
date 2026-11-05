import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/admin_models.dart';
import '../../../providers/admin_providers.dart';
import '../admin_widgets.dart';

final _subAdminsProvider = FutureProvider.autoDispose<List<SubAdmin>>(
  (ref) => ref.watch(adminServiceProvider).fetchSubAdmins(),
);

/// SUPER_ADMIN only. Sub-accounts are created through the create-sub-admin
/// Edge Function; no permission ever lets a sub-account manage staff.
class SubAdminsSection extends ConsumerWidget {
  const SubAdminsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAdmins = ref.watch(_subAdminsProvider);

    return AdminSectionList(
      value: subAdmins,
      onRefresh: () => ref.refresh(_subAdminsProvider.future),
      header: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: FilledButton.icon(
            icon: const Icon(Icons.person_add_alt),
            label: const Text('CRÉER UN SOUS-COMPTE'),
            onPressed: () => _create(context, ref),
          ),
        ),
      ],
      builder: () {
        final rows = subAdmins.requireValue;
        if (rows.isEmpty) return const [AdminEmptyState('Aucun sous-compte.')];
        return [
          for (final admin in rows)
            AdminCard(
              onTap: () => _openPermissions(context, ref, admin),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin.displayName ?? 'Sous-compte',
                          style: AppTextStyles.body,
                        ),
                        Text(
                          '${admin.permissions.length} permission(s)',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  AdminStatusChip(
                    admin.isActive ? 'ACTIF' : 'DÉSACTIVÉ',
                    color: admin.isActive
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final email = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouveau sous-compte'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom affiché'),
              ),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe (8 caractères min.)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ANNULER'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CRÉER'),
          ),
        ],
      ),
    );
    final values = (
      email: email.text.trim(),
      password: password.text,
      name: name.text.trim(),
    );
    for (final c in [email, password, name]) {
      c.dispose();
    }
    if (submitted != true || !context.mounted) return;
    if (values.email.isEmpty ||
        values.password.length < 8 ||
        values.name.isEmpty) {
      showAdminSnack(context, 'Informations invalides.', error: true);
      return;
    }
    final done = await runAdminAction(
      context,
      () => ref
          .read(adminServiceProvider)
          .createSubAdmin(
            email: values.email,
            password: values.password,
            displayName: values.name,
          ),
      success: 'Sous-compte créé. Attribuez-lui ses permissions.',
    );
    if (done) ref.invalidate(_subAdminsProvider);
  }

  Future<void> _openPermissions(
    BuildContext context,
    WidgetRef ref,
    SubAdmin admin,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SubAdminSheet(admin: admin),
    ).then((_) => ref.invalidate(_subAdminsProvider));
  }
}

class _SubAdminSheet extends ConsumerStatefulWidget {
  const _SubAdminSheet({required this.admin});

  final SubAdmin admin;

  @override
  ConsumerState<_SubAdminSheet> createState() => _SubAdminSheetState();
}

class _SubAdminSheetState extends ConsumerState<_SubAdminSheet> {
  late final Set<String> _selected = {...widget.admin.permissions};
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    final done = await runAdminAction(context, action, success: success);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.admin;
    final service = ref.read(adminServiceProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text(
            admin.displayName ?? 'Sous-compte',
            style: AppTextStyles.heading1,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final permission in AdminPermissions.all)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _selected.contains(permission),
              title: Text(AdminPermissions.labels[permission] ?? permission),
              onChanged: _busy
                  ? null
                  : (checked) => setState(() {
                      checked == true
                          ? _selected.add(permission)
                          : _selected.remove(permission);
                    }),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => service.setSubAdminPermissions(admin.id, _selected),
                    'Permissions enregistrées.',
                  ),
            child: const Text('ENREGISTRER LES PERMISSIONS'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(
                    () => admin.isActive
                        ? service.deactivateSubAdmin(admin.id)
                        : service.reactivateSubAdmin(admin.id),
                    admin.isActive
                        ? 'Sous-compte désactivé.'
                        : 'Sous-compte réactivé.',
                  ),
            child: Text(admin.isActive ? 'DÉSACTIVER' : 'RÉACTIVER'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _busy
                ? null
                : () async {
                    final ok = await confirmAdminAction(
                      context,
                      title: 'Supprimer ce sous-compte ?',
                      message: 'Cette action est définitive.',
                      confirmLabel: 'SUPPRIMER',
                      destructive: true,
                    );
                    if (ok) {
                      await _run(
                        () => service.deleteSubAdmin(admin.id),
                        'Sous-compte supprimé.',
                      );
                    }
                  },
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );
  }
}
