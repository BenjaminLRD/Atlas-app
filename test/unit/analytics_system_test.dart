import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_feedback.dart';
import 'package:atlas/services/analytics/analytics_service.dart';
import 'package:atlas/services/crash/crash_reporting_service.dart';
import 'package:atlas/services/error/app_error_handler.dart';
import 'package:atlas/services/feedback/beta_feedback_service.dart';
import 'package:atlas/services/performance/performance_monitoring_service.dart';
import 'package:atlas/services/supabase/database_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AnalyticsService.instance.clearHistory();
    PerformanceMonitoringService.instance.clearMetrics();
    CrashReportingService.instance.clearCrashLogs();
    BetaFeedbackService.instance.clearFeedback();
  });

  group(
    'Atlas Startup Launch Preparation — Product Analytics & Beta Infrastructure (Phase G.1)',
    () {
      test(
        '1. AnalyticsService tracks core product events and screen views with taxonomy',
        () {
          final analytics = AnalyticsService.instance;

          analytics.trackOnboardingStarted();
          analytics.trackGoalSelected('muscle_hypertrophy');
          analytics.trackProfileCompleted(experienceLevel: 'advanced');

          analytics.trackWorkoutGenerated('push');
          analytics.trackWorkoutStarted('Chest & Triceps Hypertrophy');
          analytics.trackExerciseCompleted('Incline Barbell Bench', 4, 3200.0);
          analytics.trackWorkoutFinished(
            'Chest & Triceps Hypertrophy',
            52,
            11400.0,
          );
          analytics.trackPersonalRecordCreated('Incline Barbell Bench', 105.0);

          analytics.trackFoodScanStarted();
          analytics.trackFoodLogged('Grilled Chicken Breast', 350, 42.0);
          analytics.trackBarcodeScanCompleted('890123456789', true);

          analytics.trackAiCoachOpened();
          analytics.trackMessageSent('hypertrophy_advice');
          analytics.trackRecommendationGenerated('protein_intake');

          analytics.trackPostCreated('workout_pr');
          analytics.trackChallengeJoined('summer_shred_2026');

          analytics.trackScreenView(
            'WorkoutActiveScreen',
            screenClass: 'WorkoutFlow',
          );
          analytics.trackUserAction(
            'toggled_rest_timer',
            parameters: {'timer_seconds': 90},
          );

          final history = analytics.eventHistory;
          expect(history.length, greaterThanOrEqualTo(16));

          expect(
            history.any(
              (e) => e['event_name'] == AnalyticsEvents.onboardingStarted,
            ),
            isTrue,
          );
          expect(
            history.any(
              (e) => e['event_name'] == AnalyticsEvents.workoutFinished,
            ),
            isTrue,
          );
          expect(
            history.any((e) => e['event_name'] == AnalyticsEvents.foodLogged),
            isTrue,
          );
          expect(
            history.any(
              (e) => e['event_name'] == AnalyticsEvents.aiCoachOpened,
            ),
            isTrue,
          );
          expect(
            history.any((e) => e['event_name'] == AnalyticsEvents.postCreated),
            isTrue,
          );
          expect(
            history.any((e) => e['event_name'] == AnalyticsEvents.screenView),
            isTrue,
          );
          expect(
            history.any((e) => e['event_name'] == AnalyticsEvents.userAction),
            isTrue,
          );
        },
      );

      test(
        '2. PerformanceMonitoringService measures and aggregates system latencies',
        () async {
          final performance = PerformanceMonitoringService.instance;

          performance.trackAppStartupTime(285);
          expect(performance.appStartupTimeMs, equals(285));

          performance.trackScreenLoadingTime('DashboardScreen', 120);
          performance.trackApiLatency('fetch_workout_history', 150);
          performance.trackAiResponseTime('chat', 540);
          performance.trackImageProcessingTime('food_label', 380);

          // Test async measurement
          final result = await performance.measureAsync<String>(
            'tflite_pose_inference',
            () async {
              await Future.delayed(const Duration(milliseconds: 15));
              return 'pose_detected';
            },
          );
          expect(result, equals('pose_detected'));

          expect(
            performance.getAverageLatency('screen_load_DashboardScreen'),
            equals(120.0),
          );
          expect(
            performance.getAverageLatency('ai_response_chat'),
            equals(540.0),
          );
          expect(
            performance.getAverageLatency('tflite_pose_inference'),
            greaterThanOrEqualTo(10.0),
          );

          final allAverages = performance.getAllAverageLatencies();
          expect(allAverages.containsKey('app_startup'), isTrue);
          expect(
            allAverages.containsKey('image_processing_food_label'),
            isTrue,
          );
        },
      );

      test(
        '3. AppErrorHandler translates technical exceptions to friendly messages without exposing errors',
        () {
          final handler = AppErrorHandler.instance;

          // Auth error translation
          final authMsg = handler.handleError(
            Exception('invalid_grant: Invalid password provided'),
            context: 'auth',
          );
          expect(
            authMsg,
            contains('The email or password you entered is incorrect'),
          );
          expect(authMsg.contains('invalid_grant'), isFalse);

          // Network / Supabase error translation
          final netMsg = handler.handleError(
            Exception('SocketException: Connection refused on port 443'),
            context: 'supabase',
          );
          expect(netMsg, contains('Network connection is currently unstable'));
          expect(netMsg.contains('SocketException'), isFalse);

          // Gemini AI rate limit translation
          final aiMsg = handler.handleError(
            Exception('ResourceExhausted: Gemini quota exceeded for tier'),
            context: 'gemini',
          );
          expect(aiMsg, contains('Your AI Coach is taking a quick breather'));
          expect(aiMsg.contains('ResourceExhausted'), isFalse);

          // Camera scanner permission translation
          final scanMsg = handler.handleError(
            Exception('CameraException: permission denied by user'),
            context: 'scanner',
          );
          expect(scanMsg, contains('Camera access is required'));

          // Verify crash queue was populated for developers
          final crashLogs = CrashReportingService.instance.crashLogQueue;
          expect(crashLogs.length, equals(4));
        },
      );

      test(
        '4. BetaFeedbackService submits, serializes, and manages beta tester feedback',
        () async {
          final feedbackService = BetaFeedbackService.instance;
          const testUser = 'usr_tester_99';

          final success = await feedbackService.submitFeedback(
            userId: testUser,
            feedback:
                'The 1RM strength trajectory graph on the profile is incredibly motivating!',
            category: 'feature_request',
            priority: 'medium',
          );

          expect(success, isTrue);
          expect(feedbackService.feedbackList.length, equals(1));

          final userItems = feedbackService.getUserFeedbackList(testUser);
          expect(userItems.length, equals(1));
          expect(userItems.first.category, equals('feature_request'));
          expect(userItems.first.feedback, contains('1RM strength trajectory'));
          expect(userItems.first.deviceInfo, isNotEmpty);

          // Test UserFeedback model serialization
          final model = userItems.first;
          final json = model.toJson();
          final roundTrip = UserFeedback.fromJson(json);
          expect(roundTrip.id, equals(model.id));
          expect(roundTrip.userId, equals(model.userId));
          expect(roundTrip.category, equals(model.category));
        },
      );

      test(
        '5. Database models and mappers serialize Analytics and Beta Feedback tables',
        () {
          // 1. AnalyticsEventData
          final eventData = AnalyticsEventData(
            id: 'evt_01',
            userId: 'usr_db_01',
            eventName: 'workout_finished',
            properties: {'duration': 45, 'volume': 8500},
            clientTimestamp: DateTime.now(),
            createdAt: DateTime.now(),
          );
          final eventMap = SupabaseModelMappers.analyticsEventToTable(
            eventData,
          );
          expect(eventMap['id'], equals('evt_01'));
          expect(eventMap['user_id'], equals('usr_db_01'));
          expect(eventMap['event_name'], equals('workout_finished'));

          // 2. BetaFeedbackData
          final feedbackData = BetaFeedbackData(
            id: 'fb_01',
            userId: 'usr_db_01',
            feedback: 'Squat form analysis is working great.',
            category: 'bug',
            priority: 'high',
            deviceInfo: {'os': 'android', 'version': '1.1.51'},
            timestamp: DateTime.now(),
          );
          final feedbackMap = SupabaseModelMappers.betaFeedbackToTable(
            feedbackData,
          );
          expect(feedbackMap['id'], equals('fb_01'));
          expect(feedbackMap['category'], equals('bug'));
          expect(feedbackMap['priority'], equals('high'));

          // Table constants
          expect(
            SupabaseTableNames.analyticsEvents,
            equals('analytics_events'),
          );
          expect(SupabaseTableNames.betaFeedbacks, equals('beta_feedbacks'));
        },
      );
    },
  );
}
