import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/services/billing/local_billing_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/config/app_config.dart';
import 'package:atlas/config/secrets_manager.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/analytics/analytics_service.dart';
import 'package:atlas/services/billing/production_billing_config.dart';
import 'package:atlas/services/crash/crash_reporting_service.dart';
import 'package:atlas/services/error/app_error_handler.dart';
import 'package:atlas/services/performance/performance_monitor.dart';
import 'package:atlas/utils/security_auditor.dart';
import 'package:atlas/widgets/common/app_error_widget.dart';
import 'package:atlas/widgets/common/app_loading_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppErrorHandler.instance.clearHistory();
    CrashReportingService.instance.clearCrashLogs();
    PerformanceMonitor.instance.clearMetrics();
    SecretsManager.clearSecrets();
  });

  group('AppConfig Environment Tests', () {
    test(
      'AppConfig dev, staging, and prod factories create correct settings',
      () {
        final dev = AppConfig.dev();
        expect(dev.isDevelopment, isTrue);
        expect(dev.enableAnalytics, isFalse);

        final staging = AppConfig.staging();
        expect(staging.isStaging, isTrue);

        final prod = AppConfig.prod();
        expect(prod.isProduction, isTrue);
        expect(prod.enableAnalytics, isTrue);

        final envProd = AppConfig.fromEnvironment(envName: 'prod');
        expect(envProd.isProduction, isTrue);
      },
    );
  });

  group('SecretsManager Unit Tests', () {
    test('setSecret, maskSecret, and isSecretConfigured behavior', () {
      SecretsManager.setSecret(
        'GEMINI_API_KEY',
        'AIzaSy1234567890SecretKey8xY',
      );
      expect(SecretsManager.isSecretConfigured('GEMINI_API_KEY'), isTrue);

      final masked = SecretsManager.maskSecret(
        SecretsManager.getSecret('GEMINI_API_KEY')!,
      );
      expect(masked, equals('AIza...y8xY'));

      expect(SecretsManager.maskSecret(''), equals('[EMPTY]'));
    });
  });

  group('AppErrorHandler Unit Tests', () {
    test('reportError records error in history and streams event', () async {
      final handler = AppErrorHandler.instance;
      expect(handler.errorHistory.isEmpty, isTrue);

      handler.reportError(
        'Test error message',
        StackTrace.current,
        context: 'unit_test',
      );
      expect(handler.errorHistory.length, equals(1));
      expect(
        handler.errorHistory.first.message,
        contains('Test error message'),
      );
    });

    test('initGlobalErrorHooks executes cleanly', () {
      final handler = AppErrorHandler.instance;
      handler.initGlobalErrorHooks();
      expect(handler, isNotNull);
    });
  });

  group('AnalyticsService Unit Tests', () {
    test('AnalyticsService logs events to active provider', () {
      final analytics = AnalyticsService.instance;
      final debugProvider = DebugAnalyticsProvider();
      analytics.setProvider(debugProvider);

      analytics.logEvent(
        'workout_completed',
        parameters: {'workout_id': 'w_1'},
      );
      expect(debugProvider.loggedEvents.length, equals(1));
      expect(
        debugProvider.loggedEvents.first['event'],
        equals('workout_completed'),
      );
    });
  });

  group('CrashReportingService Unit Tests', () {
    test('recordCrash logs crash entry with custom keys', () {
      final crashService = CrashReportingService.instance;
      crashService.setCustomKey('user_id', 'usr_local');
      crashService.recordCrash(
        'StateError: null pointer',
        StackTrace.current,
        reason: 'Test crash',
      );

      expect(crashService.crashLogQueue.length, equals(1));
      expect(crashService.crashLogQueue.first['reason'], equals('Test crash'));
      expect(
        crashService.crashLogQueue.first['customKeys']['user_id'],
        equals('usr_local'),
      );
    });
  });

  group('PerformanceMonitor Unit Tests', () {
    test(
      'measure records execution duration and updates average latencies',
      () async {
        final monitor = PerformanceMonitor.instance;
        final result = await monitor.measure('fetch_workout_history', () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 42;
        });

        expect(result, equals(42));
        expect(
          monitor.averageLatencies.containsKey('fetch_workout_history'),
          isTrue,
        );
        expect(
          monitor.averageLatencies['fetch_workout_history']!,
          greaterThanOrEqualTo(5.0),
        );
      },
    );
  });

  group('SecurityAuditor and ProductionBillingConfig Tests', () {
    test('SecurityAuditor runs audit and returns SecurityReport', () {
      final report = SecurityAuditor.runAudit(config: AppConfig.prod());
      expect(report.passedChecks.isNotEmpty, isTrue);
    });

    test('ProductionBillingConfig evaluates store readiness', () {
      // Not ready without a RevenueCat key (none in tests); debug builds fall
      // back to the test store, never to free Pro in release.
      expect(ProductionBillingConfig.isProductionReady(), isFalse);
      expect(ProductionBillingConfig.allProductIds.length, equals(3));
      expect(
        ProductionBillingConfig.resolveProvider(),
        isA<LocalBillingProvider>(),
      );
    });
  });

  group('Production UI Components Widget Tests', () {
    testWidgets('AppLoadingIndicator renders spinner and message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingIndicator(message: 'Loading fitness data...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading fitness data...'), findsOneWidget);
    });

    testWidgets('AppErrorWidget renders error message and handles retry tap', (
      tester,
    ) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(
              errorMessage: 'Network timeout',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Network timeout'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });
  });
}
