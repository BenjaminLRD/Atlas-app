import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_card.dart';

/// Dedicated UI card for logging water intake intentionally via a prominent "+" button.
class WaterIntakeCard extends StatelessWidget {
  final double currentLiters;
  final double goalLiters;
  final VoidCallback onAddWater;
  final int stepMl;

  const WaterIntakeCard({
    super.key,
    required this.currentLiters,
    this.goalLiters = 2.5,
    required this.onAddWater,
    this.stepMl = 250,
  });

  static const Color _accentGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final progress = goalLiters > 0
        ? (currentLiters / goalLiters).clamp(0.0, 1.0)
        : 1.0;
    final progressPercent = (progress * 100).round();
    final isDark = context.isDarkMode;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 1. Left: Water icon in a rounded square
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _accentGreen.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: _accentGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),

              // 2. Center: WATER title, current intake, goal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WATER',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            currentLiters.toStringAsFixed(1),
                            style: AppTheme.displayMetrics.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'L',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ${goalLiters.toStringAsFixed(1)} L goal',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Right: Non-interactive Progress Ring + Prominent Circular "+" Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 4,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.08),
                          color: _accentGreen,
                        ),
                      ),
                      Text(
                        '$progressPercent%',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _accentGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Prominent "+" Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        onAddWater();
                        _showFeedbackToast(context);
                      },
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accentGreen,
                          boxShadow: [
                            BoxShadow(
                              color: _accentGreen.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Bottom Helper Note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: _accentGreen,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Tap the + button to add water',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackToast(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.water_drop_rounded, color: _accentGreen, size: 18),
            const SizedBox(width: 8),
            Text(
              '$stepMl ml added to your intake!',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: _accentGreen.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}
