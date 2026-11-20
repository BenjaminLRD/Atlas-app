import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/profile_provider.dart';
import '../models/progress_analytics.dart';
import '../models/progress_summary.dart';
import '../models/workout_history.dart';
import '../providers/fitness_provider.dart';
import '../providers/showcase_mode_provider.dart';
import '../services/insight_service.dart';
import '../widgets/analytics/muscle_balance_chart.dart';
import '../widgets/analytics/strength_progress_card.dart';
import '../widgets/analytics/training_overview_card.dart';
import '../widgets/common/achievement_gallery.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/section_header.dart';
import '../widgets/common/skeleton_card.dart';
import '../widgets/profile_picture.dart';
import '../widgets/progress/insight_section.dart';
import '../widgets/progress/personal_records_section.dart';
import '../widgets/progress/workout_timeline.dart';
import '../widgets/recovery/profile_sleep_recovery_section.dart';

/// Consolidated Profile Screen acting as the user's personal fitness & progress dashboard.
/// Hierarchy:
/// 1. Header (Avatar, Display name, Bio, Edit Profile & Settings actions)
/// 2. Fitness Summary (Weight, Goal, Streak, Total Workouts, Rank & XP)
/// 3. Progress (Weight Trends, Training Volume, Weekly Performance, Strength Progression, Muscle Balance)
/// 4. Achievements (Personal Records, Unlocked Badges, AI Insights)
/// 5. Workout History (Session Timeline Journal)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final ProfileProvider _provider;
  late final AnimationController _refreshAnimationController;

  String _selectedWeightPeriod = '6M';
  DateTime _lastUpdatedTime = DateTime.now();
  int _weeklyPerformanceTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _provider = AppDependencies.instance.profileProvider;
    _provider.addListener(_onProfileChanged);
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void dispose() {
    _provider.removeListener(_onProfileChanged);
    _refreshAnimationController.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) {
      setState(() {
        _lastUpdatedTime = DateTime.now();
      });
    }
  }

  void _handleRefresh() {
    setState(() {
      _lastUpdatedTime = DateTime.now();
    });
    _refreshAnimationController.forward(from: 0.0);
    _provider.reload();
  }

  String _formatLastUpdated() {
    final dt = _lastUpdatedTime;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return 'Last updated: $hour:$minute $ampm';
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
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
        final fitnessProvider = FitnessProvider.instance;
        final history = fitnessProvider.workoutHistory;
        final summary = fitnessProvider.progressSummary;

        if (fitnessProvider.isLoading) {
          return Scaffold(
            backgroundColor: context.appBackground,
            body: SafeArea(child: _buildSkeletonDashboard(context)),
          );
        }

        return Scaffold(
          backgroundColor: context.appBackground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 110,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Header Bar (User Avatar, Display Name, Settings)
                  _buildTopHeader(context),
                  const SizedBox(height: 14),

                  // 2. Profile Overview Header Row with Edit Profile CTA
                  _buildOverviewHeaderRow(context),
                  const SizedBox(height: 16),

                  // 3. Fitness Summary Hero Card
                  _buildFitnessSummaryHeroCard(
                    context,
                    summary,
                    fitnessProvider,
                  ),
                  const SizedBox(height: 20),

                  // 4. Weight Trends Section
                  _buildWeightTrendsSection(context),
                  const SizedBox(height: 20),

                  // 5. Training Overview (Bento Grid)
                  TrainingOverviewCard(summary: summary),
                  const SizedBox(height: 20),

                  // 6. Weekly Performance (Interactive Tabs)
                  _buildWeeklyPerformanceSection(context, summary, history),
                  const SizedBox(height: 20),

                  // 7. Sleep & Recovery Trends (7-Day Bar Chart & Telemetry)
                  const ProfileSleepRecoverySection(),
                  const SizedBox(height: 20),

                  // 8. Strength Progression (1RM Tracking)
                  StrengthProgressCard(topExercises: summary.topExercises),
                  const SizedBox(height: 20),

                  // 8. Plateau Alerts (if detected)
                  if (fitnessProvider
                      .athleteAnalytics
                      .plateauInsights
                      .isNotEmpty) ...[
                    _buildPlateauSection(
                      context,
                      fitnessProvider.athleteAnalytics.plateauInsights,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 9. Muscle Balance (Donut Chart)
                  MuscleBalanceChart(
                    distribution: summary.muscleGroupDistribution,
                    totalWeeklyVolume: summary.weeklyVolume,
                    totalMonthlyVolume: summary.monthlyVolume,
                  ),
                  const SizedBox(height: 20),

                  // 10. Personal Records Section
                  PersonalRecordsSection(records: summary.personalRecords),
                  const SizedBox(height: 24),

                  // 11. Achievements Gallery
                  Builder(
                    builder: (context) {
                      final unlocked =
                          FitnessProvider.instance.userProgress.achievements;
                      return AchievementGallery(unlockedBadgeIds: unlocked);
                    },
                  ),
                  const SizedBox(height: 24),

                  // 12. Workout Timeline Journal
                  const SectionHeader(
                    title: 'Workout Timeline',
                    subtitle: 'Interactive training journal & session history',
                  ),
                  const SizedBox(height: 14),
                  WorkoutTimeline(history: history),
                  const SizedBox(height: 24),

                  // 13. AI-Ready Insights Section
                  InsightSection(
                    insights: InsightService.instance.generateInsights(
                      summary,
                      neededMilestones:
                          (fitnessProvider
                                  .nextRankRequirement['neededMilestones']
                              as int?) ??
                          0,
                      nextRankTitle:
                          (fitnessProvider.nextRankRequirement['nextRank']
                              as String?) ??
                          '',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // HEADER & PROFILE IDENTITY
  // -------------------------------------------------------------
  Widget _buildTopHeader(BuildContext context) {
    final hasName =
        _provider.isShowcaseIdentity || _provider.name.trim().isNotEmpty;
    final name = _provider.isShowcaseIdentity
        ? ProfileProvider.showcaseSelfLabel
        : hasName
        ? _provider.name
        : 'Athlete Profile';
    final bio = _provider.bio.trim().isNotEmpty
        ? _provider.bio.trim()
        : 'Your personal fitness journey';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: _navigateToEditProfile,
                child: Hero(
                  tag: 'profile_avatar_hero',
                  child: ProfileImage(
                    path: _provider.displayProfilePic.isNotEmpty
                        ? _provider.displayProfilePic
                        : null,
                    size: 48,
                    iconSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.settings_outlined, size: 22),
          color: context.appTextSecondary,
          tooltip: 'Settings',
        ),
      ],
    );
  }

  Widget _buildOverviewHeaderRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final editButton = AppButton.outlined(
          label: 'Edit Profile',
          icon: Icons.edit_outlined,
          height: 36,
          isFullWidth: false,
          onPressed: _navigateToEditProfile,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fitness Dashboard',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _formatLastUpdated(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 10,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: _handleRefresh,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.primary,
                          size: 15,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: editButton),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // FITNESS SUMMARY HERO CARD
  // -------------------------------------------------------------
  Widget _buildFitnessSummaryHeroCard(
    BuildContext context,
    ProgressSummary summary,
    FitnessProvider provider,
  ) {
    final isDark = context.isDarkMode;
    final isShowcase = ShowcaseModeProvider.instance.isShowcaseModeEnabled;
    final isUnlocked = provider.rankedUnlocked || isShowcase;
    final rankTitle = isUnlocked ? provider.fullRank : 'Unranked Athlete';
    final weightStr = _provider.weight.isNotEmpty
        ? '${_provider.weight} ${_provider.massUnit}'
        : (isShowcase ? '77.5 kg' : '-');
    final goalStr = _provider.fitnessGoal.isNotEmpty
        ? _provider.fitnessGoal
        : (isShowcase ? 'Hypertrophy & Strength' : 'General Fitness');

    final int streak = isShowcase ? 12 : summary.currentStreak;
    final int workouts = isShowcase ? 48 : summary.totalWorkouts;

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: isDark
          ? AppColors.primary.withValues(alpha: 0.3)
          : AppColors.primary.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Greeting & Rank badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rankTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${summary.currentXP > 0 ? summary.currentXP : (isShowcase ? 14850 : 0)} XP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Middle Row: Current Goal Pill & Weight
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Goal: $goalStr',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Weight: $weightStr',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Sub-Row: Streak, Total Workouts, Target
          Row(
            children: [
              Expanded(
                child: _buildHeroSubStat(context, '🔥 STREAK', '$streak Days'),
              ),
              Container(
                height: 20,
                width: 1,
                color: context.appOutlineVariant.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildHeroSubStat(
                  context,
                  '💪 WORKOUTS',
                  '$workouts Done',
                ),
              ),
              Container(
                height: 20,
                width: 1,
                color: context.appOutlineVariant.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildHeroSubStat(
                  context,
                  '🎯 TARGET',
                  _provider.targetWeight.isNotEmpty
                      ? '${_provider.targetWeight} ${_provider.massUnit}'
                      : (isShowcase ? '78.0 kg' : '-'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSubStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.labelCaps.copyWith(
            fontSize: 9,
            color: context.appTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // WEIGHT TRENDS SECTION
  // -------------------------------------------------------------
  Widget _buildWeightTrendsSection(BuildContext context) {
    final isShowcase = ShowcaseModeProvider.instance.isShowcaseModeEnabled;
    final hasWeight = _provider.weight.isNotEmpty || isShowcase;

    return AppCard(
      padding: const EdgeInsets.all(16),
      borderColor: context.isDarkMode
          ? AppColors.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Range Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.show_chart_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weight Trends',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Progress & body transformation',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 11,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Segmented control (1M, 6M, 1Y)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['1M', '6M', '1Y'].map((period) {
                    final isSelected = _selectedWeightPeriod == period;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedWeightPeriod = period;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          period,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : context.appTextSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!hasWeight)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.monitor_weight_outlined,
                    size: 36,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No weight logs yet',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Log your weight in Edit Profile to start tracking trends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Metrics summary bar
                Row(
                  children: [
                    Expanded(
                      child: _buildWeightStatItem(
                        'CURRENT',
                        _provider.weight.isNotEmpty
                            ? '${_provider.weight} kg'
                            : '77.5 kg',
                        context,
                      ),
                    ),
                    Expanded(
                      child: _buildWeightStatItem(
                        'CHANGE',
                        '-1.5 kg',
                        context,
                        isPositive: true,
                      ),
                    ),
                    Expanded(
                      child: _buildWeightStatItem('LOWEST', '76.8 kg', context),
                    ),
                    Expanded(
                      child: _buildWeightStatItem(
                        'HIGHEST',
                        '79.0 kg',
                        context,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Chart
                SizedBox(
                  height: 160,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: context.appOutlineVariant.withValues(
                            alpha: 0.15,
                          ),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              const months = [
                                'DEC',
                                'JAN',
                                'FEB',
                                'MAR',
                                'APR',
                                'MAY',
                              ];
                              final idx = val.toInt();
                              if (idx >= 0 && idx < months.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    months[idx],
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: context.appTextSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 5,
                      minY: 75,
                      maxY: 80,
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 79.0),
                            FlSpot(1, 78.4),
                            FlSpot(2, 78.0),
                            FlSpot(3, 77.8),
                            FlSpot(4, 77.2),
                            FlSpot(5, 77.5),
                          ],
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.25),
                                AppColors.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWeightStatItem(
    String label,
    String value,
    BuildContext context, {
    bool isPositive = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: AppTheme.labelCaps.copyWith(
            fontSize: 8,
            color: context.appTextSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isPositive
                  ? const Color(0xFF10B981)
                  : context.appTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // WEEKLY PERFORMANCE TABBED SECTION
  // -------------------------------------------------------------
  Widget _buildWeeklyPerformanceSection(
    BuildContext context,
    ProgressSummary summary,
    List<WorkoutHistory> history,
  ) {
    final isDark = context.isDarkMode;
    final tabs = ['Volume', 'Strength', 'Workouts', 'Calories'];

    String currentVal = '';
    double changePct = 0.0;
    String unit = '';

    switch (_weeklyPerformanceTabIndex) {
      case 0:
        currentVal = summary.weeklyVolume.toStringAsFixed(0);
        changePct = summary.weeklyVolumeChangePercent;
        unit = 'kg';
        break;
      case 1:
        currentVal = '+${summary.strengthGrowthPercent.toStringAsFixed(1)}';
        changePct = summary.strengthGrowthPercent;
        unit = '%';
        break;
      case 2:
        currentVal = '${summary.totalWorkouts}';
        changePct = summary.weeklyWorkoutChange.toDouble();
        unit = 'sessions';
        break;
      case 3:
        final currentWeekCals = history.fold<double>(
          0.0,
          (acc, h) => acc + h.caloriesBurned,
        );
        currentVal = currentWeekCals.toStringAsFixed(0);
        changePct = 0.0;
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
              Expanded(
                child: Text(
                  'WEEKLY PERFORMANCE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (isPositive ? AppColors.primary : Colors.redAccent)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: isPositive
                            ? AppColors.primary
                            : Colors.redAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${changePct.abs().toStringAsFixed(0)}% vs last week',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isPositive
                              ? AppColors.primary
                              : Colors.redAccent,
                        ),
                      ),
                    ],
                  )),
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
                  onTap: () =>
                      setState(() => _weeklyPerformanceTabIndex = index),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? context.appTextPrimary
                            : context.appTextSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Tab Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currentVal,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(fontSize: 12, color: context.appTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PLATEAU ALERTS SECTION
  // -------------------------------------------------------------
  Widget _buildPlateauSection(
    BuildContext context,
    List<PlateauInsight> plateaus,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
      borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Plateau Advisory',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...plateaus.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${p.exerciseName}: ${p.recommendation}',
                style: TextStyle(fontSize: 11, color: context.appTextSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          SkeletonCard(height: 80),
          SizedBox(height: 16),
          SkeletonCard(height: 160),
          SizedBox(height: 16),
          SkeletonCard(height: 180),
        ],
      ),
    );
  }
}
