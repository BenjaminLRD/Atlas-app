import 'dart:async';
import '../../models/health_metrics.dart';
import '../health/platform_health_metrics.dart';
import '../health/platform_health_reader.dart';
import 'wearable_service.dart';

/// Wearable data read through the device's health store. Watches, rings and
/// straps write into Apple Health or Health Connect; Atlas reads from there.
abstract class PlatformWearableService implements WearableService {
  final PlatformHealthReader? _readerOverride;

  /// Resolved on each use so tests can swap [PlatformHealthReader.instance].
  PlatformHealthReader get _reader =>
      _readerOverride ?? PlatformHealthReader.instance;

  PlatformWearableService({PlatformHealthReader? reader})
    : _readerOverride = reader;

  @override
  Future<bool> isAvailable() => _reader.isAvailable();

  @override
  Future<bool> isConnected() => _reader.isAvailable();

  @override
  Future<bool> hasPermissions() => _reader.hasPermissions();

  @override
  Future<bool> requestPermissions() => _reader.requestPermissions();

  @override
  Future<HealthMetrics?> syncHealthData({String userId = 'usr_local'}) async {
    try {
      if (!await _reader.isAvailable()) return null;
      final reading = await _reader.readDay(DateTime.now());
      return healthMetricsFromReading(
        reading,
        userId: userId,
        idPrefix: 'metric_${platform.name}',
      );
    } catch (_) {
      return null;
    }
  }

  /// Polls the health store for the latest heart rate. Emits only when a
  /// recent reading exists.
  @override
  Stream<int> streamHeartRate() async* {
    while (true) {
      try {
        final bpm = await _reader.latestHeartRate();
        if (bpm != null) yield bpm;
      } catch (_) {}
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }
}

/// Android: Google Health Connect.
class HealthConnectWearableService extends PlatformWearableService {
  HealthConnectWearableService({super.reader});

  @override
  WearablePlatform get platform => WearablePlatform.googleFit;

  @override
  String get providerName => 'Google Health Connect';
}
