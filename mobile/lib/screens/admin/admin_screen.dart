import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/service_providers.dart';
import 'sections/dashboard_section.dart';
import 'sections/devices_section.dart';
import 'sections/game_section.dart';
import 'sections/logs_section.dart';
import 'sections/players_section.dart';
import 'sections/settings_section.dart';
import 'sections/statistics_section.dart';
import 'sections/sub_admins_section.dart';

class _AdminSection {
  const _AdminSection({
    required this.label,
    required this.icon,
    required this.isVisible,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final bool Function(AdminAccount account) isVisible;
  final Widget Function(AdminAccount account) builder;
}

/// In-app staff area, mirroring the web dashboard (admin/). Reached only
/// from the splash gate when the signed-in account is an active row of
/// admin_users; each section is shown only with the matching permission,
/// and every server call re-checks that permission anyway.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  static final _sections = [
    _AdminSection(
      label: 'Tableau de bord',
      icon: Icons.dashboard_outlined,
      isVisible: (a) => a.can(AdminPermissions.viewDashboard),
      builder: (a) => const DashboardSection(),
    ),
    _AdminSection(
      label: 'Jeu',
      icon: Icons.sports_esports_outlined,
      isVisible: (a) => a.can(AdminPermissions.viewGame),
      builder: (a) => GameSection(account: a),
    ),
    _AdminSection(
      label: 'Utilisateurs',
      icon: Icons.people_outline,
      isVisible: (a) => a.canAny(const [
        AdminPermissions.viewUsers,
        AdminPermissions.createInvitations,
      ]),
      builder: (a) => PlayersSection(account: a),
    ),
    _AdminSection(
      label: 'Appareils',
      icon: Icons.phone_android_outlined,
      isVisible: (a) => a.canAny(const [
        AdminPermissions.viewUsers,
        AdminPermissions.manageDevices,
      ]),
      builder: (a) => DevicesSection(account: a),
    ),
    _AdminSection(
      label: 'Sous-comptes',
      icon: Icons.admin_panel_settings_outlined,
      isVisible: (a) => a.isSuperAdmin,
      builder: (a) => const SubAdminsSection(),
    ),
    _AdminSection(
      label: 'Statistiques',
      icon: Icons.bar_chart_outlined,
      isVisible: (a) => a.can(AdminPermissions.viewStatistics),
      builder: (a) => const StatisticsSection(),
    ),
    _AdminSection(
      label: 'Journaux',
      icon: Icons.receipt_long_outlined,
      isVisible: (a) => a.can(AdminPermissions.viewLogs),
      builder: (a) => const LogsSection(),
    ),
    _AdminSection(
      label: 'Paramètres',
      icon: Icons.settings_outlined,
      isVisible: (a) => a.can(AdminPermissions.viewSettings),
      builder: (a) => SettingsSection(account: a),
    ),
  ];

  int _selected = 0;

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isSignedInProvider, (previous, isSignedIn) {
      if (!isSignedIn) context.go('/login');
    });
    ref.listen(adminAccountProvider, (previous, next) {
      // Deactivated or demoted while the app was open: back to the gate.
      if (next.hasValue && next.value == null) context.go('/');
    });

    final account = ref.watch(adminAccountProvider).value;
    if (account == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final visible = _sections.where((s) => s.isVisible(account)).toList();
    final index = visible.isEmpty ? 0 : _selected.clamp(0, visible.length - 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(visible.isEmpty ? 'Administration' : visible[index].label),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _signOut,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADMINISTRATION', style: AppTextStyles.heading2),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${account.displayName ?? 'Administrateur'} · '
                      '${account.isSuperAdmin ? 'Super admin' : 'Sous-admin'}',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (var i = 0; i < visible.length; i++)
                ListTile(
                  leading: Icon(visible[i].icon),
                  title: Text(visible[i].label),
                  selected: i == index,
                  selectedColor: AppColors.primary,
                  onTap: () {
                    setState(() => _selected = i);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
      body: visible.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  "Aucune permission n'est attribuée à ce compte.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : KeyedSubtree(
              key: ValueKey(visible[index].label),
              child: visible[index].builder(account),
            ),
    );
  }
}
