import '../data/local_storage.dart';
import '../models/adaptive_workout_plan.dart';
import '../models/recommended_workout.dart';
import '../models/training_state.dart';
import '../models/user_equipment_profile.dart';
import '../models/user_goal.dart';
import '../models/workout_history.dart';
import 'ai/workout_intelligence_engine.dart';
import 'workout_generator_engine.dart';
import 'workout_validation_engine.dart';

/// Central service generating adaptive workout plans and real-time daily workout recommendations
/// backed strictly by WorkoutGeneratorEngine, WorkoutValidationEngine, and WorkoutIntelligenceEngine.
class WorkoutPlannerService {
  static WorkoutPlannerService? _instance;

  final WorkoutGeneratorEngine _generatorEngine;
  final WorkoutValidationEngine _validationEngine;
  final WorkoutIntelligenceEngine _intelligenceEngine;

  WorkoutPlannerService({
    WorkoutGeneratorEngine? generatorEngine,
    WorkoutValidationEngine? validationEngine,
    WorkoutIntelligenceEngine? intelligenceEngine,
  }) : _generatorEngine = generatorEngine ?? WorkoutGeneratorEngine(),
       _validationEngine = validationEngine ?? const WorkoutValidationEngine(),
       _intelligenceEngine = intelligenceEngine ?? WorkoutIntelligenceEngine();

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
    UserEquipmentProfile? equipmentProfile,
  }) {
    final now = DateTime.now();
    final goalType = goal?.goalType.name ?? 'build_muscle';
    final fitnessLevel = goal?.fitnessLevel.name ?? 'intermediate';
    final profile = equipmentProfile ?? LocalStorage.getUserEquipmentProfile();

    final sessions = [
      getTodayRecommendation(
        goal: goal,
        trainingState: trainingState,
        workoutHistory: workoutHistory,
        equipmentProfile: profile,
        experienceLevel: fitnessLevel,
      ),
      _buildGeneratedRecommendation(
        id: 'rec_sess_2',
        title: 'Pull & Core Hypertrophy',
        focusKey: 'pull',
        focusMuscleGroups: ['Back', 'Biceps', 'Core'],
        intensity: 'moderate',
        goalKey: goalType,
        duration: 45,
        reason:
            'Targeting pull muscle groups to allow pushing muscle recovery.',
        equipmentProfile: profile,
        workoutHistory: workoutHistory,
        experienceLevel: fitnessLevel,
      ),
      _buildGeneratedRecommendation(
        id: 'rec_sess_3',
        title: 'Lower Body Strength',
        focusKey: 'legs',
        focusMuscleGroups: ['Quadriceps', 'Hamstrings', 'Glutes'],
        intensity: 'heavy',
        goalKey: goalType,
        duration: 50,
        reason:
            'Leg day focus aligned with weekly progressive overload targets.',
        equipmentProfile: profile,
        workoutHistory: workoutHistory,
        experienceLevel: fitnessLevel,
      ),
      _buildGeneratedRecommendation(
        id: 'rec_sess_4',
        title: 'Upper Body Power',
        focusKey: 'upper',
        focusMuscleGroups: ['Chest', 'Back', 'Shoulders'],
        intensity: 'moderate',
        goalKey: goalType,
        duration: 45,
        reason: 'Full upper body technical hypertrophy and stability volume.',
        equipmentProfile: profile,
        workoutHistory: workoutHistory,
        experienceLevel: fitnessLevel,
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
    UserEquipmentProfile? equipmentProfile,
    String? experienceLevel,
    int? durationMinutes,
  }) {
    final readiness = trainingState?.readinessScore ?? 80;
    final fatigue = trainingState?.fatigueScore ?? 30;
    final primaryGoal = goal?.goalType.name.toLowerCase() ?? 'build_muscle';
    final level = experienceLevel ?? goal?.fitnessLevel.name ?? 'intermediate';
    final profile = equipmentProfile ?? LocalStorage.getUserEquipmentProfile();

    // 1. Check High Fatigue / Low Readiness -> Recovery or Rest recommendation
    if (fatigue > 65 || readiness < 45) {
      return _buildGeneratedRecommendation(
        id: 'rec_recovery',
        title: 'Active Mobility & Restorative Core',
        focusKey: 'recovery',
        focusMuscleGroups: ['Core', 'Flexibility'],
        intensity: 'recovery',
        goalKey: 'recovery',
        duration: durationMinutes ?? 25,
        reason:
            'High fatigue detected. A light mobility session will optimize recovery for your next heavy workout.',
        equipmentProfile: profile,
        workoutHistory: workoutHistory,
        experienceLevel: level,
      );
    }

    if (readiness < 60) {
      return _buildGeneratedRecommendation(
        id: 'rec_light',
        title: 'Deload Conditioning & Stability',
        focusKey: 'cardio',
        focusMuscleGroups: ['Full Body', 'Cardio'],
        intensity: 'light',
        goalKey: 'endurance',
        duration: durationMinutes ?? 35,
        reason:
            'Moderate readiness. A deload session builds endurance while keeping fatigue under control.',
        equipmentProfile: profile,
        workoutHistory: workoutHistory,
        experienceLevel: level,
      );
    }

    // 2. Check 48-hour recent workout muscle groups to avoid overtraining
    final recentTrained = _getRecentlyTrainedMuscles(workoutHistory);

    // 3. High Readiness -> Goal-aligned Session
    if (primaryGoal.contains('weight') || primaryGoal.contains('fat')) {
      final isLegTrained = recentTrained.contains('Legs');
      return _buildGeneratedRecommendation(
        id: 'rec_hiit',
        title: 'Metabolic Fat-Burn & Conditioning',
        focusKey: 'cardio',
        focusMuscleGroups: isLegTrained
            ? ['Upper Body', 'Cardio']
            : ['Full Body', 'Cardio'],
        intensity: readiness >= 80 ? 'heavy' : 'moderate',
        goalKey: 'fat_loss',
        duration: durationMinutes ?? 40,
        reason:
            'Optimized for high calorie burn and cardiovascular conditioning.',
        equipmentProfile: profile,
        workoutHistory: workoutHistory,
        experienceLevel: level,
      );
    }

    if (primaryGoal.contains('strength')) {
      final isChestTrained = recentTrained.contains('Chest');
      return _buildGeneratedRecommendation(
        id: 'rec_strength',
        title: isChestTrained
            ? 'Deadlift & Posterior Chain Power'
            : 'Heavy Bench Press & Upper Power',
        focusKey: isChestTrained ? 'pull' : 'push',
        focusMuscleGroups: isChestTrained
            ? ['Back', 'Hamstrings']
            : ['Chest', 'Triceps', 'Shoulders'],
        intensity: 'heavy',
        goalKey: 'strength',
        duration: durationMinutes ?? 50,
        reason:
            'High readiness detected! Maximizing maximal strength output on core compound lifts.',
        equipmentProfile: profile,
        workoutHistory: workoutHistory,
        experienceLevel: level,
      );
    }

    // Default: Muscle Hypertrophy
    final isPushTrained =
        recentTrained.contains('Chest') || recentTrained.contains('Shoulders');

    return _buildGeneratedRecommendation(
      id: 'rec_hypertrophy',
      title: isPushTrained
          ? 'Pull Hypertrophy & Bicep Builder'
          : 'Upper Push Power & Chest Builder',
      focusKey: isPushTrained ? 'pull' : 'push',
      focusMuscleGroups: isPushTrained
          ? ['Back', 'Biceps']
          : ['Chest', 'Shoulders', 'Triceps'],
      intensity: readiness >= 80 ? 'heavy' : 'moderate',
      goalKey: 'hypertrophy',
      duration: durationMinutes ?? 45,
      reason: isPushTrained
          ? 'Upper push trained recently. Switching to pull muscle groups for balanced development.'
          : 'High readiness! Perfect window to drive hypertrophy on upper body push muscle groups.',
      equipmentProfile: profile,
      workoutHistory: workoutHistory,
      experienceLevel: level,
    );
  }

  /// Internal helper orchestrating the 3-engine pipeline: Generator -> Validation -> Intelligence
  RecommendedWorkout _buildGeneratedRecommendation({
    required String id,
    required String title,
    required String focusKey,
    required List<String> focusMuscleGroups,
    required String intensity,
    required String goalKey,
    required int duration,
    required String reason,
    UserEquipmentProfile? equipmentProfile,
    List<WorkoutHistory>? workoutHistory,
    String? experienceLevel,
  }) {
    final profile = equipmentProfile ?? LocalStorage.getUserEquipmentProfile();

    // 1. Generate base exercises via WorkoutGeneratorEngine
    final rawExercises = _generatorEngine.generateExercisesForWorkout(
      workoutName: title,
      focus: focusKey,
      goal: goalKey,
      durationMinutes: duration,
      equipmentProfile: profile,
      workoutHistory: workoutHistory,
      intensity: intensity,
      experienceLevel: experienceLevel ?? 'intermediate',
    );

    // 2. Validate and sanitize through WorkoutValidationEngine
    final validation = _validationEngine.validateAndSanitizeWorkout(
      proposedExercises: rawExercises,
      focus: focusKey,
      durationMinutes: duration,
      equipmentProfile: profile,
      goal: goalKey,
      experienceLevel: experienceLevel ?? 'intermediate',
    );

    final sanitizedExercises = validation.sanitizedExercises.isNotEmpty
        ? validation.sanitizedExercises
        : rawExercises;

    // 3. Score intelligence and extract coaching insights
    final intelligence = _intelligenceEngine.evaluateWorkout(
      exercises: sanitizedExercises,
      focus: focusKey,
      durationMinutes: duration,
      goal: goalKey,
      equipmentProfile: profile,
      workoutHistory: workoutHistory,
    );

    final aiExplanation = intelligence.aiExplanation.isNotEmpty
        ? intelligence.aiExplanation.join(' ')
        : '';
    final finalReason = aiExplanation.isNotEmpty ? aiExplanation : reason;

    final exerciseNames = sanitizedExercises
        .map((e) => e['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    return RecommendedWorkout(
      id: id,
      title: title,
      focusMuscleGroups: focusMuscleGroups,
      intensity: intensity,
      exercises: exerciseNames,
      structuredExercises: sanitizedExercises,
      reason: finalReason,
      estimatedDuration: duration,
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
      if (name.contains('bench') ||
          name.contains('chest') ||
          name.contains('push')) {
        muscles.add('Chest');
        muscles.add('Triceps');
      }
      if (name.contains('leg') ||
          name.contains('squat') ||
          name.contains('deadlift')) {
        muscles.add('Legs');
      }
      if (name.contains('back') ||
          name.contains('pull') ||
          name.contains('row')) {
        muscles.add('Back');
      }
    }
    return muscles;
  }
}
