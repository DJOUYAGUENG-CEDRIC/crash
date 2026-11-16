import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Draws the crash-game growth curve and plane, both parameterized
/// purely by elapsed-time-fraction `t/duration` against a smooth
/// exponential ease (curvature `k`) — never by the raw multiplier
/// value directly, so motion stays visually fluid and bounded
/// regardless of how high the multiplier climbs. Position formulas:
///
///   x(t) = startX + maxX * (t/duration)
///   y(t) = startY - height * (e^(k*(t/duration)) - 1) / (e^k - 1)
///
/// The plane never reaches the right edge (maxX stops [marginRight]
/// short of it) and speed increases progressively and smoothly — the
/// exponential ease itself produces continuously increasing apparent
/// speed as t grows, without any discrete/stepped jumps.
class CrashCurvePainter extends CustomPainter {
  const CrashCurvePainter({
    required this.multiplier,
    required this.elapsedSeconds,
    required this.crashed,
    this.flightDurationSeconds = CrashCurvePainter.animationDurationSeconds,
    this.explosionProgress = .42,
    this.drawPlane = true,
  });

  final double multiplier;
  final double elapsedSeconds;
  final bool crashed;
  final double flightDurationSeconds;

  /// 0 = impact, 1 = smoke fully dispersed. This is visual only: the
  /// server timestamp remains the single source of truth for the crash.
  final double explosionProgress;
  final bool drawPlane;

  static const int _sampleCount = 40;

  /// Reference round length used to normalize t/duration. Actual crash
  /// time is decided server-side and unknown to the client in advance
  /// (spec §19/§20) — this is purely an animation-pacing constant, not
  /// a prediction. Rounds shorter than this reach the "peak" pose
  /// early; longer ones stay parked near it (see [_tFraction] clamp).
  /// A shorter duration makes the plane travel noticeably faster.
  static const double animationDurationSeconds = 15.0;

  /// Curvature factor — within the recommended 2.5-4.5 range.
  static const double _k = 2.35;

  static const double _marginRightFraction = 0.27;
  static const double _startXFraction = 0.02;
  static const double _topPlaneClearance = 28.0;

  double get _tFraction =>
      (elapsedSeconds / flightDurationSeconds).clamp(0.0, 1.0);

  double _xOf(double size, double tFraction) {
    final startX = size * _startXFraction;
    final maxX = size * (1 - _marginRightFraction);
    return startX + (maxX - startX) * tFraction;
  }

  double _yOf(double size, double tFraction) {
    final topClearance = math.min(_topPlaneClearance, size * 0.32);
    final startY = size * 0.92;
    final usableHeight = startY - topClearance;
    final ease = (math.exp(_k * tFraction) - 1) / (math.exp(_k) - 1);
    return startY - usableHeight * ease;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFFFD12F);
    final tFraction = _tFraction;

