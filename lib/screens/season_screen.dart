import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/fitness_season.dart';
import '../models/leaderboard_entry.dart';
import '../models/season_progress.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_image.dart';

/// Screen dedicated to competitive fitness seasons, seasonal XP progress, and season leaderboards.
class SeasonScreen extends StatefulWidget {
  const SeasonScreen({super.key});

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessProvider.instance.loadSeason();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final provider = FitnessProvider.instance;
        final season = provider.currentSeason;
        final progress = provider.seasonProgress;
        final leaderboard = provider.seasonLeaderboard;

        return Scaffold(
          backgroundColor: context.appBackground,
          body: SafeArea(
            child: Column(
              children: [
                AppHeader.standard(
                  title: season?.name ?? 'Fitness Season',
                  subtitle: season != null
                      ? '${season.remainingDays} days remaining in season'
                      : 'Competitive Season',
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => provider.loadSeason(),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (season != null) _buildSeasonBanner(context, season),
                          const SizedBox(height: 16),
                          _buildUserSeasonCard(context, progress),
                          const SizedBox(height: 20),
                          _buildRewardsSection(context, season),
                          const SizedBox(height: 20),
                          _buildLeaderboardHeader(context),
                          const SizedBox(height: 10),
                          _buildSeasonLeaderboard(context, leaderboard),
                        ],
                      ),
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

  Widget _buildSeasonBanner(BuildContext context, FitnessSeason season) {
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.primaryContainer),
                    SizedBox(width: 4),
                    Text(
                      'ACTIVE SEASON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${season.remainingDays} days left',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            season.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            season.description,
            style: TextStyle(
              fontSize: 13,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSeasonCard(BuildContext context, SeasonProgress? progress) {
    final seasonXP = progress?.seasonXP ?? 0;
    final targetXP = 15000;
    final percent = (seasonXP / targetXP).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Seasonal Rank',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                      Text(
                        'Season Contender',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '$seasonXP XP',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seasonal Progress',
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
              ),
              Text(
                '${(percent * 100).toInt()}% of Tier Target',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.appTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: context.isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSection(BuildContext context, FitnessSeason? season) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'End-of-Season Rewards',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  season?.rewardDescription ??
                      'Top leaderboard placement unlocks exclusive gear & golden badges!',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Season Leaderboard',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        Text(
          'Top Contenders',
          style: TextStyle(
            fontSize: 12,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonLeaderboard(
    BuildContext context,
    List<LeaderboardEntry> leaderboard,
  ) {
    if (leaderboard.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No season progress recorded yet.',
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: leaderboard.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final item = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: rank <= 3 ? Colors.amber : context.appTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppImage.avatar(
                  imageUrl: item.avatarUrl,
                  name: item.displayName,
                  radius: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Text(
                        item.rankTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.totalXP} XP',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
