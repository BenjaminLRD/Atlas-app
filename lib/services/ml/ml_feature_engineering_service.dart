import 'dart:math';
import '../../models/fitness_context.dart';
import '../../models/nutrition_log.dart';
import '../../models/workout_history.dart';
import 'ml_data_collector.dart';

/// Normalized multi-dimensional numerical feature vector for TensorFlow Lite model inputs.
class FeatureVector {
  final double trainingFrequency; // Sessions per week (0.0 to 7.0)
  final double averageVolumeKg; // Average session volume in kg
  final double
  strengthProgression; // Rate of 1RM or mechanical overload (-1.0 to 1.0)
  final double recoveryScore; // Autonomic readiness (0.0 to 100.0)
  final double nutritionAdherence; // Macro & calorie hit rate (0.0 to 1.0)
  final double
  workoutCompletionRate; // Planned vs finished sessions (0.0 to 1.0)
  final double
  exercisePreferenceScore; // Alignment with favorite exercises (0.0 to 1.0)

  const FeatureVector({
    required this.trainingFrequency,
    required this.averageVolumeKg,
    required this.strengthProgression,
    required this.recoveryScore,
    required this.nutritionAdherence,
    required this.workoutCompletionRate,
    required this.exercisePreferenceScore,
  });

  /// Factory baseline default feature vector
  factory FeatureVector.baseline() {
    return const FeatureVector(
      trainingFrequency: 4.0,
      averageVolumeKg: 10500.0,
      strengthProgression: 0.05,
      recoveryScore: 82.0,
      nutritionAdherence: 0.88,
      workoutCompletionRate: 0.90,
      exercisePreferenceScore: 0.85,
    );
  }

  /// Converts the feature vector into a normalized 1D float tensor for TFLite inference.
  List<double> toNormalizedTensor() {
    return [
      (trainingFrequency / 7.0).clamp(0.0, 1.0),
      (averageVolumeKg / 30000.0).clamp(0.0, 1.0),
      ((strengthProgression + 1.0) / 2.0).clamp(0.0, 1.0),
      (recoveryScore / 100.0).clamp(0.0, 1.0),
      nutritionAdherence.clamp(0.0, 1.0),
      workoutCompletionRate.clamp(0.0, 1.0),
      exercisePreferenceScore.clamp(0.0, 1.0),
    ];
  }

  factory FeatureVector.fromJson(Map<String, dynamic> json) {
    return FeatureVector(
      trainingFrequency:
          (json['training_frequency'] as num?)?.toDouble() ?? 4.0,
      averageVolumeKg:
          (json['average_volume_kg'] as num?)?.toDouble() ?? 10000.0,
      strengthProgression:
          (json['strength_progression'] as num?)?.toDouble() ?? 0.05,
      recoveryScore: (json['recovery_score'] as num?)?.toDouble() ?? 80.0,
      nutritionAdherence:
          (json['nutrition_adherence'] as num?)?.toDouble() ?? 0.85,
      workoutCompletionRate:
          (json['workout_completion_rate'] as num?)?.toDouble() ?? 0.90,
      exercisePreferenceScore:
          (json['exercise_preference_score'] as num?)?.toDouble() ?? 0.80,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'training_frequency': trainingFrequency,
      'average_volume_kg': averageVolumeKg,
      'strength_progression': strengthProgression,
      'recovery_score': recoveryScore,
      'nutrition_adherence': nutritionAdherence,
      'workout_completion_rate': workoutCompletionRate,
      'exercise_preference_score': exercisePreferenceScore,
      'tensor': toNormalizedTensor(),
    };
  }
}

/// Feature Engineering Pipeline transforming heterogeneous health, workout, and diet telemetry
/// into standard FeatureVectors for on-device machine learning models.
class MLFeatureEngineeringService {
  static MLFeatureEngineeringService? _instance;
  static MLFeatureEngineeringService get instance =>
      _instance ??= MLFeatureEngineeringService();

  /// Adherence used when there is no log, or no component of it is known.
  static const double neutralNutritionAdherence = 0.88;

  /// How close today's intake is to the goals (0 to 1). Missing values are
  /// handled by leaving the component out, never by reading them as 0: a
  /// calorie or protein total that misses foods with unknown values says
  /// nothing about how far from the goal the real intake is (it may be over
  /// or under), so only the components that are complete are used. With none
  /// complete, the neutral value is used, the same as with no log.
  static double nutritionAdherenceOf(NutritionLog? log) {
    if (log == null) return neutralNutritionAdherence;
    double closeness(double consumed, double goal) {
      final ratio = goal > 0 ? (consumed / goal).clamp(0.0, 1.5) : 1.0;
      return 1.0 - (1.0 - ratio).abs();
    }

    final parts = <double>[
      if (log.totals.caloriesComplete)
        closeness(log.dailyCalories, log.calorieGoal),
      if (log.totals.proteinComplete)
        closeness(log.dailyProtein, log.proteinGoal),
    ];
    if (parts.isEmpty) return neutralNutritionAdherence;
    final mean = parts.reduce((a, b) => a + b) / parts.length;
    return mean.clamp(0.0, 1.0);
  }

  /// Extracts a standardized [FeatureVector] from an athlete's context snapshot or training events.
  FeatureVector extractFeatures({
    required String userId,
    FitnessContext? fitnessContext,
    List<WorkoutHistory>? workoutHistory,
    MLDataCollector? dataCollector,
  }) {
    final history =
        workoutHistory ?? fitnessContext?.workoutHistory ?? const [];
    final collector = dataCollector ?? MLDataCollector.instance;
    final events = collector.trainingEvents;

    // 1. Training Frequency (sessions in past 7 days)
    double frequency = 4.0;
    if (history.isNotEmpty) {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentWorkouts = history
          .where((w) => w.dateCompleted.isAfter(sevenDaysAgo))
          .length;
      frequency = recentWorkouts.toDouble().clamp(1.0, 7.0);
    }

    // 2. Average Volume
    double avgVolume = 9500.0;
    if (history.isNotEmpty) {
      final totalVol = history
          .take(5)
          .map((w) => w.totalVolume)
          .reduce((a, b) => a + b);
      avgVolume = totalVol / min(history.length, 5);
    }

    // 3. Strength Progression Rate
    double progression = 0.04;
    if (history.length >= 2) {
      final latest = history.first.totalVolume;
      final previous = history[1].totalVolume;
      if (previous > 0) {
        progression = ((latest - previous) / previous).clamp(-0.5, 0.5);
      }
    }

    // 4. Recovery Score
    final recovery =
        (fitnessContext?.recoveryState?.recoveryScore ??
                fitnessContext?.todayHealthMetric?.sleepQuality?.round() ??
                82)
            .toDouble();

    // 5. Nutrition Adherence
    final nutritionAdh = nutritionAdherenceOf(fitnessContext?.todayNutritionLog);

    // 6. Workout Completion Rate
    double completionRate = 0.92;
    final workoutEvents = events.where((e) => e.domain == 'workout').toList();
    if (workoutEvents.isNotEmpty) {
      final completions = workoutEvents
          .where((e) => e.eventType == 'workout_telemetry')
          .length;
      completionRate = (completions / workoutEvents.length).clamp(0.5, 1.0);
    }

    // 7. Exercise Preference Score
    double preferenceScore = 0.85;

    return FeatureVector(
      trainingFrequency: frequency,
      averageVolumeKg: avgVolume,
      strengthProgression: progression,
      recoveryScore: recovery,
      nutritionAdherence: nutritionAdh,
      workoutCompletionRate: completionRate,
      exercisePreferenceScore: preferenceScore,
    );
  }
}
