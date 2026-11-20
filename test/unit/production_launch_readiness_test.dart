import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/config/environment/environment_manager.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/services/analytics/app_analytics_service.dart';
import 'package:atlas/services/showcase_mode_service.dart';
import 'package:atlas/services/monitoring/mock_crash_service.dart';
import 'package:atlas/services/monitoring/monitoring_manager.dart';
import 'package:atlas/utils/security_auditor.dart';

void main() {
  group('Phase 12: Production Launch Readiness & Reliability Test Suite', () {
    setUp(() {
      EnvironmentManager.resetInstance();
      MonitoringManager.resetInstance();
      AppAnalyticsService.resetInstance();
      ShowcaseModeService.resetInstance();
    });

    test(
      '1. EnvironmentManager parses configuration and environments correctly',
      () {
        final env = EnvironmentManager.instance;
        expect(env.config.apiBaseUrl, isNotEmpty);
        expect(env.config.supabaseUrl, isNotEmpty);
        expect(env.config.supabaseAnonKey, isNotEmpty);

        // Custom Production Config
        const prodConfig = EnvironmentConfig(
          environment: AppEnvironmentType.production,
          apiBaseUrl: 'https://api.Atlas.ai',
          supabaseUrl: 'https://supabase.Atlas.co',
          supabaseAnonKey: 'prod_anon_secure_jwt',
          enableAnalytics: true,
          enableCrashReporting: true,
          enableLiveAI: true,
        );

        env.setConfig(prodConfig);
        expect(env.config.isProduction, isTrue);
        expect(env.config.isDevelopment, isFalse);
        expect(env.config.apiBaseUrl, equals('https://api.Atlas.ai'));
      },
    );

    test(
      '2. CrashReportingService records exceptions, custom keys, and redacts PII',
      () async {
        final mockCrash = MockCrashService();
        await mockCrash.initialize();
        expect(mockCrash.isInitialized, isTrue);

        // Set user and logs
        await mockCrash.setUserIdentifier('usr_athlete_99');
        expect(mockCrash.currentUserId, equals('usr_athlete_99'));

        await mockCrash.logEvent('Navigated to WorkoutSessionScreen');
        expect(
          mockCrash.breadcrumbLogs,
          contains('Navigated to WorkoutSessionScreen'),
        );

        // Record caught exception
        final exception = FormatException('Invalid macro string');
        await mockCrash.recordException(
          exception,
          StackTrace.current,
          reason: 'Meal Macro Parse Error',
        );

        expect(mockCrash.recordedErrors.length, equals(1));
        expect(
          mockCrash.recordedErrors.first.reason,
          equals('Meal Macro Parse Error'),
        );
        expect(mockCrash.recordedErrors.first.fatal, isFalse);

        // PII Sanitization verification via MonitoringManager
        final rawAttributes = {
          'user_name': 'John Doe',
          'password': 'secret_password_123',
          'token': 'bearer_token_xyz',
          'device': 'Pixel 8 Pro',
          'reps': 12,
        };

        final sanitized = MonitoringManager.sanitizeAttributes(rawAttributes);
        expect(sanitized['password'], equals('[REDACTED_PII]'));
        expect(sanitized['token'], equals('[REDACTED_PII]'));
        expect(sanitized['device'], equals('Pixel 8 Pro'));
        expect(sanitized['reps'], equals(12));
      },
    );

    test(
      '3. AppAnalyticsService captures key funnel events with privacy protection',
      () {
        final analytics = AppAnalyticsService.instance;
        analytics.setUserId('usr_prod_101');

        // User Funnel
        analytics.logSignupCompleted(authMethod: 'google');
        analytics.logGoalSelected('hypertrophy');
        analytics.logOnboardingCompleted(
          fitnessLevel: 'intermediate',
          goal: 'hypertrophy',
        );

        // Workout Funnel
        analytics.logWorkoutGenerated(split: 'push', exerciseCount: 5);
        analytics.logWorkoutStarted(workoutName: 'Push Hypertrophy');
        analytics.logWorkoutCompleted(
          workoutName: 'Push Hypertrophy',
          durationSeconds: 3200,
          totalVolume: 14500.0,
          completedExercises: 5,
        );
        analytics.logPRAchieved(exerciseName: 'Bench Press', weightKg: 100.0);

        // Nutrition Funnel
        analytics.logAIScanUsed(scanType: 'meal_photo');
        analytics.logFoodLogged(source: 'ai_vision', calories: 650.0);

        // AI Funnel
        analytics.logAIChatStarted(entryPoint: 'dashboard_fab');
        analytics.logRecommendationAccepted(recommendationId: 'rec_deload_1');

        // Community Funnel
        analytics.logPostCreated(postType: 'workout');
        analytics.logChallengeJoined(
          challengeId: 'ch_on_bench',
          isSponsored: true,
        );

        final log = analytics.eventLog;
        expect(log.length, equals(13));
        expect(log.any((e) => e.name == 'signup_completed'), isTrue);
        expect(log.any((e) => e.name == 'workout_completed'), isTrue);
        expect(log.any((e) => e.name == 'pr_achieved'), isTrue);
        expect(log.any((e) => e.name == 'ai_scan_used'), isTrue);

        final completedEvent = log.firstWhere(
          (e) => e.name == 'workout_completed',
        );
        expect(completedEvent.parameters['total_volume'], equals(14500.0));
        expect(completedEvent.parameters['user_id'], equals('usr_prod_101'));
      },
    );

    test('4. ShowcaseModeService provides rich investor demonstration dataset', () {
      final demo = ShowcaseModeService.instance;
      demo.enableDemoMode();
      expect(demo.isDemoMode, isTrue);

      final profile = demo.getDemoUserProfile();
      expect(profile.name, contains('Alex'));
      expect(profile.fitnessGoal, isNotEmpty);

      final history = demo.getDemoWorkoutHistory();
      expect(history.length, greaterThanOrEqualTo(5));
      expect(history.first.totalVolume, greaterThan(10000.0));
      expect(history.first.personalRecords.isNotEmpty, isTrue);

      final badges = demo.getDemoBadges();
      expect(badges.length, greaterThanOrEqualTo(4));
      expect(badges.any((b) => b.title.contains('110kg Bench')), isTrue);

      final posts = demo.getDemoCommunityPosts();
      expect(posts.length, greaterThanOrEqualTo(2));

      final fitnessContext = demo.getDemoFitnessContext();
      expect(
        fitnessContext.userGoal?.goalType,
        equals(FitnessGoalType.muscleGain),
      );
      expect(fitnessContext.recoveryState?.recoveryScore, equals(88));
    });

    test(
      '5. SecurityAuditor validates production security rules and sanitization',
      () {
        final audit = SecurityAuditor.runAudit();
        expect(audit.passedChecks.isNotEmpty, isTrue);
        expect(audit.violations.isEmpty, isTrue);
      },
    );
  });
}
