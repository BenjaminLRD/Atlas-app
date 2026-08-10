import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_animation.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Unified Design System Empty State Component with animations and preset constructors.
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

  /// Factory constructor for empty workouts view
  factory AppEmptyState.noWorkouts({
    VoidCallback? onStartWorkout,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.fitness_center_rounded,
      title: 'No Workouts Logged Yet',
      subtitle: 'Start your fitness journey today. Your progress will appear right here!',
      actionLabel: 'START WORKOUT',
      onActionPressed: onStartWorkout,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty achievements view
  factory AppEmptyState.noAchievements({
    VoidCallback? onViewAll,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.emoji_events_outlined,
      title: 'No Badges Unlocked Yet',
      subtitle: 'Complete workouts and hit consistency milestones to earn your first badge!',
      actionLabel: 'EXPLORE BADGES',
      onActionPressed: onViewAll,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty history view
  factory AppEmptyState.noHistory({
    VoidCallback? onLogFirst,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.history_toggle_off_rounded,
      title: 'No History Recorded',
      subtitle: 'Complete your first training session to view detailed workout history & stats.',
      actionLabel: 'LOG SESSION',
      onActionPressed: onLogFirst,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty AI Chat view
  factory AppEmptyState.noChat({
    VoidCallback? onStartChat,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.auto_awesome_rounded,
      title: 'Ask AI Coach Anything',
      subtitle: 'Get instant workout form tips, nutrition guidance, and personalized advice.',
      actionLabel: 'START CONVERSATION',
      onActionPressed: onStartChat,
      cardFramed: cardFramed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAnimation.pulseGlow(
              color: AppColors.primaryContainer,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(
                    alpha: context.isDarkMode ? 0.25 : 0.15,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: AppColors.primary,
                ),
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
                    isPill: true,
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
