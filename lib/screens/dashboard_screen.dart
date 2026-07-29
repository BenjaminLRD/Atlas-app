import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/nutrition_service.dart';
import '../data/profile_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/metric_card.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/progress_ring.dart';
import '../widgets/common/section_header.dart';
import 'workout_session_screen.dart';
import 'weekly_workout_plan_screen.dart';
import 'ai_coach_chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    final months = ['OCT', 'NOV', 'DEC', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP'];
    final dateLabel = '${weekdays[now.weekday - 1]}, ${months[(now.month - 1) % 12]} ${now.day}';
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final userName = _profileProvider.name.isNotEmpty ? _profileProvider.name : 'Athlete';

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 56, bottom: 120, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: AppTheme.labelCaps.copyWith(color: context.appTextSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text('$greeting, $userName', style: AppTheme.headlineLgMobile.copyWith(color: context.appTextPrimary)),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AiCoachChatScreen()),
                    );
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bento Layout: Protocol + Activity Rings
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: _buildProtocolCard(context)),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: _buildActivityRingsCard(context)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildProtocolCard(context),
                    const SizedBox(height: 16),
                    _buildActivityRingsCard(context),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // AI Coach Insight Tile
            _buildAiCoachInsightTile(context),
            const SizedBox(height: 20),

            // Health Metric Bento Cards (Weight, Steps, Hydration)
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    icon: Icons.monitor_weight_outlined,
                    iconBgColor: AppColors.errorContainer.withValues(alpha: 0.3),
                    iconColor: AppColors.error,
                    label: 'Weight',
                    value: _profileProvider.weight,
                    unit: _profileProvider.massUnit,
                    badge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-0.4 kg',
                        style: AppTheme.labelCaps.copyWith(color: AppColors.error, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    icon: Icons.directions_walk_rounded,
                    iconBgColor: AppColors.secondaryContainer,
                    iconColor: AppColors.secondary,
                    label: 'Steps',
                    value: '7,248',
                    unit: '/ 10k',
                    progress: 0.72,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    icon: Icons.water_drop_outlined,
                    iconBgColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                    iconColor: AppColors.primary,
                    label: 'Water',
                    value: (_waterGlasses * 0.25).toStringAsFixed(1),
                    unit: 'L',
                    onTap: () {
                      setState(() {
                        _waterGlasses++;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Performance Trend Section
            const SectionHeader(
              title: 'Performance Trend',
              subtitle: '7-day workout volume & intensity',
            ),
            const SizedBox(height: 16),
            _buildPerformanceTrendChart(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.appPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'ACTIVE PROTOCOL',
                  style: AppTheme.labelCaps.copyWith(color: AppColors.onPrimary, fontSize: 10),
                ),
              ),
              const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Leg Day - Hypertrophy',
            style: AppTheme.headlineLg.copyWith(fontSize: 26, color: context.appTextPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('45 mins', style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600, color: context.appTextPrimary)),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Icon(Icons.local_fire_department, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('320 kcal', style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w600, color: context.appTextPrimary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Start Workout',
                  icon: Icons.play_arrow_rounded,
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
              ),
              const SizedBox(width: 12),
              PrimaryButton(
                label: 'Plan',
                isSecondary: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WeeklyWorkoutPlanScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRingsCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Daily Activity', style: AppTheme.headlineMd.copyWith(fontSize: 18, color: context.appTextPrimary)),
          const SizedBox(height: 16),
          ProgressRing.activityRings(
            size: 150,
            streakProgress: 0.80,
            caloriesProgress: 0.65,
            proteinProgress: (_proteinConsumed / _proteinGoal).clamp(0.0, 1.0),
            centerChild: const Icon(Icons.bolt, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRingLegend(context: context, color: AppColors.ringStreak, label: 'STREAK'),
              _buildRingLegend(context: context, color: AppColors.ringCalories, label: 'CALORIES'),
              _buildRingLegend(context: context, color: AppColors.ringProtein, label: 'PROTEIN'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRingLegend({required BuildContext context, required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTheme.labelCaps.copyWith(fontSize: 10, color: context.appTextSecondary)),
      ],
    );
  }

  Widget _buildAiCoachInsightTile(BuildContext context) {
    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AiCoachChatScreen()),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('AI Daily Insight', style: AppTheme.headlineMd.copyWith(fontSize: 16, color: context.appTextPrimary)),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.appTextSecondary),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '"Recovery metrics look optimal today. Focus on controlled eccentrics during your squats to maximize tension and drive hypertrophy."',
                  style: AppTheme.bodySm.copyWith(
                    fontStyle: FontStyle.italic,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrendChart(BuildContext context) {
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final heights = [0.40, 0.55, 0.78, 0.30, 0.65, 0.85, 0.92];

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly Relative Intensity', style: AppTheme.bodySm.copyWith(color: context.appTextSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('+12% THIS WEEK', style: AppTheme.labelCaps.copyWith(color: AppColors.primary, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
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
                      width: 24,
                      height: 100 * heights[i],
                      decoration: BoxDecoration(
                        color: isToday ? context.appPrimary : context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[i],
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        color: isToday ? context.appPrimary : context.appTextSecondary,
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
