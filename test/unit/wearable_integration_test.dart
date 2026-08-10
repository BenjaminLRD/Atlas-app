import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/connected_device.dart';
import 'package:aizawl_gym/models/health_metrics.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';
import 'package:aizawl_gym/services/health/apple_health_provider.dart';
import 'package:aizawl_gym/services/health/fitbit_provider.dart';
import 'package:aizawl_gym/services/health/garmin_provider.dart';
import 'package:aizawl_gym/services/health/google_fit_provider.dart';
import 'package:aizawl_gym/services/health/health_sync_service.dart';
import 'package:aizawl_gym/services/health/mock_health_provider.dart';
import 'package:aizawl_gym/services/recovery_intelligence_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    HealthSyncService.resetInstance();
    RecoveryIntelligenceService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('HealthMetrics Enhanced Model Tests', () {
    test('HealthMetrics includes wearable fields and serialization', () {
      final now = DateTime.now();
      final metrics = HealthMetrics(
        id: 'hm_test_1',
        date: now,
        steps: 10500,
        caloriesBurned: 520.0,
        heartRateAverage: 65.0,
        sleepHours: 8.0,
        activeMinutes: 50,
        sourceDevice: 'Apple Health (Watch Ultra)',
        restingHeartRate: 56.0,
        bloodOxygen: 99.0,
        hrv: 65.0,
        syncTimestamp: now,
      );

      final json = metrics.toJson();
      expect(json['sourceDevice'], equals('Apple Health (Watch Ultra)'));
      expect(json['restingHeartRate'], equals(56.0));
      expect(json['hrv'], equals(65.0));

      final parsed = HealthMetrics.fromJson(json);
      expect(parsed.sourceDevice, equals('Apple Health (Watch Ultra)'));
      expect(parsed.restingHeartRate, equals(56.0));
      expect(parsed.hrv, equals(65.0));
    });
  });

  group('ConnectedDevice Model Tests', () {
    test('ConnectedDevice serialization and copyWith', () {
      const device = ConnectedDevice(
        id: 'dev_apple',
        name: 'Apple Watch Ultra',
        type: 'apple_health',
        isConnected: true,
      );

      final json = device.toJson();
      expect(json['id'], equals('dev_apple'));
      expect(json['type'], equals('apple_health'));

      final parsed = ConnectedDevice.fromJson(json);
      expect(parsed.isConnected, isTrue);

      final updated = device.copyWith(isConnected: false);
      expect(updated.isConnected, isFalse);
    });
  });

  group('Wearable Health Providers Unit Tests', () {
    test('AppleHealthProvider returns Apple metrics', () async {
      final provider = AppleHealthProvider();
      final metrics = await provider.fetchTodayMetrics();

      expect(metrics, isNotNull);
      expect(metrics!.sourceDevice.contains('Apple'), isTrue);
      expect(metrics.steps, greaterThan(8000));
    });

    test('GoogleFitProvider returns Google Fit metrics', () async {
      final provider = GoogleFitProvider();
      final metrics = await provider.fetchTodayMetrics();

      expect(metrics, isNotNull);
      expect(metrics!.sourceDevice.contains('Google'), isTrue);
    });

    test('FitbitProvider returns Fitbit metrics', () async {
      final provider = FitbitProvider();
      final metrics = await provider.fetchTodayMetrics();

      expect(metrics, isNotNull);
      expect(metrics!.sourceDevice.contains('Fitbit'), isTrue);
    });

    test('GarminProvider returns Garmin metrics', () async {
      final provider = GarminProvider();
      final metrics = await provider.fetchTodayMetrics();

      expect(metrics, isNotNull);
      expect(metrics!.sourceDevice.contains('Garmin'), isTrue);
    });
  });

  group('HealthSyncService Multi-Provider & Fallback Tests', () {
    test('HealthSyncService switches provider and connects device', () async {
      final service = HealthSyncService.instance;
      const device = ConnectedDevice(
        id: 'dev_apple',
        name: 'Apple Watch Ultra',
        type: 'apple_health',
      );

      final devices = await service.connectDevice(device);
      expect(devices.any((d) => d.type == 'apple_health' && d.isConnected), isTrue);

      final metrics = await service.fetchTodayMetrics();
      expect(metrics, isNotNull);
      expect(metrics!.sourceDevice.contains('Apple'), isTrue);
    });

    test('HealthSyncService falls back to MockHealthProvider on permission failure', () async {
      final service = HealthSyncService.instance;
      // Provider without permission
      service.setProvider(MockHealthProvider(initialPermission: false));

      final metrics = await service.fetchTodayMetrics();
      expect(metrics, isNotNull); // Falls back seamlessly
      expect(metrics!.steps, greaterThan(0));
    });
  });

  group('FitnessProvider Wearable Integration Tests', () {
    test('FitnessProvider connectWearableDevice and syncHealthData update recovery and training state', () async {
      final provider = FitnessProvider.instance;

      expect(provider.connectedDevices, isNotEmpty);

      const device = ConnectedDevice(
        id: 'dev_garmin',
        name: 'Garmin Forerunner 265',
        type: 'garmin',
      );

      await provider.connectWearableDevice(device);

      expect(provider.healthMetrics, isNotNull);
      expect(provider.healthMetrics!.sourceDevice.contains('Garmin'), isTrue);
      expect(provider.recoveryState, isNotNull);

      final context = provider.buildFitnessContext();
      expect(context.recoveryState, isNotNull);
    });
  });
}
