import 'package:flutter/material.dart';
import '../widgets/ranked/ranked_progress_panel.dart';
import '../app_theme.dart';
import '../data/mock_badges.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/badge_detail_popup.dart';
import '../widgets/common/challenge_card.dart';

/// Ranked Progression Screen designed after Stitch specifications.
/// Supports both Dark and Light modes dynamically using AppTheme system.
class RankedScreen extends StatefulWidget {
  const RankedScreen({super.key});

  @override
  State<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends State<RankedScreen> {
  // Reads the current progress each time, so the badges follow it.
  final BadgeService _badgeService = BadgeService(
    unlockedAchievementIds: () =>
        FitnessProvider.instance.userProgress.achievements,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessProvider.instance.refreshRanked();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: context.appBackground,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Header Bar
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Rank, stats and milestones
                        const RankedProgressPanel(),
                        const SizedBox(height: 16),

                        // 2b. Daily Streak & 7-Day Calendar Card
                        _buildDailyStreakCalendarCard(context),
                        const SizedBox(height: 20),

                        // Responsive Grid: Progression Path & Challenge / Leaderboard
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 768) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      children: [
                                        _buildWeeklyChallengeCard(context),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        const RankedLeaderboardCard(),
                                        const SizedBox(height: 16),
                                        _buildAchievementPreview(context),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 4. Weekly Challenge Card
                                _buildWeeklyChallengeCard(context),
                                const SizedBox(height: 16),

                                // 5. Leaderboard
                                const RankedLeaderboardCard(),
                                const SizedBox(height: 16),

                                // 6. Achievement Preview
                                _buildAchievementPreview(context),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 1. Header Navigation Bar matching Stitch design
  Widget _buildHeader(BuildContext context) {
    return AppHeader.back(
      title: 'Ranked',
      subtitle: 'Climb the leaderboard. Become stronger.',
      onBackTap: () => Navigator.pop(context),
    );
  }

  /// 4. Weekly Challenges Section with live horizontal scrolling ChallengeCards
  Widget _buildWeeklyChallengeCard(BuildContext context) {
    final provider = FitnessProvider.instance;
    final challenges = provider.weeklyChallenges;

    if (challenges.isEmpty) {
      return const SizedBox.shrink();
    }

    final completedCount = challenges.where((c) => c.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'WEEKLY CHALLENGES',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.appTextSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$completedCount / ${challenges.length} Done',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(160).clamp(160.0, 300.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: challenges.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              return ChallengeCard(challenge: challenge, width: 275);
            },
          ),
        ),
      ],
    );
  }

  /// 4b. Daily Streak Card with 7-Day Calendar Visualization (M T W T F S S)
  Widget _buildDailyStreakCalendarCard(BuildContext context) {
    final isDark = context.isDarkMode;
    final provider = FitnessProvider.instance;
    final streakData = provider.streakData;
    final weeklyCalendar = provider.getWeeklyWorkoutCalendar();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CURRENT STREAK',
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: context.appTextSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '${streakData.currentStreak} ${streakData.currentStreak == 1 ? "Day" : "Days"}',
                            style: AppTheme.headlineLgMobile.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.appOutlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'LONGEST STREAK',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 9,
                        color: context.appTextSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${streakData.longestStreak} ${streakData.longestStreak == 1 ? "Day" : "Days"}',
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            color: context.appOutlineVariant.withValues(alpha: 0.3),
            height: 1,
          ),
          const SizedBox(height: 14),

          // 7-day calendar visualization: M T W T F S S
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weeklyCalendar.map((day) {
              return Column(
                children: [
                  Text(
                    day.dayLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: day.isToday
                          ? FontWeight.w900
                          : FontWeight.w600,
                      color: day.isToday
                          ? AppColors.primaryContainer
                          : context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: day.isCompleted
                          ? AppColors.primary
                          : (day.isPast
                                ? (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey.shade200)
                                : Colors.transparent),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: day.isCompleted
                            ? AppColors.primary
                            : (day.isToday
                                  ? AppColors.primaryContainer
                                  : context.appOutlineVariant.withValues(
                                      alpha: 0.4,
                                    )),
                        width: day.isToday ? 2.0 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: day.isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.black,
                            )
                          : Text(
                              '${day.dayNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: day.isToday
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: day.isToday
                                    ? AppColors.primaryContainer
                                    : (day.isPast
                                          ? context.appTextSecondary
                                          : context.appOutlineVariant),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 6. Achievement Preview Section (Horizontally Scrollable & Interactive)
  Widget _buildAchievementPreview(BuildContext context) {
    final recentBadges = _badgeService.getRecentBadges();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'RECENT BADGES',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.appTextSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _showViewAllBadgesModal(context),
              child: Row(
                children: [
                  const Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.primaryContainer,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(124).clamp(124.0, 240.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recentBadges.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final badge = recentBadges[index];
              final Color badgeColor = _getBadgeColor(badge.rarity);

              return GestureDetector(
                onTap: () => BadgeDetailPopup.show(context, badge),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    width: 115,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            badge.iconData,
                            size: 24,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatEarnedSummary(badge.earnedDate),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getBadgeColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return const Color(0xFFFFD700);
      case 'epic':
        return const Color(0xFFFF6D00);
      case 'rare':
        return const Color(0xFF00E5FF);
      case 'common':
      default:
        return AppColors.primaryContainer;
    }
  }

  String _formatEarnedSummary(DateTime? date) {
    if (date == null) return 'Locked';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Earned Today';
    if (diff.inDays == 1) return 'Earned Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}';
  }

  void _showViewAllBadgesModal(BuildContext context) {
    final isDark = context.isDarkMode;
    final allBadges = _badgeService.getAllBadges();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14151B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Badge Collection',
                    style: AppTheme.headlineLgMobile.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Grid of all badges
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.25,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: allBadges.length,
                  itemBuilder: (context, index) {
                    final badge = allBadges[index];
                    final color = _getBadgeColor(badge.rarity);

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        BadgeDetailPopup.show(context, badge);
                      },
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              badge.iconData,
                              size: 28,
                              color: badge.isUnlocked ? color : Colors.grey,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              badge.title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: badge.isUnlocked
                                    ? context.appTextPrimary
                                    : context.appTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              badge.isUnlocked ? 'Unlocked' : 'Locked',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: badge.isUnlocked ? color : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
