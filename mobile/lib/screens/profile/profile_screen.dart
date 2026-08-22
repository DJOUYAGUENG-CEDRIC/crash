import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/bet.dart';
import '../../models/enums.dart';
import '../../providers/auth_providers.dart';
import '../../providers/game_providers.dart';
import '../../providers/service_providers.dart';
import '../../providers/wallet_providers.dart';
import '../../services/supabase_service.dart';

/// Reads the signed-in player's own rows from `authorized_devices`
/// directly (RLS already scopes this to `auth.uid()` — see
/// services/activation_service.dart's doc comment on check_activation).
/// Kept as a screen-local provider rather than growing ActivationService,
/// since this is a read-only display concern, not device-registration
/// logic.
final _myDevicesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final rows = await SupabaseService.client.from('authorized_devices').select().eq('user_id', userId);
  return (rows as List).cast<Map<String, dynamic>>();
});

/// Profile tab (spec §28): editable display name, email, live balance,
/// client-side aggregated stats from the player's own bet history, and
/// the devices authorized on this account.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final walletAsync = ref.watch(walletProvider);
    final betsAsync = ref.watch(myBetHistoryProvider);
    final devicesAsync = ref.watch(_myDevicesProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(myBetHistoryProvider);
          ref.invalidate(_myDevicesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Profil', style: AppTextStyles.heading1),
            const SizedBox(height: AppSpacing.lg),
            profileAsync.when(
              data: (profile) => _ProfileCard(
                displayName: profile.displayName,
                email: profile.email,
                balance: walletAsync.value?.balance,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Impossible de charger le profil.', style: AppTextStyles.bodyMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Statistiques', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            betsAsync.when(
              data: (bets) => _StatsGrid(bets: bets),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Impossible de charger les statistiques.', style: AppTextStyles.bodyMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Appareil associé', style: AppTextStyles.heading2),
            const SizedBox(height: AppSpacing.sm),
            devicesAsync.when(
              data: (devices) {
                if (devices.isEmpty) {
                  return Text('Aucun appareil enregistré.', style: AppTextStyles.bodyMuted);
                }
                return Column(children: [for (final d in devices) _DeviceRow(device: d)]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Impossible de charger vos appareils.', style: AppTextStyles.bodyMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.displayName, required this.email, required this.balance});

  final String displayName;
  final String email;
  final double? balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: AppTextStyles.heading2),
                    Text(email, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                tooltip: "Modifier le nom d'affichage",
                onPressed: () => _showEditNameDialog(context, ref, displayName),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Solde virtuel', style: AppTextStyles.bodyMuted),
              const Spacer(),
              Text(
                balance == null ? '…' : '${Formatters.amount(balance!)} FCFA',
                style: AppTextStyles.heading2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text("Modifier le nom d'affichage"),
        content: TextField(controller: controller, autofocus: true, style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ANNULER')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('ENREGISTRER'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;
    try {
      await ref.read(authServiceProvider).updateDisplayName(newName);
      ref.invalidate(profileProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Impossible de modifier le nom pour le moment.')));
      }
    }
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.bets});

  final List<Bet> bets;

  @override
  Widget build(BuildContext context) {
    final played = bets.length;
    final wins = bets.where((b) => b.status == BetStatus.cashedOut).length;
    final losses = bets.where((b) => b.status == BetStatus.lost).length;
    final totalStaked = bets.fold<double>(0, (sum, b) => sum + b.amount);
    final totalWon = bets
        .where((b) => b.status == BetStatus.cashedOut)
        .fold<double>(0, (sum, b) => sum + (b.payout ?? 0));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.4,
      children: [
        _StatTile(label: 'Parties jouées', value: '$played'),
        _StatTile(label: 'Victoires', value: '$wins', color: AppColors.success),
        _StatTile(label: 'Pertes', value: '$losses', color: AppColors.danger),
        _StatTile(label: 'Total misé', value: '${Formatters.amount(totalStaked)} FCFA'),
        _StatTile(label: 'Total gagné', value: '${Formatters.amount(totalWon)} FCFA', color: AppColors.success),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final Map<String, dynamic> device;

  @override
  Widget build(BuildContext context) {
    final name = (device['device_name'] as String?) ?? 'Appareil';
    final platform = (device['platform'] as String?) ?? '';
    // Matches authorized_devices in supabase/migrations/0001_initial_schema.sql
    // (last_seen, not last_seen_at — that table has no updated_at column).
    final lastSeenRaw = (device['last_seen'] ?? device['created_at']) as String?;
    final lastSeen = lastSeenRaw == null ? null : DateTime.tryParse(lastSeenRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.smartphone_rounded, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.body),
                Text(
                  [if (platform.isNotEmpty) platform, if (lastSeen != null) 'vu le ${Formatters.dateTime(lastSeen)}']
                      .join(' · '),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
