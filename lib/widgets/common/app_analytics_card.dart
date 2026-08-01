import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_card.dart';

/// Reusable Analytics Card component for summary bento stats and biometrics.
class AppAnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final double? progress;
  final VoidCallback? onTap;

  const AppAnalyticsCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 10,
                  color: context.appTextSecondary,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDarkMode ? 0.25 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.headlineLg.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 6,
                color: color,
                backgroundColor: context.appSurfaceElevated,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
