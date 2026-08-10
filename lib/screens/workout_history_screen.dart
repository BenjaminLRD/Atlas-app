import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/progress_summary.dart';
import '../models/workout_history.dart';
import '../providers/fitness_provider.dart';
import '../widgets/analytics/muscle_balance_chart.dart';
import '../widgets/analytics/strength_progress_card.dart';
import '../widgets/analytics/training_overview_card.dart';
import '../services/insight_service.dart';
import '../widgets/progress/insight_section.dart';
import '../widgets/progress/personal_records_section.dart';
import '../widgets/progress/workout_timeline.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/skeleton_card.dart';
import 'notifications_screen.dart';
import 'ranked_screen.dart';
import 'settings_screen.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<WorkoutHistory> _history = [];
  late final AnimationController _glowController;
  int _weeklyPerformanceTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _history = FitnessProvider.instance.workoutHistory;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationState();
    _history = FitnessProvider.instance.workoutHistory;
  }

  void _updateAnimationState() {
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (!tickerEnabled || disableAnimations) {
      if (_glowController.isAnimating) {
        _glowController.stop();
      }
    } else {
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final provider = FitnessProvider.instance;
        _history = provider.workoutHistory;
        final summary = provider.progressSummary;

        return Scaffold(
          backgroundColor: context.appBackground,
          body: Stack(
            children: [
              // Ambient green glow highlight background
              Positioned(
                top: -80,
                left: MediaQuery.of(context).size.width * 0.2,
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.6 + (_glowController.value * 0.4),
                      child: Transform.scale(
                        scale: 0.95 + (_glowController.value * 0.1),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(
                        alpha: context.isDarkMode ? 0.16 : 0.08,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: provider.isLoading
                    ? _buildSkeletonDashboard(context)
                    : SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 130,
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Standard Header Bar
                      _buildHeaderBar(context),
                      const SizedBox(height: 16),

                      // SECTION 1 — Hero Summary Card
                      _buildHeroSummaryCard(context, summary, provider),
                      const SizedBox(height: 20),

                      // SECTION 2 — Training Overview (Bento Grid)
                      TrainingOverviewCard(summary: summary),
                      const SizedBox(height: 20),

                      // SECTION 3 — Weekly Performance (Interactive Tabs)
                      _buildWeeklyPerformanceSection(context, summary),
                      const SizedBox(height: 20),

                      // SECTION 4 — Strength Progression
                      StrengthProgressCard(topExercises: summary.topExercises),
                      const SizedBox(height: 20),

                      // SECTION 5 — Muscle Balance (Donut Chart)
                      MuscleBalanceChart(
                        distribution: summary.muscleGroupDistribution,
                        totalWeeklyVolume: summary.weeklyVolume,
                        totalMonthlyVolume: summary.monthlyVolume,
                      ),
                      const SizedBox(height: 20),

                      // SECTION 6 — Personal Records Section
                      PersonalRecordsSection(records: summary.personalRecords),
                      const SizedBox(height: 24),

                      // SECTION 7 — Workout Timeline
                      const SectionHeader(
                        title: 'Workout Timeline',
                        subtitle: 'Interactive training journal & session history',
                      ),
                      const SizedBox(height: 14),

                      WorkoutTimeline(history: _history),
                      const SizedBox(height: 24),

                      // SECTION 8 — AI-Ready Insights Section
                      InsightSection(
                        insights: InsightService.instance.generateInsights(
                          summary,
                          neededXP: (provider.nextRankRequirement['neededXP'] as int?) ?? 340,
                          nextRankTitle: (provider.nextRankRequirement['nextRank'] as String?) ?? 'Gold II',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return AppHeader.standard(
      title: 'Progress & Analytics',
      subtitle: '${_history.length} Completed Sessions',
      onNotificationsTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      onSettingsTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    );
  }

  /// SECTION 1 — Premium Hero Summary Card
  Widget _buildHeroSummaryCard(
    BuildContext context,
    ProgressSummary summary,
    FitnessProvider provider,
  ) {
    if (summary.totalWorkouts == 0) {
      return _buildHeroZeroStateCard(context);
    }

    final isDark = context.isDarkMode;
    final isUnlocked = provider.rankedUnlocked;
    final rankTitle = isUnlocked ? provider.fullRank : 'Unranked';
    final nextReq = provider.nextRankRequirement;
    final int neededXP = (nextReq['neededXP'] as int?) ?? (isUnlocked ? 0 : 500);
    final String nextRankTitle = nextReq['nextRank'] as String? ?? 'Bronze IV';
    final double progressPct = isUnlocked
        ? ((nextReq['progressPercentage'] as double?) ?? 0.0).clamp(0.0, 1.0)
        : (summary.totalWorkouts / 5.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RankedScreen()),
        );
        if (mounted) setState(() {});
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14151B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryContainer.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryContainer,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rankTitle,
                      style: AppTheme.headlineLgMobile.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.primaryContainer),
                      const SizedBox(width: 4),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: summary.currentXP.toDouble()),
                        builder: (context, val, _) {
                          return Text(
                            '${val.toInt()} XP',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryContainer,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // XP Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rank Progress',
                  style: AppTheme.bodySm.copyWith(fontSize: 11, color: context.appTextSecondary),
                ),
                Text(
                  neededXP == 0 ? 'Max Rank' : '$neededXP XP until $nextRankTitle',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: progressPct),
                builder: (context, val, _) {
                  return LinearProgressIndicator(
                    value: val,
                    minHeight: 7,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Stats Sub-Row: Streak, Weekly Workouts, Longest Streak
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeroSubStat(context, '🔥 Streak', '${summary.currentStreak} Days'),
                Container(height: 24, width: 1, color: context.appOutlineVariant.withValues(alpha: 0.3)),
                _buildHeroSubStat(context, '💪 This Week', '${summary.totalWorkouts} Done'),
                Container(height: 24, width: 1, color: context.appOutlineVariant.withValues(alpha: 0.3)),
                _buildHeroSubStat(context, '🏆 Best Streak', '${summary.longestStreak} Days'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSubStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.labelCaps.copyWith(
            fontSize: 10,
            color: context.appTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.headlineMd.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }

  /// SECTION 3 — Weekly Performance Section with Interactive Tabs & Sparkline
  Widget _buildWeeklyPerformanceSection(BuildContext context, ProgressSummary summary) {
    final isDark = context.isDarkMode;
    final tabs = ['Volume', 'Strength', 'Workouts', 'Calories'];

    // Values for tabs
    String currentVal = '';
    String prevVal = '';
    double changePct = 0.0;
    String unit = '';

    switch (_weeklyPerformanceTabIndex) {
      case 0:
        currentVal = summary.weeklyVolume.toStringAsFixed(0);
        prevVal = (summary.weeklyVolume / (1 + (summary.weeklyVolumeChangePercent / 100.0))).toStringAsFixed(0);
        changePct = summary.weeklyVolumeChangePercent;
        unit = 'kg';
        break;
      case 1:
        currentVal = '+${summary.strengthGrowthPercent.toStringAsFixed(1)}';
        prevVal = '+0.0';
        changePct = summary.strengthGrowthPercent;
        unit = '%';
        break;
      case 2:
        currentVal = '${summary.totalWorkouts}';
        prevVal = '${(summary.totalWorkouts - summary.weeklyWorkoutChange).clamp(0, 999)}';
        changePct = summary.weeklyWorkoutChange.toDouble();
        unit = 'sessions';
        break;
      case 3:
        currentVal = '${(summary.weeklyVolume * 0.05).round()}';
        prevVal = '${(summary.weeklyVolume * 0.04).round()}';
        changePct = 12.0;
        unit = 'kcal';
        break;
    }

    final isPositive = changePct >= 0;

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
              Text(
                'WEEKLY PERFORMANCE',
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
                  color: (isPositive ? AppColors.primaryContainer : Colors.redAccent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 12,
                      color: isPositive ? AppColors.primaryContainer : Colors.redAccent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${changePct.abs().toStringAsFixed(0)}% vs last week',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isPositive ? AppColors.primaryContainer : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tabs
          Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = index == _weeklyPerformanceTabIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _weeklyPerformanceTabIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryContainer : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? context.appTextPrimary : context.appTextSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Values Comparison & Sparkline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT WEEK',
                    style: AppTheme.labelCaps.copyWith(fontSize: 9, color: context.appTextSecondary),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currentVal,
                        style: AppTheme.headlineLgMobile.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryContainer),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'PREVIOUS WEEK',
                    style: AppTheme.labelCaps.copyWith(fontSize: 9, color: context.appTextSecondary),
                  ),
                  Text(
                    '$prevVal $unit',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Zero state Hero card when user has 0 workouts logged
  Widget _buildHeroZeroStateCard(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.primaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Aizawl Gym',
                      style: AppTheme.headlineLgMobile.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    Text(
                      'Start your fitness journey today',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Complete your first workout to unlock:',
            style: AppTheme.bodySm.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildZeroFeatureRow(context, Icons.analytics_outlined, 'Performance analytics & volume tracking'),
          const SizedBox(height: 6),
          _buildZeroFeatureRow(context, Icons.emoji_events_outlined, 'Rankings & XP division progression'),
          const SizedBox(height: 6),
          _buildZeroFeatureRow(context, Icons.military_tech_outlined, 'Achievement badges & streak tracking'),
          const SizedBox(height: 6),
          _buildZeroFeatureRow(context, Icons.auto_awesome_outlined, 'Personalized AI fitness recommendations'),
          const SizedBox(height: 18),
          AppButton.primary(
            label: 'START WORKOUT',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              // Action prompt
            },
          ),
        ],
      ),
    );
  }

  Widget _buildZeroFeatureRow(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Shimmer loading skeleton dashboard
  Widget _buildSkeletonDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonCard(height: 48, borderRadius: 12),
          SizedBox(height: 16),
          SkeletonCard(height: 180, borderRadius: 20),
          SizedBox(height: 20),
          SkeletonAnalyticsCard(),
          SizedBox(height: 20),
          SkeletonChartCard(),
          SizedBox(height: 20),
          SkeletonTimelineCard(),
        ],
      ),
    );
  }
}
