import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/bet_validation.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../models/bet.dart';
import '../../models/enums.dart';
import '../../models/game_round.dart';
import '../../providers/game_providers.dart';
import '../../providers/service_providers.dart';
import '../../widgets/live_multiplier_builder.dart';

/// One independent betting slot (spec §17/§26 — "MISE 1" / "MISE 2"):
/// amount stepper + quick chips + custom input, an optional
/// auto-cashout multiplier, a MISER button (only enabled while the round
/// is accepting bets and this slot hasn't already bet this round) and an
/// ENCAISSER button that appears once this slot's bet goes ACTIVE and the
/// round starts RUNNING, showing the live potential payout.
class BetPanel extends ConsumerStatefulWidget {
  const BetPanel({super.key, required this.slot});

  final int slot;

  @override
  ConsumerState<BetPanel> createState() => _BetPanelState();
}

class _BetPanelState extends ConsumerState<BetPanel> {
  static const double _step = 100;

  double _amount = GameConstants.quickBetAmounts.first;
  bool _autoCashoutEnabled = false;
  bool _isSubmitting = false;
  late final TextEditingController _amountController;
  late final TextEditingController _autoCashoutController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _amount.toStringAsFixed(0));
    _autoCashoutController = TextEditingController(text: '2.00');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _autoCashoutController.dispose();
    super.dispose();
  }

  void _setAmount(double value) {
    final clamped = BetValidation.clampAmount(value);
    setState(() {
      _amount = clamped;
      _amountController.text = clamped.toStringAsFixed(0);
    });
  }

  Future<void> _placeBet(String roundId) async {
    double? autoCashout;
    if (_autoCashoutEnabled) {
      final parsed = double.tryParse(_autoCashoutController.text.replaceAll(',', '.'));
      if (parsed == null || !BetValidation.isValidAutoCashout(parsed)) {
        _showSnack(
          "Multiplicateur d'encaissement automatique invalide "
          '(min ${GameConstants.minAutoCashoutMultiplier}x).',
        );
        return;
      }
      autoCashout = parsed;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(gameServiceProvider)
          .placeBet(roundId: roundId, slot: widget.slot, amount: _amount, autoCashoutMultiplier: autoCashout);
    } catch (error) {
      _showSnack(friendlyBetErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cashout(String betId) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(gameServiceProvider).cashout(betId);
    } catch (error) {
      _showSnack(friendlyBetErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final round = ref.watch(currentRoundProvider).value;
    final myBets = ref.watch(myBetsForCurrentRoundProvider).value ?? const [];
    final myBet = myBets.where((b) => b.slot == widget.slot).firstOrNull;

    final canBet = round?.status == RoundStatus.betting && myBet == null;
    final canCashout = myBet != null && myBet.status == BetStatus.active && round?.status == RoundStatus.running;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MISE ${widget.slot}', style: AppTextStyles.heading2),
          const SizedBox(height: AppSpacing.sm),
          if (myBet != null) ...[
            _BetStatusLine(bet: myBet),
            if (canCashout) ...[
              const SizedBox(height: AppSpacing.sm),
              LiveMultiplierBuilder(
                round: round,
                builder: (context, multiplier) {
                  final potential = myBet.amount * multiplier;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: _isSubmitting ? null : () => _cashout(myBet.id),
                    child: Text('ENCAISSER ${Formatters.amount(potential)} FCFA'),
                  );
                },
              ),
            ],
          ] else ...[
            Row(
              children: [
                _StepButton(icon: Icons.remove, onTap: () => _setAmount(_amount - _step)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: TextField(
                      controller: _amountController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(isDense: true, suffixText: 'FCFA'),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null) setState(() => _amount = parsed);
                      },
                    ),
                  ),
                ),
                _StepButton(icon: Icons.add, onTap: () => _setAmount(_amount + _step)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final quick in GameConstants.quickBetAmounts)
                  _QuickChip(amount: quick, selected: _amount == quick, onTap: () => _setAmount(quick)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Switch(
                  value: _autoCashoutEnabled,
                  onChanged: (value) => setState(() => _autoCashoutEnabled = value),
                ),
                Expanded(child: Text('Auto-encaissement', style: AppTextStyles.bodyMuted)),
                if (_autoCashoutEnabled)
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _autoCashoutController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(isDense: true, suffixText: 'x'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: (canBet && !_isSubmitting && round != null) ? () => _placeBet(round.id) : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                    )
                  : Text(canBet ? 'MISER' : _disabledReason(round)),
            ),
          ],
        ],
      ),
    );
  }

  String _disabledReason(GameRound? round) {
    if (round == null) return 'CHARGEMENT…';
    return switch (round.status) {
      RoundStatus.running => 'TOUR EN COURS',
      RoundStatus.crashed => 'TOUR TERMINÉ',
      RoundStatus.result => 'PROCHAIN TOUR…',
      RoundStatus.waiting => 'EN ATTENTE',
      RoundStatus.betting => 'MISE DÉJÀ PLACÉE',
    };
  }
}

class _BetStatusLine extends StatelessWidget {
  const _BetStatusLine({required this.bet});

  final Bet bet;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (bet.status) {
      BetStatus.pending => ('Mise en attente — ${Formatters.amount(bet.amount)} FCFA', AppColors.textSecondary),
      BetStatus.active => ('Mise active — ${Formatters.amount(bet.amount)} FCFA', AppColors.primaryVariant),
      BetStatus.cashedOut => (
        'Encaissé à ${Formatters.multiplier(bet.cashoutMultiplier ?? 0)} — +${Formatters.amount(bet.payout ?? 0)} FCFA',
        AppColors.success,
      ),
      BetStatus.lost => ('Perdu — ${Formatters.amount(bet.amount)} FCFA', AppColors.danger),
      BetStatus.cancelled => ('Mise annulée', AppColors.textSecondary),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.smRadius),
      child: Text(label, style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.smRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: AppRadius.smRadius),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.amount, required this.selected, required this.onTap});

  final double amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.pillRadius,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: AppRadius.pillRadius,
        ),
        child: Text(Formatters.amount(amount), style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
