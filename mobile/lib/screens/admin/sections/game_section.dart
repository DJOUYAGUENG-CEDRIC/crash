import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/admin_models.dart';
import '../../../models/enums.dart';
import '../../../models/game_round.dart';
import '../../../providers/admin_providers.dart';
import '../../../providers/game_providers.dart';
import '../../../widgets/live_multiplier_builder.dart';
import '../admin_widgets.dart';

final _gameSettingsProvider = FutureProvider.autoDispose<GameSettings?>(
  (ref) => ref.watch(adminServiceProvider).fetchGameSettings(),
);

/// Live supervision of the shared round: the same public round every
/// player's device follows, plus the operational controls.
class GameSection extends ConsumerWidget {
  const GameSection({super.key, required this.account});

  final AdminAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = ref.watch(currentRoundProvider);
    final canControl = account.can(AdminPermissions.controlGame);

    return AdminSectionList(
      value: round,
      onRefresh: () async {
        ref.invalidate(currentRoundProvider);
        ref.invalidate(recentRoundsProvider);
        ref.invalidate(_gameSettingsProvider);
      },
      builder: () => [
        _LiveRoundCard(round: round.value, canControl: canControl),
        const SizedBox(height: AppSpacing.lg),
        const _RecentRounds(),
        if (canControl) ...[
          const SizedBox(height: AppSpacing.lg),
          const _GameSettingsForm(),
        ],
      ],
    );
  }
}

class _LiveRoundCard extends ConsumerWidget {
  const _LiveRoundCard({required this.round, required this.canControl});

  final GameRound? round;
  final bool canControl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = this.round;
    if (round == null) return const AdminEmptyState('Aucune manche en cours.');
    final status = round.status.name.toUpperCase();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Manche #${round.roundNumber}',
                style: AppTextStyles.heading2,
              ),
              const Spacer(),
              AdminStatusChip(status, color: adminStatusColor(status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: LiveMultiplierBuilder(
              round: round,
              builder: (context, multiplier) => Text(
                switch (round.status) {
                  RoundStatus.waiting ||
                  RoundStatus.betting => 'Mises : ${round.countdown ?? 0} s',
                  _ => Formatters.multiplier(multiplier),
                },
                style: AppTextStyles.multiplier.copyWith(
                  color: round.status == RoundStatus.running
                      ? AppColors.multiplierRising
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${round.totalPlayers} joueur(s) · '
            '${Formatters.amount(round.totalBetsAmount)} misés',
            style: AppTextStyles.bodyMuted,
          ),
          if (canControl && round.status == RoundStatus.running) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('ARRÊTER LA MANCHE'),
                onPressed: () async {
                  final ok = await confirmAdminAction(
                    context,
                    title: 'Arrêter la manche ?',
                    message:
                        'La manche crashe immédiatement pour tous les '
                        'appareils. Les mises encore actives sont perdues.',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  await runAdminAction(
                    context,
                    ref.read(adminServiceProvider).forceCrash,
                    success: 'La manche a été arrêtée.',
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentRounds extends ConsumerWidget {
  const _RecentRounds();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rounds = ref.watch(recentRoundsProvider).value ?? const [];
    final finished = rounds.where((r) => r.crashMultiplier != null).take(12);
    if (finished.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Derniers crashs', style: AppTextStyles.heading2),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final r in finished)
              AdminStatusChip(
                Formatters.multiplier(r.crashMultiplier!),
                color: r.crashMultiplier! >= 2
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
          ],
        ),
      ],
    );
  }
}

class _GameSettingsForm extends ConsumerStatefulWidget {
  const _GameSettingsForm();

  @override
  ConsumerState<_GameSettingsForm> createState() => _GameSettingsFormState();
}

class _GameSettingsFormState extends ConsumerState<_GameSettingsForm> {
  final _duration = TextEditingController();
  final _minBet = TextEditingController();
  final _maxBet = TextEditingController();
  final _houseEdge = TextEditingController();
  GameSettings? _loaded;
  bool _saving = false;

  @override
  void dispose() {
    _duration.dispose();
    _minBet.dispose();
    _maxBet.dispose();
    _houseEdge.dispose();
    super.dispose();
  }

  void _fill(GameSettings settings) {
    if (identical(settings, _loaded)) return;
    _loaded = settings;
    _duration.text = '${settings.bettingDurationSeconds}';
    _minBet.text = settings.minBet.toStringAsFixed(0);
    _maxBet.text = settings.maxBet.toStringAsFixed(0);
    _houseEdge.text = '${settings.houseEdgePercent}';
  }

  Future<void> _save() async {
    final duration = int.tryParse(_duration.text);
    final minBet = double.tryParse(_minBet.text);
    final maxBet = double.tryParse(_maxBet.text);
    final houseEdge = double.tryParse(_houseEdge.text.replaceAll(',', '.'));
    if (duration == null ||
        minBet == null ||
        maxBet == null ||
        houseEdge == null) {
      showAdminSnack(context, 'Valeurs invalides.', error: true);
      return;
    }
    setState(() => _saving = true);
    final ok = await runAdminAction(
      context,
      () => ref
          .read(adminServiceProvider)
          .updateGameSettings(
            GameSettings(
              bettingDurationSeconds: duration,
              minBet: minBet,
              maxBet: maxBet,
              houseEdgePercent: houseEdge,
            ),
          ),
      success: 'Réglages enregistrés.',
    );
    if (ok) ref.invalidate(_gameSettingsProvider);
    if (mounted) setState(() => _saving = false);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
          ),
        ],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(_gameSettingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    _fill(settings);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Réglages du jeu', style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.md),
          _field(_duration, 'Durée des mises (s)'),
          _field(_minBet, 'Mise minimale'),
          _field(_maxBet, 'Mise maximale'),
          _field(_houseEdge, 'Avantage maison (%)', decimal: true),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'ENREGISTREMENT…' : 'ENREGISTRER'),
          ),
        ],
      ),
    );
  }
}
