import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/server_clock.dart';
import '../../models/enums.dart';
import '../../models/game_round.dart';
import '../../providers/game_providers.dart';
import '../../widgets/crash_curve_painter.dart';
import '../../widgets/game_notice.dart';
import '../../widgets/live_bets_table.dart';
import '../../widgets/live_multiplier_builder.dart';
import '../../widgets/starfield_background.dart';
import 'bet_panel.dart';

/// The Crash tab (spec §17-§21) — the centerpiece screen: live animated
/// multiplier + curve, two independent bet slots.
class CrashScreen extends StatelessWidget {
  const CrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF151936),
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(child: _GameTab(label: 'Règles', outlined: true)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: _GameTab(
                      label: 'HISTORIQUE',
                      icon: Icons.alarm,
                      outlined: false,
                    ),
                  ),
                ],
              ),
            ),
            const _GameStageConnector(),
            const SizedBox(height: 5),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 700 && !isLandscape) {
                  return const Column(
                    children: [
                      BetPanel(slot: 1),
                      SizedBox(height: 5),
                      BetPanel(slot: 2),
                    ],
                  );
                }
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: BetPanel(slot: 1)),
                    SizedBox(width: 8),
                    Expanded(child: BetPanel(slot: 2)),
                  ],
                );
              },
            ),
            const SizedBox(height: 5),
            const LiveBetsTable(),
          ],
        ),
      ),
    );
  }
}

class _GameStageConnector extends ConsumerWidget {
  const _GameStageConnector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = ref.watch(currentRoundProvider).value;
    final targetMultiplier = ref
        .watch(currentRoundTargetMultiplierProvider)
        .value;
    return _GameStage(round: round, targetMultiplier: targetMultiplier);
  }
}

class _GameTab extends StatelessWidget {
  const _GameTab({required this.label, required this.outlined, this.icon});

