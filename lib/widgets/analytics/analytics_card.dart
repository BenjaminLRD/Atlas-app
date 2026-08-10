import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Reusable Analytics Card component supporting animated counters, Vitality Green glow, and tap handlers.
class AnalyticsCard extends StatelessWidget {
  final String title;
  final double value;
  final String unit;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;
  final bool isInteger;

  const AnalyticsCard({
    super.key,
    required this.title,
    required this.value,
    this.unit = '',
    required this.icon,
    this.accentColor,
    this.onTap,
    this.isInteger = false,
  });

  String _formatValue(double val) {
    if (isInteger) {
      return val.toInt().toString();
    }
    if (val >= 1000) {
      return '${(val / 1000.0).toStringAsFixed(1)}k';
    }
    return val.toStringAsFixed(val % 1 == 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final primaryColor = accentColor ?? AppColors.primaryContainer;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: primaryColor.withValues(alpha: 0.1),
        highlightColor: primaryColor.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14151B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: value),
                builder: (context, animVal, child) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatValue(animVal),
                        style: AppTheme.headlineLgMobile.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
