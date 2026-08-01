import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Unified Design System Empty State Component.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Widget? customAction;
  final bool cardFramed;
  final EdgeInsetsGeometry padding;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.customAction,
    this.cardFramed = true,
    this.padding = const EdgeInsets.all(AppSpacing.xxl),
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: context.isDarkMode ? 0.25 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTheme.bodySm.copyWith(
                fontSize: 13,
                color: context.appTextSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            if (customAction != null || (actionLabel != null && onActionPressed != null)) ...[
              const SizedBox(height: AppSpacing.xl),
              customAction ??
                  AppButton.primary(
                    label: actionLabel!,
                    onPressed: onActionPressed,
                    isFullWidth: false,
                  ),
            ],
          ],
        ),
      ),
    );

    if (cardFramed) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: content,
      );
    }

    return content;
  }
}
