import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/gamification_service.dart';
import '../data/mock_badges.dart';
import '../models/leaderboard_user.dart';
import '../models/leaderboard_entry.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_image.dart';
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
  int _selectedLeaderboardTab = 0;
  String? _selectedTier;
  final BadgeService _badgeService = BadgeService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessProvider.instance.loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final provider = FitnessProvider.instance;
        final isUnlocked = provider.rankedUnlocked;
        final rankTitle = isUnlocked ? provider.fullRank : 'Unranked';
        final currentTier = provider.userProgress.currentRank;
        final currentDivision = provider.userProgress.currentDivision;
        final totalXP = provider.totalXP;
        final workoutCount = provider.completedWorkoutsCount;
        final streakCount = provider.workoutStreak;

        final selectedTier = _selectedTier ?? (isUnlocked ? currentTier : 'Bronze');

        final nextRankReq = provider.nextRankRequirement;
        final String nextRankTitle = nextRankReq['nextRank'] as String? ?? 'Bronze IV';
        final int neededXP = (nextRankReq['neededXP'] as int?) ?? (isUnlocked ? 0 : 500);

        final double progressPct = isUnlocked
            ? ((nextRankReq['progressPercentage'] as double?) ?? 0.0).clamp(0.0, 1.0)
            : (workoutCount / 5.0).clamp(0.0, 1.0);

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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Current Rank Hero Card
                        _buildHeroRankCard(
                          context,
                          isUnlocked: isUnlocked,
                          rankTitle: rankTitle,
                          neededXP: neededXP,
                          nextRankTitle: nextRankTitle,
                          progressPct: progressPct,
                          totalXP: totalXP,
                          workouts: workoutCount,
                          streak: streakCount,
                        ),
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
                                        _buildDivisionProgressionPanel(
                                          context,
                                          userTier: currentTier,
                                          userDivision: currentDivision,
                                          selectedTier: selectedTier,
                                          totalXP: totalXP,
                                          isUnlocked: isUnlocked,
                                          onSelectTier: (tier) =>
                                              setState(() => _selectedTier = tier),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildWeeklyChallengeCard(context),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      children: [
                                        _buildLeaderboard(context, rankTitle, totalXP),
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
                                // 3. Division Progression Panel
                                _buildDivisionProgressionPanel(
                                  context,
                                  userTier: currentTier,
                                  userDivision: currentDivision,
                                  selectedTier: selectedTier,
                                  totalXP: totalXP,
                                  isUnlocked: isUnlocked,
                                  onSelectTier: (tier) =>
                                      setState(() => _selectedTier = tier),
                                ),
                                const SizedBox(height: 16),

                                // 4. Weekly Challenge Card
                                _buildWeeklyChallengeCard(context),
                                const SizedBox(height: 16),

                                // 5. Leaderboard
                                _buildLeaderboard(context, rankTitle, totalXP),
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

  /// 2. Current Rank Hero Card
  Widget _buildHeroRankCard(
    BuildContext context, {
    required bool isUnlocked,
    required String rankTitle,
    required int neededXP,
    required String nextRankTitle,
    required double progressPct,
    required int totalXP,
    required int workouts,
    required int streak,
  }) {
    final isDark = context.isDarkMode;

    final String subtitleText = !isUnlocked
        ? (workouts < 5
            ? 'Complete ${5 - workouts} more workout${(5 - workouts) == 1 ? '' : 's'} to unlock Ranked'
            : 'Complete 5 workouts to unlock Ranked')
        : (neededXP == 0 ? 'Max Rank Reached' : '$neededXP XP until $nextRankTitle');

    // Compute active division level XP span for numerics display
    int startXP = 500;
    int targetXP = 750;
    if (isUnlocked) {
      for (int i = 0; i < GamificationService.rankStructure.length; i++) {
        final rank = GamificationService.rankStructure[i];
        if (totalXP >= rank.minXP) {
          startXP = rank.minXP;
          if (i + 1 < GamificationService.rankStructure.length) {
            targetXP = GamificationService.rankStructure[i + 1].minXP;
          } else {
            targetXP = startXP + 3000;
          }
        }
      }
    }
    final int divSpan = targetXP - startXP;
    final int earnedInDiv = isUnlocked ? (totalXP - startXP).clamp(0, divSpan) : 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.15 : 0.1),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rank Emblem Circle with Gold/Emerald Border
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color(0xFFFFF9E6),
                      border: Border.all(
                        color: isUnlocked ? const Color(0xFFFFD700) : context.appOutlineVariant,
                        width: 2,
                      ),
                      boxShadow: isUnlocked
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isUnlocked ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                      size: 52,
                      color: isUnlocked ? const Color(0xFFFFD700) : context.appTextSecondary,
                    ),
                  ),
                  Positioned(
                    bottom: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isUnlocked ? const Color(0xFFFFD700) : context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: isUnlocked ? null : Border.all(color: context.appOutlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        rankTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isUnlocked ? Colors.black : context.appTextSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),

              // Title and Progress Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rankTitle,
                      style: AppTheme.headlineLgMobile.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            subtitleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodySm.copyWith(
                              color: context.appTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isUnlocked) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$earnedInDiv / $divSpan XP',
                            style: AppTheme.headlineLgMobile.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryContainer,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isUnlocked ? const Color(0xFFFFD700) : AppColors.primaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: context.appOutlineVariant, height: 1),
          const SizedBox(height: 16),

          // 4 Grid Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStatItem(
                context,
                label: 'GLOBAL POS',
                value: isUnlocked ? '#247' : '--',
                valueColor: context.appTextPrimary,
              ),
              _buildHeroStatItem(
                context,
                label: 'TOTAL XP',
                value: _formatXP(totalXP),
                valueColor: AppColors.primaryContainer,
              ),
              _buildHeroStatItem(
                context,
                label: 'WORKOUTS',
                value: isUnlocked ? '$workouts' : '$workouts/5',
                valueColor: context.appTextPrimary,
              ),
              _buildHeroStatItem(
                context,
                label: 'STREAK',
                value: '$streak 🔥',
                valueColor: context.appTextPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.labelCaps.copyWith(
            fontSize: 10,
            color: context.appTextSecondary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.headlineLgMobile.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  /// 3. Two-Level Division Progression Panel
  Widget _buildDivisionProgressionPanel(
    BuildContext context, {
    required String userTier,
    required String userDivision,
    required String selectedTier,
    required int totalXP,
    required bool isUnlocked,
    required ValueChanged<String> onSelectTier,
  }) {
    final isDark = context.isDarkMode;

    final majorTiers = [
      {'tier': 'Bronze', 'icon': Icons.workspace_premium_rounded, 'color': const Color(0xFFCD7F32)},
      {'tier': 'Silver', 'icon': Icons.workspace_premium_rounded, 'color': const Color(0xFFC0C0C0)},
      {'tier': 'Gold', 'icon': Icons.military_tech_rounded, 'color': const Color(0xFFFFD700)},
      {'tier': 'Platinum', 'icon': Icons.diamond_outlined, 'color': const Color(0xFF00E5FF)},
      {'tier': 'Diamond', 'icon': Icons.diamond_rounded, 'color': const Color(0xFFB388FF)},
      {'tier': 'Elite', 'icon': Icons.stars_rounded, 'color': const Color(0xFF00E676)},
    ];

    int userTierIndex = -1;
    if (isUnlocked) {
      userTierIndex = majorTiers.indexWhere(
        (t) => (t['tier'] as String).toLowerCase() == userTier.toLowerCase(),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DIVISION PROGRESSION',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.appTextSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Active: $userTier $userDivision',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Two-Column Layout (Left: Major Tiers, Right: Divisions)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE: Major Tiers List
              Expanded(
                flex: 4,
                child: Column(
                  children: List.generate(majorTiers.length, (index) {
                    final tierData = majorTiers[index];
                    final String tierName = tierData['tier'] as String;
                    final IconData icon = tierData['icon'] as IconData;
                    final Color color = tierData['color'] as Color;

                    final bool isSelected =
                        tierName.toLowerCase() == selectedTier.toLowerCase();
                    final bool isUserTier = isUnlocked && index == userTierIndex;
                    final bool isPastTier = isUnlocked && index < userTierIndex;

                    return GestureDetector(
                      onTap: () => onSelectTier(tierName),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1))
                              : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : (isUserTier
                                    ? AppColors.primaryContainer.withValues(alpha: 0.5)
                                    : context.appOutlineVariant.withValues(alpha: 0.3)),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 18,
                              color: isPastTier || isUserTier || isSelected
                                  ? color
                                  : color.withValues(alpha: 0.35),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tierName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.headlineLgMobile.copyWith(
                                  fontSize: 12,
                                  fontWeight: isSelected || isUserTier
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? color
                                      : (isPastTier || isUserTier
                                          ? context.appTextPrimary
                                          : context.appTextSecondary.withValues(alpha: 0.6)),
                                ),
                              ),
                            ),
                            if (isPastTier)
                              const Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppColors.primaryContainer)
                            else if (isUserTier)
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(width: 12),

              // RIGHT SIDE: Divisions within Selected Tier
              Expanded(
                flex: 6,
                child: _buildDivisionsList(
                  context,
                  selectedTier: selectedTier,
                  userTier: userTier,
                  userDivision: userDivision,
                  totalXP: totalXP,
                  isUnlocked: isUnlocked,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivisionsList(
    BuildContext context, {
    required String selectedTier,
    required String userTier,
    required String userDivision,
    required int totalXP,
    required bool isUnlocked,
  }) {
    final isDark = context.isDarkMode;
    final divisions = ['IV', 'III', 'II', 'I'];

    if (!isUnlocked) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appOutlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock_rounded, size: 32, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              'Ranked Locked',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete 5 workouts to unlock competitive tiers & divisions.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 4),
          child: Text(
            '$selectedTier Divisions',
            style: AppTheme.headlineLgMobile.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
        ),
        Column(
          children: divisions.map((div) {
            RankInfo? rankInfo;
            int rankIndex = -1;

            for (int i = 0; i < GamificationService.rankStructure.length; i++) {
              final r = GamificationService.rankStructure[i];
              if (r.tier.toLowerCase() == selectedTier.toLowerCase() &&
                  r.division.toLowerCase() == div.toLowerCase()) {
                rankInfo = r;
                rankIndex = i;
                break;
              }
            }

            if (rankInfo == null) return const SizedBox.shrink();

            final int minXP = rankInfo.minXP;
            final int nextMinXP = (rankIndex + 1 < GamificationService.rankStructure.length)
                ? GamificationService.rankStructure[rankIndex + 1].minXP
                : minXP + 3000;
            final int divSpan = nextMinXP - minXP;

            final bool isCurrentDiv =
                userTier.toLowerCase() == selectedTier.toLowerCase() &&
                    userDivision.toLowerCase() == div.toLowerCase();
            final bool isCompleted = totalXP >= nextMinXP;

            Color tierColor = const Color(0xFFFFD700);
            if (selectedTier.toLowerCase() == 'bronze') tierColor = const Color(0xFFCD7F32);
            if (selectedTier.toLowerCase() == 'silver') tierColor = const Color(0xFFC0C0C0);
            if (selectedTier.toLowerCase() == 'platinum') tierColor = const Color(0xFF00E5FF);
            if (selectedTier.toLowerCase() == 'diamond') tierColor = const Color(0xFFB388FF);
            if (selectedTier.toLowerCase() == 'elite') tierColor = const Color(0xFF00E676);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrentDiv
                    ? tierColor.withValues(alpha: isDark ? 0.15 : 0.1)
                    : (isCompleted
                        ? (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100)
                        : (isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrentDiv
                      ? tierColor
                      : (isCompleted
                          ? AppColors.primaryContainer.withValues(alpha: 0.4)
                          : context.appOutlineVariant.withValues(alpha: 0.3)),
                  width: isCurrentDiv ? 1.5 : 1.0,
                ),
                boxShadow: isCurrentDiv
                    ? [
                        BoxShadow(
                          color: tierColor.withValues(alpha: 0.25),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${rankInfo.tier} ${rankInfo.division}',
                        style: AppTheme.headlineLgMobile.copyWith(
                          fontSize: 13,
                          fontWeight: isCurrentDiv ? FontWeight.w800 : FontWeight.w700,
                          color: isCurrentDiv
                              ? tierColor
                              : (isCompleted
                                  ? context.appTextPrimary
                                  : context.appTextSecondary),
                        ),
                      ),
                      if (isCurrentDiv)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tierColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        )
                      else if (isCompleted)
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: AppColors.primaryContainer),
                            SizedBox(width: 4),
                            Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '$minXP XP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.appTextSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  if (isCurrentDiv) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(totalXP - minXP).clamp(0, divSpan)} / $divSpan XP',
                          style: AppTheme.headlineLgMobile.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        Text(
                          '${(nextMinXP - totalXP).clamp(0, divSpan)} XP left',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((totalXP - minXP) / divSpan).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
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
            Text(
              'WEEKLY CHALLENGES',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
                letterSpacing: 1.0,
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
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: challenges.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final challenge = challenges[index];
              return ChallengeCard(
                challenge: challenge,
                width: 275,
              );
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
    final workoutHistory = provider.workoutHistory;

    final now = DateTime.now();
    // Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Column(
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
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
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
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: context.appOutlineVariant.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 14),

          // 7-day calendar visualization: M T W T F S S
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final dayDate = monday.add(Duration(days: index));
              final dayLabel = weekDays[index];

              final bool isToday = dayDate.year == now.year &&
                  dayDate.month == now.month &&
                  dayDate.day == now.day;
              final bool isPast = dayDate.isBefore(DateTime(now.year, now.month, now.day));

              final bool hasWorkout = workoutHistory.any((w) =>
                  w.dateCompleted.year == dayDate.year &&
                  w.dateCompleted.month == dayDate.month &&
                  w.dateCompleted.day == dayDate.day);

              return Column(
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                      color: isToday ? AppColors.primaryContainer : context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hasWorkout
                          ? AppColors.primary
                          : (isPast
                              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200)
                              : Colors.transparent),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasWorkout
                            ? AppColors.primary
                            : (isToday
                                ? AppColors.primaryContainer
                                : context.appOutlineVariant.withValues(alpha: 0.4)),
                        width: isToday ? 2.0 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: hasWorkout
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.black)
                          : Text(
                              '${dayDate.day}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                color: hasWorkout
                                    ? Colors.black
                                    : (isPast
                                        ? context.appTextSecondary
                                        : context.appTextPrimary.withValues(alpha: 0.6)),
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 5. Global Leaderboard Section

  /// 5. Global Leaderboard Section
  Widget _buildLeaderboard(BuildContext context, String userRank, int userXP) {
    final isDark = context.isDarkMode;
    final provider = FitnessProvider.instance;

    String title = 'Global Leaderboard';
    if (_selectedLeaderboardTab == 1) title = 'Friends Leaderboard';
    if (_selectedLeaderboardTab == 2) title = 'Local Leaderboard';

    List<LeaderboardEntry> rawEntries;
    switch (_selectedLeaderboardTab) {
      case 1:
        rawEntries = provider.friendsLeaderboard;
        break;
      case 2:
        rawEntries = provider.localLeaderboard;
        break;
      case 0:
      default:
        rawEntries = provider.globalLeaderboard;
        break;
    }

    final currentUserId = provider.currentUser?.id;
    final currentUserName = provider.profile.name;

    final List<LeaderboardUser> leaderboardUsers = rawEntries
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isCurrent = (currentUserId != null && item.userId == currentUserId) ||
              item.displayName == currentUserName;
          return item.toLeaderboardUser(
            rankPosition: index + 1,
            isCurrentUser: isCurrent,
          );
        })
        .toList();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTheme.headlineLgMobile.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),

              // Filter Tabs
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildTabButton(context, index: 0, label: 'Global'),
                    _buildTabButton(context, index: 1, label: 'Friends'),
                    _buildTabButton(context, index: 2, label: 'Local'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Loading State
          if (provider.isLeaderboardLoading && leaderboardUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          // Error State
          else if (provider.leaderboardError != null && leaderboardUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.red.shade400, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load leaderboard data.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => provider.refreshLeaderboard(),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          // Empty State
          else if (leaderboardUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No rankings available in this category.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            )
          // User List with Smooth AnimatedSwitcher Transition
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0.0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey<int>(_selectedLeaderboardTab),
                children: leaderboardUsers.map((user) {
                  final int userIndex = leaderboardUsers.indexOf(user);
                  final bool showDots = user.isCurrentUser &&
                      user.rankPosition > 3 &&
                      userIndex > 0 &&
                      leaderboardUsers[userIndex - 1].rankPosition != user.rankPosition - 1;

                  if (showDots) {
                    return Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.more_horiz_rounded, color: Colors.grey, size: 20),
                            ],
                          ),
                        ),
                        _buildLeaderboardUserTile(context, user: user),
                      ],
                    );
                  }

                  return _buildLeaderboardUserTile(context, user: user);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, {required int index, required String label}) {
    final bool isSelected = _selectedLeaderboardTab == index;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () => setState(() => _selectedLeaderboardTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? context.appTextPrimary : context.appTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardUserTile(
    BuildContext context, {
    required LeaderboardUser user,
  }) {
    final isDark = context.isDarkMode;

    Color rankColor = context.appTextPrimary;
    if (user.rankPosition == 1) rankColor = const Color(0xFFFFD700);
    if (user.rankPosition == 2) rankColor = const Color(0xFFC0C0C0);
    if (user.rankPosition == 3) rankColor = const Color(0xFFCD7F32);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: user.isCurrentUser
            ? AppColors.primaryContainer.withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(10),
        border: user.isCurrentUser
            ? Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.5), width: 1)
            : Border.all(color: context.appOutlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#${user.rankPosition}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.headlineLgMobile.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // User Profile Avatar via AppImage.avatar
          AppImage.avatar(
            imageUrl: user.imageUrl,
            name: user.name,
            radius: 20,
          ),
          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: AppTheme.headlineLgMobile.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: user.isCurrentUser ? AppColors.primaryContainer : context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  user.rankTitle,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),

          // XP Score
          Text(
            _formatXP(user.xp),
            style: AppTheme.headlineLgMobile.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: user.isCurrentUser ? AppColors.primaryContainer : context.appTextPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'XP',
            style: AppTheme.bodySm.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
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
            Text(
              'RECENT BADGES',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
                letterSpacing: 1.0,
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
          height: 124,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  String _formatXP(int xp) {
    if (xp >= 1000) {
      final double k = xp / 1000.0;
      return '${k.toStringAsFixed(1)}k';
    }
    return xp.toString();
  }
}
