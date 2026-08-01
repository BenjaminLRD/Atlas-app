import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../app_theme.dart';
import 'app_card.dart';
import 'app_loading_state.dart';

class MetricCard extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
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
  final bool isLoading;

  const MetricCard({
    super.key,
    this.icon,
    this.iconAsset,
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
    this.isLoading = false,
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
                  boxShadow: [
                    BoxShadow(
                      color: iconBgColor.withValues(alpha: context.isDarkMode ? 0.5 : 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: iconAsset != null
                    ? SvgPicture.asset(
                        iconAsset!,
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                      )
                    : Icon(icon ?? Icons.help_outline, color: iconColor, size: 18),
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),

          if (isLoading) ...[
            const SizedBox(height: 4),
            const AppSkeletonBox(width: 80, height: 26),
          ] else
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
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: AppTheme.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Optional Animated Progress Indicator
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: AppRadii.borderFull,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: progress!.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, animProgress, child) {
                  return LinearProgressIndicator(
                    value: animProgress,
                    minHeight: 5,
                    backgroundColor: context.appOutlineVariant.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.isDarkMode ? AppColors.primaryContainer : AppColors.primary,
                    ),
                  );
                },
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