  final String label;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    decoration: BoxDecoration(
      gradient: outlined
          ? null
          : const LinearGradient(
              colors: [Color(0xFFFF6500), Color(0xFFF13D58)],
            ),
      border: Border.all(color: const Color(0xFFFF681B), width: 1.5),
      borderRadius: BorderRadius.circular(7),
    ),
    alignment: Alignment.center,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            color: outlined ? const Color(0xFFFF762F) : Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class _GameStage extends StatefulWidget {
  const _GameStage({required this.round, required this.targetMultiplier});

  final GameRound? round;
  final double? targetMultiplier;

  @override
  State<_GameStage> createState() => _GameStageState();
}

class _GameStageState extends State<_GameStage>
    with SingleTickerProviderStateMixin {
  static const _crashAnimationDuration = Duration(milliseconds: 900);

  late final AnimationController _axisController;
  GameRound? _displayedRound;
  GameRound? _pendingRound;
  DateTime? _crashAnimationEndsAt;
  Timer? _roundTransitionTimer;
  Timer? _targetCrashTimer;

  @override
  void initState() {
    super.initState();
    _displayedRound = widget.round;
    if (_isCrashed(widget.round)) {
      _crashAnimationEndsAt = DateTime.now().add(_crashAnimationDuration);
    }
    _axisController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 734),
    );
    _scheduleTargetCrash();
    _syncAxisAnimation();
  }

  @override
  void didUpdateWidget(covariant _GameStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextRound = widget.round;
    if (_isCrashed(nextRound)) {
      final isNewCrash =
          !_isCrashed(_displayedRound) || _displayedRound?.id != nextRound?.id;
      _displayedRound = nextRound;
      _pendingRound = null;
      _roundTransitionTimer?.cancel();
      _roundTransitionTimer = null;
      _targetCrashTimer?.cancel();
      _targetCrashTimer = null;
      if (isNewCrash) {
        _crashAnimationEndsAt = DateTime.now().add(_crashAnimationDuration);
      }
    } else if (_isCrashed(_displayedRound)) {
      if (nextRound?.id != _displayedRound?.id) {
        _pendingRound = nextRound;
        _showPendingRoundAfterCrash();
      }
    } else {
      _displayedRound = nextRound;
      _scheduleTargetCrash();
    }
    _syncAxisAnimation();
  }

  bool _isCrashed(GameRound? round) =>
      round?.status == RoundStatus.crashed ||
      round?.status == RoundStatus.result;

  Duration? _timeToTargetCrash(GameRound round, double targetMultiplier) {
    final startedAt = round.runningStartedAt;
    if (round.status != RoundStatus.running || startedAt == null) return null;
    final crashElapsedSeconds =
        math.log(math.max(1.0, targetMultiplier)) / GameConstants.growthRate;
    final crashAt = startedAt.add(
      Duration(microseconds: (crashElapsedSeconds * 1000000).ceil()),
    );
    return crashAt.difference(ServerClock.now());
  }

  void _scheduleTargetCrash() {
    _targetCrashTimer?.cancel();
    _targetCrashTimer = null;
    final round = widget.round;
    final target = widget.targetMultiplier;
    if (round == null || target == null) return;

    final remaining = _timeToTargetCrash(round, target);
    if (remaining == null) return;

    void showCrash() {
      if (!mounted || widget.round?.id != round.id) return;
      setState(() {
        _displayedRound = round.copyWith(
          status: RoundStatus.crashed,
          crashMultiplier: target,
          crashedAt: ServerClock.now(),
        );
        _crashAnimationEndsAt = DateTime.now().add(_crashAnimationDuration);
      });
      _targetCrashTimer = null;
      _syncAxisAnimation();
    }

    if (remaining <= Duration.zero) {
      showCrash();
    } else {
      _targetCrashTimer = Timer(remaining, showCrash);
    }
  }

  void _showPendingRoundAfterCrash() {
    final endsAt = _crashAnimationEndsAt;
    final remaining = endsAt == null
        ? Duration.zero
        : endsAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _displayedRound = _pendingRound;
      _pendingRound = null;
      _crashAnimationEndsAt = null;
      _roundTransitionTimer?.cancel();
      _roundTransitionTimer = null;
      return;
    }

    _roundTransitionTimer?.cancel();
    _roundTransitionTimer = Timer(remaining, () {
      if (!mounted) return;
      setState(() {
        _displayedRound = _pendingRound;
        _pendingRound = null;
        _crashAnimationEndsAt = null;
        _roundTransitionTimer = null;
      });
      _syncAxisAnimation();
    });
  }

  void _syncAxisAnimation() {
    if (_displayedRound?.status == RoundStatus.running) {
      if (!_axisController.isAnimating) {
        _axisController.repeat();
      }
    } else {
      _axisController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _roundTransitionTimer?.cancel();
    _targetCrashTimer?.cancel();
    _axisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = _displayedRound;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Container(
      key: const ValueKey('crash-game-stage'),
      height: isLandscape ? 112 : 160,
      width: double.infinity,
      decoration: BoxDecoration(color: const Color(0xFF151936)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: StarfieldBackground()),
          AnimatedBuilder(
            animation: _axisController,
            builder: (context, child) => Positioned.fill(
              child: CustomPaint(
                painter: _StageBackdropPainter(_axisController.value),
              ),
            ),
          ),
          switch (round?.status) {
            null => const _CountdownDisplay(
              seconds: GameConstants.bettingDurationSeconds,
            ),
            RoundStatus.waiting ||
            RoundStatus.betting => _WaitingStage(round: round!),
            RoundStatus.running => _RunningStage(
              round: round!,
              targetMultiplier: widget.targetMultiplier,
            ),
            RoundStatus.crashed ||
            RoundStatus.result => _CrashedStage(round: round!),
          },
          const Positioned(
            left: 36,
            right: 108,
            top: 54,
            child: Center(child: GameNoticeOverlay()),
          ),
        ],
      ),
    );
  }
}

