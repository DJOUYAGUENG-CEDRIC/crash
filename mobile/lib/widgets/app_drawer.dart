import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/auth_providers.dart';
import '../providers/service_providers.dart';

/// Side menu (spec §13): profile shortcut, demo-mode reminder, sign out.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, color: AppColors.textPrimary, size: 28),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    profileAsync.maybeWhen(data: (p) => p.displayName, orElse: () => '…'),
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    profileAsync.maybeWhen(data: (p) => p.email, orElse: () => ''),
                    style: AppTextStyles.bodyMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.textPrimary),
              title: const Text('Mon profil', style: AppTextStyles.body),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/profile');
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Se déconnecter', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
