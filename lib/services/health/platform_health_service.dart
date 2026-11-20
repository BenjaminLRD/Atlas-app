import 'dart:async';
import '../../data/local_storage.dart';
import '../../models/health_metric.dart';
import 'health_service.dart';
import 'platform_health_reader.dart';

/// [HealthService] that reads real data from Apple Health or Health Connect.
///
/// Values the health store does not have stay null, so the UI can show "no
/// data" instead of sample numbers. The last reading is cached locally for
/// offline display.
class PlatformHealthService implements HealthService {
  final PlatformHealthReader? _readerOverride;

  /// Resolved on each use so tests can swap [PlatformHealthReader.instance].
  PlatformHealthReader get _reader =>
      _readerOverride ?? PlatformHealthReader.instance;

  PlatformHealthService({PlatformHealthReader? reader})
    : _readerOverride = reader;

  @override
  Future<bool> isProviderAvailable() => _reader.isAvailable();

  @override
  Future<bool> hasPermissions() => _reader.hasPermissions();

  @override
  Future<bool> requestPermissions() => _reader.requestPermissions();

  @override
  Future<HealthMetric> getTodayHealthMetric() async {
    try {
      if (!await _reader.isAvailable()) return _empty(DateTime.now());
      final metric = _toMetric(await _reader.readDay(DateTime.now()));
      await LocalStorage.saveHealthMetric(metric);
      return metric;
    } catch (_) {
      return LocalStorage.getHealthMetric() ?? _empty(DateTime.now());
    }
  }

  @override
  Future<List<HealthMetric>> getWeeklyHealthHistory() async {
    final today = DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    try {
      if (!await _reader.isAvailable()) return days.map(_empty).toList();
      final readings = <HealthMetric>[];
      for (final day in days) {
        readings.add(_toMetric(await _reader.readDay(day)));
      }
      return readings;
    } catch (_) {
      return days.map(_empty).toList();
    }
  }

  @override
  Stream<int?> watchHeartRate() async* {
    while (true) {
      try {
        yield await _reader.latestHeartRate();
      } catch (_) {
        yield null;
      }
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }

  @override
  Future<void> updateHealthMetric(HealthMetric metric) =>
      LocalStorage.saveHealthMetric(metric);

  static HealthMetric _toMetric(DailyHealthReading r) {
    final steps = r.steps ?? 0;
    return HealthMetric(
      timestamp: r.day,
      steps: steps,
      // Average stride; Health stores report distance separately but not
      // consistently across devices.
      distanceKm: steps * 0.00075,
      activeCalories: r.activeCalories ?? 0,
      heartRate: r.averageHeartRate?.round(),
      sleepMinutes: r.sleepMinutes,
      restingHeartRate: r.restingHeartRate?.round(),
      deepSleepMinutes: r.deepSleepMinutes,
      remSleepMinutes: r.remSleepMinutes,
      heartRateVariability: r.heartRateVariability,
      sleepQuality: null,
      stressScore: null,
      trainingLoad: null,
      source: r.sourceName,
    );
  }

  static HealthMetric _empty(DateTime day) => HealthMetric(
    timestamp: day,
    heartRateVariability: null,
    sleepQuality: null,
    stressScore: null,
    trainingLoad: null,
    source: 'none',
  );
}