class _StageBackdropPainter extends CustomPainter {
  const _StageBackdropPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final mountainPaint = Paint()
      ..color = const Color(0xFF202653).withValues(alpha: .72);
    final mountain = Path()
      ..moveTo(0, size.height * .58)
      ..lineTo(size.width * .08, size.height * .48)
      ..lineTo(size.width * .15, size.height * .54)
      ..lineTo(size.width * .25, size.height * .36)
      ..lineTo(size.width * .34, size.height * .57)
      ..lineTo(size.width * .45, size.height * .43)
      ..lineTo(size.width * .55, size.height * .59)
      ..lineTo(size.width * .68, size.height * .45)
      ..lineTo(size.width * .78, size.height * .57)
      ..lineTo(size.width * .89, size.height * .40)
      ..lineTo(size.width, size.height * .55)
      ..lineTo(size.width, size.height * .82)
      ..quadraticBezierTo(
        size.width * .7,
        size.height * .72,
        size.width * .48,
        size.height * .82,
      )
      ..quadraticBezierTo(
        size.width * .22,
        size.height * .92,
        0,
        size.height * .72,
      )
      ..close();
    canvas.drawPath(mountain, mountainPaint);

    final dashPaint = Paint()
      ..color = const Color(0xFFB2B8D0).withValues(alpha: .17)
      ..strokeWidth = 1;
    for (
      double y = size.height * .16;
      y < size.height * .76;
      y += size.height * .18
    ) {
      for (double x = 18; x < size.width; x += 9) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 3, size.width), y),
          dashPaint,
        );
      }
    }

    final dotPaint = Paint()
      ..color = const Color(0xFFD5D9E8).withValues(alpha: .68);

    const axisX = 14.0;
    final axisY = size.height - 16;
    const intersectionGap = 6.0;
    final verticalStart = size.height * .10;
    final verticalEnd = axisY - intersectionGap;
    final verticalSpan = verticalEnd - verticalStart;
    final verticalGap = verticalSpan / 6;
    for (var i = 0; i < 6; i++) {
      final y =
          verticalStart +
          ((i * verticalGap + progress * verticalGap) % verticalSpan);
      canvas.drawCircle(Offset(axisX, y), 2.35, dotPaint);
    }

    final horizontalStart = axisX + intersectionGap;
    final horizontalSpan = size.width - horizontalStart;
    final horizontalGap = horizontalSpan / 6;
    for (var i = 0; i < 6; i++) {
      final shifted = i * horizontalGap - progress * horizontalGap;
      final wrapped =
          (shifted % horizontalSpan + horizontalSpan) % horizontalSpan;
      canvas.drawCircle(
        Offset(horizontalStart + wrapped, axisY),
        2.4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StageBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WaitingStage extends StatefulWidget {
  const _WaitingStage({required this.round});

  final GameRound round;

  @override
  State<_WaitingStage> createState() => _WaitingStageState();
}

class _WaitingStageState extends State<_WaitingStage>
    with TickerProviderStateMixin {
  late final AnimationController _particleController;
  late final AnimationController _clockController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    // This controller only requests repaints. Countdown and dash positions
    // are derived from the shared betting_started_at timestamp below.
    _clockController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _particleController.dispose();
    _clockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_particleController, _clockController]),
      builder: (context, child) {
        final startedAt = widget.round.bettingStartedAt;
        final elapsedMs = startedAt == null
            ? null
            : math.max(
                0,
                ServerClock.now().difference(startedAt).inMilliseconds,
              );
        final remainingMs = elapsedMs == null
            ? null
            : math.max(
                0,
                GameConstants.bettingDurationSeconds * 1000 - elapsedMs,
              );
        final seconds = remainingMs == null
            ? (widget.round.countdown ?? 0)
                  .clamp(1, GameConstants.bettingDurationSeconds)
                  .toInt()
            : (remainingMs / 1000).ceil().clamp(
                1,
                GameConstants.bettingDurationSeconds,
              );
        final ballProgress = elapsedMs == null
            ? _clockController.value
            : (elapsedMs % 1000) / 1000.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _FallingDebrisPainter(_particleController.value),
            ),
            _CountdownDisplay(seconds: seconds, ballProgress: ballProgress),
          ],
        );
      },
    );
  }
}

