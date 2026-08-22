import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/constants/game_constants.dart';
import '../models/enums.dart';
import '../models/game_round.dart';

/// Drives a per-frame [Ticker] scoped to whatever small widget subtree
/// [builder] returns — NOT the whole screen (spec §49: no unnecessary
/// rebuilds). While the round is RUNNING it recomputes
/// [GameRound.liveMultiplier] every frame; otherwise it freezes on the
/// round's final crash multiplier (or 1.0 while waiting/betting).
///
/// Reused for both the big centerpiece multiplier on the crash screen and
/// the live potential-payout figure inside each bet panel, so there's a
/// single ticking implementation instead of one per usage site.
class LiveMultiplierBuilder extends StatefulWidget {
  const LiveMultiplierBuilder({super.key, required this.round, required this.builder});

  final GameRound? round;
  final Widget Function(BuildContext context, double multiplier) builder;

  @override
  State<LiveMultiplierBuilder> createState() => _LiveMultiplierBuilderState();
}

class _LiveMultiplierBuilderState extends State<LiveMultiplierBuilder> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late double _multiplier;

  @override
  void initState() {
    super.initState();
    _multiplier = _compute();
    _ticker = createTicker(_onTick)..start();
  }

  double _compute() {
    final round = widget.round;
    if (round == null) return 1.0;
    if (round.status == RoundStatus.running) {
      return round.liveMultiplier(GameConstants.growthRate, DateTime.now());
    }
    return round.crashMultiplier ?? 1.0;
  }

  void _onTick(Duration elapsed) {
    if (widget.round?.status != RoundStatus.running) return;
    final next = _compute();
    if (next != _multiplier) {
      setState(() => _multiplier = next);
    }
  }

  @override
  void didUpdateWidget(covariant LiveMultiplierBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.round != widget.round) {
      _multiplier = _compute();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _multiplier);
}
