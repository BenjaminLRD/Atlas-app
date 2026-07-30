import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/nutrition_service.dart';
import '../data/profile_provider.dart';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final NutritionService _nutritionService;
  late final ProfileProvider _profileProvider;

  double _proteinConsumed = 0.0;
  double _proteinGoal = 140.0;
  int _waterGlasses = 7;

  @override
  void initState() {
    super.initState();
    _nutritionService = AppDependencies.instance.nutritionService;
    _profileProvider = AppDependencies.instance.profileProvider;
    _profileProvider.addListener(_onProfileChanged);
    _loadState();
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  void _loadState() {
    setState(() {
      _proteinConsumed = _nutritionService.getProteinConsumed();
      _proteinGoal = _nutritionService.getProteinGoal();
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkoutSessionScreen(
                    workoutName: 'Leg Day - Hypertrophy',
                    workoutId: 'leg_day_hypertrophy_01',
                  ),
                ),
              );
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
          Text(
            'Daily Activity',
            style: AppTheme.headlineMd.copyWith(
              fontSize: 16,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ProgressRing.activityRings(
            size: 130,
            streakProgress: 0.80,
            caloriesProgress: 0.65,
            proteinProgress: (_proteinConsumed / _proteinGoal).clamp(0.0, 1.0),
            centerChild: const Icon(
              Icons.bolt,
              color: AppColors.primary,
              size: 26,
            ),
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
          icon: Icons.monitor_weight_outlined,
          iconBgColor: AppColors.primaryContainer.withValues(alpha: 0.2),
          iconColor: AppColors.primary,
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
          icon: Icons.directions_walk_rounded,
          iconBgColor: AppColors.secondaryContainer.withValues(alpha: 0.4),
          iconColor: AppColors.secondary,
          label: 'Steps',
          value: '7,248',
          unit: '/ 10K',
          progress: 0.72,
          subtext: '72% of goal',
          subtextColor: AppColors.primary,
          onTap: _showStepsAnalyticsModal,
        );

        final waterCard = MetricCard(
          icon: Icons.water_drop_outlined,
          iconBgColor: AppColors.primaryContainer.withValues(alpha: 0.2),
          iconColor: AppColors.primary,
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

  Widget _buildPerformanceTrendChart(BuildContext context) {
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final heights = [0.40, 0.55, 0.78, 0.30, 0.65, 0.85, 0.92];

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
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+12% THIS WEEK',
                      style: AppTheme.labelCaps.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = i == 6;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 22,
                      height: 85 * heights[i],
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isToday
                              ? [
                                  AppColors.primary,
                                  AppColors.primary.withValues(alpha: 0.6),
                                ]
                              : [
                                  context.appPrimary.withValues(alpha: 0.75),
                                  context.appSurfaceElevated,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: isToday
                          ? BoxDecoration(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.25,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      child: Text(
                        days[i],
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isToday
                              ? AppColors.primary
                              : context.appTextSecondary,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
