import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/challenge.dart';
import '../models/user_challenge.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';

/// Screen dedicated to displaying, tracking, and claiming Weekly Challenges.
/// Built with Stitch design principles and reactive AppTheme dark/light styling.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessProvider.instance.loadChallenges();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final provider = FitnessProvider.instance;
        final active = provider.activeChallenges;
        final userChallenges = provider.userChallenges;
        final summary = provider.challengeSummary;

        return Scaffold(
          backgroundColor: context.appBackground,
          body: SafeArea(
            child: Column(
              children: [
                const AppHeader.standard(
                  title: 'Weekly Challenges',
                  subtitle: 'Complete tasks to earn XP and level up',
                ),
                Expanded(
                  child: provider.isChallengesLoading && active.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : provider.challengesError != null && active.isEmpty
                          ? _buildErrorState(context, provider)
                          : active.isEmpty
                              ? _buildEmptyState(context)
                              : RefreshIndicator(
                                  onRefresh: () => provider.refreshChallenges(),
                                  child: ListView(
                                    padding: const EdgeInsets.all(16),
                                    children: [
                                      _buildSummaryBanner(context, summary),
                                      const SizedBox(height: 16),
                                      _buildCategoryFilterChips(context),
                                      const SizedBox(height: 16),
                                      _buildActiveChallengesSection(
                                        context,
                                        active: active,
                                        userChallenges: userChallenges,
                                        provider: provider,
                                      ),
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

  Widget _buildSummaryBanner(BuildContext context, Map<String, dynamic> summary) {
    final isDark = context.isDarkMode;
    final completedCount = summary['completedCount'] as int? ?? 0;
    final totalCount = summary['totalCount'] as int? ?? 0;
    final claimableXP = summary['claimableXP'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [AppColors.primaryContainer, AppColors.primaryContainer.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.amber,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Quests',
                  style: AppTheme.headlineMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$completedCount of $totalCount Completed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (claimableXP > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade400,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '+$claimableXP XP Ready',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips(BuildContext context) {
    final categories = ['all', 'training', 'nutrition', 'volume', 'streak', 'strength'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          final label = cat[0].toUpperCase() + cat.substring(1);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(label),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : context.appTextPrimary,
              ),
              selectedColor: AppColors.primaryContainer,
              backgroundColor: context.isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
              onSelected: (_) => setState(() => _selectedCategory = cat),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveChallengesSection(
    BuildContext context, {
    required List<Challenge> active,
    required List<UserChallenge> userChallenges,
    required FitnessProvider provider,
  }) {
    final filtered = _selectedCategory == 'all'
        ? active
        : active.where((c) => c.category.toLowerCase() == _selectedCategory).toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No challenges found in this category.',
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((ch) {
        final uc = userChallenges.firstWhere(
          (u) => u.challengeId == ch.id,
          orElse: () => UserChallenge(
            id: 'uc_${ch.id}',
            userId: 'usr_local',
            challengeId: ch.id,
          ),
        );
        return _buildChallengeCard(context, challenge: ch, userChallenge: uc, provider: provider);
      }).toList(),
    );
  }

  Widget _buildChallengeCard(
    BuildContext context, {
    required Challenge challenge,
    required UserChallenge userChallenge,
    required FitnessProvider provider,
  }) {
    final isDark = context.isDarkMode;
    final progressRatio = (userChallenge.progress / challenge.targetValue).clamp(0.0, 1.0);
    final isCompleted = userChallenge.completed;
    final isClaimed = userChallenge.rewardClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    challenge.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ),
                // Expiration Countdown & XP Reward Tag
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: context.appTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      challenge.countdownLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+${challenge.rewardXP} XP',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              challenge.title,
              style: AppTheme.headlineLgMobile.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              challenge.description,
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 14),

            // Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatProgressText(challenge, userChallenge),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                Text(
                  '${(progressRatio * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? Colors.green : context.appTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressRatio,
                minHeight: 8,
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
                color: isCompleted ? Colors.green : AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: 12),

            // Claim Reward / Status Action Button
            if (isCompleted && !isClaimed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => provider.claimChallengeReward(challenge.id),
                  icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                  label: const Text('Claim Reward'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              )
            else if (isClaimed)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Reward Claimed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatProgressText(Challenge challenge, UserChallenge uc) {
    if (challenge.category == 'volume') {
      return '${uc.progress.toInt()} / ${challenge.targetValue.toInt()} kg';
    }
    return '${uc.progress.toInt()} / ${challenge.targetValue.toInt()}';
  }

  Widget _buildErrorState(BuildContext context, FitnessProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 36),
          const SizedBox(height: 8),
          Text(
            'Failed to load challenges.',
            style: TextStyle(color: context.appTextSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => provider.refreshChallenges(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text(
        'No active weekly challenges.',
        style: TextStyle(color: context.appTextSecondary, fontSize: 14),
      ),
    );
  }
}
