import 'dart:math';
import 'ml_privacy_manager.dart';

/// Event payload stored for offline machine learning model training and calibration.
class MLTrainingEvent {
  final String id;
  final String anonymizedUserId;
  final String domain; // 'workout', 'nutrition', 'recovery', 'behavior'
  final String eventType;
  final Map<String, dynamic> featurePayload;
  final bool isAnonymized;
  final DateTime timestamp;

  const MLTrainingEvent({
    required this.id,
    required this.anonymizedUserId,
    required this.domain,
    required this.eventType,
    required this.featurePayload,
    this.isAnonymized = true,
    required this.timestamp,
  });

  factory MLTrainingEvent.fromJson(Map<String, dynamic> json) {
    return MLTrainingEvent(
      id: json['id'] as String? ?? '',
      anonymizedUserId:
          json['user_id'] as String? ??
          json['anonymized_user_id'] as String? ??
          '',
      domain: json['domain'] as String? ?? 'workout',
      eventType: json['event_type'] as String? ?? '',
      featurePayload: json['feature_payload'] != null
          ? Map<String, dynamic>.from(json['feature_payload'] as Map)
          : (json['payload'] != null
                ? Map<String, dynamic>.from(json['payload'] as Map)
                : {}),
      isAnonymized: json['is_anonymized'] as bool? ?? true,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': anonymizedUserId,
      'anonymized_user_id': anonymizedUserId,
      'domain': domain,
      'event_type': eventType,
      'feature_payload': featurePayload,
      'is_anonymized': isAnonymized,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Ingests and sanitizes athlete telemetry across workout, nutrition, recovery, and behavioral domains
/// to create proprietary training sets for on-device machine learning models.
class MLDataCollector {
  static MLDataCollector? _instance;
  static MLDataCollector get instance => _instance ??= MLDataCollector();

  final List<MLTrainingEvent> _trainingEvents = [];
  final MLPrivacyManager _privacyManager;

  MLDataCollector({MLPrivacyManager? privacyManager})
    : _privacyManager = privacyManager ?? MLPrivacyManager.instance;

  /// Clear in-memory event buffer (useful for test isolation)
  void reset() {
    _trainingEvents.clear();
  }

  /// All collected training events
  List<MLTrainingEvent> get trainingEvents =>
      List.unmodifiable(_trainingEvents);

  /// 1. Collect Workout ML Telemetry
  bool collectWorkoutData({
    required String rawUserId,
    required String workoutName,
    required String split,
    required List<String> exercises,
    required double totalVolumeKg,
    required int totalSets,
    required int totalReps,
    required double averageWeightKg,
    required double progressionRate, // e.g. +2.5% strength gain
    required int durationMinutes,
    Map<String, dynamic> extraMetrics = const {},
  }) {
    if (!_privacyManager.hasConsent) return false;

    final anonId = _privacyManager.anonymizeUserId(rawUserId);
    final sanitizedMetrics = _privacyManager.sanitizeFeatures(extraMetrics);

    final event = MLTrainingEvent(
      id: 'mle_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      anonymizedUserId: anonId,
      domain: 'workout',
      eventType: 'workout_telemetry',
      featurePayload: {
        'workout_name': workoutName,
        'split': split,
        'exercises': exercises,
        'total_volume_kg': totalVolumeKg,
        'total_sets': totalSets,
        'total_reps': totalReps,
        'average_weight_kg': averageWeightKg,
        'progression_rate': progressionRate,
        'duration_minutes': durationMinutes,
        ...sanitizedMetrics,
      },
      isAnonymized: true,
      timestamp: DateTime.now(),
    );

    _trainingEvents.add(event);
    return true;
  }

  /// 2. Collect Nutrition ML Telemetry
  bool collectNutritionData({
    required String rawUserId,
    required int caloriesConsumed,
    required int calorieTarget,
    required double proteinGrams,
    required double proteinTarget,
    required double carbsGrams,
    required double fatGrams,
    required double adherenceRate, // 0.0 to 1.0
    Map<String, dynamic> extraMetrics = const {},
  }) {
    if (!_privacyManager.hasConsent) return false;

    final anonId = _privacyManager.anonymizeUserId(rawUserId);
    final sanitizedMetrics = _privacyManager.sanitizeFeatures(extraMetrics);

    final event = MLTrainingEvent(
      id: 'mle_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      anonymizedUserId: anonId,
      domain: 'nutrition',
      eventType: 'nutrition_telemetry',
      featurePayload: {
        'calories_consumed': caloriesConsumed,
        'calorie_target': calorieTarget,
        'protein_grams': proteinGrams,
        'protein_target': proteinTarget,
        'carbs_grams': carbsGrams,
        'fat_grams': fatGrams,
        'adherence_rate': adherenceRate,
        ...sanitizedMetrics,
      },
      isAnonymized: true,
      timestamp: DateTime.now(),
    );

    _trainingEvents.add(event);
    return true;
  }

  /// 3. Collect Recovery & Autonomic ML Telemetry
  bool collectRecoveryData({
    required String rawUserId,
    required double sleepHours,
    required double hrvScore,
    required int restingHeartRate,
    required double readinessScore, // 0 to 100
    Map<String, dynamic> extraMetrics = const {},
  }) {
    if (!_privacyManager.hasConsent) return false;

    final anonId = _privacyManager.anonymizeUserId(rawUserId);
    final sanitizedMetrics = _privacyManager.sanitizeFeatures(extraMetrics);

    final event = MLTrainingEvent(
      id: 'mle_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      anonymizedUserId: anonId,
      domain: 'recovery',
      eventType: 'recovery_telemetry',
      featurePayload: {
        'sleep_hours': sleepHours,
        'hrv_score': hrvScore,
        'resting_heart_rate': restingHeartRate,
        'readiness_score': readinessScore,
        ...sanitizedMetrics,
      },
      isAnonymized: true,
      timestamp: DateTime.now(),
    );

    _trainingEvents.add(event);
    return true;
  }

  /// 4. Collect Athlete Behavioral & Interaction ML Telemetry
  bool collectBehaviorData({
    required String rawUserId,
    required double appUsageFrequency, // opens per week
    required double trainingConsistency, // completed / scheduled
    required List<String> preferredMuscleGroups,
    required List<String> favoriteExercises,
    Map<String, dynamic> extraMetrics = const {},
  }) {
    if (!_privacyManager.hasConsent) return false;

    final anonId = _privacyManager.anonymizeUserId(rawUserId);
    final sanitizedMetrics = _privacyManager.sanitizeFeatures(extraMetrics);

    final event = MLTrainingEvent(
      id: 'mle_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      anonymizedUserId: anonId,
      domain: 'behavior',
      eventType: 'behavior_telemetry',
      featurePayload: {
        'app_usage_frequency': appUsageFrequency,
        'training_consistency': trainingConsistency,
        'preferred_muscle_groups': preferredMuscleGroups,
        'favorite_exercises': favoriteExercises,
        ...sanitizedMetrics,
      },
      isAnonymized: true,
      timestamp: DateTime.now(),
    );

    _trainingEvents.add(event);
    return true;
  }

  /// Query collected training events for a specific domain
  List<MLTrainingEvent> getEventsByDomain(String domain) {
    return _trainingEvents.where((e) => e.domain == domain).toList();
  }
}
