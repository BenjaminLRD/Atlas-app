import '../../models/health_metrics.dart';
import 'platform_health_reader.dart';

/// Converts a [DailyHealthReading] into the [HealthMetrics] model used by the
/// recovery engine and wearable layer.
///
/// Values the health store did not report stay null: there is no default
/// sleep, heart rate or HRV. Returns null when the store had no data at all, so
/// callers can show "no data" instead of a reading.
HealthMetrics? healthMetricsFromReading(
  DailyHealthReading reading, {
  required String userId,
  required String idPrefix,
}) {
  if (!reading.hasAnyData) return null;
  final now = DateTime.now();
  return HealthMetrics(
    id: '${idPrefix}_${reading.day.millisecondsSinceEpoch}',
    userId: userId,
    timestamp: reading.day,
    steps: reading.steps ?? 0,
    caloriesBurned: reading.activeCalories ?? 0,
    sleepHours: reading.sleepMinutes == null
        ? null
        : reading.sleepMinutes! / 60.0,
    restingHeartRate: reading.restingHeartRate,
    heartRateAverage: reading.averageHeartRate,
    hrv: reading.heartRateVariability,
    sourceDevice: reading.sourceName,
    syncTimestamp: now,
  );
}
