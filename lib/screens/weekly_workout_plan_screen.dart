import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../models/user_equipment_profile.dart';
import '../services/workout_generator_engine.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_chip.dart';
import '../widgets/common/app_header.dart';
import '../widgets/exercise/muscle_map_card.dart';
import 'workout_session_screen.dart';

class DailyPlan {
  final String dayName;
  final String date;
  final String title;
  final String duration;
  final String muscleGroups;
  final List<String> exercises;
  final List<Map<String, dynamic>> structuredExercises;
  final bool isToday;

  /// Generator focus key for this day (for example `legs`, `pull`, `recovery`).
  final String focus;

  /// Target session length in minutes from the plan template.
  final int durationMinutes;

  /// True for days the plan marks as rest.
  final bool isRestDay;

  const DailyPlan({
    required this.dayName,
    required this.date,
    required this.title,
    required this.duration,
    required this.muscleGroups,
    required this.exercises,
    this.structuredExercises = const [],
    this.isToday = false,
    this.focus = '',
    this.durationMinutes = 0,
    this.isRestDay = false,
  });
}

/// Builds this week's plan (Monday to Sunday) from the template below and the
/// workout generator, using the user's saved equipment profile. Shared by the
/// weekly plan screen and the Workouts tab so both show the same sessions.
List<DailyPlan> buildWeeklyPlans({
  DateTime? now,
  UserEquipmentProfile? profile,
  WorkoutGeneratorEngine? engine,
}) {
  final today = now ?? DateTime.now();
  final currentWeekday = today.weekday; // 1 = Monday, 7 = Sunday
  final monday = today.subtract(Duration(days: currentWeekday - 1));
  final generator = engine ?? WorkoutGeneratorEngine();
  final equipment = profile ?? LocalStorage.getUserEquipmentProfile();

  final daysConfig = [
    {
      'dayName': 'MONDAY',
      'title': 'Lower Body Technical',
      'focus': 'legs',
      'muscleGroups': 'Quads, Glutes & Calves',
      'duration': '45 mins',
      'durationInt': 45,
    },
    {
      'dayName': 'TUESDAY',
      'title': 'Active Recovery: Zone 2',
      'focus': 'recovery',
      'muscleGroups': 'Cardio / Full Body',
      'duration': '30 mins',
      'durationInt': 30,
    },
    {
      'dayName': 'WEDNESDAY',
      'title': 'Upper Body Flow & Power',
      'focus': 'push',
      'muscleGroups': 'Chest, Back, Arms',
      'duration': '65 mins',
      'durationInt': 65,
    },
    {
      'dayName': 'THURSDAY',
      'isRest': true,
      'title': 'Rest & Core Stability',
      'focus': 'core',
      'muscleGroups': 'Core & Mobility',
      'duration': '25 mins',
      'durationInt': 25,
    },
    {
      'dayName': 'FRIDAY',
      'title': 'Pull & Posterior Chain',
      'focus': 'pull',
      'muscleGroups': 'Back, Biceps, Lats',
      'duration': '60 mins',
      'durationInt': 60,
    },
    {
      'dayName': 'SATURDAY',
      'title': 'Aerobic Endurance & HIIT',
      'focus': 'cardio',
      'muscleGroups': 'Cardiovascular',
      'duration': '45 mins',
      'durationInt': 45,
    },
    {
      'dayName': 'SUNDAY',
      'isRest': true,
      'title': 'Rest & Repair',
      'focus': 'recovery',
      'muscleGroups': 'Total Rest & Flexibility',
      'duration': '20 mins',
      'durationInt': 20,
    },
  ];

  final plans = <DailyPlan>[];
  for (int i = 0; i < daysConfig.length; i++) {
    final cfg = daysConfig[i];
    final dayDate = monday.add(Duration(days: i));

    final structured = generator.generateExercisesForWorkout(
      workoutName: cfg['title'] as String,
      focus: cfg['focus'] as String,
      durationMinutes: cfg['durationInt'] as int,
      equipmentProfile: equipment,
    );

    final exerciseDescriptions = structured.map((ex) {
      final name = ex['name']?.toString() ?? 'Exercise';
      final sets = (ex['sets'] as List?)?.length ?? 3;
      final reps = ex['reps'] ?? 10;
      return '$name ($sets sets x $reps reps)';
    }).toList();

    plans.add(
      DailyPlan(
        dayName: cfg['dayName'] as String,
        date: dayDate.day.toString(),
        title: cfg['title'] as String,
        duration: cfg['duration'] as String,
        muscleGroups: cfg['muscleGroups'] as String,
        exercises: exerciseDescriptions,
        structuredExercises: structured,
        isToday: (i + 1) == currentWeekday,
        focus: cfg['focus'] as String,
        durationMinutes: cfg['durationInt'] as int,
        isRestDay: cfg['isRest'] == true,
      ),
    );
  }
  return plans;
}

