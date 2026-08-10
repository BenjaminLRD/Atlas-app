import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/profile_provider.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_hero_card.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_bottom_sheet.dart';
import '../widgets/common/app_list_tile.dart';
import '../widgets/common/metric_card.dart';
import '../widgets/common/progress_ring.dart';
import '../widgets/common/section_header.dart';
import 'body_composition_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'workout_session_screen.dart';
import 'weekly_workout_plan_screen.dart';
import '../widgets/coach/coach_summary_card.dart';
import '../widgets/common/readiness_card.dart';
import '../widgets/common/recovery_dashboard_card.dart';
import '../widgets/common/deload_alert_card.dart';
import '../widgets/common/adaptive_workout_card.dart';
import '../widgets/common/daily_motivation_card.dart';
import '../widgets/common/animated_rank_progress_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ProfileProvider _profileProvider;

  double _proteinConsumed = 0.0;
  double _proteinGoal = 140.0;
  int _waterGlasses = 7;

  @override
  void initState() {
    super.initState();
    _profileProvider = AppDependencies.instance.profileProvider;
    _profileProvider.addListener(_onProfileChanged);
    FitnessProvider.instance.addListener(_onFitnessChanged);
    _loadState();
  }

  @override
  void dispose() {
    FitnessProvider.instance.removeListener(_onFitnessChanged);
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onFitnessChanged() {
    if (mounted) {
      _loadState();
    }
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  void _loadState() {
    setState(() {
      _proteinConsumed = FitnessProvider.instance.proteinConsumed;
      _proteinGoal = FitnessProvider.instance.proteinGoal;
    });
  }

  void _showActivityRingsModal() {
    AppBottomSheet.show(
      context: context,
      title: 'Daily Activity Breakdown',
      child: Column(
        children: [
          AppListTile(
            leadingIcon: Icons.bolt,
            iconColor: AppColors.ringStreak,
            title: 'Workout Streak',
            subtitle: '8 consecutive active days completed',
            trailing: Text(
              '80%',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                color: AppColors.ringStreak,
              ),
            ),
          ),
          const Divider(height: 1),
          AppListTile(
            leadingIcon: Icons.local_fire_department,
            iconColor: AppColors.ringCalories,
            title: 'Calories Burned',
            subtitle: '320 kcal of 500 kcal daily target',
            trailing: Text(
              '65%',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                color: AppColors.ringCalories,
              ),
            ),
          ),
          const Divider(height: 1),
          AppListTile(
            leadingIcon: Icons.restaurant,
            iconColor: AppColors.ringProtein,
            title: 'Protein Consumed',
            subtitle:
                '${_proteinConsumed.toStringAsFixed(0)}g of ${_proteinGoal.toStringAsFixed(0)}g target',
            trailing: Text(
              '${((_proteinConsumed / _proteinGoal) * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 16,
                color: AppColors.ringProtein,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStepsAnalyticsModal() {
    AppBottomSheet.show(
      context: context,
      title: 'Daily Step Breakdown',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Steps Today: 7,248 / 10,000 steps',
            style: AppTheme.headlineMd.copyWith(
              fontSize: 15,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Distance Covered: 5.2 km  |  Active Walking Time: 58 mins',
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              value: 0.72,
              minHeight: 8,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceElevated,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    final months = [
      'OCT',
      'NOV',
      'DEC',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
    ];
    final dateLabel =
        '${weekdays[now.weekday - 1]}, ${months[(now.month - 1) % 12]} ${now.day}';
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final userName = _profileProvider.name.isNotEmpty
        ? _profileProvider.name
        : 'Athlete';

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: topInset + 16,
          bottom: bottomInset + 130,
          left: 16,
          right: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader.standard(
              title: '$greeting, $userName',
              subtitle: dateLabel,
              userInitials: userName.isNotEmpty
                  ? userName[0].toUpperCase()
                  : 'AG',
              onNotificationsTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              onSettingsTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: 16),
            const DailyMotivationCard(),
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final progress = FitnessProvider.instance.userProgress;
                return AnimatedRankProgressCard(
                  currentRank: progress.currentRank,
                  nextRank: 'Silver',
                  currentXp: progress.totalXP,
                  targetXp: 1000,
                );
              },
            ),
            const SizedBox(height: 14),

            // Bento Layout: Active Protocol + Daily Activity Rings
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: _buildProtocolCard(context)),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 5,
                        child: _buildActivityRingsCard(context),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildProtocolCard(context),
                    const SizedBox(height: 14),
                    _buildActivityRingsCard(context),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // AI Coach Summary Card
            const CoachSummaryCard(),
            const SizedBox(height: 14),

            // Readiness, Recovery & Adaptive Workout Intelligence Section
            Builder(
              builder: (context) {
                final provider = FitnessProvider.instance;
                final recoveryState = provider.recoveryState;
                final recommendation = provider.todaysRecommendation;

                return Column(
                  children: [
                    ReadinessCard(state: provider.trainingState),
                    const SizedBox(height: 14),
                    if (recoveryState?.isDeloadRecommended ?? false) ...[
                      const DeloadAlertCard(),
                      const SizedBox(height: 14),
                    ],
                    RecoveryDashboardCard(state: recoveryState),
                    const SizedBox(height: 14),
                    AdaptiveWorkoutCard(
                      workout: recommendation,
                      onStartWorkout: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkoutSessionScreen(
                              workoutName: recommendation?.title ?? 'Adaptive Workout',
                              workoutId: recommendation?.id ?? 'rec_adaptive_01',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),

            // Responsive Health Metric Section (2-Column Bento Grid on Mobile)
            _buildResponsiveMetricsGrid(context),
            const SizedBox(height: 16),

            // Performance Trend Section Header & Bar Chart
            const SectionHeader(
              title: 'Performance Trend',
              subtitle: '7-day workout volume & intensity',
            ),
            const SizedBox(height: 12),
            _buildPerformanceTrendChart(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolCard(BuildContext context) {
    return AppHeroCard(
      tag: 'ACTIVE PROTOCOL',
      title: 'Leg Day - Hypertrophy',
      subtitle: '45 mins · 320 kcal targeted burn',
      actionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton.secondary(
            label: 'Plan',
            isFullWidth: false,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WeeklyWorkoutPlanScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          AppButton.primary(
            label: 'Start Workout',
            icon: Icons.play_arrow_rounded,
            isFullWidth: false,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkoutSessionScreen(
                    workoutName: 'Leg Day - Hypertrophy',
                    workoutId: 'leg_day_hypertrophy_01',
                  ),
                ),
              );
              if (context.mounted) {
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRingsCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: _showActivityRingsModal,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Daily Activity',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppColors.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, animVal, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(
                        alpha: context.isDarkMode ? 0.25 : 0.1,
                      ),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ProgressRing.activityRings(
                  size: 130,
                  streakProgress: 0.80 * animVal,
                  caloriesProgress: 0.65 * animVal,
                  proteinProgress:
                      ((_proteinConsumed / _proteinGoal) * animVal).clamp(0.0, 1.0),
                  centerChild: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryContainer.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: AppColors.primaryContainer,
                      size: 24,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRingLegend(
                context: context,
                color: AppColors.ringStreak,
                label: 'STREAK',
              ),
              _buildRingLegend(
                context: context,
                color: AppColors.ringCalories,
                label: 'CALORIES',
              ),
              _buildRingLegend(
                context: context,
                color: AppColors.ringProtein,
                label: 'PROTEIN',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRingLegend({
    required BuildContext context,
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTheme.labelCaps.copyWith(
            fontSize: 10,
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }

  /// Responsive Health Metric Bento Section (2-Column Layout on Mobile, 3-Column on Desktop)
  Widget _buildResponsiveMetricsGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final weightCard = MetricCard(
          iconAsset: 'assets/icons/weight.svg',
          iconBgColor: AppColors.primaryContainer,
          iconColor: Colors.white,
          label: 'Weight',
          value: _profileProvider.weight,
          unit: _profileProvider.massUnit,
          subtext: 'vs yesterday',
          badge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '↓ 0.4 kg',
              style: AppTheme.labelCaps.copyWith(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BodyCompositionScreen()),
            );
          },
        );

        final stepsCard = MetricCard(
          iconAsset: 'assets/icons/steps.svg',
          iconBgColor: AppColors.primaryContainer,
          iconColor: Colors.white,
          label: 'Steps',
          value: '7,248',
          unit: '/ 10K',
          progress: 0.72,
          subtext: '72% of goal',
          subtextColor: AppColors.primary,
          onTap: _showStepsAnalyticsModal,
        );

        final waterCard = MetricCard(
          iconAsset: 'assets/icons/water.svg',
          iconBgColor: AppColors.primaryContainer,
          iconColor: Colors.white,
          label: 'Water',
          value: (_waterGlasses * 0.25).toStringAsFixed(1),
          unit: 'L',
          subtext: 'of 2.5 L goal',
          trailingWidget: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              '72%',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          onTap: () {
            setState(() {
              _waterGlasses++;
            });
          },
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: weightCard),
              const SizedBox(width: 12),
              Expanded(child: stepsCard),
              const SizedBox(width: 12),
              Expanded(child: waterCard),
            ],
          );
        }

        // Mobile: 2-column bento grid for clean layout without clipping
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: weightCard),
                const SizedBox(width: 12),
                Expanded(child: stepsCard),
              ],
            ),
            const SizedBox(height: 12),
            waterCard,
          ],
        );
      },
    );
  }

  int _selectedDayIndex = DateTime.now().weekday - 1;

  Widget _buildPerformanceTrendChart(BuildContext context) {
    final todayIndex = DateTime.now().weekday - 1;
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final fullDates = [
      'Jul 28',
      'Jul 29',
      'Jul 30',
      'Jul 31',
      'Aug 1',
      'Aug 2',
      'Aug 3',
    ];
    final fullDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final heights = [0.40, 0.55, 0.78, 0.30, 0.65, 0.85, 0.92];
    final intensities = [40, 55, 78, 30, 65, 85, 92];
    final volumes = ['3,450 kg', '4,800 kg', '6,240 kg', '2,100 kg', '5,400 kg', '7,100 kg', '7,850 kg'];
    final durations = ['35 min', '48 min', '62 min', '25 min', '55 min', '70 min', '75 min'];
    final workouts = [1, 1, 2, 1, 1, 2, 2];

    final selectedIndex = _selectedDayIndex.clamp(0, 6);
    final selectedDayName = fullDays[selectedIndex];
    final selectedDateStr = fullDates[selectedIndex];
    final selectedIntensity = intensities[selectedIndex];
    final selectedVolume = volumes[selectedIndex];
    final selectedDuration = durations[selectedIndex];
    final selectedWorkouts = workouts[selectedIndex];

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Relative Intensity',
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_upward_rounded,
                      size: 13,
                      color: AppColors.primaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '↑ 12% vs last week',
                      style: AppTheme.labelCaps.copyWith(
                        color: context.isDarkMode ? AppColors.primaryContainer : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart with Dynamic Selection, Glows, and Animations
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-Axis Labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: ['100', '75', '50', '25', '0']
                      .map(
                        (val) => Text(
                          val,
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 9,
                            color: context.appTextSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(width: 8),

                // Grid & Bars Stack
                Expanded(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Horizontal Background Grid Lines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          return Divider(
                            height: 1,
                            thickness: 0.8,
                            color: context.appOutlineVariant.withValues(alpha: 0.3),
                          );
                        }),
                      ),

                      // Bars Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final isSelected = i == selectedIndex;
                          final isToday = i == todayIndex;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _selectedDayIndex = i;
                              });
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // White Glow Indicator Dot on Selected Bar
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 250),
                                  opacity: isSelected ? 1.0 : 0.0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryContainer,
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Dynamic Height Animated Bar
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: heights[i]),
                                  duration: Duration(milliseconds: 600 + (i * 80)),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animValue, child) {
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: isSelected ? 24 : 20,
                                      height: 90 * animValue,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: isSelected
                                              ? [
                                                  AppColors.primaryContainer,
                                                  AppColors.primary,
                                                ]
                                              : isToday
                                                  ? [
                                                      context.appPrimary.withValues(alpha: 0.9),
                                                      context.appPrimary.withValues(alpha: 0.5),
                                                    ]
                                                  : [
                                                      context.appPrimary.withValues(alpha: 0.5),
                                                      context.appSurfaceElevated,
                                                    ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primaryContainer.withValues(alpha: 0.6),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),

                                // Day Label Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: isSelected
                                      ? BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(4),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primaryContainer.withValues(alpha: 0.4),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        )
                                      : isToday
                                          ? BoxDecoration(
                                              color: AppColors.primaryContainer.withValues(
                                                alpha: 0.2,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            )
                                          : null,
                                  child: Text(
                                    days[i],
                                    style: AppTheme.labelCaps.copyWith(
                                      fontSize: 10,
                                      fontWeight: (isSelected || isToday)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : isToday
                                              ? AppColors.primaryContainer
                                              : context.appTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Selected Day Insights Panel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.isDarkMode
                    ? AppColors.primaryContainer.withValues(alpha: 0.2)
                    : context.appOutlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$selectedDayName ($selectedDateStr)',
                      style: AppTheme.labelCaps.copyWith(
                        color: AppColors.primaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$selectedIntensity',
                          style: AppTheme.headlineLg.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Relative Intensity',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Volume: $selectedVolume',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Duration: $selectedDuration',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Workouts: $selectedWorkouts',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
