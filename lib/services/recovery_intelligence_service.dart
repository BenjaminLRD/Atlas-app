import '../models/health_metrics.dart';
import '../models/recovery_state.dart';
import '../models/training_state.dart';
import '../models/workout_feedback.dart';
import '../models/workout_history.dart';

/// Central service computing athlete recovery intelligence, fatigue detection, and deload alerts.
class RecoveryIntelligenceService {
  static RecoveryIntelligenceService? _instance;

  RecoveryIntelligenceService();

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static RecoveryIntelligenceService get instance {
    _instance ??= RecoveryIntelligenceService();
    return _instance!;
  }

  /// Evaluates recovery metrics and computes comprehensive RecoveryState.
  RecoveryState analyzeRecoveryState({
    HealthMetrics? healthMetrics,
    TrainingState? trainingState,
    List<WorkoutHistory>? workouts,
    List<WorkoutFeedback>? feedbackHistory,
    int? customRecoveryScore,
  }) {
    final now = DateTime.now();

    // 1. Base Recovery Score (0 - 100)
    int baseRecovery = customRecoveryScore ?? 80;
    if (healthMetrics != null) {
      // Sleep quality contribution (8+ hours = +10, <6 hours = -15)
      if (healthMetrics.sleepHours >= 8.0) {
        baseRecovery += 5;
      } else if (healthMetrics.sleepHours < 6.0) {
        baseRecovery -= 15;
      }

      // Resting heart rate contribution
      if (healthMetrics.heartRateAverage > 75.0) {
        baseRecovery -= 10;
      }
    }
    final finalRecoveryScore = baseRecovery.clamp(0, 100);

    // 2. Compute Fatigue Score (0 - 100)
    final readinessScore = trainingState?.readinessScore ?? 80;
    int fatigueScore = trainingState?.fatigueScore ?? (100 - finalRecoveryScore);

    // Factor in recent 'too_hard' feedback
    if (feedbackHistory != null && feedbackHistory.isNotEmpty) {
      final hardCount = feedbackHistory
          .take(3)
          .where((f) => f.difficultyRating == 'too_hard')
          .length;
      fatigueScore += hardCount * 10;
    }

    fatigueScore = fatigueScore.clamp(0, 100);

    // 3. Classify Fatigue Level
    FatigueLevel fatigueLevel = FatigueLevel.low;
    if (fatigueScore > 75) {
      fatigueLevel = FatigueLevel.critical;
    } else if (fatigueScore > 55) {
      fatigueLevel = FatigueLevel.high;
    } else if (fatigueScore > 25) {
      fatigueLevel = FatigueLevel.moderate;
    }

    // 4. Deload Detection Rule: fatigueScore > 75 AND readinessScore < 45
    final isDeloadRecommended = fatigueScore > 75 && readinessScore < 45;

    // 5. Recovery Trend (compare last 7 days vs previous 7 days)
    final trend = _calculateRecoveryTrend(workouts);

    // 6. Recommendation Mapping
    RecoveryRecommendation recommendation = RecoveryRecommendation.trainNormal;
    if (isDeloadRecommended) {
      recommendation = RecoveryRecommendation.deloadWeek;
    } else if (fatigueScore > 65 || readinessScore < 45) {
      recommendation = RecoveryRecommendation.restDay;
    } else if (fatigueScore > 50 || readinessScore < 60) {
      recommendation = RecoveryRecommendation.activeRecovery;
    } else if (fatigueScore > 35) {
      recommendation = RecoveryRecommendation.reduceIntensity;
    }

    final sleepQuality = healthMetrics != null
        ? (healthMetrics.sleepHours / 8.0).clamp(0.0, 1.0)
        : 0.85;

    return RecoveryState(
      id: 'rec_${now.millisecondsSinceEpoch}',
      recoveryScore: finalRecoveryScore,
      fatigueLevel: fatigueLevel,
      trainingStress: (fatigueScore * 1.2).clamp(0.0, 100.0),
      sleepQuality: sleepQuality,
      recoveryTrend: trend,
      recommendation: recommendation,
      isDeloadRecommended: isDeloadRecommended,
      lastUpdated: now,
    );
  }

  String _calculateRecoveryTrend(List<WorkoutHistory>? workouts) {
    if (workouts == null || workouts.length < 4) return 'stable';

    final now = DateTime.now();
    final recentWeek = workouts
        .where((w) => now.difference(w.dateCompleted).inDays <= 7)
        .length;
    final previousWeek = workouts
        .where((w) =>
            now.difference(w.dateCompleted).inDays > 7 &&
            now.difference(w.dateCompleted).inDays <= 14)
        .length;

    if (recentWeek > previousWeek + 2) {
      return 'declining'; // High volume spike indicates declining recovery
    } else if (recentWeek < previousWeek) {
      return 'improving';
    }
    return 'stable';
  }
}
