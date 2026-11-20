import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// User-facing active state modes of Atlas AI Fitness Intelligence.
enum AIStatusState {
  learning('Continuously learning about you', Color(0xFF10B981)), // Emerald Green
  analyzing('Analyzing today\'s recovery', Color(0xFFF59E0B)), // Amber
  planning('Creating personalized plan', Color(0xFF3B82F6)); // Blue

  final String label;
  final Color color;
  const AIStatusState(this.label, this.color);
}

/// Subtle, friendly AI status indicator displaying current coaching state
/// without exposing backend technical jargon.
class AIStatusIndicator extends StatelessWidget {
  final AIStatusState state;
  final VoidCallback? onTap;

  const AIStatusIndicator({
    super.key,
    this.state = AIStatusState.learning,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _showStatusDetails(context),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: state.color.withValues(alpha: 0.12),
          borderRadius: AppRadii.borderFull,
          border: Border.all(color: state.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: state.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: state.color.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                state.label,
                style: AppTheme.labelCaps.copyWith(
                  color: state.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: state.color,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Atlas AI Status',
                      style: AppTheme.headlineSm.copyWith(
                        color: ctx.appTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Atlas AI operates continuously in the background to analyze workout volume, recovery readiness, and nutritional balance to provide hyper-personalized fitness intelligence.',
                  style: AppTheme.bodySm.copyWith(
                    color: ctx.appTextSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: state.color.withValues(alpha: 0.1),
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(
                      color: state.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: state.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          state.label,
                          style: AppTheme.bodyMd.copyWith(
                            color: ctx.appTextPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }
}
