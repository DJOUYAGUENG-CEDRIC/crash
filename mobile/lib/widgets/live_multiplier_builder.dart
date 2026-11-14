import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/constants/game_constants.dart';
import '../core/utils/server_clock.dart';
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
  const LiveMultiplierBuilder({
    super.key,
    required this.round,
    required this.builder,
    this.maxMultiplier,
  });

  final GameRound? round;
  final Widget Function(BuildContext context, double multiplier) builder;
  final double? maxMultiplier;

  @override
  State<LiveMultiplierBuilder> createState() => _LiveMultiplierBuilderState();
}

class _LiveMultiplierBuilderState extends State<LiveMultiplierBuilder>
    with SingleTickerProviderStateMixin {
  static const _frameInterval = Duration(milliseconds: 33);

  late final Ticker _ticker;
  late double _multiplier;
  Duration _lastUpdate = Duration.zero;

  @override
  void initState() {
    super.initState();
    _multiplier = _compute();
    _ticker = createTicker(_onTick);
    _syncTicker();
  }

  double _compute() {
    final round = widget.round;
    if (round == null) return 1.0;
    if (round.status == RoundStatus.running) {
      final multiplier = round.liveMultiplier(
        GameConstants.growthRate,
        ServerClock.now(),
      );
      final maximum = widget.maxMultiplier;
      return maximum == null ? multiplier : math.min(multiplier, maximum);
    }
    return round.crashMultiplier ?? 1.0;
  }

  void _onTick(Duration elapsed) {
    if (widget.round?.status != RoundStatus.running) return;
    if (elapsed - _lastUpdate < _frameInterval) return;
    _lastUpdate = elapsed;
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
    _syncTicker();
  }

  void _syncTicker() {
    final shouldRun = widget.round?.status == RoundStatus.running;
    if (shouldRun && !_ticker.isActive) {
      _lastUpdate = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
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
