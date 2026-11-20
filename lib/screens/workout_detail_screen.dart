import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/recommended_workout.dart';
import '../services/workout_generator_engine.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/workout/ai_verified_workout_card.dart';
import 'workout_session_screen.dart';

/// Dedicated detail screen for viewing recommended workout information, exercises, and launching the workout.
class WorkoutDetailScreen extends StatelessWidget {
  final RecommendedWorkout workout;

  const WorkoutDetailScreen({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final muscleText = workout.focusMuscleGroups.isNotEmpty
        ? workout.focusMuscleGroups.join(' • ')
        : 'Upper Body Push';

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.back(
        title: workout.title,
        onBackTap: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Summary Banner
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  workout.title,
                                  style: AppTheme.headlineMd.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: context.appTextPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildIntensityBadge(workout.intensity),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: AppColors.primaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${workout.estimatedDuration} mins',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.fitness_center_rounded,
                                size: 16,
                                color: context.appTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  muscleText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.bodySm.copyWith(
                                    fontSize: 13,
                                    color: context.appTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 2. AI Verified Workout Intelligence Card
                    AiVerifiedWorkoutCard(
                      coachNotes: workout.reason.isNotEmpty
                          ? workout.reason
                          : 'Your recovery readiness is optimal today. Full volume programmed with progressive stimulus.',
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 3. Exercise Preview List
                    Text(
                      'EXERCISE PREVIEW',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.appTextSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (workout.structuredExercises.isNotEmpty)
                      Column(
                        children: workout.structuredExercises.map((ex) {
                          final exName = ex['name']?.toString() ?? 'Exercise';
                          final sets = (ex['sets'] as List?)?.length ?? 3;
                          final reps = ex['reps'] ?? 10;
                          final setsReps = '$sets sets • $reps reps';
                          return _buildExerciseListItem(
                            context,
                            exName,
                            setsReps,
                          );
                        }).toList(),
                      )
                    else if (workout.exercises.isNotEmpty)
                      Column(
                        children: workout.exercises.asMap().entries.map((
                          entry,
                        ) {
                          final idx = entry.key;
                          final exName = entry.value;
                          final setsReps = _getSetsRepsForIndex(idx);
                          return _buildExerciseListItem(
                            context,
                            exName,
                            setsReps,
                          );
                        }).toList(),
                      )
                    else
                      _buildFallbackExerciseList(context),
                  ],
                ),
              ),
            ),

            // 4. Fixed Bottom Action Button
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.appSurface,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: 'START WORKOUT',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutSessionScreen(
                          workoutName: workout.title,
                          workoutId: workout.id.isNotEmpty
                              ? workout.id
                              : 'custom_session_${DateTime.now().millisecondsSinceEpoch}',
                          initialExercises:
                              workout.structuredExercises.isNotEmpty
                              ? workout.structuredExercises
                              : (workout.exercises.isNotEmpty
                                    ? workout.exercises
                                          .map((e) => {'name': e})
                                          .toList()
                                    : null),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackExerciseList(BuildContext context) {
    final generated = WorkoutGeneratorEngine().generateExercisesForWorkout(
      workoutName: workout.title,
      focus: workout.focusMuscleGroups.isNotEmpty
          ? workout.focusMuscleGroups.first
          : null,
    );
    return Column(
      children: generated.map((ex) {
        final name = ex['name']?.toString() ?? 'Exercise';
        final sets = (ex['sets'] as List?)?.length ?? 3;
        final reps = ex['reps'] ?? 10;
        return _buildExerciseListItem(context, name, '$sets sets • $reps reps');
      }).toList(),
    );
  }

  String _getSetsRepsForIndex(int index) {
    switch (index % 4) {
      case 0:
        return '4 sets • 8-12 reps';
      case 1:
        return '4 sets • 8-12 reps';
      case 2:
        return '3 sets • 10-15 reps';
      case 3:
      default:
        return '3 sets • 10-15 reps';
    }
  }

  Widget _buildExerciseListItem(
    BuildContext context,
    String name,
    String setsReps,
  ) {
    final isDark = context.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
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
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  setsReps,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
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
