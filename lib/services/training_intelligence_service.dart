import '../models/recovery/readiness_inputs.dart';
import '../models/health_metrics.dart';
import '../models/training_state.dart';
import '../models/workout_history.dart';

/// Central service computing fatigue scores, readiness scores, and adaptive intensity recommendations.
class TrainingIntelligenceService {
  static TrainingIntelligenceService? _instance;

  TrainingIntelligenceService();

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static TrainingIntelligenceService get instance {
    _instance ??= TrainingIntelligenceService();
    return _instance!;
  }

  /// Analyze recent workout volume, health metrics, and recovery score to compute readiness.
  TrainingState analyzeTrainingState({
    required List<WorkoutHistory> workouts,
    HealthMetrics? healthMetrics,
    int recoveryScore = 80,
  }) {
    final now = DateTime.now();

    // Real inputs. Readiness is a measurement only with a sleep, HRV or
    // heart-rate reading; otherwise the score below is a neutral placeholder
    // for the planners and the narrative says so.
    final inputs = ReadinessInputs.fromMetrics(
      healthMetrics,
      hasWorkoutHistory: workouts.isNotEmpty,
    );
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // 1. Filter 7-day recent workouts
    final recentWorkouts = workouts
        .where((w) => w.dateCompleted.isAfter(sevenDaysAgo))
        .toList();

    final recentCount = recentWorkouts.length;
    final weeklyVolume = recentWorkouts.fold<double>(
      0.0,
      (sum, w) => sum + w.totalVolume,
    );

    final trainingLoad = (recentCount * 25.0 + (weeklyVolume / 500.0)).clamp(
      10.0,
      300.0,
    );

    // 2. Compute Fatigue Score (0 - 100)
    final freqFatigue = (recentCount / 6.0 * 35.0).clamp(0.0, 35.0);
    final volFatigue = (weeklyVolume / 35000.0 * 35.0).clamp(0.0, 35.0);
    // The recovery part of fatigue only counts when recovery was measured.
    final recoveryFatigue = inputs.hasPhysiological
        ? ((100 - recoveryScore) * 0.3).clamp(0.0, 30.0)
        : 0.0;

    final fatigueScore = (freqFatigue + volFatigue + recoveryFatigue)
        .round()
        .clamp(0, 100);

    // 3. Compute Readiness Score (0 - 100)
    final readinessScore = inputs.hasPhysiological
        ? ((recoveryScore * 0.55) + ((100 - fatigueScore) * 0.45)).round().clamp(
            0,
            100,
          )
        : 80; // neutral placeholder, not measured (see [TrainingState.isMeasured])

    // 4. Determine Recommended Intensity & Narrative
    String recommendedIntensity;
    String recommendation;

    if (!inputs.hasPhysiological) {
      // No recovery data: training volume can still say "back off", but nothing
      // here claims the athlete is recovered.
      final heavyRecentLoad = fatigueScore >= 65;
      recommendedIntensity = heavyRecentLoad ? 'recovery' : 'moderate_training';
      recommendation = heavyRecentLoad
          ? 'Readiness cannot be judged without sleep or heart-rate data. Your recent training load is high, so keep today lighter.'
          : 'Readiness cannot be judged without sleep or heart-rate data. Record them (watch, Health Connect or manual entry) for a readiness score.';
    } else if (readinessScore >= 80) {
      recommendedIntensity = 'heavy_training';
      recommendation =
          'Optimal readiness! Your muscles and nervous system are fully recovered for heavy compound lifting.';
    } else if (readinessScore >= 60) {
      recommendedIntensity = 'moderate_training';
      recommendation =
          'Good readiness. Maintain target intensity with structured hyper-trophy sets and moderate volume.';
    } else if (readinessScore >= 40) {
      recommendedIntensity = 'recovery';
      recommendation =
          'Elevated fatigue detected. Focus on active recovery, mobility, stretching, and lighter cardio.';
    } else {
      recommendedIntensity = 'rest';
      recommendation =
          'High fatigue alert! Take a rest day to allow muscle tissue repair and prevent overtraining.';
    }

    return TrainingState(
      inputs: inputs,
      id: 'ts_${now.millisecondsSinceEpoch}',
      fatigueScore: fatigueScore,
      readinessScore: readinessScore,
      trainingLoad: trainingLoad,
      weeklyVolume: weeklyVolume,
      recommendedIntensity: recommendedIntensity,
      recommendation: recommendation,
      lastUpdated: now,
    );
  }
}