class _FallingDebrisPainter extends CustomPainter {
  const _FallingDebrisPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(13307);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (.38 + random.nextDouble() * .60);
      final speed = .55 + random.nextDouble() * .75;
      final phase = (progress * speed + random.nextDouble()) % 1;
      final y = phase * (size.height + 24) - 12;
      final opacity =
          (.10 + random.nextDouble() * .20) * math.sin(math.pi * phase).abs();
      final paint = Paint()
        ..color = (i % 6 == 0 ? const Color(0xFFFF681B) : Colors.white)
            .withValues(alpha: opacity)
        ..strokeWidth = i % 6 == 0 ? 1.8 : 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 1.5, y + 4 + random.nextDouble() * 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FallingDebrisPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _CountdownDisplay extends StatelessWidget {
  const _CountdownDisplay({required this.seconds, this.ballProgress = 0});

  final int seconds;
  final double ballProgress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _CountdownPainter(
              seconds: seconds,
              ballProgress: ballProgress,
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 20,
          child: Text(
            '$seconds',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownPainter extends CustomPainter {
  const _CountdownPainter({required this.seconds, required this.ballProgress});

  final int seconds;
  final double ballProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final count = seconds.clamp(0, GameConstants.bettingDurationSeconds);
    final pivot = Offset(size.width * .72, size.height * .78);
    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    final orangePaint = Paint()
      ..color = const Color(0xFFFF681B)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;

    const startAngle = -115 * math.pi / 180;
    const sweepAngle = 90 * math.pi / 180;
    final radius = size.height * .53;

    const visibleArcSlots = 5;

    Offset pointFor(double slot) {
      final t = (slot - 1) / (visibleArcSlots - 1);
      final angle = startAngle + sweepAngle * t;
      return Offset(
        pivot.dx + radius * (math.sin(angle) - math.sin(startAngle)),
        pivot.dy + radius * (-math.cos(angle) + math.cos(startAngle)),
      );
    }

    Offset directionFor(double slot) {
      final markAngle =
          ((slot - 1) * 90 / (visibleArcSlots - 1)) * math.pi / 180;
      return Offset(math.cos(markAngle), math.sin(markAngle));
    }

    final remainingTicks = count.clamp(1, GameConstants.bettingDurationSeconds);
    final phase = ballProgress.clamp(0.0, 1.0);

    // One mark disappears while the ball rises. As the ball comes back,
    // every remaining mark advances exactly one position towards it.
    // This leaves the ball aligned with the following second at rest.
    final currentHasDisappeared = remainingTicks > 1 && phase >= .50;
    final advance = remainingTicks > 1
        ? Curves.easeInOutCubic.transform(((phase - .50) / .44).clamp(0.0, 1.0))
        : 0.0;
    final visibleCount = math.min(remainingTicks, visibleArcSlots);

    for (var slot = 1; slot <= visibleCount; slot++) {
      if (slot == 1 && currentHasDisappeared) continue;
      final movingSlot = slot == 1 ? 1.0 : slot - advance;
      final point = pointFor(movingSlot);
      final direction = directionFor(movingSlot);
      final isOrange =
          remainingTicks <= visibleArcSlots && slot == visibleCount;
      canvas.drawLine(
        point - direction * (isOrange ? 5.3 : 5.0),
        point + direction * (isOrange ? 5.3 : 5.0),
        isOrange ? orangePaint : whitePaint,
      );
    }

    // At 7 a white mark enters. At 6 the entering mark is orange; it then
    // stays orange and advances one position per second until it reaches 1.
    if (remainingTicks > visibleArcSlots) {
      final incomingSlot = visibleArcSlots + 1 - advance;
      if (advance > 0) {
        final reveal = advance;
        final point = pointFor(incomingSlot);
        final direction = directionFor(incomingSlot);
        final incomingIsOrange = remainingTicks == visibleArcSlots + 1;
        final enteringPaint = Paint()
          ..color = (incomingIsOrange ? orangePaint.color : Colors.white)
              .withValues(alpha: reveal)
          ..strokeWidth = incomingIsOrange ? 4.2 : 4.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          point - direction * (incomingIsOrange ? 5.3 : 5.0) * reveal,
          point + direction * (incomingIsOrange ? 5.3 : 5.0) * reveal,
          enteringPaint,
        );
      }
    }

    const alignmentGap = Offset(14, 0);
    final restingPoint = pointFor(1) + alignmentGap;
    final intervalPoint = remainingTicks > 1
        ? Offset.lerp(pointFor(1), pointFor(2), .42)! + alignmentGap
        : restingPoint + const Offset(0, -9);

    double excursion;
    if (phase < .50) {
      excursion = Curves.easeOutCubic.transform(phase / .50);
    } else {
      excursion = 1 - Curves.easeInCubic.transform((phase - .50) / .50);
    }

    final ballPoint = Offset.lerp(restingPoint, intervalPoint, excursion)!;
    canvas.drawCircle(ballPoint, 5.0, whitePaint);
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter oldDelegate) =>
      oldDelegate.seconds != seconds ||
      oldDelegate.ballProgress != ballProgress;
}

class _RunningStage extends StatelessWidget {
  const _RunningStage({required this.round, required this.targetMultiplier});

  final GameRound round;
  final double? targetMultiplier;

  @override
  Widget build(BuildContext context) {
    final target = targetMultiplier;
    if (target == null) {
      return const Center(
        child: Text(
          'Synchronisation de la cote en cours…',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final targetElapsedSeconds =
        math.log(math.max(1.0, target)) / GameConstants.growthRate;
    return LiveMultiplierBuilder(
      round: round,
      maxMultiplier: target,
      builder: (context, multiplier) {
        final rawElapsedSeconds = round.runningStartedAt == null
            ? 0.0
            : ServerClock.now()
                      .difference(round.runningStartedAt!)
                      .inMilliseconds /
                  1000.0;
        final elapsedSeconds = math.min(
          rawElapsedSeconds,
          targetElapsedSeconds,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: CrashCurvePainter(
                multiplier: multiplier,
                elapsedSeconds: elapsedSeconds,
                crashed: false,
                drawPlane: false,
              ),
            ),
            _PlaneSprite(elapsedSeconds: elapsedSeconds),
            Positioned(
              right: 22,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.multiplier(multiplier),
                    style: AppTextStyles.multiplier.copyWith(
                      fontSize: multiplier >= 10 ? 40 : 48,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlaneSprite extends StatelessWidget {
  const _PlaneSprite({required this.elapsedSeconds});

  final double elapsedSeconds;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final t = (elapsedSeconds / CrashCurvePainter.animationDurationSeconds)
          .clamp(0.0, 1.0);
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final x = width * (.02 + (.73 - .02) * t);
      final topClearance = math.min(28.0, height * .32);
      final startY = height * .92;
      const k = 2.35;
      final ease = (math.exp(k * t) - 1) / (math.exp(k) - 1);
      final y = startY - (startY - topClearance) * ease;
      return Stack(
        children: [
          Positioned(
            left: x - 57,
            top: y - 28,
            width: 64,
            height: 52,
            child: Image.asset(
              'assets/images/crash_plane_v2.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      );
    },
  );
}

class _CrashedStage extends StatelessWidget {
  const _CrashedStage({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final crashValue = round.crashMultiplier ?? 1.0;
    // Place the final frame at the exact instant where exp(rate * t) reaches
    // the authoritative crash value. A delayed server tick must never move
    // the plane beyond the announced value and then make it jump backwards.
    final elapsedSeconds = crashValue <= 1
        ? 0.0
        : math.log(crashValue) / GameConstants.growthRate;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('global-crash-stage'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.linear,
      builder: (context, explosionProgress, child) => Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: CrashCurvePainter(
              multiplier: crashValue,
              elapsedSeconds: elapsedSeconds,
              crashed: true,
              explosionProgress: explosionProgress,
            ),
          ),
          Positioned(
            right: 22,
            bottom: 16,
            child: Text(
              Formatters.multiplier(crashValue),
              style: AppTextStyles.multiplier.copyWith(
                color: Colors.white,
                fontSize: crashValue >= 10 ? 40 : 48,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
