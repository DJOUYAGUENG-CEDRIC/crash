import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A static field of small stars over a deep-space gradient, used as the
/// backdrop of the Crash game stage (spec §17 wants an "immersive" game
/// screen). Original, generated procedurally from a fixed seed — not a
/// copied illustration or asset from any third-party game.
class StarfieldBackground extends StatelessWidget {
  const StarfieldBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF171A3B), Color(0xFF121631)],
        ),
      ),
      child: CustomPaint(painter: _StarfieldPainter(), size: Size.infinite),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  const _StarfieldPainter();

  static const int _starCount = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(
      42,
    ); // fixed seed: stable, no per-frame recompute
    final paint = Paint()..color = Colors.white;

    for (var i = 0; i < _starCount; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.4 + 0.3;
      paint.color = Colors.white.withValues(
        alpha: random.nextDouble() * 0.5 + 0.25,
      );
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => false;
}
