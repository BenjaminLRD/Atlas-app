import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_card.dart';

/// Reusable AI Insight & Informational Card component.
class AppInsightCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color? accentColor;
  final Widget? trailing;

  const AppInsightCard({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.auto_awesome_rounded,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.borderMd,
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDarkMode ? 0.25 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        height: 1.45,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
