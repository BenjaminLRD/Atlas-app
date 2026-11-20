import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/health/platform_health_reader.dart';
import 'package:atlas/services/health/platform_health_service.dart';
import '../mocks/fake_health_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('PlatformHealthReader', () {
    test(
      'sums sleep stages, averages heart rate and uses latest resting HR',
      () async {
        final reader = PlatformHealthReader(
          FakeHealthDataSource.withTypicalDay(),
          isIOS: false,
        );
        final day = await reader.readDay(DateTime.now());

        expect(day.steps, 8432);
        expect(day.sleepMinutes, 420);
        expect(day.deepSleepMinutes, 90);
        expect(day.remSleepMinutes, 90);
        expect(day.averageHeartRate, 75);
        expect(day.restingHeartRate, 58);
        expect(day.heartRateVariability, 72);
        expect(day.activeCalories, 450);
        expect(day.sourceName, 'Test Watch');
      },
    );

    test(
      'falls back to sleep sessions when a device records no stages',
      () async {
        final today = DateTime.now();
        final midnight = DateTime(today.year, today.month, today.day);
        final reader = PlatformHealthReader(
          FakeHealthDataSource(
            samples: [
              HealthSample(
                type: HealthDataType.SLEEP_SESSION,
                value: 0,
                from: midnight.subtract(const Duration(hours: 2)),
                to: midnight.add(const Duration(hours: 4)),
              ),
            ],
          ),
          isIOS: false,
        );

        expect((await reader.readDay(today)).sleepMinutes, 360);
      },
    );

    test('reports missing data as null, not as made-up values', () async {
      final reader = PlatformHealthReader(FakeHealthDataSource(), isIOS: false);
      final day = await reader.readDay(DateTime.now());

      expect(day.hasAnyData, isFalse);
      expect(day.sleepMinutes, isNull);
      expect(day.restingHeartRate, isNull);
      expect(day.heartRateVariability, isNull);
    });

    test(
      'reads the latest smart-scale values and normalises body fat',
      () async {
        final now = DateTime.now();
        HealthSample sample(HealthDataType t, double v, int daysAgo) =>
            HealthSample(
              type: t,
              value: v,
              from: now.subtract(Duration(days: daysAgo)),
              to: now.subtract(Duration(days: daysAgo)),
            );
        final reader = PlatformHealthReader(
          FakeHealthDataSource(
            samples: [
              sample(HealthDataType.WEIGHT, 80.4, 5),
              sample(HealthDataType.WEIGHT, 79.6, 1),
              // HealthKit stores body fat as a fraction.
              sample(HealthDataType.BODY_FAT_PERCENTAGE, 0.182, 1),
              sample(HealthDataType.LEAN_BODY_MASS, 65.1, 1),
            ],
          ),
          isIOS: true,
        );

        final body = await reader.latestBodyComposition();
        expect(body.weightKg, 79.6);
        expect(body.bodyFatPercent, closeTo(18.2, 0.001));
        expect(body.leanMassKg, 65.1);
      },
    );

    test('asks for HRV in the format each platform stores', () {
      expect(
        PlatformHealthReader(FakeHealthDataSource(), isIOS: true).readTypes,
        contains(HealthDataType.HEART_RATE_VARIABILITY_SDNN),
      );
      expect(
        PlatformHealthReader(FakeHealthDataSource(), isIOS: false).readTypes,
        contains(HealthDataType.HEART_RATE_VARIABILITY_RMSSD),
      );
    });
  });

  group('PlatformHealthService', () {
    test('maps a real day for the dashboard', () async {
      final service = PlatformHealthService(
        reader: PlatformHealthReader(
          FakeHealthDataSource.withTypicalDay(),
          isIOS: false,
        ),
      );
      final metric = await service.getTodayHealthMetric();

      expect(metric.steps, 8432);
      expect(metric.sleepMinutes, 420);
      expect(metric.restingHeartRate, 58);
      expect(metric.source, 'Test Watch');
    });

    test(
      'shows no data, not samples, when the health store is unavailable',
      () async {
        final service = PlatformHealthService(
          reader: PlatformHealthReader(
            FakeHealthDataSource(available: false),
            isIOS: false,
          ),
        );
        final metric = await service.getTodayHealthMetric();
        final week = await service.getWeeklyHealthHistory();

        expect(metric.steps, 0);
        expect(metric.sleepMinutes, isNull);
        expect(metric.heartRateVariability, isNull);
        expect(week, hasLength(7));
        expect(week.every((m) => m.sleepMinutes == null), isTrue);
      },
    );
  });
}
