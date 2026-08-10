import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/recommended_workout.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Reusable UI widget presenting today's recommended workout, coach reasoning, exercise preview, and Start button.
class AdaptiveWorkoutCard extends StatelessWidget {
  final RecommendedWorkout? workout;
  final VoidCallback? onStartWorkout;

  const AdaptiveWorkoutCard({
    super.key,
    this.workout,
    this.onStartWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final title = workout?.title ?? 'Upper Push Power & Chest Builder';
    final intensity = workout?.intensity ?? 'heavy';
    final duration = workout?.estimatedDuration ?? 45;
    final reason = workout?.reason ??
        'High readiness detected! Perfect window to drive hypertrophy on upper body push muscle groups.';
    final exercises = workout?.exercises ??
        const ['Incline Dumbbell Bench Press', 'Overhead Press', 'Cable Flyes', 'Triceps Pushdowns'];

    final isDark = context.isDarkMode;

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Recommended Workout",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Text(
                        'Adaptive Planner Engine',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildIntensityBadge(intensity),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.primaryContainer),
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
          const SizedBox(height: 8),
          Text(
            reason,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'EXERCISE PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.appTextSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: exercises.map((ex) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ex,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              label: 'START WORKOUT',
              icon: Icons.play_arrow_rounded,
              onPressed: onStartWorkout ?? () {},
            ),
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
