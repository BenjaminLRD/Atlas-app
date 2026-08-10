import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/health_metrics.dart';
import 'package:aizawl_gym/services/health/health_sync_service.dart';
import 'package:aizawl_gym/services/health/mock_health_provider.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    HealthSyncService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('HealthMetrics Model Unit Tests', () {
    test('HealthMetrics serialization, copyWith, and equality', () {
      final now = DateTime.now();
      final metrics = HealthMetrics(
        id: 'hm_1',
        date: now,
        steps: 10200,
        caloriesBurned: 520.0,
        heartRateAverage: 64.0,
        sleepHours: 8.2,
        activeMinutes: 50,
      );

      final json = metrics.toJson();
      expect(json['id'], equals('hm_1'));
      expect(json['steps'], equals(10200));
      expect(json['sleepHours'], equals(8.2));

      final parsed = HealthMetrics.fromJson(json);
      expect(parsed.id, equals('hm_1'));
      expect(parsed.activeMinutes, equals(50));

      final updated = metrics.copyWith(steps: 12000);
      expect(updated.steps, equals(12000));
    });
  });

  group('MockHealthProvider & HealthSyncService Unit Tests', () {
    test('MockHealthProvider fetchTodayMetrics returns realistic data', () async {
      final provider = MockHealthProvider();
      final metrics = await provider.fetchTodayMetrics();

      expect(metrics, isNotNull);
      expect(metrics!.steps, greaterThan(0));
      expect(metrics.sleepHours, greaterThan(0));
    });

    test('MockHealthProvider fetchHistory returns requested days', () async {
      final provider = MockHealthProvider();
      final history = await provider.fetchHistory(days: 7);

      expect(history.length, equals(7));
    });

    test('HealthSyncService calculateRecoveryScore returns score within 0-100', () {
      final service = HealthSyncService.instance;
      final metrics = HealthMetrics(
        id: 'hm_score',
        date: DateTime.now(),
        steps: 9000,
        caloriesBurned: 450.0,
        heartRateAverage: 66.0,
        sleepHours: 8.0,
        activeMinutes: 45,
      );

      final score = service.calculateRecoveryScore(metrics);
      expect(score, greaterThanOrEqualTo(0));
      expect(score, lessThanOrEqualTo(100));
      expect(score, greaterThanOrEqualTo(80));
    });
  });

  group('FitnessProvider Health Integration Tests', () {
    test('syncHealthData fetches metrics and updates recovery score', () async {
      final provider = FitnessProvider.instance;
      await provider.syncHealthData();

      expect(provider.healthMetrics, isNotNull);
      expect(provider.healthMetrics!.steps, greaterThan(0));
      expect(provider.recoveryScore, greaterThan(0));
    });
  });
}
