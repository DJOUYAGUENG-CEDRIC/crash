import 'package:flutter/material.dart';

/// CRASHX design system — elevation shadows for a dark UI (subtle, since
/// heavy shadows barely read on dark backgrounds; used sparingly).
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x88000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
}
