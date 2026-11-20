import '../../models/user_goal.dart';

/// Validation result for workout generation and agent tool execution safety
class SafetyCheckResult {
  final bool isSafe;
  final String? warningMessage;
  final List<String> contraindicatedExercises;

  const SafetyCheckResult({
    required this.isSafe,
    this.warningMessage,
    this.contraindicatedExercises = const [],
  });

  factory SafetyCheckResult.safe() => const SafetyCheckResult(isSafe: true);

  factory SafetyCheckResult.unsafe(
    String message, {
    List<String> contraindicated = const [],
  }) => SafetyCheckResult(
    isSafe: false,
    warningMessage: message,
    contraindicatedExercises: contraindicated,
  );
}

/// Validator enforcing biomechanical safety, injury contraindications, and agent action limits.
class WorkoutSafetyValidator {
  /// Validates workout prescription matching user experience level and injury history.
  static SafetyCheckResult validateWorkoutPlan({
    required FitnessLevel fitnessLevel,
    required List<String> exercises,
    List<String> injuries = const [],
  }) {
    final contraindicated = <String>[];

    // 1. Beginner Safety Check: Avoid high-technical Olympic lifts and dangerous 1RM maximal work
    if (fitnessLevel == FitnessLevel.beginner) {
      final advancedOlympicMovements = [
        'snatch',
        'clean and jerk',
        'behind the neck press',
        'depth drop box jump',
      ];

      for (final ex in exercises) {
        final lower = ex.toLowerCase();
        if (advancedOlympicMovements.any((adv) => lower.contains(adv))) {
          contraindicated.add(ex);
        }
      }

      if (contraindicated.isNotEmpty) {
        return SafetyCheckResult.unsafe(
          'Advanced Olympic movements are not recommended for beginners. Safer fundamental compounds have been substituted.',
          contraindicated: contraindicated,
        );
      }
    }

    // 2. Injury Contraindication Filtering
    final lowerInjuries = injuries.map((i) => i.toLowerCase()).toList();

    for (final ex in exercises) {
      final lower = ex.toLowerCase();

      // Shoulder injury: Avoid overhead press, behind the neck, heavy dips
      if (lowerInjuries.any(
        (inj) => inj.contains('shoulder') || inj.contains('rotator cuff'),
      )) {
        if (lower.contains('overhead press') ||
            lower.contains('military press') ||
            lower.contains('behind the neck') ||
            lower.contains('dip')) {
          contraindicated.add(ex);
        }
      }

      // Knee injury: Avoid heavy back squat, plyometric jump squats
      if (lowerInjuries.any(
        (inj) =>
            inj.contains('knee') ||
            inj.contains('meniscus') ||
            inj.contains('patella'),
      )) {
        if (lower.contains('back squat') ||
            lower.contains('jump squat') ||
            lower.contains('box jump') ||
            lower.contains('heavy leg extension')) {
          contraindicated.add(ex);
        }
      }

      // Lower back injury: Avoid heavy conventional deadlift, good mornings
      if (lowerInjuries.any(
        (inj) =>
            inj.contains('back') ||
            inj.contains('hernia') ||
            inj.contains('lumbar'),
      )) {
        if (lower.contains('deadlift') ||
            lower.contains('good morning') ||
            lower.contains('barbell row')) {
          contraindicated.add(ex);
        }
      }
    }

    if (contraindicated.isNotEmpty) {
      return SafetyCheckResult.unsafe(
        'Contraindicated movements detected for reported injury limitations. Movements flagged for safe substitution.',
        contraindicated: contraindicated,
      );
    }

    return SafetyCheckResult.safe();
  }

  /// Validates AI agent tool modifications to calorie targets
  static SafetyCheckResult validateCalorieTargetModification({
    required double currentTarget,
    required double proposedTarget,
  }) {
    // 1. Absolute safe physiological boundaries
    if (proposedTarget < 1200.0 || proposedTarget > 5000.0) {
      return SafetyCheckResult.unsafe(
        'Calorie target must remain within safe physiological limits (1,200 - 5,000 kcal).',
      );
    }

    // 2. Single adjustment maximum delta (Max ±1000 kcal jump)
    final delta = (proposedTarget - currentTarget).abs();
    if (delta > 1000.0) {
      return SafetyCheckResult.unsafe(
        'Extreme calorie adjustment blocked (+${delta.toInt()} kcal). Maximum safe single adjustment is ±1,000 kcal.',
      );
    }

    return SafetyCheckResult.safe();
  }

  /// Validates workout duration bounds
  static SafetyCheckResult validateWorkoutDuration(int durationMinutes) {
    if (durationMinutes < 15 || durationMinutes > 120) {
      return SafetyCheckResult.unsafe(
        'Workout duration must be between 15 and 120 minutes.',
      );
    }
    return SafetyCheckResult.safe();
  }
}
