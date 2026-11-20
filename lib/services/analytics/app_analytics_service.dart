import 'dart:async';

/// Structured telemetry event model for product analytics.
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    Map<String, dynamic>? parameters,
    DateTime? timestamp,
  }) : parameters = parameters != null
           ? Map<String, dynamic>.from(parameters)
           : {},
       timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'AnalyticsEvent(name: $name, parameters: $parameters)';
}

/// Centralized product analytics service for tracking user journeys, workout execution,
/// nutrition consistency, and AI interactions with privacy-first sanitization.
class AppAnalyticsService {
  static AppAnalyticsService? _instance;
  final List<AnalyticsEvent> _eventLog = [];
  final _eventStreamController = StreamController<AnalyticsEvent>.broadcast();
  bool _isEnabled = true;
  String? _userId;

  AppAnalyticsService();

  static AppAnalyticsService get instance =>
      _instance ??= AppAnalyticsService();

  static void resetInstance() {
    _instance = null;
  }

  Stream<AnalyticsEvent> get eventStream => _eventStreamController.stream;
  List<AnalyticsEvent> get eventLog => List.unmodifiable(_eventLog);

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Core generic tracking function
  void trackEvent(String name, [Map<String, dynamic>? parameters]) {
    if (!_isEnabled) return;

    final sanitizedParams = _sanitizeParameters(parameters);
    if (_userId != null) {
      sanitizedParams['user_id'] = _userId;
    }

    final event = AnalyticsEvent(name: name, parameters: sanitizedParams);

    _eventLog.add(event);
    _eventStreamController.add(event);
  }

  // --- 1. User Journey Events ---
  void logSignupCompleted({String authMethod = 'email'}) {
    trackEvent('signup_completed', {'auth_method': authMethod});
  }

  void logOnboardingCompleted({
    required String fitnessLevel,
    required String goal,
  }) {
    trackEvent('onboarding_completed', {
      'fitness_level': fitnessLevel,
      'goal': goal,
    });
  }

  void logGoalSelected(String goalType) {
    trackEvent('goal_selected', {'goal_type': goalType});
  }

  // --- 2. Workout Pipeline Events ---
  void logWorkoutGenerated({required String split, int exerciseCount = 4}) {
    trackEvent('workout_generated', {
      'split': split,
      'exercise_count': exerciseCount,
    });
  }

  void logWorkoutStarted({required String workoutName}) {
    trackEvent('workout_started', {'workout_name': workoutName});
  }

  void logWorkoutCompleted({
    required String workoutName,
    required int durationSeconds,
    required double totalVolume,
    required int completedExercises,
  }) {
    trackEvent('workout_completed', {
      'workout_name': workoutName,
      'duration_seconds': durationSeconds,
      'total_volume': totalVolume,
      'completed_exercises': completedExercises,
    });
  }

  void logPRAchieved({required String exerciseName, required double weightKg}) {
    trackEvent('pr_achieved', {
      'exercise_name': exerciseName,
      'weight_kg': weightKg,
    });
  }

  // --- 3. Nutrition Events ---
  void logFoodLogged({required String source, required double calories}) {
    trackEvent('food_logged', {
      'source': source, // 'barcode', 'ai_vision', 'search', 'manual'
      'calories': calories,
    });
  }

  void logAIScanUsed({required String scanType}) {
    trackEvent('ai_scan_used', {
      'scan_type': scanType,
    }); // 'meal_photo', 'barcode'
  }

  void logMealCompleted({required String mealType}) {
    trackEvent('meal_completed', {'meal_type': mealType});
  }

  // --- 4. AI Interaction Events ---
  void logAIChatStarted({String? entryPoint}) {
    trackEvent('ai_chat_started', {'entry_point': entryPoint ?? 'main_chat'});
  }

  void logRecommendationAccepted({required String recommendationId}) {
    trackEvent('recommendation_accepted', {
      'recommendation_id': recommendationId,
    });
  }

  void logRecommendationRejected({required String recommendationId}) {
    trackEvent('recommendation_rejected', {
      'recommendation_id': recommendationId,
    });
  }

  // --- 5. Community & Gamification Events ---
  void logPostCreated({required String postType}) {
    trackEvent('post_created', {'post_type': postType});
  }

  void logChallengeJoined({
    required String challengeId,
    bool isSponsored = false,
  }) {
    trackEvent('challenge_joined', {
      'challenge_id': challengeId,
      'is_sponsored': isSponsored,
    });
  }

  /// Privacy sanitizer: Never log sensitive PII, biometric raw ECG, medical data, or passwords.
  Map<String, dynamic> _sanitizeParameters(Map<String, dynamic>? input) {
    if (input == null) return {};
    final sanitized = <String, dynamic>{};

    final sensitiveKeys = [
      'password',
      'token',
      'secret',
      'auth',
      'email',
      'phone',
      'name',
      'full_name',
      'credit_card',
      'address',
    ];

    for (final entry in input.entries) {
      final keyLower = entry.key.toLowerCase();
      if (sensitiveKeys.any((s) => keyLower.contains(s))) {
        sanitized[entry.key] = '[REDACTED_PII]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }

    return sanitized;
  }

  void clear() {
    _eventLog.clear();
    _userId = null;
  }
}
