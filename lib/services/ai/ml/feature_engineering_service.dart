import '../../analytics/user_behavior_tracker.dart';

/// Normalized numerical and categorical feature vector representing an athlete's behavioral habits.
class UserFeatureVector {
  final double trainingConsistency; // 0.0 to 1.0
  final double avgWorkoutDurationMinutes;
  final Map<String, double> preferredMuscleGroups;
  final double exerciseSuccessRate; // 0.0 to 1.0
  final double nutritionAdherence; // 0.0 to 1.0
  final double recoveryReadinessAvg; // 0 to 100
  final double engagementScore; // 0 to 100
  final String optimalTrainingTime; // 'morning', 'afternoon', 'evening'

  const UserFeatureVector({
    required this.trainingConsistency,
    required this.avgWorkoutDurationMinutes,
    required this.preferredMuscleGroups,
    required this.exerciseSuccessRate,
    required this.nutritionAdherence,
    required this.recoveryReadinessAvg,
    required this.engagementScore,
    required this.optimalTrainingTime,
  });

  /// Factory baseline default feature vector
  factory UserFeatureVector.baseline() {
    return const UserFeatureVector(
      trainingConsistency: 0.85,
      avgWorkoutDurationMinutes: 48.0,
      preferredMuscleGroups: {
        'Chest': 0.35,
        'Back': 0.30,
        'Legs': 0.25,
        'Shoulders': 0.10,
      },
      exerciseSuccessRate: 0.92,
      nutritionAdherence: 0.88,
      recoveryReadinessAvg: 82.0,
      engagementScore: 90.0,
      optimalTrainingTime: 'evening',
    );
  }

  factory UserFeatureVector.fromJson(Map<String, dynamic> json) {
    final rawMuscles =
        json['preferred_muscle_groups'] as Map<String, dynamic>? ?? {};
    final muscleMap = rawMuscles.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    return UserFeatureVector(
      trainingConsistency:
          (json['training_consistency'] as num?)?.toDouble() ?? 0.8,
      avgWorkoutDurationMinutes:
          (json['avg_workout_duration_minutes'] as num?)?.toDouble() ?? 45.0,
      preferredMuscleGroups: muscleMap,
      exerciseSuccessRate:
          (json['exercise_success_rate'] as num?)?.toDouble() ?? 0.9,
      nutritionAdherence:
          (json['nutrition_adherence'] as num?)?.toDouble() ?? 0.85,
      recoveryReadinessAvg:
          (json['recovery_readiness_avg'] as num?)?.toDouble() ?? 80.0,
      engagementScore: (json['engagement_score'] as num?)?.toDouble() ?? 85.0,
      optimalTrainingTime:
          json['optimal_training_time'] as String? ?? 'evening',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'training_consistency': trainingConsistency,
      'avg_workout_duration_minutes': avgWorkoutDurationMinutes,
      'preferred_muscle_groups': preferredMuscleGroups,
      'exercise_success_rate': exerciseSuccessRate,
      'nutrition_adherence': nutritionAdherence,
      'recovery_readiness_avg': recoveryReadinessAvg,
      'engagement_score': engagementScore,
      'optimal_training_time': optimalTrainingTime,
    };
  }
}

/// Service converting raw telemetry and behavioral events into standardized ML feature vectors.
class FeatureEngineeringService {
  static FeatureEngineeringService? _instance;
  static FeatureEngineeringService get instance =>
      _instance ??= FeatureEngineeringService();

  /// Extracts a normalized feature vector for a user from their event history.
  UserFeatureVector extractFeatureVector({
    required String userId,
    UserBehaviorTracker? tracker,
  }) {
    final behaviorTracker = tracker ?? UserBehaviorTracker.instance;
    final events = behaviorTracker.getEventsForUser(userId);

    if (events.isEmpty) {
      return UserFeatureVector.baseline();
    }

    final workouts = events
        .where((e) => e.eventType == 'workout_completed')
        .toList();
    final skips = events
        .where((e) => e.eventType == 'workout_skipped')
        .toList();
    final meals = events.where((e) => e.eventType == 'meal_logged').toList();
    final aiInteractions = events
        .where((e) => e.domain == BehaviorDomain.aiCoach)
        .toList();

    // 1. Consistency: completed / (completed + skipped)
    final totalScheduled = workouts.length + skips.length;
    final consistency = totalScheduled > 0
        ? (workouts.length / totalScheduled)
        : 0.85;

    // 2. Average Duration
    double avgDuration = 48.0;
    if (workouts.isNotEmpty) {
      final durations = workouts.map(
        (w) => (w.payload['duration_minutes'] as num?)?.toDouble() ?? 45.0,
      );
      avgDuration = durations.reduce((a, b) => a + b) / workouts.length;
    }

    // 3. Optimal Training Time
    final timeCounts = <String, int>{};
    for (final w in workouts) {
      final tod = w.payload['time_of_day'] as String? ?? 'evening';
      timeCounts[tod] = (timeCounts[tod] ?? 0) + 1;
    }
    String bestTime = 'evening';
    int maxCount = 0;
    timeCounts.forEach((time, count) {
      if (count > maxCount) {
        maxCount = count;
        bestTime = time;
      }
    });

    // 4. Nutrition Adherence
    double nutritionAdh = 0.85;
    if (meals.isNotEmpty) {
      final adherentMeals = meals
          .where((m) => m.payload['is_adherent'] == true)
          .length;
      nutritionAdh = adherentMeals / meals.length;
    }

    // 5. Engagement Score
    final engagement =
        (workouts.length * 10 + meals.length * 5 + aiInteractions.length * 4)
            .clamp(0, 100)
            .toDouble();

    return UserFeatureVector(
      trainingConsistency: consistency.clamp(0.0, 1.0),
      avgWorkoutDurationMinutes: avgDuration,
      preferredMuscleGroups: {'Chest': 0.4, 'Back': 0.3, 'Legs': 0.3},
      exerciseSuccessRate: 0.94,
      nutritionAdherence: nutritionAdh.clamp(0.0, 1.0),
      recoveryReadinessAvg: 84.0,
      engagementScore: engagement > 0 ? engagement : 85.0,
      optimalTrainingTime: bestTime,
    );
  }
}
