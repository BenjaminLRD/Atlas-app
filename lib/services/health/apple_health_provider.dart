import '../../models/health_metrics.dart';
import 'health_sync_service.dart';
import 'platform_health_metrics.dart';
import 'platform_health_reader.dart';

/// [HealthProvider] that reads the device's health store (Apple Health or
/// Health Connect) through [PlatformHealthReader].
class PlatformHealthProvider implements HealthProvider {
  final PlatformHealthReader? _readerOverride;

  /// Resolved on each use so tests can swap [PlatformHealthReader.instance].
  PlatformHealthReader get _reader =>
      _readerOverride ?? PlatformHealthReader.instance;
  final String idPrefix;

  PlatformHealthProvider({PlatformHealthReader? reader, this.idPrefix = 'hm'})
    : _readerOverride = reader;

  @override
  Future<bool> requestPermissions() => _reader.requestPermissions();

  @override
  Future<HealthMetrics?> fetchTodayMetrics() async {
    if (!await _reader.isAvailable()) return null;
    return healthMetricsFromReading(
      await _reader.readDay(DateTime.now()),
      userId: 'usr_local',
      idPrefix: idPrefix,
    );
  }

  @override
  Future<List<HealthMetrics>> fetchHistory({int days = 7}) async {
    if (!await _reader.isAvailable()) return [];
    final now = DateTime.now();
    final list = <HealthMetrics>[];
    for (var i = 0; i < days; i++) {
      final metrics = healthMetricsFromReading(
        await _reader.readDay(now.subtract(Duration(days: i))),
        userId: 'usr_local',
        idPrefix: idPrefix,
      );
      if (metrics != null) list.add(metrics);
    }
    return list;
  }
}

/// Apple Health (HealthKit) on iOS.
class AppleHealthProvider extends PlatformHealthProvider {
  AppleHealthProvider({super.reader}) : super(idPrefix: 'hm_apple');
}
