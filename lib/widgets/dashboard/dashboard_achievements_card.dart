import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../providers/fitness_provider.dart';
import '../../providers/showcase_mode_provider.dart';
import '../../screens/ranked_screen.dart';
import '../../services/achievement_service.dart';
import '../common/app_card.dart';

/// Achievements banner card for Dashboard.
/// Renders onboarding encouragement for fresh users and unlocked milestone highlights in Showcase Mode.
class DashboardAchievementsCard extends StatefulWidget {
  const DashboardAchievementsCard({super.key});

  @override
  State<DashboardAchievementsCard> createState() =>
      _DashboardAchievementsCardState();
}

class _DashboardAchievementsCardState extends State<DashboardAchievementsCard> {
  @override
  void initState() {
    super.initState();
    ShowcaseModeProvider.instance.addListener(_onStateUpdated);
    FitnessProvider.instance.addListener(_onStateUpdated);
  }

  @override
  void dispose() {
    ShowcaseModeProvider.instance.removeListener(_onStateUpdated);
    FitnessProvider.instance.removeListener(_onStateUpdated);
    super.dispose();
  }

  void _onStateUpdated() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isShowcase = ShowcaseModeProvider.instance.isShowcaseModeEnabled;
    final provider = FitnessProvider.instance;
    final hasCompletedWorkout = provider.workoutHistory.isNotEmpty;
    // Each achievement counts once, however many ids were saved for it.
    final earnedCount = AchievementService.earnedCount(
      provider.userProgress.achievements,
    );
    final hasUnlockedAchievements =
        isShowcase || (hasCompletedWorkout && earnedCount > 0);

    final title = hasUnlockedAchievements
        ? (isShowcase ? 'Great job! 🔥' : 'Great job! 🔥')
        : 'Keep it up!';

    final subtitle = hasUnlockedAchievements
        ? (isShowcase
              ? 'You\'ve hit 7 day streak milestone! Keep pushing toward your goals.'
              : 'You\'ve earned $earnedCount achievement milestones! Keep pushing toward your goals.')
        : 'Complete your first workout to see personalized achievements here.';

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RankedScreen()),
        );
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.primaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.appTextSecondary,
          ),
        ],
      ),
    );
  }
}
