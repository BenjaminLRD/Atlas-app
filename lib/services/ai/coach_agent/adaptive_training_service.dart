/// Supported in-session and pre-session adaptive workout adjustment types.
enum TrainingAdjustmentType {
  increaseWeight,
  decreaseWeight,
  changeReps,
  replaceExercise,
  extendRest,
  reduceVolume,
}

/// Actionable training adjustment proposal created by the AI Coach.
/// Adheres strictly to the rule: Never mutate active sessions without explicit user confirmation.
class TrainingAdjustmentRecommendation {
  final TrainingAdjustmentType type;
  final String title;
  final String reason;
  final String suggestedValue;
  final double? numericDelta;
  final bool isConfirmed;

  const TrainingAdjustmentRecommendation({
    required this.type,
    required this.title,
    required this.reason,
    required this.suggestedValue,
    this.numericDelta,
    this.isConfirmed = false,
  });

  /// Produces a copy with user confirmation state updated.
  TrainingAdjustmentRecommendation confirm() {
    return TrainingAdjustmentRecommendation(
      type: type,
      title: title,
      reason: reason,
      suggestedValue: suggestedValue,
      numericDelta: numericDelta,
      isConfirmed: true,
    );
  }
}

/// Service providing real-time in-gym workout adaptation recommendations.
class AdaptiveTrainingService {
  static AdaptiveTrainingService? _instance;
  static AdaptiveTrainingService get instance =>
      _instance ??= AdaptiveTrainingService();

  /// Analyzes single completed set performance to propose live weight, rep, or rest adjustments.
  TrainingAdjustmentRecommendation? evaluateLiveSet({
    required String exerciseName,
    required double currentWeightKg,
    required int targetReps,
    required int completedReps,
    required int currentSet,
    required int totalSets,
    double? rpe, // Rate of Perceived Exertion (1 - 10)
    double? recoveryScore, // 0 - 100
  }) {
    // 1. Check severe fatigue or under-performance (missed by >= 2 reps)
    if (completedReps <= targetReps - 2) {
      final dropAmount = currentWeightKg >= 50.0 ? 5.0 : 2.5;
      return TrainingAdjustmentRecommendation(
        type: TrainingAdjustmentType.decreaseWeight,
        title: 'Reduce Weight on $exerciseName',
        reason:
            'You completed $completedReps of $targetReps target reps. Lowering weight by ${dropAmount}kg preserves movement quality and target rep ranges.',
        suggestedValue:
            '${(currentWeightKg - dropAmount).clamp(0.0, 999.0)} kg',
        numericDelta: -dropAmount,
      );
    }

    // 2. Check mild fatigue (missed by 1 rep)
    if (completedReps == targetReps - 1) {
      return const TrainingAdjustmentRecommendation(
        type: TrainingAdjustmentType.extendRest,
        title: 'Extend Rest Interval',
        reason:
            'Target missed by 1 rep. An additional 30 seconds of rest will restore ATP and central nervous system capacity.',
        suggestedValue: '+30 seconds',
        numericDelta: 30.0,
      );
    }

    // 3. Check low RPE / easy set for progressive overload opportunity
    if (completedReps >= targetReps && rpe != null && rpe <= 6.5) {
      final increaseAmount = currentWeightKg >= 60.0 ? 2.5 : 1.25;
      return TrainingAdjustmentRecommendation(
        type: TrainingAdjustmentType.increaseWeight,
        title: 'Progressive Overload on $exerciseName',
        reason:
            'Target hit with low RPE ($rpe/10). You are primed to increase load by ${increaseAmount}kg on your next set.',
        suggestedValue: '${currentWeightKg + increaseAmount} kg',
        numericDelta: increaseAmount,
      );
    }

    // 4. Check low pre-workout recovery score
    if (recoveryScore != null &&
        recoveryScore < 50.0 &&
        currentSet >= (totalSets * 0.75).round()) {
      return TrainingAdjustmentRecommendation(
        type: TrainingAdjustmentType.reduceVolume,
        title: 'Omit Final Accessory Set',
        reason:
            'Daily recovery score is low ($recoveryScore%). Capping volume here prevents overtraining while retaining 90% of hypertrophy stimulus.',
        suggestedValue: 'Complete session early',
      );
    }

    return null;
  }
}
