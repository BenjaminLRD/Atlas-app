import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_card.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  final Widget? badge;
  final double? progress;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.label,
    required this.value,
    this.unit = '',
    this.badge,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              ?badge,
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: AppTheme.labelCaps.copyWith(
              color: context.appTextSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTheme.displayMetrics.copyWith(
                  fontSize: 32,
                  color: context.appTextPrimary,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: AppTheme.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: context.appOutlineVariant.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
