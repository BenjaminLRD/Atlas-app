import '../models/adaptive_workout_plan.dart';
import '../models/recommended_workout.dart';
import '../models/training_state.dart';
import '../models/user_goal.dart';
import '../models/workout_history.dart';

/// Central service generating adaptive workout plans and real-time daily workout recommendations.
class WorkoutPlannerService {
  static WorkoutPlannerService? _instance;

  WorkoutPlannerService();

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static WorkoutPlannerService get instance {
    _instance ??= WorkoutPlannerService();
    return _instance!;
  }

  /// Generate a full adaptive workout plan based on user goals and training state.
  AdaptiveWorkoutPlan generatePlan({
    UserGoal? goal,
    TrainingState? trainingState,
    List<WorkoutHistory>? workoutHistory,
  }) {
    final now = DateTime.now();
    final goalType = goal?.goalType.name ?? 'build_muscle';
    final fitnessLevel = goal?.fitnessLevel.name ?? 'intermediate';

    final sessions = [
      getTodayRecommendation(
        goal: goal,
        trainingState: trainingState,
        workoutHistory: workoutHistory,
      ),
      const RecommendedWorkout(
        id: 'rec_sess_2',
        title: 'Pull & Core Hypertrophy',
        focusMuscleGroups: ['Back', 'Biceps', 'Core'],
        intensity: 'moderate',
        exercises: ['Lat Pulldowns', 'Barbell Rows', 'Hammer Curls', 'Hanging Leg Raises'],
        reason: 'Targeting pull muscle groups to allow pushing muscle recovery.',
        estimatedDuration: 45,
      ),
      const RecommendedWorkout(
        id: 'rec_sess_3',
        title: 'Lower Body Strength',
        focusMuscleGroups: ['Quadriceps', 'Hamstrings', 'Glutes'],
        intensity: 'heavy',
        exercises: ['Barbell Squats', 'Romanian Deadlifts', 'Leg Press', 'Calf Raises'],
        reason: 'Leg day focus aligned with weekly progressive overload targets.',
        estimatedDuration: 50,
      ),
    ];

    return AdaptiveWorkoutPlan(
      id: 'plan_${now.millisecondsSinceEpoch}',
      goalType: goalType,
      fitnessLevel: fitnessLevel,
      weeklySchedule: const ['Monday', 'Wednesday', 'Friday', 'Saturday'],
      sessions: sessions,
      generatedAt: now,
      lastModified: now,
    );
  }

  /// Generate today's specific recommended workout based on readiness, fatigue, and muscle recovery.
  RecommendedWorkout getTodayRecommendation({
    UserGoal? goal,
    TrainingState? trainingState,
    List<WorkoutHistory>? workoutHistory,
  }) {
    final readiness = trainingState?.readinessScore ?? 80;
    final fatigue = trainingState?.fatigueScore ?? 30;
    final primaryGoal = goal?.goalType.name.toLowerCase() ?? 'build_muscle';

    // 1. Check High Fatigue / Low Readiness -> Recovery or Rest recommendation
    if (fatigue > 65 || readiness < 45) {
      return const RecommendedWorkout(
        id: 'rec_recovery',
        title: 'Active Mobility & Restorative Core',
        focusMuscleGroups: ['Core', 'Flexibility'],
        intensity: 'recovery',
        exercises: ['Cat-Cow Stretch', 'Thoracic Spine Openers', 'Plank Hold', 'Child Pose'],
        reason: 'High fatigue detected. A light mobility session will optimize recovery for your next heavy workout.',
        estimatedDuration: 25,
      );
    }

    if (readiness < 60) {
      return const RecommendedWorkout(
        id: 'rec_light',
        title: 'Deload Conditioning & Stability',
        focusMuscleGroups: ['Full Body', 'Cardio'],
        intensity: 'light',
        exercises: ['Incline Treadmill Walk', 'Kettlebell Swings', 'Face Pulls', 'Bird-Dogs'],
        reason: 'Moderate readiness. A deload session builds endurance while keeping fatigue under control.',
        estimatedDuration: 35,
      );
    }

    // 2. Check 48-hour recent workout muscle groups to avoid overtraining
    final recentTrained = _getRecentlyTrainedMuscles(workoutHistory);

    // 3. High Readiness -> Goal-aligned Session
    if (primaryGoal.contains('weight') || primaryGoal.contains('fat')) {
      return RecommendedWorkout(
        id: 'rec_hiit',
        title: 'Metabolic Fat-Burn & Conditioning',
        focusMuscleGroups: recentTrained.contains('Legs') ? ['Upper Body', 'Cardio'] : ['Full Body', 'Cardio'],
        intensity: readiness >= 80 ? 'heavy' : 'moderate',
        exercises: const ['Dumbbell Thrusters', 'Burpees', 'Mountain Climbers', 'Rowing Ergometer'],
        reason: 'Optimized for high calorie burn and cardiovascular conditioning.',
        estimatedDuration: 40,
      );
    }

    if (primaryGoal.contains('strength')) {
      return RecommendedWorkout(
        id: 'rec_strength',
        title: recentTrained.contains('Chest') ? 'Deadlift & Posterior Chain Power' : 'Heavy Bench Press & Upper Power',
        focusMuscleGroups: recentTrained.contains('Chest') ? ['Back', 'Hamstrings'] : ['Chest', 'Triceps', 'Shoulders'],
        intensity: 'heavy',
        exercises: recentTrained.contains('Chest')
            ? const ['Conventional Deadlifts', 'Barbell Bent-Over Rows', 'Farmer Carries']
            : const ['Barbell Bench Press', 'Incline Dumbbell Press', 'Weighted Dips'],
        reason: 'High readiness detected! Maximizing maximal strength output on core compound lifts.',
        estimatedDuration: 50,
      );
    }

    // Default: Muscle Hypertrophy
    final isPushTrained = recentTrained.contains('Chest') || recentTrained.contains('Shoulders');

    return RecommendedWorkout(
      id: 'rec_hypertrophy',
      title: isPushTrained ? 'Pull Hypertrophy & Bicep Builder' : 'Upper Push Power & Chest Builder',
      focusMuscleGroups: isPushTrained ? ['Back', 'Biceps'] : ['Chest', 'Shoulders', 'Triceps'],
      intensity: readiness >= 80 ? 'heavy' : 'moderate',
      exercises: isPushTrained
          ? const ['Lat Pulldowns', 'Seated Cable Rows', 'EZ-Bar Preacher Curls', 'Face Pulls']
          : const ['Incline Dumbbell Bench Press', 'Overhead Press', 'Cable Flyes', 'Triceps Pushdowns'],
      reason: isPushTrained
          ? 'Upper push trained recently. Switching to pull muscle groups for balanced development.'
          : 'High readiness! Perfect window to drive hypertrophy on upper body push muscle groups.',
      estimatedDuration: 45,
    );
  }

  Set<String> _getRecentlyTrainedMuscles(List<WorkoutHistory>? history) {
    if (history == null || history.isEmpty) return {};

    final now = DateTime.now();
    final recent = history
        .where((w) => now.difference(w.dateCompleted).inHours < 48)
        .toList();

    final muscles = <String>{};
    for (final w in recent) {
      final name = w.workoutName.toLowerCase();
      if (name.contains('bench') || name.contains('chest') || name.contains('push')) {
        muscles.add('Chest');
        muscles.add('Triceps');
      }
      if (name.contains('leg') || name.contains('squat') || name.contains('deadlift')) {
        muscles.add('Legs');
      }
      if (name.contains('back') || name.contains('pull') || name.contains('row')) {
        muscles.add('Back');
      }
    }
    return muscles;
  }
}