class WeeklyWorkoutPlanScreen extends StatefulWidget {
  const WeeklyWorkoutPlanScreen({super.key});

  @override
  State<WeeklyWorkoutPlanScreen> createState() =>
      _WeeklyWorkoutPlanScreenState();
}

class _WeeklyWorkoutPlanScreenState extends State<WeeklyWorkoutPlanScreen> {
  late List<DailyPlan> _weeklyPlans;
  int _expandedIndex = 0;

  @override
  void initState() {
    super.initState();
    _generateWeeklySchedule();
  }

  void _generateWeeklySchedule() {
    _weeklyPlans = buildWeeklyPlans();
    final todayIndex = _weeklyPlans.indexWhere((p) => p.isToday);
    _expandedIndex = todayIndex < 0 ? 0 : todayIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.back(
        title: 'Weekly Workout Plan',
        subtitle: 'HYBRID STRENGTH II',
        onBackTap: () => Navigator.maybePop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'HYBRID STRENGTH II',
              style: AppTheme.labelCaps.copyWith(
                color: AppColors.tertiary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Weekly Schedule',
              style: AppTheme.headlineLgMobile.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Click daily cards below to reveal specific exercises, goals, and training guidelines.',
              style: AppTheme.bodyMd.copyWith(color: context.appTextSecondary),
            ),
            const SizedBox(height: 24),

            // Schedule Cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _weeklyPlans.length,
              itemBuilder: (context, index) {
                final plan = _weeklyPlans[index];
                final isExpanded = _expandedIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    borderColor: plan.isToday ? AppColors.primary : null,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        // Header row
                        InkWell(
                          onTap: () {
                            setState(() {
                              _expandedIndex = isExpanded ? -1 : index;
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: Column(
                                    children: [
                                      Text(
                                        plan.dayName.substring(0, 3),
                                        style: AppTheme.labelCaps.copyWith(
                                          color: plan.isToday
                                              ? AppColors.primary
                                              : AppColors.tertiary,
                                          fontSize: 10,
                                          fontWeight: plan.isToday
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        plan.date,
                                        style: AppTheme.headlineMd.copyWith(
                                          fontSize: 20,
                                          color: plan.isToday
                                              ? AppColors.primary
                                              : context.appTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 36,
                                  width: 1,
                                  color: context.appOutlineVariant,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        plan.title,
                                        style: AppTheme.bodyMd.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: context.appTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Target: ${plan.muscleGroups}',
                                        style: AppTheme.bodySm.copyWith(
                                          color: context.appTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (plan.isToday)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: AppChip.primary(
                                            label: 'TODAY',
                                          ),
                                        ),
                                      Text(
                                        plan.duration,
                                        style: AppTheme.bodySm.copyWith(
                                          color: context.appTextSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: plan.isToday
                                      ? AppColors.primary
                                      : AppColors.outline,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expanded exercise list
                        if (isExpanded)
                          Container(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 20,
                            ),
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Divider(
                                  height: 1,
                                  color: context.appOutlineVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'EXERCISE SEQUENCE',
                                  style: AppTheme.labelCaps.copyWith(
                                    fontSize: 9,
                                    color: AppColors.tertiary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(plan.exercises.length, (
                                  exIdx,
                                ) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            plan.exercises[exIdx],
                                            style: AppTheme.bodyMd.copyWith(
                                              color: context.appTextPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (plan.structuredExercises.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  AppButton.outlined(
                                    key: Key('plan_muscle_map_${plan.dayName}'),
                                    label: 'View muscle map',
                                    icon: Icons.accessibility_new_rounded,
                                    onPressed: () => MuscleMapSheet.show(
                                      context,
                                      workoutName: plan.title,
                                      exercises: plan.structuredExercises,
                                    ),
                                  ),
                                ],
                                if (plan.isToday) ...[
                                  const SizedBox(height: 16),
                                  AppButton.primary(
                                    label: 'Start Workout',
                                    icon: Icons.play_arrow,
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              WorkoutSessionScreen(
                                                workoutName: plan.title,
                                                workoutId:
                                                    'weekly_plan_${plan.dayName.toLowerCase()}',
                                                initialExercises:
                                                    plan
                                                        .structuredExercises
                                                        .isNotEmpty
                                                    ? plan.structuredExercises
                                                    : plan.exercises
                                                          .map(
                                                            (e) => {
                                                              'name': e
                                                                  .split('(')
                                                                  .first
                                                                  .split('-')
                                                                  .first
                                                                  .trim(),
                                                            },
                                                          )
                                                          .toList(),
                                              ),
                                        ),
                                      );
                                      if (context.mounted) {
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
