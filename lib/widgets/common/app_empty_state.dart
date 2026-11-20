import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_animation.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Unified Design System Premium Empty State Component with animations,
/// value checklist unlocks, and preset constructors.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final String title;
  final String subtitle;
  final List<String>? checklist;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onActionPressed;
  final String? secondaryActionLabel;
  final IconData? secondaryActionIcon;
  final VoidCallback? onSecondaryActionPressed;
  final Widget? customAction;
  final bool cardFramed;
  final EdgeInsetsGeometry padding;

  const AppEmptyState({
    super.key,
    required this.icon,
    this.badge,
    required this.title,
    required this.subtitle,
    this.checklist,
    this.actionLabel,
    this.actionIcon,
    this.onActionPressed,
    this.secondaryActionLabel,
    this.secondaryActionIcon,
    this.onSecondaryActionPressed,
    this.customAction,
    this.cardFramed = true,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  /// Factory constructor for the Hero "Start your journey" state
  factory AppEmptyState.startJourney({
    VoidCallback? onStartWorkout,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.fitness_center_rounded,
      badge: 'START YOUR JOURNEY',
      title: 'Start your journey',
      subtitle: 'Complete your first workout to unlock:',
      checklist: const [
        'Performance analytics',
        'XP progression',
        'Achievements',
        'AI recommendations',
      ],
      actionLabel: 'Start Workout',
      actionIcon: Icons.play_arrow_rounded,
      onActionPressed: onStartWorkout,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty workouts view
  factory AppEmptyState.noWorkouts({
    VoidCallback? onStartWorkout,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.fitness_center_rounded,
      badge: 'START YOUR JOURNEY',
      title: 'No completed workouts yet.',
      subtitle: 'Complete your first workout to start your streak and unlock performance analytics.',
      checklist: const [
        'Performance analytics',
        'XP progression',
        'Achievements',
        'AI recommendations',
      ],
      actionLabel: 'Start Workout',
      actionIcon: Icons.play_arrow_rounded,
      onActionPressed: onStartWorkout,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty achievements view
  factory AppEmptyState.noAchievements({
    VoidCallback? onStartWorkout,
    VoidCallback? onViewAll,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.emoji_events_outlined,
      badge: 'UNLOCK YOUR POTENTIAL',
      title: 'Unlock Your Potential',
      subtitle: 'Complete workouts and hit consistency milestones to unlock:',
      checklist: const [
        'Milestone & Consistency badges',
        'Profile showcase rank & flair',
        'Leaderboard XP multipliers',
      ],
      actionLabel: 'Start Workout',
      actionIcon: Icons.play_arrow_rounded,
      onActionPressed: onStartWorkout ?? onViewAll,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty nutrition/meals view
  factory AppEmptyState.noNutrition({
    VoidCallback? onAddFood,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.restaurant_rounded,
      badge: 'FUEL YOUR PERFORMANCE',
      title: 'No meals tracked today.',
      subtitle: 'Log your first meal today to track calories and macronutrients.',
      checklist: const [
        'Calorie deficit & surplus balance',
        'Macronutrient breakdown (Protein, Carbs, Fats)',
        'Nutrition consistency & meal streaks',
      ],
      actionLabel: 'Log First Meal',
      actionIcon: Icons.add_rounded,
      onActionPressed: onAddFood,
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
      badge: 'TRAINING TIMELINE',
      title: 'No completed workouts yet.',
      subtitle: 'Complete your first workout to unlock performance analytics, XP progression, and personal records.',
      checklist: const [
        'Performance analytics',
        'XP progression',
        'Achievements',
        'AI recommendations',
      ],
      actionLabel: 'Start Workout',
      actionIcon: Icons.play_arrow_rounded,
      onActionPressed: onLogFirst,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty progress view
  factory AppEmptyState.noProgress({
    VoidCallback? onStartWorkout,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.insights_rounded,
      badge: 'PROGRESS & ANALYTICS',
      title: 'Complete workouts to see your progress.',
      subtitle: 'Your strength curves, volume charts, and personal records will appear after your first session.',
      checklist: const [
        'Strength curves & progression charts',
        'Muscle group training volume breakdown',
        'Estimated 1RM lifting benchmarks',
      ],
      actionLabel: 'Start Workout',
      actionIcon: Icons.play_arrow_rounded,
      onActionPressed: onStartWorkout,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty AI Chat / Memory view
  factory AppEmptyState.noChat({
    VoidCallback? onStartChat,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.auto_awesome_rounded,
      badge: 'AI COACH ONLINE',
      title: 'Start chatting with your coach.',
      subtitle: 'Ask your AI coach for personalized workouts, nutrition plans, and form advice.',
      checklist: const [
        'Instant workout form tips & tutorials',
        'Personalized meal & macro suggestions',
        'Adaptive volume & deload advice',
      ],
      actionLabel: 'Start Conversation',
      actionIcon: Icons.chat_bubble_outline_rounded,
      onActionPressed: onStartChat,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty AI Memory view
  factory AppEmptyState.noMemory({
    VoidCallback? onStartChat,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.psychology_rounded,
      badge: 'AI FITNESS MEMORY',
      title: 'Start chatting with your coach.',
      subtitle: 'Your AI coach learns your exercise preferences, favorite foods, and lifting goals as you interact.',
      checklist: const [
        'Learned exercise & movement preferences',
        'Nutritional restrictions & favorite meals',
        'Progressive overload benchmarks',
      ],
      actionLabel: 'Chat with Coach',
      actionIcon: Icons.chat_bubble_outline_rounded,
      onActionPressed: onStartChat,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for empty notifications view
  factory AppEmptyState.noNotifications({
    VoidCallback? onExplore,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.notifications_none_rounded,
      badge: 'ALL CAUGHT UP',
      title: 'No New Notifications',
      subtitle:
          'You are all caught up! System updates and workout alerts will appear here as you train.',
      actionLabel: onExplore != null ? 'Explore Workouts' : null,
      actionIcon: Icons.fitness_center_rounded,
      onActionPressed: onExplore,
      cardFramed: cardFramed,
    );
  }

  /// Factory constructor for search zero states
  factory AppEmptyState.noSearchResults({
    String? query,
    VoidCallback? onClear,
    bool cardFramed = true,
  }) {
    return AppEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No Results Found',
      subtitle: query != null && query.isNotEmpty
          ? 'No matching results found for "$query". Try searching with different keywords.'
          : 'No items match your filter criteria.',
      actionLabel: onClear != null ? 'Clear Search' : null,
      actionIcon: Icons.clear_rounded,
      onActionPressed: onClear,
      cardFramed: cardFramed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    final Widget content = Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Optional Badge
            if (badge != null && badge!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(
                    alpha: isDark ? 0.25 : 0.15,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  badge!,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 2. Animated Pulse Glow Icon
            AppAnimation.pulseGlow(
              color: AppColors.primaryContainer,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(
                    alpha: isDark ? 0.25 : 0.15,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: isDark
                      ? AppColors.primaryContainer
                      : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 3. Title
            Text(
              title,
              style: AppTheme.headlineLgMobile.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),

            // 4. Subtitle
            Text(
              subtitle,
              style: AppTheme.bodySm.copyWith(
                fontSize: 13,
                color: context.appTextSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            // 5. Checklist Features (Unlocks)
            if (checklist != null && checklist!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : AppColors.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.appOutlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: checklist!.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(
                                alpha: isDark ? 0.3 : 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: AppTheme.bodySm.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // 6. Action Button(s)
            if (customAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              customAction!,
            ] else if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  AppButton.primary(
                    label: actionLabel!,
                    icon: actionIcon,
                    onPressed: onActionPressed,
                    isFullWidth: false,
                    isPill: true,
                  ),
                  if (secondaryActionLabel != null &&
                      onSecondaryActionPressed != null)
                    AppButton.secondary(
                      label: secondaryActionLabel!,
                      icon: secondaryActionIcon,
                      onPressed: onSecondaryActionPressed,
                      isFullWidth: false,
                      isPill: true,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (cardFramed) {
      return AppCard(padding: EdgeInsets.zero, child: content);
    }

    return content;
  }
}
