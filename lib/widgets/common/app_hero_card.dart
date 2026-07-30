import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_card.dart';
import 'app_chip.dart';

/// Reusable Hero Banner / Card component for featured protocols and exercises.
class AppHeroCard extends StatelessWidget {
  final String tag;
  final String title;
  final String subtitle;
  final String? valueText;
  final Widget? actionButton;
  final Widget? footer;

  const AppHeroCard({
    super.key,
    required this.tag,
    required this.title,
    required this.subtitle,
    this.valueText,
    this.actionButton,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppChip.status(label: tag, color: AppColors.primary),
              if (valueText != null)
                Text(
                  valueText!,
                  style: AppTheme.headlineLg.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTheme.headlineLgMobile.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTheme.bodySm.copyWith(
              fontSize: 13,
              color: context.appTextSecondary,
            ),
          ),
          if (footer != null || actionButton != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (footer != null) Expanded(child: footer!),
                // ignore: use_null_aware_elements
                if (actionButton != null) actionButton!,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
