import '../../data/local_storage.dart';
import '../../models/health_metric.dart';
import '../../models/health_metric_record.dart';
import '../../repositories/health_repository.dart';
import 'database_models.dart';
import 'supabase_client.dart';

/// Cloud-first, local-fallback repository for health telemetry & metrics.
class SupabaseHealthRepository implements HealthRepository {
  final SupabaseClientManager _clientManager;

  SupabaseHealthRepository({SupabaseClientManager? clientManager})
    : _clientManager = clientManager ?? SupabaseClientManager.instance;

  @override
  /// Retrieves today's health metric: tries Supabase first, falls back to LocalStorage cache.
  Future<HealthMetric?> getTodayHealthMetric({String? userId}) async {
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final rows = await _clientManager
          .from(SupabaseTableNames.healthMetrics)
          .select('user_id', uid);

      final matching = rows.where((r) => r['metric_date'] == dateStr || r['date'] == dateStr);
      if (matching.isNotEmpty) {
        final row = matching.first;
        final metric = HealthMetric(
          timestamp: DateTime.parse(row['created_at'] as String),
          steps: (row['steps'] as num?)?.toInt() ?? 0,
          distanceKm: (row['distance_km'] as num?)?.toDouble() ?? 0.0,
          activeCalories: (row['active_calories'] as num?)?.toDouble() ?? 0.0,
          heartRate: (row['heart_rate'] as num?)?.toInt(),
          sleepMinutes: (row['sleep_minutes'] as num?)?.toInt() ?? (row['sleep_hours'] != null ? ((row['sleep_hours'] as num) * 60).round() : null),
          deepSleepMinutes: (row['deep_sleep_minutes'] as num?)?.toInt(),
          restingHeartRate: (row['resting_heart_rate'] as num?)?.toInt(),
          source: 'supabase_cloud',
        );
        await LocalStorage.saveHealthMetric(metric);
        return metric;
      }
    } catch (_) {
      // Offline fallback
    }
    return LocalStorage.getHealthMetric();
  }

  @override
  /// Saves health metric: saves to local encrypted storage first, then attempts cloud sync.
  Future<void> saveHealthMetric(HealthMetric metric, {String? userId}) async {
    // 1. Local Cache
    await LocalStorage.saveHealthMetric(metric);

    // 2. Cloud Sync
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final payload = SupabaseModelMappers.healthMetricToTable(
        metric,
        userId: uid,
      );
      await _clientManager
          .from(SupabaseTableNames.healthMetrics)
          .upsert(payload, onConflictColumn: 'id');
    } catch (_) {
      // Offline fallback
    }
  }

  @override
  /// Retrieves health metric history list for user.
  Future<List<HealthMetric>> getHealthHistory({
    String? userId,
    int limit = 30,
  }) async {
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final rows = await _clientManager
          .from(SupabaseTableNames.healthMetrics)
          .select('user_id', uid);

      if (rows.isNotEmpty) {
        final list = rows.map((row) {
          return HealthMetric(
            timestamp: DateTime.parse(row['created_at'] as String),
            steps: (row['steps'] as num?)?.toInt() ?? 0,
            distanceKm: (row['distance_km'] as num?)?.toDouble() ?? 0.0,
            activeCalories: (row['active_calories'] as num?)?.toDouble() ?? 0.0,
            heartRate: (row['heart_rate'] as num?)?.toInt(),
            sleepMinutes: (row['sleep_minutes'] as num?)?.toInt() ?? (row['sleep_hours'] != null ? ((row['sleep_hours'] as num) * 60).round() : null),
            deepSleepMinutes: (row['deep_sleep_minutes'] as num?)?.toInt(),
            restingHeartRate: (row['resting_heart_rate'] as num?)?.toInt(),
            source: 'supabase_cloud',
          );
        }).toList();

        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (list.length > limit) {
          return list.sublist(0, limit);
        }
        return list;
      }
    } catch (_) {
      // Offline fallback
    }
    final localList = LocalStorage.getHealthHistory();
    if (localList.length > limit) {
      return localList.sublist(0, limit);
    }
    return localList;
  }

  @override
  Future<void> saveHealthRecord(HealthMetricRecord record, {String? userId}) async {
    await saveHealthMetric(record.toHealthMetric(), userId: userId);
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
