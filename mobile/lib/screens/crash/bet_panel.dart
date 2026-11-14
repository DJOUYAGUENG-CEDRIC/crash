import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_constants.dart';
import '../../core/utils/bet_validation.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/formatters.dart';
import '../../models/bet.dart';
import '../../models/enums.dart';
import '../../models/game_round.dart';
import '../../providers/game_providers.dart';
import '../../providers/service_providers.dart';
import '../../widgets/game_notice.dart';

/// One independent betting slot (spec §17/§26 — "MISE 1" / "MISE 2"):
/// amount stepper + quick chips + custom input, an optional
/// auto-cashout multiplier, a MISER button (only enabled while the round
/// is accepting bets and this slot hasn't already bet this round) and an
/// OBTENIR button that appears once this slot's bet goes ACTIVE and the
/// round starts RUNNING. The confirmed gain is only shown after the tap.
class BetPanel extends ConsumerStatefulWidget {
  const BetPanel({super.key, required this.slot});

  final int slot;

  @override
  ConsumerState<BetPanel> createState() => _BetPanelState();
}

class _BetPanelState extends ConsumerState<BetPanel> {
  double _amount = GameConstants.quickBetAmounts.first;
  bool _autoCashoutEnabled = false;
  bool _isSubmitting = false;
  String? _lastAutomaticRoundId;
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

  Future<void> _placeBet(String roundId, {bool automatic = false}) async {
    double? autoCashout;
    if (_autoCashoutEnabled) {
      final parsed = double.tryParse(
        _autoCashoutController.text.replaceAll(',', '.'),
      );
      if (parsed == null || !BetValidation.isValidAutoCashout(parsed)) {
        _showSnack(
          "Multiplicateur d'encaissement automatique invalide "
          '(${GameConstants.minAutoCashoutMultiplier}x à '
          '${GameConstants.maxAutoCashoutMultiplier.toStringAsFixed(0)}x).',
        );
        return;
      }
      autoCashout = parsed;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(gameServiceProvider)
          .placeBet(
            roundId: roundId,
            slot: widget.slot,
            amount: _amount,
            autoCashoutMultiplier: autoCashout,
          );
      gameNoticeController.show('Votre pari est accepté !');
    } catch (error) {
      if (automatic && mounted) {
        setState(() => _autoCashoutEnabled = false);
      }
      _showSnack(friendlyBetErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _scheduleAutomaticBet(GameRound? round, Bet? myBet) {
    if (!_autoCashoutEnabled ||
        round == null ||
        (round.status != RoundStatus.waiting &&
            round.status != RoundStatus.betting) ||
        (round.countdown ?? 1) <= 0 ||
        myBet != null ||
        _isSubmitting ||
        _lastAutomaticRoundId == round.id) {
      return;
    }

    // Reserve this round before scheduling the request. Realtime can rebuild
    // the panel several times during the countdown, but auto-play must submit
    // at most one bet per slot and per round.
    _lastAutomaticRoundId = round.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_autoCashoutEnabled || _isSubmitting) return;
      _placeBet(round.id, automatic: true);
    });
  }

  Future<void> _cashout(String betId) async {
    setState(() => _isSubmitting = true);
    try {
      final cashedOutBet = await ref.read(gameServiceProvider).cashout(betId);
      gameNoticeController.show(
        'Vous avez gagné : ${Formatters.amount(cashedOutBet.payout ?? 0)} XAF',
      );
    } catch (error) {
      _showSnack(friendlyBetErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final round = ref.watch(currentRoundProvider).value;
    final myBets = ref.watch(myBetsForCurrentRoundProvider).value ?? const [];
    final myBet = myBets.where((b) => b.slot == widget.slot).firstOrNull;

    _scheduleAutomaticBet(round, myBet);

    final canBet =
        (round?.status == RoundStatus.waiting ||
            round?.status == RoundStatus.betting) &&
        (round?.countdown ?? 1) > 0 &&
        myBet == null;
    final canCashout =
        myBet != null &&
        myBet.status == BetStatus.active &&
        round?.status == RoundStatus.running &&
        myBet.roundId == round?.id;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isLandscape ? 2 : 4),
      padding: EdgeInsets.all(isLandscape ? 4 : 6),
      decoration: BoxDecoration(
        color: const Color(0xFF171B3B),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                SizedBox(
                  height: isLandscape ? 32 : 40,
                  child: TextField(
                    controller: _amountController,
                    enabled: myBet == null,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      color: Color(0xFF171B3B),
                      fontSize: isLandscape ? 15 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 6 : 10,
                        vertical: isLandscape ? 4 : 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(color: Color(0xFF7885B5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF681B),
                          width: 2,
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      suffixIcon: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF20264B),
                          size: 18,
                        ),
                        onPressed: () =>
                            _setAmount(GameConstants.quickBetAmounts.first),
                      ),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) {
                        setState(() => _amount = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 5),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 5,
                  childAspectRatio: isLandscape ? 2 : 1.9,
                  children: [
                    for (final quick in GameConstants.quickBetAmounts)
                      _QuickChip(
                        amount: quick,
                        selected: _amount == quick,
                        onTap: myBet == null ? () => _setAmount(quick) : () {},
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => setState(
                    () => _autoCashoutEnabled = !_autoCashoutEnabled,
                  ),
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: isLandscape ? 34 : 42,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _autoCashoutEnabled
                          ? const Color(0x22FF681B)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: const Color(0xFFFF681B),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _autoCashoutEnabled
                          ? 'JEU AUTOMATIQUE\nACTIVÉ'
                          : 'ACTIVER LE JEU\nAUTOMATIQUE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFF762F),
                        fontSize: isLandscape ? 9 : 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (_autoCashoutEnabled) ...[
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 37,
                    child: TextField(
                      controller: _autoCashoutController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: 'x',
                        contentPadding: EdgeInsets.all(8),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                SizedBox(
                  height: _autoCashoutEnabled
                      ? (isLandscape ? 48 : 55)
                      : (isLandscape ? 48 : 66),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canCashout
                          ? const Color(0xFFFFB20F)
                          : const Color(0xFFFF620D),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF80432D),
                      disabledForegroundColor: Colors.white38,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : canCashout
                        ? () => _cashout(myBet.id)
                        : (canBet && round != null)
                        ? () => _placeBet(round.id)
                        : null,
                    child: _isSubmitting
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          )
                        : canCashout
                        ? Text(
                            'OBTENIR',
                            style: TextStyle(
                              fontSize: isLandscape ? 12 : 14,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  canBet
                                      ? 'PLACER UN PARI'
                                      : _disabledReason(round),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isLandscape ? 10 : 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (canBet)
                                  Text(
                                    '(sur le prochain tour)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isLandscape ? 8 : 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
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

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final double amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minWidth: isLandscape ? 0 : 48),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 2 : 4,
          vertical: isLandscape ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B3F78) : const Color(0xFF2A2F61),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected ? const Color(0xFFFF681B) : const Color(0xFF3C4276),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            Formatters.amount(amount),
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLandscape ? 10 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
