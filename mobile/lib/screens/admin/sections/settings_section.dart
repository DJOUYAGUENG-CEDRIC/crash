import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/admin_models.dart';
import '../../../providers/admin_providers.dart';
import '../admin_widgets.dart';

final _appSettingsProvider = FutureProvider.autoDispose<AppSettings?>(
  (ref) => ref.watch(adminServiceProvider).fetchAppSettings(),
);

/// Version gate and maintenance mode. Read with VIEW_SETTINGS; only a
/// SUPER_ADMIN can save (update_app_settings re-checks server-side).
class SettingsSection extends ConsumerStatefulWidget {
  const SettingsSection({super.key, required this.account});

  final AdminAccount account;

  @override
  ConsumerState<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<SettingsSection> {
  final _currentVersion = TextEditingController();
  final _minimumVersion = TextEditingController();
  final _downloadUrl = TextEditingController();
  bool _maintenance = false;
  AppSettings? _loaded;
  bool _saving = false;

  @override
  void dispose() {
    _currentVersion.dispose();
    _minimumVersion.dispose();
    _downloadUrl.dispose();
    super.dispose();
  }

  void _fill(AppSettings settings) {
    if (identical(settings, _loaded)) return;
    _loaded = settings;
    _currentVersion.text = settings.currentVersion;
    _minimumVersion.text = settings.minimumSupportedVersion;
    _downloadUrl.text = settings.downloadUrl;
    _maintenance = settings.maintenanceMode;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => ref
          .read(adminServiceProvider)
          .updateAppSettings(
            AppSettings(
              currentVersion: _currentVersion.text.trim(),
              minimumSupportedVersion: _minimumVersion.text.trim(),
              downloadUrl: _downloadUrl.text.trim(),
              maintenanceMode: _maintenance,
            ),
          ),
      success: 'Paramètres enregistrés.',
    );
    if (ok) ref.invalidate(_appSettingsProvider);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(_appSettingsProvider);
    final editable = widget.account.isSuperAdmin;

    return AdminSectionList(
      value: settings,
      onRefresh: () => ref.refresh(_appSettingsProvider.future),
      header: [
        AdminSectionTitle(
          "Paramètres de l'application",
          subtitle: editable ? null : 'Lecture seule (super admin requis).',
        ),
      ],
      builder: () {
        final value = settings.requireValue;
        if (value == null) {
          return const [AdminEmptyState('Paramètres introuvables.')];
        }
        _fill(value);
        return [
          TextField(
            controller: _currentVersion,
            enabled: editable,
            decoration: const InputDecoration(labelText: 'Version actuelle'),
          ),
          TextField(
            controller: _minimumVersion,
            enabled: editable,
            decoration: const InputDecoration(
              labelText: 'Version minimale supportée',
            ),
          ),
          TextField(
            controller: _downloadUrl,
            enabled: editable,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Lien de téléchargement',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mode maintenance'),
            subtitle: Text(
              "Bloque l'accès des joueurs à l'application.",
              style: AppTextStyles.caption,
            ),
            value: _maintenance,
            onChanged: editable
                ? (v) => setState(() => _maintenance = v)
                : null,
          ),
          if (editable) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'ENREGISTREMENT…' : 'ENREGISTRER'),
            ),
          ],
        ];
      },
    );
  }
}
