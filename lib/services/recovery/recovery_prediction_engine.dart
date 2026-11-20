import '../../models/daily_nutrition.dart';
import '../../models/health_metrics.dart';
import '../../models/recovery/readiness_inputs.dart';
import '../../models/recovery/recovery_report.dart';
import '../../models/recovery/training_readiness_score.dart';
import '../../models/workout_feedback.dart';
import '../../models/workout_history.dart';
import 'training_load_engine.dart';

/// Central prediction engine analyzing physiological signals, workouts, nutrition,
/// and sleep to compute athlete Training Readiness and adaptive volume guidelines.
class RecoveryPredictionEngine {
  final TrainingLoadEngine trainingLoadEngine;

  const RecoveryPredictionEngine({
    this.trainingLoadEngine = const TrainingLoadEngine(),
  });

  /// Generates a comprehensive RecoveryReport answering "Should this athlete train hard today?"
  RecoveryReport analyzeReadiness({
    required String userId,
    required List<WorkoutHistory> workoutHistory,
    HealthMetrics? healthMetrics,
    DailyNutrition? todayNutrition,
    List<WorkoutFeedback>? feedbackHistory,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final riskFactors = <String>[];

    // 1. Training Load Analytics (ATL, CTL, ACWR, TSB)
    final atl = trainingLoadEngine.calculateAcuteTrainingLoad(
      workoutHistory,
      referenceDate: now,
    );
    final ctl = trainingLoadEngine.calculateChronicTrainingLoad(
      workoutHistory,
      referenceDate: now,
    );
    final acwr = trainingLoadEngine.calculateACWR(acuteLoad: atl, chronicLoad: ctl);
    final tsb = trainingLoadEngine.calculateTSB(acuteLoad: atl, chronicLoad: ctl);
    final isSpike = trainingLoadEngine.isVolumeSpike(acwr);
    final isOvertraining = trainingLoadEngine.evaluateOvertrainingRisk(
      acwr: acwr,
      tsb: tsb,
      workoutsLast7Days: workoutHistory.where((w) => w.dateCompleted.isAfter(now.subtract(const Duration(days: 7)))).length,
    );

    if (isSpike) {
      riskFactors.add('Acute volume spike detected (ACWR: ${acwr.toStringAsFixed(2)})');
    }
    if (isOvertraining) {
      riskFactors.add('High cumulative strain with insufficient chronic recovery');
    }

    // Which real inputs exist. A factor without data is null and is left out of
    // the score; no neutral number stands in for it.
    final hasWorkouts = workoutHistory.isNotEmpty;
    final consumed = todayNutrition?.totalsConsumed;
    final hasFoodLogged =
        consumed != null &&
        (consumed.itemCount > 0 || consumed.calories > 0 || consumed.protein > 0);
    final inputs = ReadinessInputs.fromMetrics(
      healthMetrics,
      hasWorkoutHistory: hasWorkouts,
      hasNutrition: hasFoodLogged,
    );

    // 2. Factor 1: Workout Recovery Score (30% weight)
    final workoutRecovery = hasWorkouts
        ? _calculateWorkoutRecoveryScore(workoutHistory, feedbackHistory, now, riskFactors)
        : null;

    // 3. Factor 2: Sleep Score (25% weight)
    final sleepScore = _calculateSleepScore(healthMetrics, riskFactors);

    // 4. Factor 3: HRV Score (20% weight)
    final hrvScore = _calculateHrvScore(healthMetrics, riskFactors);

    // 5. Factor 4: Training Load Score (15% weight)
    final trainingLoadScore = hasWorkouts
        ? _calculateTrainingLoadScore(acwr, tsb)
        : null;

    // 6. Factor 5: Nutrition Score (10% weight)
    final nutritionScore = hasFoodLogged
        ? _calculateNutritionScore(todayNutrition, riskFactors)
        : null;

    // 7. Calculate Weighted Training Readiness Score (0 - 100), or "unavailable"
    // when no sleep, HRV or heart-rate signal was recorded.
    final readiness = TrainingReadinessScore.calculate(
      inputs: inputs,
      workoutRecovery: workoutRecovery,
      sleepScore: sleepScore,
      hrvScore: hrvScore,
      trainingLoadScore: trainingLoadScore,
      nutritionScore: nutritionScore,
      riskFactors: riskFactors,
      timestamp: now,
    );

    // 8. Determine Fatigue Level & Deload Alert
    final String fatigueLevel;
    final double volumeAdjustmentPercent;
    final bool isDeloadRecommended;

    if (!readiness.isAvailable) {
      // Nothing to judge fatigue from: no level, no volume change, no deload.
      fatigueLevel = 'unknown';
      volumeAdjustmentPercent = 0.0;
      isDeloadRecommended = false;
    } else if (readiness.score >= 80.0) {
      fatigueLevel = 'low';
      volumeAdjustmentPercent = 0.0;
      isDeloadRecommended = false;
    } else if (readiness.score >= 65.0) {
      fatigueLevel = 'moderate';
      volumeAdjustmentPercent = 0.0;
      isDeloadRecommended = false;
    } else if (readiness.score >= 50.0) {
      fatigueLevel = 'high';
      volumeAdjustmentPercent = -20.0;
      isDeloadRecommended = false;
    } else {
      fatigueLevel = 'extreme';
      volumeAdjustmentPercent = -50.0;
      isDeloadRecommended = true;
    }

    // 9. Generate Actionable Recommendation
    final recommendation = _generateRecommendation(readiness, fatigueLevel, isSpike, isDeloadRecommended);

    return RecoveryReport(
      id: 'rec_${now.millisecondsSinceEpoch}',
      userId: userId,
      readinessScore: readiness,
      fatigueLevel: fatigueLevel,
      recommendation: recommendation,
      riskFactors: riskFactors,
      hasTrainingHistory: hasWorkouts,
      acuteTrainingLoad: atl,
      chronicTrainingLoad: ctl,
      acuteToChronicRatio: acwr,
      trainingStressBalance: tsb,
      isVolumeSpikeDetected: isSpike,
      isOvertrainingRisk: isOvertraining,
      isDeloadRecommended: isDeloadRecommended,
      suggestedVolumeAdjustmentPercent: volumeAdjustmentPercent,
      generatedAt: now,
    );
  }

  /// Factor 1: Evaluates muscle rest time, recent intensity, and subjective feedback.
  double _calculateWorkoutRecoveryScore(
    List<WorkoutHistory> workoutHistory,
    List<WorkoutFeedback>? feedbackHistory,
    DateTime now,
    List<String> riskFactors,
  ) {
    if (workoutHistory.isEmpty) return 95.0;

    final lastWorkout = workoutHistory.first;
    final hoursSinceLast = now.difference(lastWorkout.dateCompleted).inHours;

    double score = 85.0;

    if (hoursSinceLast >= 48) {
      score += 15.0; // Fully refreshed window
    } else if (hoursSinceLast >= 24) {
      score += 5.0;  // Standard 24h rest
    } else if (hoursSinceLast < 14) {
      score -= 30.0; // Two-a-day or late night session
      riskFactors.add('Less than 14 hours since last intense workout session');
    } else {
      score -= 10.0;
    }

    // Check feedback history for 'too_hard' or extreme fatigue
    if (feedbackHistory != null && feedbackHistory.isNotEmpty) {
      final recentHard = feedbackHistory.take(2).where((f) => f.difficultyRating == 'too_hard').length;
      if (recentHard >= 2) {
        score -= 20.0;
        riskFactors.add('Athlete rated multiple recent workouts as "Too Hard"');
      }
    }

    return score.clamp(0.0, 100.0);
  }

  /// Factor 2: Evaluates sleep duration vs 8.0h baseline. Null when no sleep
  /// was recorded: a missing night is not scored.
  double? _calculateSleepScore(HealthMetrics? metrics, List<String> riskFactors) {
    final hours = metrics?.sleepHours;
    if (hours == null || hours <= 0) return null;
    if (hours >= 8.0) return 100.0;
    if (hours >= 7.0) return 85.0;
    if (hours >= 6.0) return 65.0;
    if (hours >= 5.0) {
      riskFactors.add('Sub-optimal sleep (${hours.toStringAsFixed(1)} hrs)');
      return 40.0;
    }
    riskFactors.add('Severe sleep deprivation (${hours.toStringAsFixed(1)} hrs)');
    return 20.0;
  }

  /// Factor 3: Evaluates HRV and Resting Heart Rate (autonomic nervous system
  /// recovery). Null when neither was recorded.
  double? _calculateHrvScore(HealthMetrics? metrics, List<String> riskFactors) {
    final hrv = (metrics?.heartRateVariability ?? 0) > 0
        ? metrics!.heartRateVariability
        : null;
    final rhr = (metrics?.restingHeartRate ?? 0) > 0
        ? metrics!.restingHeartRate
        : null;
    if (hrv == null && rhr == null) return null;

    // With HRV the score comes from it. With resting heart rate alone the
    // score is a rule on that one reading (a typical day is 80, nudged by it).
    double score = 80.0;
    if (hrv != null) {
      if (hrv >= 70.0) {
        score = 100.0;
      } else if (hrv >= 55.0) {
        score = 85.0;
      } else if (hrv >= 45.0) {
        score = 60.0;
      } else if (hrv >= 35.0) {
        riskFactors.add('Depressed HRV (${hrv.toStringAsFixed(0)} ms) indicating sympathetic dominance');
        score = 40.0;
      } else {
        riskFactors.add('Severely suppressed HRV (${hrv.toStringAsFixed(0)} ms)');
        score = 20.0;
      }
    }

    // Physiological Resting Heart Rate adjustment
    if (rhr != null) {
      if (rhr >= 75.0) {
        score = (score - 15.0).clamp(0.0, 100.0);
        riskFactors.add('Elevated resting heart rate (${rhr.toStringAsFixed(0)} bpm) indicating systemic fatigue');
      } else if (rhr <= 55.0) {
        score = (score + 5.0).clamp(0.0, 100.0);
      }
    }

    return score;
  }

  /// Factor 4: Evaluates training stress ratio (ACWR sweet spot: 0.8 - 1.3).
  double _calculateTrainingLoadScore(double acwr, double tsb) {
    if (acwr >= 0.85 && acwr <= 1.25) return 100.0;
    if (acwr >= 0.70 && acwr <= 1.40) return 85.0;
    if (acwr > 1.40 && acwr <= 1.55) return 55.0;
    if (acwr > 1.55) return 30.0; // Extreme volume spike
    return 70.0; // Under-training (< 0.70)
  }

  /// Factor 5: Evaluates nutrition and protein intake adherence.
  double? _calculateNutritionScore(DailyNutrition? nutrition, List<String> riskFactors) {
    // Nothing logged is not "ate nothing": no judgement either way.
    if (nutrition == null) return null;
    final logged = nutrition.totalsConsumed;
    if (logged.itemCount == 0 && logged.calories <= 0 && logged.protein <= 0) {
      return null;
    }

    final totals = nutrition.totalsConsumed;
    final calories = totals.calories;
    final protein = totals.protein;

    // A shortfall is only judged on a complete total. Foods with unknown
    // values make the totals minimums: they can prove a high intake (the real
    // figure is at least as high) but never a low one.
    if (calories >= 1800 && protein >= 100.0) return 100.0;
    if (calories >= 1400 && protein >= 70.0) return 80.0;
    final lowCalories = totals.caloriesComplete && calories < 1200;
    final lowProtein = totals.proteinComplete && protein < 50.0;
    if (lowCalories || lowProtein) {
      riskFactors.add('Under-fueling detected (low caloric or protein intake)');
      return 45.0;
    }
    if (!totals.caloriesComplete || !totals.proteinComplete) {
      return null; // foods with unknown values: not enough to judge intake
    }
    return 70.0;
  }

  /// Formats personalized training recommendation.
  String _generateRecommendation(
    TrainingReadinessScore readiness,
    String fatigueLevel,
    bool isSpike,
    bool isDeload,
  ) {
    if (!readiness.isAvailable) {
      return 'No recommendation yet: ${readiness.explanation}';
    }
    if (isDeload || readiness.score < 50.0) {
      return 'Athlete shows elevated systemic strain. Recommended action: 50% volume reduction, omit heavy spinal loading, and prioritize 30 mins restorative mobility or walking.';
    }
    if (readiness.score < 70.0 || isSpike) {
      return 'Moderate nervous system fatigue detected. Recommended action: Maintain working weights on primary compound lifts but reduce secondary accessory sets by 20%.';
    }
    if (readiness.score >= 88.0) {
      return 'Prime training readiness detected across HRV, sleep, and muscular recovery. Recommended action: Target progressive overload or attempt planned PRs today.';
    }
    return 'Recovery indicators are in optimal balance. Execute scheduled training session as programmed.';
  }
}
