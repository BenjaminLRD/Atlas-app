import '../models/recommended_workout.dart';
import '../models/recovery/training_readiness_score.dart';
import '../models/training_state.dart';
import '../models/workout_feedback.dart';

/// Service analyzing user workout feedback and computing adaptive load adjustment multipliers.
class WorkoutAdaptationService {
  static WorkoutAdaptationService? _instance;

  WorkoutAdaptationService();

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static WorkoutAdaptationService get instance {
    _instance ??= WorkoutAdaptationService();
    return _instance!;
  }

  /// Modifies an existing workout based on Phase C.2 TrainingReadinessScore.
  /// High readiness (>= 70): Normal volume & progressive overload
  /// Medium readiness (50-69): Maintain intensity, reduce volume by 20%
  /// Low readiness (< 50): Recovery mode, reduce volume by 50%, light intensity
  RecommendedWorkout adaptWorkoutForReadiness({
    required RecommendedWorkout workout,
    required TrainingReadinessScore readiness,
  }) {
    // Without sleep, HRV or heart-rate data there is no readiness to adapt to.
    if (!readiness.isAvailable || readiness.score >= 70.0) {
      return workout;
    }

    final isDeload = readiness.score < 50.0;
    final reason = isDeload
        ? 'Deload active: Volume scaled down 50% due to low recovery (${readiness.score.toStringAsFixed(0)}% readiness).'
        : 'Volume scaled down 20% for moderate readiness (${readiness.score.toStringAsFixed(0)}%).';

    final updatedStructured = workout.structuredExercises.map((e) {
      final copy = Map<String, dynamic>.from(e);
      final int originalSets = (copy['sets'] as num?)?.toInt() ?? 4;
      int adjustedSets;
      if (isDeload) {
        adjustedSets = (originalSets * 0.5).round().clamp(2, originalSets);
      } else {
        adjustedSets = (originalSets - 1).clamp(2, originalSets);
      }
      copy['sets'] = adjustedSets;
      copy['notes'] = reason;
      return copy;
    }).toList();

    return workout.copyWith(
      structuredExercises: updatedStructured,
      intensity: isDeload ? 'light' : 'moderate',
      reason: '$reason ${workout.reason}',
      estimatedDuration: isDeload
          ? (workout.estimatedDuration * 0.65).round()
          : (workout.estimatedDuration * 0.85).round(),
    );
  }

  /// Calculates cumulative progression multiplier based on recent feedback history (e.g. 1.0 to 1.15).
  double calculateProgressionFactor(List<WorkoutFeedback> feedbackHistory) {
    if (feedbackHistory.isEmpty) return 1.0;

    // Take recent 5 feedbacks
    final recent = feedbackHistory.take(5).toList();
    double factor = 1.0;

    for (final fb in recent) {
      switch (fb.difficultyRating.toLowerCase()) {
        case 'too_easy':
          factor += 0.05; // +5% increase per 'too_easy'
          break;
        case 'too_hard':
          factor -= 0.05; // -5% reduction per 'too_hard'
          break;
        case 'perfect':
        default:
          factor += 0.01; // +1% progressive overload per 'perfect'
          break;
      }
    }

    // Clamp factor between 0.85 (-15%) and 1.25 (+25%)
    return factor.clamp(0.85, 1.25);
  }

  /// Generates natural language adaptation summary explaining how future recommendations adapt.
  String generateAdaptationNote(WorkoutFeedback feedback) {
    switch (feedback.difficultyRating.toLowerCase()) {
      case 'too_easy':
        return 'Feedback recorded: "Too Easy". Future recommendations will increase load and intensity by 5-10%.';
      case 'too_hard':
        return 'Feedback recorded: "Too Hard". Future recommendations will scale back intensity to ensure complete recovery.';
      case 'perfect':
      default:
        return 'Feedback recorded: "Perfect". Future recommendations will apply steady progressive overload.';
    }
  }

  /// Computes recommended volume target for next session based on previous volume and feedback factor.
  double computeTargetVolume({
    required double lastVolume,
    required List<WorkoutFeedback> history,
    TrainingState? trainingState,
  }) {
    final factor = calculateProgressionFactor(history);
    final readinessMultiplier = (trainingState?.readinessScore ?? 80) / 100.0;
    return lastVolume * factor * readinessMultiplier;
  }
}
