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
  const CrashCurvePainter({required this.multiplier, required this.elapsedSeconds, required this.crashed});

  final double multiplier;
  final double elapsedSeconds;
  final bool crashed;

  static const int _sampleCount = 40;

  /// Reference round length used to normalize t/duration. Actual crash
  /// time is decided server-side and unknown to the client in advance
  /// (spec §19/§20) — this is purely an animation-pacing constant, not
  /// a prediction. Rounds shorter than this reach the "peak" pose
  /// early; longer ones stay parked near it (see [_tFraction] clamp).
  static const double _durationSeconds = 60.0;

  /// Curvature factor — within the recommended 2.5-4.5 range.
  static const double _k = 3.5;

  static const double _marginRightFraction = 0.05;
  static const double _startXFraction = 0.02;
  static const double _topMarginFraction = 0.08;

  double get _tFraction => (elapsedSeconds / _durationSeconds).clamp(0.0, 1.0);

  double _xOf(double size, double tFraction) {
    final startX = size * _startXFraction;
    final maxX = size * (1 - _marginRightFraction);
    return startX + (maxX - startX) * tFraction;
  }

  double _yOf(double size, double tFraction) {
    final startY = size * (1 - _topMarginFraction);
    final usableHeight = startY;
    final ease = (math.exp(_k * tFraction) - 1) / (math.exp(_k) - 1);
    return startY - usableHeight * ease;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final color = crashed ? AppColors.crashRed : AppColors.curveLine;
    final tFraction = _tFraction;

    final path = Path();
    Offset tip = Offset(0, size.height);
    for (var i = 0; i <= _sampleCount; i++) {
      final sampleT = tFraction * (i / _sampleCount);
      final point = Offset(_xOf(size.width, sampleT), _yOf(size.height, sampleT));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      tip = point;
    }

    final fillPath = Path.from(path)
      ..lineTo(tip.dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillColors = crashed
        ? [AppColors.crashRed.withValues(alpha: 0.45), AppColors.crashRed.withValues(alpha: 0)]
        : [AppColors.crashRed.withValues(alpha: 0.5), AppColors.accent.withValues(alpha: 0.05)];
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: fillColors,
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    if (crashed) {
      canvas.drawCircle(tip, 5, Paint()..color = color);
    } else {
      _drawPlane(canvas, tip, color);
    }
  }

  /// An original, hand-drawn side-view propeller-plane silhouette
  /// (nose, canopy, tail fin, swept wing, spinning propeller) — not a
  /// copied asset or stock icon. Nose tilted up 5-10° as specified.
  void _drawPlane(Canvas canvas, Offset tip, Color bodyColor) {
    const scale = 1.15;
    const tilt = -7.5 * math.pi / 180; // nose-up tilt, within the 5°-10° range

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(tilt);
    canvas.scale(scale);

    final fill = Paint()..color = AppColors.crashRed;
    final darkFill = Paint()..color = const Color(0xFF7A0E14);

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
    canvas.drawCircle(const Offset(17, 0), 1.6, Paint()..color = AppColors.textPrimary);
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
        oldDelegate.crashed != crashed;
  }
}
