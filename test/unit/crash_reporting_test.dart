import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/config/app_config.dart';
import 'package:atlas/services/monitoring/mock_crash_service.dart';
import 'package:atlas/services/monitoring/monitoring_manager.dart';
import 'package:atlas/services/monitoring/performance_tracker.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/widgets/error/error_card.dart';
import 'package:atlas/widgets/error/error_message_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCrashService mockService;
  late MonitoringManager monitoring;

  setUp(() async {
    mockService = MockCrashService();
    monitoring = MonitoringManager.instance;
    monitoring.setService(mockService, isEnabled: false);
    await monitoring.clear();
  });

  group('Phase 1 & 2 — Crash Reporting Disabled vs Enabled Mode', () {
    test(
      'Disabled Mode (Dev): No external calls or error recording occurs',
      () async {
        await monitoring.initialize(AppConfig.dev());
        expect(monitoring.isEnabled, isFalse);

        await monitoring.recordError(
          Exception('Test non-fatal exception'),
          StackTrace.current,
          reason: 'Developer test',
        );
        await monitoring.log('Test breadcrumb');
        await monitoring.setUserContext('usr_123');

        expect(mockService.recordedErrors.isEmpty, isTrue);
        expect(mockService.breadcrumbLogs.isEmpty, isTrue);
        expect(mockService.currentUserId, isNull);
      },
    );

    test(
      'Enabled Mode (Prod): Errors, logs, and user context are captured',
      () async {
        await monitoring.initialize(AppConfig.prod());
        expect(monitoring.isEnabled, isTrue);

        final stack = StackTrace.current;
        await monitoring.recordError(
          const FormatException('Malformed response payload'),
          stack,
          reason: 'Network parsing error',
          fatal: true,
        );

        expect(mockService.recordedErrors.length, equals(1));
        final recorded = mockService.recordedErrors.first;
        expect(recorded.error, isA<FormatException>());
        expect(recorded.fatal, isTrue);
        expect(recorded.reason, equals('Network parsing error'));
        expect(recorded.stackTrace, equals(stack));

        await monitoring.log('User navigated to Dashboard');
        expect(
          mockService.breadcrumbLogs,
          contains('User navigated to Dashboard'),
        );

        await monitoring.setUserContext(
          'usr_super_athlete',
          appVersion: '2.4.0',
          environment: 'production',
        );
        expect(mockService.currentUserId, equals('usr_super_athlete'));
        expect(mockService.customKeys['app_version'], equals('2.4.0'));
        expect(mockService.customKeys['environment'], equals('production'));
      },
    );
  });

  group('Phase 6 — Privacy & PII Log Sanitization', () {
    test(
      'Strictly strips passwords, tokens, DOB, and health metrics from logs',
      () async {
        await monitoring.initialize(AppConfig.prod());

        final rawAttributes = {
          'user_id': 'usr_99',
          'password': 'PlainTextPassword123!',
          'access_token': 'jwt_secret_token_xyz',
          'auth_token': 'bearer_token_abc',
          'dob': '1995-05-15',
          'heartRate': 155,
          'heart_rate_bpm': 160,
          'sleepMinutes': 450,
          'resting_heart_rate': 58,
          'private_phone': '+91 9876543210',
          'screen_name': 'WorkoutSessionScreen',
        };

        await monitoring.recordError(
          Exception('Render error'),
          null,
          customAttributes: rawAttributes,
        );

        final recorded = mockService.recordedErrors.first;
        final attrs = recorded.customAttributes;

        // Safe metadata preserved
        expect(attrs['user_id'], equals('usr_99'));
        expect(attrs['screen_name'], equals('WorkoutSessionScreen'));

        // PII and health data redacted
        expect(attrs['password'], equals('[REDACTED_PII]'));
        expect(attrs['access_token'], equals('[REDACTED_PII]'));
        expect(attrs['auth_token'], equals('[REDACTED_PII]'));
        expect(attrs['dob'], equals('[REDACTED_PII]'));
        expect(attrs['heartRate'], equals('[REDACTED_PII]'));
        expect(attrs['heart_rate_bpm'], equals('[REDACTED_PII]'));
        expect(attrs['sleepMinutes'], equals('[REDACTED_PII]'));
        expect(attrs['resting_heart_rate'], equals('[REDACTED_PII]'));
        expect(attrs['private_phone'], equals('[REDACTED_PII]'));
      },
    );
  });

  group('Phase 5 & 9 — Specialized Service Error & Offline Queue Tracking', () {
    test('tracks AI service, Supabase, and Health Connect failures', () async {
      await monitoring.initialize(AppConfig.prod());

      // 1. AI Error
      await monitoring.trackAiServiceError(
        TimeoutException('Gemini generation timed out'),
        null,
        provider: 'gemini-1.5-flash',
        promptTopic: 'workout_generation',
      );

      // 2. Supabase Error
      await monitoring.trackSupabaseError(
        const PostgresSecurityException('Access Denied', table: 'workouts'),
        null,
        table: 'workout_sessions',
        operation: 'UPDATE',
      );

      // 3. Health Connect Error
      await monitoring.trackHealthConnectError(
        Exception('Permission denied for steps and heart rate'),
        null,
        operation: 'READ_TELEMETRY',
        deviceType: 'smartwatch',
      );

      // 4. Offline Queue Failure
      await monitoring.trackOfflineActionFailure(
        'WORKOUT_UPLOAD',
        3,
        const SocketException('Connection refused'),
      );

      expect(mockService.recordedErrors.length, equals(4));

      final aiError = mockService.recordedErrors[0];
      expect(aiError.customAttributes['service'], equals('ai_coach'));
      expect(aiError.customAttributes['provider'], equals('gemini-1.5-flash'));

      final supaError = mockService.recordedErrors[1];
      expect(supaError.customAttributes['service'], equals('supabase'));
      expect(supaError.customAttributes['table'], equals('workout_sessions'));

      final healthError = mockService.recordedErrors[2];
      expect(healthError.customAttributes['service'], equals('health_connect'));

      final offlineError = mockService.recordedErrors[3];
      expect(offlineError.customAttributes['service'], equals('offline_queue'));
      expect(
        offlineError.customAttributes['action_type'],
        equals('WORKOUT_UPLOAD'),
      );
      expect(offlineError.customAttributes['retry_count'], equals(3));
    });
  });

  group('Phase 7 — Performance Monitoring', () {
    test('records app startup duration and custom operation spans', () async {
      final tracker = PerformanceTracker.instance;
      tracker.clear();

      // Cold startup
      tracker.recordAppStartup(
        duration: const Duration(milliseconds: 320),
        isColdLaunch: true,
      );
      expect(
        tracker.completedTraces['app_startup_cold'],
        equals(const Duration(milliseconds: 320)),
      );

      // Async measurement
      final result = await tracker.measureAsync('dashboard_load', () async {
        await Future.delayed(const Duration(milliseconds: 20));
        return 'loaded_dashboard_data';
      }, attributes: {'tab': 'home'});

      expect(result, equals('loaded_dashboard_data'));
      expect(tracker.completedTraces.containsKey('dashboard_load'), isTrue);
      expect(
        tracker.completedTraces['dashboard_load']!.inMilliseconds,
        greaterThanOrEqualTo(15),
      );
    });
  });

  group('Phase 8 — User-Friendly Error Mapping & Widget Tests', () {
    test('maps raw technical errors into friendly athlete messages', () {
      final socketResult = ErrorMessageMapper.map(
        const SocketException('Failed lookup'),
      );
      expect(socketResult.title, equals('No Internet Connection'));
      expect(socketResult.message, contains('Check your internet connection'));

      final timeoutResult = ErrorMessageMapper.map(
        TimeoutException('Request timed out'),
      );
      expect(timeoutResult.title, equals('Request Timed Out'));

      final rlsResult = ErrorMessageMapper.map(
        const PostgresSecurityException('Access denied', table: 'workouts'),
      );
      expect(rlsResult.title, equals('Access Restricted'));
    });

    testWidgets(
      'ErrorCard and RetryButton render friendly copy and respond to taps',
      (WidgetTester tester) async {
        bool retried = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ErrorCard(
                error: const SocketException('No route to host'),
                onRetry: () {
                  retried = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('No Internet Connection'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);

        await tester.tap(find.text('Try Again'));
        await tester.pump();

        expect(retried, isTrue);
      },
    );
  });
}
