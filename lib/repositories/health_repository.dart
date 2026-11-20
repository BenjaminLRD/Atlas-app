import '../data/local_storage.dart';
import '../models/health_metric.dart';
import '../models/health_metric_record.dart';

/// Abstract repository interface for health metrics, biometrics, and sleep telemetry.
abstract class HealthRepository {
  /// Retrieves today's health metric for the active user.
  Future<HealthMetric?> getTodayHealthMetric({String? userId});

  /// Persists a health metric reading.
  Future<void> saveHealthMetric(HealthMetric metric, {String? userId});

  /// Retrieves health metric history list for the user up to [limit] records.
  Future<List<HealthMetric>> getHealthHistory({String? userId, int limit = 30});

  /// Persists a unified HealthMetricRecord.
  Future<void> saveHealthRecord(HealthMetricRecord record, {String? userId});

  /// Retrieves today's unified HealthMetricRecord.
  Future<HealthMetricRecord?> getTodayHealthRecord({String? userId});

  /// Retrieves health metric record history.
  Future<List<HealthMetricRecord>> getHealthRecordHistory({String? userId, int limit = 30});
}

/// Local-first implementation of [HealthRepository] persisting to [LocalStorage].
class LocalHealthRepository implements HealthRepository {
  @override
  Future<HealthMetric?> getTodayHealthMetric({String? userId}) async {
    return LocalStorage.getHealthMetric();
  }

  @override
  Future<void> saveHealthMetric(HealthMetric metric, {String? userId}) async {
    await LocalStorage.saveHealthMetric(metric);
  }

  @override
  Future<List<HealthMetric>> getHealthHistory({
    String? userId,
    int limit = 30,
  }) async {
    final list = LocalStorage.getHealthHistory();
    if (list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  @override
  Future<void> saveHealthRecord(HealthMetricRecord record, {String? userId}) async {
    await LocalStorage.saveHealthMetric(record.toHealthMetric());
  }

  @override
  Future<HealthMetricRecord?> getTodayHealthRecord({String? userId}) async {
    final metric = await getTodayHealthMetric(userId: userId);
    if (metric == null) return null;
    return HealthMetricRecord.fromHealthMetric(metric, userId: userId ?? 'usr_local');
  }

  @override
  Future<List<HealthMetricRecord>> getHealthRecordHistory({String? userId, int limit = 30}) async {
    final history = await getHealthHistory(userId: userId, limit: limit);
    return history.map((m) => HealthMetricRecord.fromHealthMetric(m, userId: userId ?? 'usr_local')).toList();
  }
}
