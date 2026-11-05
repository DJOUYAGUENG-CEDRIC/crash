import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Short French message for a failed admin call. Server error codes are
/// shown as-is because staff need the exact reason (unlike players).
String adminErrorMessage(Object error) {
  final raw = switch (error) {
    PostgrestException(:final message) => message,
    FunctionException(:final details) =>
      details is Map ? '${details['error'] ?? details}' : '$details',
    AuthException(:final message) => message,
    _ => error.toString(),
  };
  if (raw.startsWith('ACCESS DENIED')) {
    return "Accès refusé : vous n'avez pas la permission nécessaire.";
  }
  return raw;
}

void showAdminSnack(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : null,
    ),
  );
}

/// Runs a server action, then shows success or the server's error.
Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  try {
    await action();
    if (context.mounted) showAdminSnack(context, success);
    return true;
  } catch (error) {
    if (context.mounted) {
      showAdminSnack(context, adminErrorMessage(error), error: true);
    }
    return false;
  }
}

Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'CONFIRMER',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('ANNULER'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Loading / error / data scaffolding shared by every admin section,
/// with pull-to-refresh.
class AdminSectionList extends StatelessWidget {
  const AdminSectionList({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
    this.header = const [],
  });

  final AsyncValue<Object?> value;
  final Future<void> Function() onRefresh;
  final List<Widget> Function() builder;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final List<Widget> body;
    if (value.hasError && !value.hasValue) {
      body = [
        const SizedBox(height: AppSpacing.xxl),
        Icon(Icons.error_outline, color: AppColors.danger, size: 40),
        const SizedBox(height: AppSpacing.md),
        Text(
          adminErrorMessage(value.error!),
          style: AppTextStyles.bodyMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: OutlinedButton(
            onPressed: onRefresh,
            child: const Text('RÉESSAYER'),
          ),
        ),
      ];
    } else if (!value.hasValue) {
      body = const [
        SizedBox(height: AppSpacing.xxl),
        Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ];
    } else {
      body = builder();
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [...header, ...body],
      ),
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        child: InkWell(
          borderRadius: AppRadius.mdRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color)),
    );
  }
}

Color adminStatusColor(String status) => switch (status) {
  'ACTIVE' || 'PENDING' || 'RUNNING' => AppColors.success,
  'BLOCKED' || 'REVOKED' || 'CRASHED' => AppColors.danger,
  'WAITING' || 'BETTING' => AppColors.warning,
  _ => AppColors.textSecondary,
};

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.heading1),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: AppTextStyles.bodyMuted),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Text(
        message,
        style: AppTextStyles.bodyMuted,
        textAlign: TextAlign.center,
      ),
    );
  }
}
