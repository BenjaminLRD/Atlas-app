import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/models/sleep_record.dart';
import 'package:atlas/models/recovery_insight.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/providers/showcase_data_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SleepRecord Domain Model Tests', () {
    test('Calculates correct duration crossing midnight', () {
      final now = DateTime(2026, 8, 29);
      final bedtime = DateTime(2026, 8, 28, 23, 18);
      final wakeTime = DateTime(2026, 8, 29, 7, 0);

      final record = SleepRecord.fromTimes(
        id: 'sleep_test_1',
        date: now,
        bedtime: bedtime,
        wakeTime: wakeTime,
        quality: SleepQuality.good,
        consistency: SleepConsistency.good,
        source: HealthDataSource.manual,
        restingHeartRate: 58.0,
        hrv: 62.0,
      );

      expect(record.durationMinutes, 462);
      expect(record.formattedDuration, '7h 42m');
      expect(record.formattedBedtime, '11:18 PM');
      expect(record.formattedWakeTime, '7:00 AM');
      expect(record.quality.label, 'Good');
      expect(record.consistency.label, 'Good');
    });

    test('Serializes to and from JSON correctly', () {
      final now = DateTime(2026, 8, 29, 8, 0);
      final record = SleepRecord(
        id: 'sleep_json_1',
        userId: 'usr_test',
        date: now,
        bedtime: now.subtract(const Duration(hours: 8)),
        wakeTime: now,
        durationMinutes: 480,
        quality: SleepQuality.excellent,
        consistency: SleepConsistency.optimal,
        source: HealthDataSource.appleHealth,
        restingHeartRate: 55.0,
        hrv: 70.0,
        notes: 'Restful night',
      );

      final json = record.toJson();
      final deserialized = SleepRecord.fromJson(json);

      expect(deserialized.id, record.id);
      expect(deserialized.durationMinutes, record.durationMinutes);
      expect(deserialized.quality, SleepQuality.excellent);
      expect(deserialized.consistency, SleepConsistency.optimal);
      expect(deserialized.source, HealthDataSource.appleHealth);
      expect(deserialized.restingHeartRate, 55.0);
      expect(deserialized.hrv, 70.0);
      expect(deserialized.notes, 'Restful night');
    });
  });

  group('RecoveryInsight Domain Model Tests', () {
    test('Creates empty insufficient data state for fresh users', () {
      final insight = RecoveryInsight.insufficientData();
      expect(insight.hasSufficientData, isFalse);
      expect(insight.status, RecoveryStatus.insufficientData);
      expect(insight.interpretation, contains('Not enough data yet'));
      expect(insight.reasoningBullets, isEmpty);
    });

    test('Calculates recovery from telemetry and history baseline', () {
      final now = DateTime.now();
      final latest = SleepRecord.fromTimes(
        id: 'sleep_latest',
        date: now,
        bedtime: DateTime(now.year, now.month, now.day - 1, 23, 0),
        wakeTime: DateTime(now.year, now.month, now.day, 7, 30),
        quality: SleepQuality.good,
        consistency: SleepConsistency.good,
        source: HealthDataSource.appleHealth,
        restingHeartRate: 58.0,
        hrv: 65.0,
      );

      final history = [
        latest,
        SleepRecord.fromTimes(
          id: 'sleep_prev_1',
          date: now.subtract(const Duration(days: 1)),
          bedtime: DateTime(now.year, now.month, now.day - 2, 23, 0),
          wakeTime: DateTime(now.year, now.month, now.day - 1, 7, 0),
          quality: SleepQuality.good,
          consistency: SleepConsistency.good,
          source: HealthDataSource.appleHealth,
          restingHeartRate: 61.0,
          hrv: 60.0,
        ),
      ];

      final insight = RecoveryInsight.fromTelemetry(
        latestSleep: latest,
        history: history,
        restingHeartRate: 58.0,
        hrv: 65.0,
        source: HealthDataSource.appleHealth,
      );

      expect(insight.hasSufficientData, isTrue);
      expect(insight.status, isNot(RecoveryStatus.insufficientData));
      expect(insight.reasoningBullets, isNotEmpty);
      expect(insight.restingHeartRate, 58.0);
      expect(insight.hrv, 65.0);
      expect(insight.rhrDiffFromBaseline, isNotNull);
    });
  });

  group('LocalStorage & Showcase Mode Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
    });

    test('Saves and retrieves sleep records in LocalStorage', () async {
      expect(LocalStorage.getSleepRecords(), isEmpty);
      expect(LocalStorage.getLatestSleepRecord(), isNull);

      final record = SleepRecord.fromTimes(
        id: 'sleep_local_1',
        date: DateTime.now(),
        bedtime: DateTime(2026, 8, 28, 23, 0),
        wakeTime: DateTime(2026, 8, 29, 7, 0),
        quality: SleepQuality.good,
        consistency: SleepConsistency.good,
        source: HealthDataSource.manual,
      );

      await LocalStorage.saveSleepRecord(record);

      final records = LocalStorage.getSleepRecords();
      expect(records.length, 1);
      expect(records.first.id, 'sleep_local_1');
      expect(LocalStorage.getLatestSleepRecord()?.id, 'sleep_local_1');
    });

    test('Wearable connection state persists in LocalStorage', () async {
      expect(LocalStorage.getIsWearableConnected(), isFalse);
      expect(LocalStorage.getConnectedWearableSource(), 'Apple Health');

      await LocalStorage.setWearableConnected(true, source: 'Garmin');
      expect(LocalStorage.getIsWearableConnected(), isTrue);
      expect(LocalStorage.getConnectedWearableSource(), 'Garmin');
    });

    test('ShowcaseDataProvider supplies deterministic 7-day sleep records', () {
      final showcase = ShowcaseDataProvider.instance;
      final history = showcase.getShowcaseSleepHistory();
      final latest = showcase.getShowcaseLatestSleep();
      final insight = showcase.getShowcaseRecoveryInsight();

      expect(history.length, 7);
      expect(latest.formattedDuration, '7h 42m');
      expect(latest.source, HealthDataSource.showcase);
      expect(insight.hasSufficientData, isTrue);
      expect(insight.reasoningBullets.length, greaterThanOrEqualTo(3));
    });
  });
}
