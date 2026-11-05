import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/activation_providers.dart';
import '../../providers/admin_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/service_providers.dart';

/// Initial route and the sole enforcement point for spec §30/§34/§35/§48:
/// re-verifies auth + account/device/version status with the server on
/// every launch (and every resume, via main.dart's lifecycle observer
/// invalidating [activationProvider]) before letting a session — even a
/// previously-valid local one — reach the rest of the app.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);

    if (!isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const _SplashScaffold(child: _SplashLoading());
    }

    // Staff accounts have no player profile/device quota: they go to the
    // admin area instead of the player activation gate.
    final adminAsync = ref.watch(adminAccountProvider);
    if (adminAsync.isLoading) {
      return const _SplashScaffold(child: _SplashLoading());
    }
    if (adminAsync.hasError) return _connectionError(ref);
    if (adminAsync.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/admin');
      });
      return const _SplashScaffold(child: _SplashLoading());
    }

    final activationAsync = ref.watch(activationProvider);

    return activationAsync.when(
      loading: () => const _SplashScaffold(child: _SplashLoading()),
      error: (error, stackTrace) => _connectionError(ref),
      data: (result) {
        if (result.reason == 'NOT_AUTHENTICATED') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return const _SplashScaffold(child: _SplashLoading());
        }

        if (result.allowed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/home');
          });
          return const _SplashScaffold(child: _SplashLoading());
        }

        return _SplashScaffold(
          child: _blockedMessageFor(
            context,
            ref,
            result.reason,
            result.downloadUrl,
          ),
        );
      },
    );
  }

  Widget _connectionError(WidgetRef ref) {
    return _SplashScaffold(
      child: _BlockedMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Connexion impossible',
        message: 'Impossible de vérifier votre accès. Vérifiez votre connexion et réessayez.',
        actions: [
          FilledButton(
            onPressed: () {
              ref.invalidate(adminAccountProvider);
              ref.invalidate(activationProvider);
            },
            child: const Text('RÉESSAYER'),
          ),
        ],
      ),
    );
  }

  Widget _blockedMessageFor(
    BuildContext context,
    WidgetRef ref,
    String reason,
    String? downloadUrl,
  ) {
    switch (reason) {
      case 'UPDATE_REQUIRED':
        return _BlockedMessage(
          icon: Icons.system_update_rounded,
          title: 'Mise à jour requise',
          message: 'Une nouvelle version est obligatoire pour continuer à utiliser CRASH.',
          actions: [
            FilledButton.icon(
              onPressed: downloadUrl == null
                  ? null
                  : () => launchUrl(
                      Uri.parse(downloadUrl),
                      mode: LaunchMode.externalApplication,
                    ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('METTRE À JOUR'),
            ),
          ],
        );
      case 'ACCOUNT_BLOCKED':
        return _BlockedMessage(
          icon: Icons.block_rounded,
          title: 'Compte bloqué',
          message: 'Votre compte a été bloqué. Contactez un administrateur pour plus d\'informations.',
          actions: [_signOutButton(ref)],
        );
      case 'DEVICE_REVOKED':
        return _BlockedMessage(
          icon: Icons.phonelink_erase_rounded,
          title: 'Appareil non autorisé',
          message: 'L\'accès à CRASH depuis cet appareil a été révoqué.',
          actions: [_signOutButton(ref)],
        );
      case 'DEVICE_LIMIT_REACHED':
        return _BlockedMessage(
          icon: Icons.devices_other_rounded,
          title: 'Limite d\'appareils atteinte',
          message: 'Le nombre maximal d\'appareils autorisés pour votre compte est atteint.',
          actions: [_signOutButton(ref)],
        );
      case 'MAINTENANCE':
        return const _BlockedMessage(
          icon: Icons.build_rounded,
          title: 'Maintenance en cours',
          message: 'CRASH est temporairement indisponible pour maintenance. Merci de revenir plus tard.',
          actions: [],
        );
      default:
        return _BlockedMessage(
          icon: Icons.error_outline_rounded,
          title: 'Accès indisponible',
          message: 'Impossible d\'accéder à CRASH pour le moment.',
          actions: [_signOutButton(ref)],
        );
    }
  }

  Widget _signOutButton(WidgetRef ref) {
    return Builder(
      builder: (context) => OutlinedButton(
        onPressed: () async {
          await ref.read(authServiceProvider).signOut();
          if (context.mounted) context.go('/login');
        },
        child: const Text('SE DÉCONNECTER'),
      ),
    );
  }
}

class _SplashScaffold extends StatelessWidget {
  const _SplashScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppConstants.appName,
          style: AppTextStyles.displayLarge.copyWith(
            color: AppColors.primaryVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const SizedBox(height: AppSpacing.xxl),
        const CircularProgressIndicator(color: AppColors.primary),
      ],
    );
  }
}

class _BlockedMessage extends StatelessWidget {
  const _BlockedMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: AppColors.warning),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: AppTextStyles.heading1, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: AppTextStyles.bodyMuted,
          textAlign: TextAlign.center,
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          ...actions,
        ],
      ],
    );
  }
}
