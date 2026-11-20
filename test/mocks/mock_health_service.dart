import 'dart:async';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/services/health/health_service.dart';

/// Deterministic mock health telemetry service used for testing,
/// simulators, and platforms without native Health Connect support.
class MockHealthService implements HealthService {
  bool _hasPermissions = true;
  final _heartRateController = StreamController<int?>.broadcast();
  HealthMetric? _cachedToday;

  MockHealthService({bool initialPermissions = true})
    : _hasPermissions = initialPermissions;

  @override
  Future<bool> hasPermissions() async {
    return _hasPermissions;
  }

  @override
  Future<bool> requestPermissions() async {
    _hasPermissions = true;
    return true;
  }

  @override
  Future<bool> isProviderAvailable() async {
    return true;
  }

  @override
  Future<HealthMetric> getTodayHealthMetric() async {
    if (_cachedToday != null) return _cachedToday!;

    final saved = LocalStorage.getHealthMetric();
    if (saved != null) {
      _cachedToday = saved;
      return saved;
    }

    final sample = HealthMetric.sample();
    _cachedToday = sample;
    await LocalStorage.saveHealthMetric(sample);
    return sample;
  }

  @override
  Future<List<HealthMetric>> getWeeklyHealthHistory() async {
    final today = DateTime.now();
    final list = <HealthMetric>[];

    final stepsSamples = [7200, 8900, 10200, 6800, 9400, 11100, 8432];
    final calsSamples = [450.0, 580.0, 620.0, 410.0, 560.0, 680.0, 520.0];
    final sleepSamples = [450, 480, 420, 390, 460, 500, 440]; // mins

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: 6 - i));
      list.add(
        HealthMetric(
          timestamp: date,
          steps: stepsSamples[i],
          distanceKm: stepsSamples[i] * 0.00075,
          activeCalories: calsSamples[i],
          heartRate: 70 + (i % 5),
          sleepMinutes: sleepSamples[i],
          restingHeartRate: 62 + (i % 4),
          source: 'health_connect',
        ),
      );
    }
    return list;
  }

  @override
  Stream<int?> watchHeartRate() {
    return _heartRateController.stream;
  }

  /// Helper to push real-time heart rate update in tests/demo
  void emitHeartRate(int bpm) {
    _heartRateController.add(bpm);
  }

  @override
  Future<void> updateHealthMetric(HealthMetric metric) async {
    _cachedToday = metric;
    await LocalStorage.saveHealthMetric(metric);
  }

  void dispose() {
    _heartRateController.close();
  }
}
