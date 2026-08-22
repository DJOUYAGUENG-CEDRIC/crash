import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text_styles.dart';

/// The clearly-visible "DEMO" pill — the one signal that tells anyone
/// using this app, including someone who received it outside its
/// original context, that the balance is virtual, not real money
/// (spec §3). Kept deliberately legible rather than shrunk away.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = ''});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.demoBadgeBg,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: AppColors.demoBadgeText.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.demoBadgeText, fontWeight: FontWeight.w800),
      ),
    );
  }
}
