import 'package:flutter/foundation.dart';
import '../error/app_error_handler.dart';

/// Predefined taxonomy constants for product analytics tracking.
class AnalyticsEvents {
  // Onboarding Domain
  static const String onboardingStarted = 'onboarding_started';
  static const String goalSelected = 'goal_selected';
  static const String profileCompleted = 'profile_completed';

  // Workout Domain
  static const String workoutGenerated = 'workout_generated';
  static const String workoutStarted = 'workout_started';
  static const String exerciseCompleted = 'exercise_completed';
  static const String workoutFinished = 'workout_finished';
  static const String personalRecordCreated = 'personal_record_created';

  // Nutrition Domain
  static const String foodScanStarted = 'food_scan_started';
  static const String foodLogged = 'food_logged';
  static const String barcodeScanCompleted = 'barcode_scan_completed';

  // AI Coaching Domain
  static const String aiCoachOpened = 'ai_coach_opened';
  static const String messageSent = 'message_sent';
  static const String recommendationGenerated = 'recommendation_generated';

  // Community Domain
  static const String postCreated = 'post_created';
  static const String challengeJoined = 'challenge_joined';

  // Error Domain
  static const String appError = 'app_error';
  static const String screenView = 'screen_view';
  static const String userAction = 'user_action';
}

/// Abstract contract for user analytics event tracking.
abstract class AnalyticsProvider {
  void logEvent(String eventName, {Map<String, dynamic>? parameters});
  void setUserProperty(String key, String value);
  void setCurrentScreen(String screenName);
}

/// Debug implementation of [AnalyticsProvider] logging events in memory.
class DebugAnalyticsProvider implements AnalyticsProvider {
  final List<Map<String, dynamic>> loggedEvents = [];

  @override
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    final entry = {
      'event': eventName,
      'parameters': parameters ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    loggedEvents.insert(0, entry);
    if (loggedEvents.length > 200) {
      loggedEvents.removeLast();
    }
    debugPrint('[Analytics] Event: $eventName $parameters');
  }

  @override
  void setUserProperty(String key, String value) {
    debugPrint('[Analytics] UserProperty: $key = $value');
  }

  @override
  void setCurrentScreen(String screenName) {
    debugPrint('[Analytics] Screen: $screenName');
  }
}

/// Central Analytics Service providing unified product telemetry,
/// screen tracking, and user interaction measurement across Atlas.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  AnalyticsProvider _provider = DebugAnalyticsProvider();
  final List<Map<String, dynamic>> _inMemoryEvents = [];

  void setProvider(AnalyticsProvider provider) {
    _provider = provider;
  }

  AnalyticsProvider get provider => _provider;
  List<Map<String, dynamic>> get eventHistory =>
      List.unmodifiable(_inMemoryEvents);

  void clearHistory() {
    _inMemoryEvents.clear();
    if (_provider is DebugAnalyticsProvider) {
      (_provider as DebugAnalyticsProvider).loggedEvents.clear();
    }
  }

  /// 1. Track Arbitrary Event
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    final payload = parameters ?? {};
    _inMemoryEvents.insert(0, {
      'event_name': eventName,
      'event_data': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (_inMemoryEvents.length > 200) {
      _inMemoryEvents.removeLast();
    }

    _provider.logEvent(eventName, parameters: payload);
  }

  /// 2. Track Screen View
  void trackScreenView(String screenName, {String? screenClass}) {
    trackEvent(
      AnalyticsEvents.screenView,
      parameters: {
        'screen_name': screenName,
        'screen_class': ?screenClass,
      },
    );
    _provider.setCurrentScreen(screenName);
  }

  /// 3. Track User Error & Exception Telemetry
  void trackError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? extraData,
  }) {
    final safeMessage = AppErrorHandler.instance.handleError(
      error,
      stackTrace: stackTrace,
      context: context ?? 'analytics',
      extraData: extraData ?? {},
    );

    trackEvent(
      AnalyticsEvents.appError,
      parameters: {
        'error': error.toString(),
        'context': context ?? 'general',
        'user_friendly_message': safeMessage,
        ...?extraData,
      },
    );
  }

  /// 4. Track Specific User Action
  void trackUserAction(String action, {Map<String, dynamic>? parameters}) {
    trackEvent(
      AnalyticsEvents.userAction,
      parameters: {'action': action, ...?parameters},
    );
  }

  void setUserProperty(String key, String value) {
    _provider.setUserProperty(key, value);
  }

  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    trackEvent(eventName, parameters: parameters);
  }

  void setCurrentScreen(String screenName) {
    trackScreenView(screenName);
  }

  // --------------------------------------------------------------------------
  // TAXONOMY HELPER METHODS
  // --------------------------------------------------------------------------

  // Onboarding
  void trackOnboardingStarted() =>
      trackEvent(AnalyticsEvents.onboardingStarted);
  void trackGoalSelected(String goal) =>
      trackEvent(AnalyticsEvents.goalSelected, parameters: {'goal': goal});
  void trackProfileCompleted({String? experienceLevel}) => trackEvent(
    AnalyticsEvents.profileCompleted,
    parameters: {'experience_level': experienceLevel ?? 'intermediate'},
  );

  // Workout
  void trackWorkoutGenerated(String split) => trackEvent(
    AnalyticsEvents.workoutGenerated,
    parameters: {'split': split},
  );
  void trackWorkoutStarted(String workoutName) => trackEvent(
    AnalyticsEvents.workoutStarted,
    parameters: {'workout_name': workoutName},
  );
  void trackExerciseCompleted(String exercise, int sets, double volumeKg) =>
      trackEvent(
        AnalyticsEvents.exerciseCompleted,
        parameters: {'exercise': exercise, 'sets': sets, 'volume_kg': volumeKg},
      );
  void trackWorkoutFinished(
    String workoutName,
    int durationMinutes,
    double totalVolumeKg,
  ) => trackEvent(
    AnalyticsEvents.workoutFinished,
    parameters: {
      'workout_name': workoutName,
      'duration_minutes': durationMinutes,
      'total_volume_kg': totalVolumeKg,
    },
  );
  void trackPersonalRecordCreated(String exercise, double weightKg) =>
      trackEvent(
        AnalyticsEvents.personalRecordCreated,
        parameters: {'exercise': exercise, 'weight_kg': weightKg},
      );

  // Nutrition
  void trackFoodScanStarted() => trackEvent(AnalyticsEvents.foodScanStarted);
  void trackFoodLogged(String foodName, int calories, double proteinGrams) =>
      trackEvent(
        AnalyticsEvents.foodLogged,
        parameters: {
          'food_name': foodName,
          'calories': calories,
          'protein_grams': proteinGrams,
        },
      );
  void trackBarcodeScanCompleted(String barcode, bool itemFound) => trackEvent(
    AnalyticsEvents.barcodeScanCompleted,
    parameters: {'barcode': barcode, 'item_found': itemFound},
  );

  // AI Coach
  void trackAiCoachOpened() => trackEvent(AnalyticsEvents.aiCoachOpened);
  void trackMessageSent(String category) => trackEvent(
    AnalyticsEvents.messageSent,
    parameters: {'category': category},
  );
  void trackRecommendationGenerated(String recType) => trackEvent(
    AnalyticsEvents.recommendationGenerated,
    parameters: {'recommendation_type': recType},
  );

  // Community
  void trackPostCreated(String postType) => trackEvent(
    AnalyticsEvents.postCreated,
    parameters: {'post_type': postType},
  );
  void trackChallengeJoined(String challengeId) => trackEvent(
    AnalyticsEvents.challengeJoined,
    parameters: {'challenge_id': challengeId},
  );
}
