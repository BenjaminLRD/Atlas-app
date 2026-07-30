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
  final String? subtext;
  final Color? subtextColor;
  final Widget? badge;
  final Widget? trailingWidget;
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
    this.subtext,
    this.subtextColor,
    this.badge,
    this.trailingWidget,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Icon & Badge / Trailing Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              ?badge,
              ?trailingWidget,
            ],
          ),
          const SizedBox(height: 10),

          // Label Caps
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.labelCaps.copyWith(
              color: context.appTextSecondary,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),

          // Value & Unit with FittedBox to prevent overflow
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTheme.headlineLg.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
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
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Optional Progress Indicator
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: context.appOutlineVariant.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
              ),
            ),
          ],

          // Optional Subtext
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(
              subtext!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                color: subtextColor ?? context.appTextSecondary,
                fontWeight: subtextColor != null ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
