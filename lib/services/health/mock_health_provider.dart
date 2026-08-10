import '../../models/health_metrics.dart';
import 'health_sync_service.dart';

/// Mock development implementation of HealthProvider generating realistic platform metrics.
class MockHealthProvider implements HealthProvider {
  bool _hasPermission = true;

  MockHealthProvider({bool initialPermission = true})
      : _hasPermission = initialPermission;

  @override
  Future<bool> requestPermissions() async {
    _hasPermission = true;
    return true;
  }

  @override
  Future<HealthMetrics?> fetchTodayMetrics() async {
    if (!_hasPermission) return null;

    final now = DateTime.now();
    return HealthMetrics(
      id: 'hm_today',
      date: now,
      steps: 8450,
      caloriesBurned: 420.0,
      heartRateAverage: 68.0,
      sleepHours: 7.5,
      activeMinutes: 42,
    );
  }

  @override
  Future<List<HealthMetrics>> fetchHistory({int days = 7}) async {
    if (!_hasPermission) return [];

    final now = DateTime.now();
    final list = <HealthMetrics>[];

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      list.add(
        HealthMetrics(
          id: 'hm_hist_$i',
          date: date,
          steps: 7500 + (i * 320) % 3000,
          caloriesBurned: 380.0 + (i * 25) % 150,
          heartRateAverage: 65.0 + (i % 8),
          sleepHours: 6.8 + (i % 3) * 0.4,
          activeMinutes: 30 + (i * 5) % 30,
        ),
      );
    }

    return list;
  }
}