    final path = Path();
    Offset tip = Offset(0, size.height);
    for (var i = 0; i <= _sampleCount; i++) {
      final sampleT = tFraction * (i / _sampleCount);
      final point = Offset(
        _xOf(size.width, sampleT),
        _yOf(size.height, sampleT),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      tip = point;
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    if (crashed) {
      _drawExplosion(canvas, tip);
    } else if (drawPlane) {
      _drawPlane(canvas, tip, color);
    }
  }

  void _drawExplosion(Canvas canvas, Offset tip) {
    final phase = explosionProgress.clamp(0.0, 1.0);
    final burst = Curves.easeOutCubic.transform(math.min(phase / .58, 1));
    // Keep the wreck visible until the next round. The first burst still
    // animates, but it no longer fades to an empty curve after one second.
    final opacity = phase < .62 ? 1.0 : math.max(.62, (1 - phase) / .38);
    // The burst must remain beside the multiplier, not cover it. Its final
    // footprint mirrors the compact explosion shown in the reference video.
    final spread = .24 + burst * .56;

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.scale(spread);
    canvas.translate(-tip.dx, -tip.dy);
    canvas.drawCircle(
      tip,
      30,
      Paint()..color = const Color(0xFFFF8A18).withValues(alpha: .30 * opacity),
    );
    final smoke = Paint()
      ..color = const Color(0xFF827575).withValues(alpha: .82 * opacity);
    final darkSmoke = Paint()
      ..color = const Color(0xFF554D55).withValues(alpha: .9 * opacity);
    final fire = Paint()
      ..color = const Color(0xFFFFD12F).withValues(alpha: opacity);
    final hotFire = Paint()
      ..color = const Color(0xFFFF5A16).withValues(alpha: opacity);
    const cloud = [
      Offset(-19, -13),
      Offset(-8, -24),
      Offset(6, -22),
      Offset(18, -12),
      Offset(-23, 1),
      Offset(-8, -5),
      Offset(8, -5),
      Offset(23, 1),
      Offset(-14, 12),
      Offset(2, 10),
      Offset(15, 14),
    ];
    for (var i = 0; i < cloud.length; i++) {
      canvas.drawCircle(
        tip + cloud[i],
        i.isEven ? 9 : 7,
        i % 3 == 0 ? darkSmoke : smoke,
      );
    }
    canvas.drawCircle(tip, 11, hotFire);
    canvas.drawCircle(tip + const Offset(4, -3), 6, fire);

    final debrisPaint = Paint()
      ..color = const Color(0xFFFF8A18).withValues(alpha: opacity)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const debris = [
      (Offset(-31, -23), Offset(-39, -31)),
      (Offset(27, -20), Offset(38, -27)),
      (Offset(-30, 20), Offset(-40, 28)),
      (Offset(28, 18), Offset(39, 25)),
      (Offset(1, -34), Offset(3, -45)),
    ];
    for (final piece in debris) {
      canvas.drawLine(tip + piece.$1, tip + piece.$2, debrisPaint);
    }
    canvas.restore();
  }

  /// An original, hand-drawn side-view propeller-plane silhouette
  /// (nose, canopy, tail fin, swept wing, spinning propeller) — not a
  /// copied asset or stock icon. Nose tilted up 5-10° as specified.
  void _drawPlane(Canvas canvas, Offset tip, Color bodyColor) {
    const scale = 1.7;
    const tilt = -7.5 * math.pi / 180; // nose-up tilt, within the 5°-10° range

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(tilt);
    canvas.scale(scale);

    final fill = Paint()..color = const Color(0xFFFFC928);
    final darkFill = Paint()..color = const Color(0xFFFF7A16);

    // Fuselage — nose points toward +x (direction of travel).
    final fuselage = Path()
      ..moveTo(16, 0)
      ..quadraticBezierTo(10, -5, -2, -4)
      ..quadraticBezierTo(-12, -3.5, -16, -6)
      ..quadraticBezierTo(-13, -1, -14, 3)
      ..quadraticBezierTo(-10, 4.5, -2, 4)
      ..quadraticBezierTo(10, 5, 16, 0)
      ..close();
    canvas.drawShadow(fuselage, Colors.black, 3, false);
    canvas.drawPath(fuselage, fill);

    // Canopy.
    final canopy = Path()
      ..moveTo(4, -4)
      ..quadraticBezierTo(0, -9, -6, -5)
      ..quadraticBezierTo(-1, -6, 4, -4)
      ..close();
    canvas.drawPath(canopy, darkFill);

    // Swept wing, trailing below/behind the body.
    final wing = Path()
      ..moveTo(-2, 1)
      ..lineTo(-6, 13)
      ..lineTo(-11, 12)
      ..lineTo(-9, 1)
      ..close();
    canvas.drawPath(wing, darkFill);

    // Tail fin.
    final tailFin = Path()
      ..moveTo(-13, -1)
      ..lineTo(-19, -9)
      ..lineTo(-16, -1)
      ..close();
    canvas.drawPath(tailFin, darkFill);

    // Propeller hub + blades at the nose.
    canvas.drawCircle(
      const Offset(17, 0),
      1.6,
      Paint()..color = AppColors.textPrimary,
    );
    final propellerPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.85)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(17, -7), const Offset(17, 6), propellerPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CrashCurvePainter oldDelegate) {
    return oldDelegate.multiplier != multiplier ||
        oldDelegate.elapsedSeconds != elapsedSeconds ||
        oldDelegate.crashed != crashed ||
        oldDelegate.drawPlane != drawPlane ||
        oldDelegate.explosionProgress != explosionProgress;
  }
}
