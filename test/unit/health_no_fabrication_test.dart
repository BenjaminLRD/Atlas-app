import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/health_metric_record.dart';
import 'package:atlas/models/health_metrics.dart';
import 'package:atlas/models/recovery_summary.dart';
import 'package:atlas/services/health/apple_health_provider.dart';
import 'package:atlas/services/health/health_sync_service.dart';
import 'package:atlas/services/health/platform_health_metrics.dart';
import 'package:atlas/services/health/platform_health_reader.dart';
import 'package:atlas/services/recovery/recovery_prediction_engine.dart';
import 'package:atlas/services/wearables/wearable_service.dart';
import 'package:atlas/widgets/common/health_dashboard_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/fake_health_data_source.dart';

class _ThrowingProvider implements HealthProvider {
  @override
  Future<HealthMetrics?> fetchTodayMetrics() async => throw StateError('x');
  @override
  Future<List<HealthMetrics>> fetchHistory({int days = 7}) async =>
      throw StateError('x');
  @override
  Future<bool> requestPermissions() async => throw StateError('x');
}

void main() {
  group('no fabricated health readings', () {
    test('an unreported value is null, never a default number', () {
      final m = HealthMetrics(id: 'a');
      expect(m.sleepHours, isNull);
      expect(m.restingHeartRate, isNull);
      expect(m.heartRateVariability, isNull);
      expect(m.heartRateAverage, isNull);
      expect(m.bloodOxygen, isNull);
      expect(m.stressLevel, isNull);
      expect(m.recoveryScore, isNull);

      final fromEmptyJson = HealthMetrics.fromJson({'id': 'b'});
      expect(fromEmptyJson.sleepHours, isNull);
      expect(fromEmptyJson.heartRateAverage, isNull);
      expect(fromEmptyJson.recoveryScore, isNull);
    });

    test('values the health store reported survive a JSON round trip', () {
      final m = HealthMetrics(
        id: 'a',
        sleepHours: 6.5,
        heartRateAverage: 71,
        hrv: 52,
      );
      final back = HealthMetrics.fromJson(m.toJson());
      expect(back.sleepHours, 6.5);
      expect(back.heartRateAverage, 71);
      expect(back.hrv, 52);
      expect(back.restingHeartRate, isNull);
    });

    test('the unified HealthMetric has no default HRV, quality or load', () {
      final m = HealthMetric(timestamp: DateTime(2026, 1, 1));
      expect(m.heartRate, isNull);
      expect(m.heartRateVariability, isNull);
      expect(m.sleepQuality, isNull);
      expect(m.stressScore, isNull);
      expect(m.trainingLoad, isNull);
      expect(m.source, isNot('mock'));
    });

    test('converting a stored record keeps missing values missing', () {
      final record = HealthMetricRecord(
        id: 'r',
        userId: 'u',
        timestamp: DateTime(2026, 1, 1),
        steps: 100,
        source: HealthMetricSource.manual,
      );
      final metrics = record.toHealthMetrics();
      expect(metrics.sleepHours, isNull);
      expect(metrics.restingHeartRate, isNull);
      expect(metrics.heartRateVariability, isNull);
      expect(metrics.heartRateAverage, isNull);
      final unified = record.toHealthMetric();
      expect(unified.sleepMinutes, isNull);
      expect(unified.heartRateVariability, isNull);
    });

    test('a health-store reading with only steps has no sleep or heart rate', () {
      final metrics = healthMetricsFromReading(
        DailyHealthReading(day: DateTime(2026, 1, 1), steps: 4200),
        userId: 'u',
        idPrefix: 't',
      )!;
      expect(metrics.steps, 4200);
      expect(metrics.sleepHours, isNull);
      expect(metrics.restingHeartRate, isNull);
      expect(metrics.heartRateAverage, isNull);
      expect(metrics.heartRateVariability, isNull);
    });

    test('an empty health store gives no metrics, not stand-in numbers', () async {
      final reader = PlatformHealthReader(
        FakeHealthDataSource(granted: true),
        isIOS: false,
      );
      final provider = PlatformHealthProvider(reader: reader);
      expect(await provider.fetchTodayMetrics(), isNull);
    });

    test('HealthSyncService returns nothing when the provider fails', () async {
      final service = HealthSyncService(provider: _ThrowingProvider());
      expect(await service.fetchTodayMetrics(), isNull);
      expect(await service.fetchHistory(), isEmpty);
      expect(await service.requestPermissions(), isFalse);
    });

    test('HealthSyncService has no simulated provider type', () {
      final service = HealthSyncService();
      for (final type in ['garmin', 'fitbit', 'mock', 'unknown', 'google_fit']) {
        final provider = service.getProviderForType(type);
        expect(provider, isA<PlatformHealthProvider>(), reason: type);
      }
    });

    test('there is no simulated wearable platform', () {
      expect(WearablePlatform.values, [
        WearablePlatform.appleHealth,
        WearablePlatform.googleFit,
      ]);
    });

    test('the recovery score only uses the signals that were reported', () {
      final service = HealthSyncService(provider: _ThrowingProvider());
      expect(service.calculateRecoveryScore(HealthMetrics(id: 'none')), isNull);
      // Steps alone are not a recovery signal.
      expect(
        service.calculateRecoveryScore(HealthMetrics(id: 's', steps: 9000)),
        isNull,
      );
      // Sleep alone: 8 h is a full score on its own.
      expect(
        service.calculateRecoveryScore(HealthMetrics(id: 'sl', sleepHours: 8)),
        100,
      );
      // 4 h of sleep alone is half.
      expect(
        service.calculateRecoveryScore(HealthMetrics(id: 'sl2', sleepHours: 4)),
        50,
      );
    });

    test('recovery factors are left out when sleep and HRV are not reported', () {
      const engine = RecoveryPredictionEngine();
      final report = engine.analyzeReadiness(
        userId: 'u',
        workoutHistory: const [],
        healthMetrics: HealthMetrics(id: 'empty'),
      );
      expect(report.readinessScore.sleepContribution, isNull);
      expect(report.readinessScore.hrvContribution, isNull);
      expect(report.readinessScore.isAvailable, isFalse);
    });

    test('a recovery summary from an unreported watch has no heart rate', () {
      final summary = RecoverySummary.fromJson(const {});
      expect(summary.restingHeartRate, isNull);
      expect(summary.hrv, isNull);
    });
  });

  group('health card shows no stand-in numbers', () {
    testWidgets('without data every value is a dash and there is no badge', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HealthDashboardCard())),
      );
      expect(find.text('--'), findsNWidgets(4));
      expect(find.text('8450'), findsNothing);
      expect(find.text('420 kcal'), findsNothing);
      expect(find.textContaining('7.5'), findsNothing);
      expect(find.textContaining('/100'), findsNothing);
      expect(find.text('No health data source connected'), findsOneWidget);
    });

    testWidgets('with data it shows the reported values and their source', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HealthDashboardCard(
              metrics: HealthMetrics(
                id: 'm',
                steps: 5123,
                sleepHours: 6.5,
                sourceDevice: 'Pixel Watch',
              ),
              recoveryScore: 70,
            ),
          ),
        ),
      );
      expect(find.text('5123'), findsOneWidget);
      expect(find.text('6.5 hrs'), findsOneWidget);
      expect(find.text('From Pixel Watch'), findsOneWidget);
      expect(find.text('70/100'), findsOneWidget);
    });
  });
}
