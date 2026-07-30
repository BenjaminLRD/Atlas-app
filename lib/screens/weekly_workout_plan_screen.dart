import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_chip.dart';
import '../widgets/common/app_header.dart';
import 'workout_session_screen.dart';

class DailyPlan {
  final String dayName;
  final String date;
  final String title;
  final String duration;
  final String muscleGroups;
  final List<String> exercises;
  final bool isToday;

  const DailyPlan({
    required this.dayName,
    required this.date,
    required this.title,
    required this.duration,
    required this.muscleGroups,
    required this.exercises,
    this.isToday = false,
  });
}

class WeeklyWorkoutPlanScreen extends StatefulWidget {
  const WeeklyWorkoutPlanScreen({super.key});

  @override
  State<WeeklyWorkoutPlanScreen> createState() =>
      _WeeklyWorkoutPlanScreenState();
}

class _WeeklyWorkoutPlanScreenState extends State<WeeklyWorkoutPlanScreen> {
  final List<DailyPlan> _weeklyPlans = const [
    DailyPlan(
      dayName: 'MONDAY',
      date: '14',
      title: 'Lower Body Technical',
      duration: '45 mins',
      muscleGroups: 'Quads, Glutes & Calves',
      exercises: [
        'Goblet Squats (4 sets x 10 reps)',
        'Leg Press (3 sets x 15 reps)',
        'Leg Extensions (3 sets x 15 reps)',
        'Calf Raises (4 sets x 20 reps)',
      ],
    ),
    DailyPlan(
      dayName: 'TUESDAY',
      date: '15',
      title: 'Active Recovery: Zone 2',
      duration: '30 mins',
      muscleGroups: 'Cardio / Full Body',
      exercises: [
        'Light Cycling (Zone 2 HR) - 20 mins',
        'Dynamic Mobility Stretching - 10 mins',
      ],
    ),
    DailyPlan(
      dayName: 'WEDNESDAY',
      date: '16',
      title: 'Upper Body Flow & Power',
      duration: '65 mins',
      muscleGroups: 'Chest, Back, Arms',
      exercises: [
        'Barbell Bench Press (4 sets x 8 reps)',
        'Bent-over Rows (4 sets x 10 reps)',
        'Incline Dumbbell Flys (3 sets x 12 reps)',
        'Tricep Pushdowns (3 sets x 15 reps)',
        'Bicep Hammer Curls (3 sets x 12 reps)',
      ],
      isToday: true,
    ),
    DailyPlan(
      dayName: 'THURSDAY',
      date: '17',
      title: 'Rest & Mindfulness',
      duration: '0 mins',
      muscleGroups: 'Active Rest / Recovery',
      exercises: [
        'Deep Breathing Meditation - 10 mins',
        'Foam Rolling & Myofascial Release - 15 mins',
      ],
    ),
    DailyPlan(
      dayName: 'FRIDAY',
      date: '18',
      title: 'Full Body Integrative',
      duration: '60 mins',
      muscleGroups: 'Compound Movements',
      exercises: [
        'Deadlifts (4 sets x 6 reps)',
        'Overhead Press (4 sets x 8 reps)',
        'Pull-ups (4 sets to Failure)',
        'Hanging Knee Raises (3 sets x 15 reps)',
      ],
    ),
    DailyPlan(
      dayName: 'SATURDAY',
      date: '19',
      title: 'Aerobic Endurance',
      duration: '50 mins',
      muscleGroups: 'Cardiovascular',
      exercises: [
        'Incline Treadmill Walk / Run - 40 mins',
        'Core Plank Block - 10 mins',
      ],
    ),
    DailyPlan(
      dayName: 'SUNDAY',
      date: '20',
      title: 'Rest & Repair',
      duration: '0 mins',
      muscleGroups: 'Total Rest',
      exercises: ['Light Walk - 20 mins', 'Passive Stretching - 15 mins'],
    ),
  ];

  // Set today (Wednesday) as initially expanded
  int _expandedIndex = 2;

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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (plan.isToday)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: AppChip.primary(label: 'TODAY'),
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
                                if (plan.isToday) ...[
                                  const SizedBox(height: 16),
                                  AppButton.primary(
                                    label: 'Start Workout',
                                    icon: Icons.play_arrow,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const WorkoutSessionScreen(),
                                        ),
                                      );
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
