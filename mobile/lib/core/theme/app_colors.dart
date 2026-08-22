import 'package:flutter/material.dart';

/// CRASHX design system — colors.
/// Dark, dense betting-app aesthetic. Original palette, no third-party
/// branding. Used everywhere instead of ad-hoc Color(...) literals.
class AppColors {
  AppColors._();

  // Backgrounds — deep navy, original CRASHX palette
  static const Color background = Color(0xFF0D1030);
  static const Color surface = Color(0xFF161A42);
  static const Color surfaceElevated = Color(0xFF1F2452);
  static const Color surfaceBorder = Color(0xFF323868);

  // Brand — vivid orange on navy
  static const Color primary = Color(0xFFFF7A1A);
  static const Color primaryVariant = Color(0xFFFF9A4D);
  static const Color accent = Color(0xFFFFC94A);

  // Text
  static const Color textPrimary = Color(0xFFF5F6FA);
  static const Color textSecondary = Color(0xFF9AA1B4);
  static const Color textDisabled = Color(0xFF565D70);

  // Semantic
  static const Color success = Color(0xFF2ECC71);
  static const Color danger = Color(0xFFFF4D4D);
  static const Color warning = Color(0xFFFFB020);

  // Game-specific
  static const Color multiplierRising = Color(0xFF2ECC71);
  static const Color crashRed = Color(0xFFFF4D4D);
  static const Color curveLine = Color(0xFFFFC94A);
  static const Color demoBadgeBg = Color(0x22FFB020);
  static const Color demoBadgeText = Color(0xFFFFB020);
}
