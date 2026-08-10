import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/config/app_config.dart';
import 'package:aizawl_gym/config/secrets_manager.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/screens/developer_diagnostics_screen.dart';
import 'package:aizawl_gym/services/analytics/analytics_service.dart';
import 'package:aizawl_gym/services/billing/production_billing_config.dart';
import 'package:aizawl_gym/services/crash/crash_reporting_service.dart';
import 'package:aizawl_gym/services/error/app_error_handler.dart';
import 'package:aizawl_gym/services/offline/offline_action_queue.dart';
import 'package:aizawl_gym/services/performance/performance_monitor.dart';
import 'package:aizawl_gym/utils/security_auditor.dart';
import 'package:aizawl_gym/widgets/common/app_error_widget.dart';
import 'package:aizawl_gym/widgets/common/app_loading_indicator.dart';

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
    test('AppConfig dev, staging, and prod factories create correct settings', () {
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
    });
  });

  group('SecretsManager Unit Tests', () {
    test('setSecret, maskSecret, and isSecretConfigured behavior', () {
      SecretsManager.setSecret('GEMINI_API_KEY', 'AIzaSy1234567890SecretKey8xY');
      expect(SecretsManager.isSecretConfigured('GEMINI_API_KEY'), isTrue);

      final masked = SecretsManager.maskSecret(SecretsManager.getSecret('GEMINI_API_KEY')!);
      expect(masked, equals('AIza...y8xY'));

      expect(SecretsManager.maskSecret(''), equals('[EMPTY]'));
    });
  });

  group('AppErrorHandler Unit Tests', () {
    test('reportError records error in history and streams event', () async {
      final handler = AppErrorHandler.instance;
      expect(handler.errorHistory.isEmpty, isTrue);

      handler.reportError('Test error message', StackTrace.current, context: 'unit_test');
      expect(handler.errorHistory.length, equals(1));
      expect(handler.errorHistory.first.message, contains('Test error message'));
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

      analytics.logEvent('workout_completed', parameters: {'workout_id': 'w_1'});
      expect(debugProvider.loggedEvents.length, equals(1));
      expect(debugProvider.loggedEvents.first['event'], equals('workout_completed'));
    });
  });

  group('CrashReportingService Unit Tests', () {
    test('recordCrash logs crash entry with custom keys', () {
      final crashService = CrashReportingService.instance;
      crashService.setCustomKey('user_id', 'usr_local');
      crashService.recordCrash('StateError: null pointer', StackTrace.current, reason: 'Test crash');

      expect(crashService.crashLogQueue.length, equals(1));
      expect(crashService.crashLogQueue.first['reason'], equals('Test crash'));
      expect(crashService.crashLogQueue.first['customKeys']['user_id'], equals('usr_local'));
    });
  });

  group('PerformanceMonitor Unit Tests', () {
    test('measure records execution duration and updates average latencies', () async {
      final monitor = PerformanceMonitor.instance;
      final result = await monitor.measure('fetch_workout_history', () async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 42;
      });

      expect(result, equals(42));
      expect(monitor.averageLatencies.containsKey('fetch_workout_history'), isTrue);
      expect(monitor.averageLatencies['fetch_workout_history']!, greaterThanOrEqualTo(5.0));
    });
  });

  group('OfflineActionQueue Unit Tests', () {
    test('enqueueAction and processQueue workflow', () async {
      final queue = OfflineActionQueue.instance;
      queue.init();
      await queue.clearQueue();

      final action = await queue.enqueueAction('log_water', {'amount_ml': 500});
      expect(queue.pendingActions.length, equals(1));
      expect(action.actionType, equals('log_water'));

      final processed = await queue.processQueue((act) async => true);
      expect(processed, equals(1));
      expect(queue.pendingActions.isEmpty, isTrue);
    });
  });

  group('SecurityAuditor and ProductionBillingConfig Tests', () {
    test('SecurityAuditor runs audit and returns SecurityReport', () {
      final report = SecurityAuditor.runAudit(config: AppConfig.prod());
      expect(report.passedChecks.isNotEmpty, isTrue);
    });

    test('ProductionBillingConfig evaluates store readiness', () {
      expect(ProductionBillingConfig.isProductionReady(), isTrue);
      expect(ProductionBillingConfig.allProductIds.length, equals(3));
    });
  });

  group('Production UI Components Widget Tests', () {
    testWidgets('AppLoadingIndicator renders spinner and message', (tester) async {
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

    testWidgets('AppErrorWidget renders error message and handles retry tap', (tester) async {
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

    testWidgets('DeveloperDiagnosticsScreen renders health console', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeveloperDiagnosticsScreen(),
        ),
      );

      expect(find.text('System Diagnostics'), findsOneWidget);
      expect(find.text('App Environment & Config'), findsOneWidget);
      expect(find.text('Security Audit Report'), findsOneWidget);
    });
  });
}
