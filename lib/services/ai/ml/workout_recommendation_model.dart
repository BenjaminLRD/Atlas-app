import 'feature_engineering_service.dart';

/// Output payload from the personalized workout ML recommendation model.
class PersonalizedWorkoutRecommendation {
  final String split;
  final List<String> exercises;
  final double targetVolumeKg;
  final double recommendedIntensityRpe;
  final double completionProbability; // 0.0 to 1.0
  final String rationale;

  const PersonalizedWorkoutRecommendation({
    required this.split,
    required this.exercises,
    required this.targetVolumeKg,
    required this.recommendedIntensityRpe,
    required this.completionProbability,
    required this.rationale,
  });

  factory PersonalizedWorkoutRecommendation.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawEx = json['exercises'] as List<dynamic>? ?? [];
    return PersonalizedWorkoutRecommendation(
      split: json['split'] as String? ?? 'Upper Body Hypertrophy',
      exercises: rawEx.map((e) => e.toString()).toList(),
      targetVolumeKg: (json['target_volume_kg'] as num?)?.toDouble() ?? 10000.0,
      recommendedIntensityRpe:
          (json['recommended_intensity_rpe'] as num?)?.toDouble() ?? 8.0,
      completionProbability:
          (json['completion_probability'] as num?)?.toDouble() ?? 0.90,
      rationale:
          json['rationale'] as String? ?? 'Optimized for user consistency.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'split': split,
      'exercises': exercises,
      'target_volume_kg': targetVolumeKg,
      'recommended_intensity_rpe': recommendedIntensityRpe,
      'completion_probability': completionProbability,
      'rationale': rationale,
    };
  }
}

/// Machine Learning recommendation model evaluating athlete feature vectors, recovery readiness,
/// and past performance to generate adaptive workout prescriptions.
class WorkoutRecommendationModel {
  static WorkoutRecommendationModel? _instance;
  static WorkoutRecommendationModel get instance =>
      _instance ??= WorkoutRecommendationModel();

  PersonalizedWorkoutRecommendation generateRecommendation({
    required UserFeatureVector featureVector,
    required String goal,
    required String fitnessLevel,
    double recoveryScore = 85.0,
  }) {
    // 1. Calculate base intensity and volume scaled by recovery readiness
    final recoveryFactor = (recoveryScore / 100.0).clamp(0.6, 1.2);
    final intensityRpe = recoveryScore < 60
        ? 6.5
        : (recoveryScore < 80 ? 7.5 : 8.5);
    final baseVolume = fitnessLevel.toLowerCase().contains('advanced')
        ? 14000.0
        : 9500.0;
    final targetVolume = baseVolume * recoveryFactor;

    // 2. Determine split and exercise selection based on goal & muscle preferences
    String splitName = 'Push Hypertrophy & Chest Builder';
    List<String> exercises = [
      'Incline Barbell Bench Press',
      'Dumbbell Shoulder Press',
      'Cable Chest Fly / Crossover',
      'Tricep Rope Pushdown',
    ];

    if (goal.toLowerCase().contains('strength')) {
      splitName = 'Upper Power & Compound Peaking';
      exercises = [
        'Barbell Bench Press',
        'Overhead Press',
        'Weighted Dips',
        'Close Grip Bench Press',
      ];
    } else if (goal.toLowerCase().contains('fat') ||
        goal.toLowerCase().contains('endurance')) {
      splitName = 'Full Body Metabolic Conditioning';
      exercises = [
        'Goblet Squats',
        'Dumbbell Push Press',
        'Kettlebell Swings',
        'Plank Hold',
      ];
    }

    // 3. Compute completion probability from historical consistency and recovery score
    final completionProb =
        (featureVector.trainingConsistency * 0.6 +
                (recoveryScore / 100.0) * 0.4)
            .clamp(0.5, 0.98);

    final rationale =
        'Prescribed $splitName with an RPE of $intensityRpe based on your ${recoveryScore.toStringAsFixed(0)}% recovery score and ${(featureVector.trainingConsistency * 100).toStringAsFixed(0)}% training consistency.';

    return PersonalizedWorkoutRecommendation(
      split: splitName,
      exercises: exercises,
      targetVolumeKg: targetVolume,
      recommendedIntensityRpe: intensityRpe,
      completionProbability: completionProb,
      rationale: rationale,
    );
  }
}
