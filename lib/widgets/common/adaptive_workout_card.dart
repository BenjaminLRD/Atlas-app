import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/recommended_workout.dart';
import '../../screens/workout_detail_screen.dart';
import '../../screens/workout_session_screen.dart';
import '../../services/workout_planner_service.dart';
import '../../providers/fitness_provider.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Reusable UI widget presenting today's recommended workout summary card on Dashboard.
class AdaptiveWorkoutCard extends StatelessWidget {
  final RecommendedWorkout? workout;
  final VoidCallback? onStartWorkout;
  final VoidCallback? onTap;

  const AdaptiveWorkoutCard({
    super.key,
    this.workout,
    this.onStartWorkout,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeWorkout =
        workout ?? WorkoutPlannerService.instance.getTodayRecommendation();

    final title = activeWorkout.title;
    final intensity = activeWorkout.intensity;
    final duration = activeWorkout.estimatedDuration;

    void handleTap() {
      if (onTap != null) {
        onTap!();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkoutDetailScreen(workout: activeWorkout),
          ),
        );
      }
    }

    return AppCard(
      onTap: handleTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Icon, Title, Subtitle & Intensity Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Recommended Workout",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    Text(
                      'Adaptive Planner Engine',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildIntensityBadge(intensity),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Workout Title & Duration
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: AppColors.primaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$duration mins',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Why this recommendation? Transparent Reasoning
          Builder(
            builder: (context) {
              final insightBullets = FitnessProvider.instance.recoveryInsight.reasoningBullets;
              final bullets = insightBullets.isNotEmpty
                  ? insightBullets
                  : const [
                      'Scheduled push progressive overload split',
                      'Targeting hypertrophy on chest, delts & triceps',
                    ];

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.appSurfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.insights_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Why this recommendation?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...bullets.take(3).map(
                          (bullet) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '✓ ',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.appTextSecondary,
                                    ),
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
          ),
          const SizedBox(height: 14),

          // 4. Action Buttons Row: View Details & Start Workout
          Row(
            children: [
              Expanded(
                flex: 5,
                child: AppButton.outlined(
                  label: 'Details',
                  icon: Icons.info_outline_rounded,
                  height: 42,
                  onPressed: handleTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: AppButton.primary(
                  label: 'Start Workout',
                  icon: Icons.play_arrow_rounded,
                  height: 42,
                  onPressed:
                      onStartWorkout ??
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkoutSessionScreen(
                              workoutName: activeWorkout.title,
                              workoutId: activeWorkout.id,
                              initialExercises:
                                  activeWorkout.structuredExercises.isNotEmpty
                                  ? activeWorkout.structuredExercises
                                  : (activeWorkout.exercises.isNotEmpty
                                        ? activeWorkout.exercises
                                              .map((e) => {'name': e})
                                              .toList()
                                        : null),
                            ),
                          ),
                        );
                      },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityBadge(String intensity) {
    Color color = AppColors.primaryContainer;
    String text = 'MODERATE';

    switch (intensity.toLowerCase()) {
      case 'heavy':
        color = Colors.red;
        text = 'HEAVY';
        break;
      case 'moderate':
        color = AppColors.primaryContainer;
        text = 'MODERATE';
        break;
      case 'light':
        color = Colors.blue;
        text = 'LIGHT';
        break;
      case 'recovery':
      default:
        color = Colors.green;
        text = 'RECOVERY';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
