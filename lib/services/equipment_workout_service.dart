import '../models/exercise.dart';
import '../models/user_equipment_profile.dart';

/// Represents the equipment validation and feasibility of a planned workout session.
class WorkoutEquipmentValidation {
  final List<Exercise> availableExercises;
  final List<Exercise> unavailableExercises;
  final Map<String, List<Exercise>> suggestedReplacements;
  final bool isFullyFeasible;

  const WorkoutEquipmentValidation({
    required this.availableExercises,
    required this.unavailableExercises,
    required this.suggestedReplacements,
    required this.isFullyFeasible,
  });
}

/// Description of an individual exercise substitution made during adaptive workout generation.
class ExerciseSubstitutionLog {
  final Exercise original;
  final Exercise replacement;
  final List<String> missingEquipment;
  final String rationale;

  const ExerciseSubstitutionLog({
    required this.original,
    required this.replacement,
    required this.missingEquipment,
    required this.rationale,
  });
}

/// Result of adapting a complete workout routine to the athlete's available equipment.
class AdaptiveWorkoutPlanResult {
  final List<Exercise> adaptedExercises;
  final List<ExerciseSubstitutionLog> substitutions;
  final bool requiredSubstitutions;

  const AdaptiveWorkoutPlanResult({
    required this.adaptedExercises,
    required this.substitutions,
    required this.requiredSubstitutions,
  });
}

/// Domain service responsible for filtering exercise databases, suggesting viable alternatives,
/// and adapting planned training sessions to the user's available gym equipment.
class EquipmentWorkoutService {
  const EquipmentWorkoutService();

  /// Determines whether a user has all physical equipment required to perform the given exercise.
  bool canPerformExercise(Exercise exercise, UserEquipmentProfile profile) {
    if (exercise.requiredEquipment.isEmpty) {
      // If requiredEquipment is unspecified, check legacy equipment string
      final legacy = exercise.equipment.toLowerCase().replaceAll(' ', '_');
      if (legacy == 'bodyweight' || legacy == 'none' || legacy.isEmpty) {
        return true;
      }
      return profile.isEquipmentAvailable(legacy);
    }
    return profile.hasAllEquipment(exercise.requiredEquipment);
  }

  /// Filters a list of exercises to only include those completely feasible with the athlete's equipment profile.
  List<Exercise> filterAvailableExercises({
    required List<Exercise> exercises,
    required UserEquipmentProfile profile,
  }) {
    return exercises.where((e) => canPerformExercise(e, profile)).toList();
  }

  /// Identifies and ranks viable substitution exercises for a movement when required equipment is missing.
  List<Exercise> findAlternatives({
    required Exercise target,
    required UserEquipmentProfile profile,
    required List<Exercise> pool,
  }) {
    final List<Exercise> candidates = [];

    // 1. First priority: Check target exercise's explicit alternative IDs/names
    for (final altIdentifier in target.alternatives) {
      final normalized = altIdentifier.toLowerCase().replaceAll(' ', '_');
      final match = pool.firstWhere(
        (e) =>
            e.id.toLowerCase() == normalized ||
            e.name.toLowerCase() == altIdentifier.toLowerCase() ||
            e.id.toLowerCase().contains(normalized),
        orElse: () =>
            const Exercise(id: '', name: '', muscleGroup: '', equipment: ''),
      );

      if (match.id.isNotEmpty && canPerformExercise(match, profile)) {
        if (!candidates.any((c) => c.id == match.id)) {
          candidates.add(match);
        }
      }
    }

    // 2. Second priority: Find exercises in pool targeting the same primary muscle group
    final primaryTargetMuscle = target.muscleGroup
        .split(',')
        .first
        .trim()
        .toLowerCase();
    for (final exercise in pool) {
      if (exercise.id == target.id) continue;
      if (candidates.any((c) => c.id == exercise.id)) continue;

      final candidateMuscle = exercise.muscleGroup.toLowerCase();
      if (candidateMuscle.contains(primaryTargetMuscle) &&
          canPerformExercise(exercise, profile)) {
        candidates.add(exercise);
      }
    }

    return candidates;
  }

  /// Validates a routine against user equipment and generates candidate replacements for missing items.
  WorkoutEquipmentValidation validateWorkoutEquipment({
    required List<Exercise> exercises,
    required UserEquipmentProfile profile,
    List<Exercise>? exercisePool,
  }) {
    final pool = exercisePool ?? Exercise.defaultRegistry();
    final List<Exercise> available = [];
    final List<Exercise> unavailable = [];
    final Map<String, List<Exercise>> replacements = {};

    for (final exercise in exercises) {
      if (canPerformExercise(exercise, profile)) {
        available.add(exercise);
      } else {
        unavailable.add(exercise);
        replacements[exercise.id] = findAlternatives(
          target: exercise,
          profile: profile,
          pool: pool,
        );
      }
    }

    return WorkoutEquipmentValidation(
      availableExercises: available,
      unavailableExercises: unavailable,
      suggestedReplacements: replacements,
      isFullyFeasible: unavailable.isEmpty,
    );
  }

  /// Automatically adapts an entire workout session by replacing unavailable exercises with viable substitutes.
  AdaptiveWorkoutPlanResult adaptWorkoutSession({
    required List<Exercise> originalSession,
    required UserEquipmentProfile profile,
    List<Exercise>? exercisePool,
  }) {
    final pool = exercisePool ?? Exercise.defaultRegistry();
    final List<Exercise> adapted = [];
    final List<ExerciseSubstitutionLog> logs = [];

    for (final exercise in originalSession) {
      if (canPerformExercise(exercise, profile)) {
        adapted.add(exercise);
      } else {
        final alternatives = findAlternatives(
          target: exercise,
          profile: profile,
          pool: pool,
        );

        if (alternatives.isNotEmpty) {
          final chosenReplacement = alternatives.first;
          adapted.add(chosenReplacement);

          final missing = exercise.requiredEquipment
              .where((req) => !profile.isEquipmentAvailable(req))
              .toList();

          logs.add(
            ExerciseSubstitutionLog(
              original: exercise,
              replacement: chosenReplacement,
              missingEquipment: missing,
              rationale:
                  'Substituted with ${chosenReplacement.name} because ${missing.join(', ')} is not available in your setup.',
            ),
          );
        } else {
          // Fallback: keep original if no alternatives are feasible
          adapted.add(exercise);
        }
      }
    }

    return AdaptiveWorkoutPlanResult(
      adaptedExercises: adapted,
      substitutions: logs,
      requiredSubstitutions: logs.isNotEmpty,
    );
  }
}
