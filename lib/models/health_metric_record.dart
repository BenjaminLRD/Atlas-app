import 'health_metrics.dart';
import 'health_metric.dart';

/// Supported health data source platforms and providers.
enum HealthMetricSource {
  manual,
  healthConnect,
  appleHealth,
  garmin,
  fitbit,
  mock;

  String get displayName {
    switch (this) {
      case HealthMetricSource.manual:
        return 'Manual Entry';
      case HealthMetricSource.healthConnect:
        return 'Google Health Connect';
      case HealthMetricSource.appleHealth:
        return 'Apple HealthKit';
      case HealthMetricSource.garmin:
        return 'Garmin Connect';
      case HealthMetricSource.fitbit:
        return 'Fitbit';
      case HealthMetricSource.mock:
        return 'Local Sensor / Simulation';
    }
  }

  static HealthMetricSource fromString(String? source) {
    if (source == null) return HealthMetricSource.mock;
    final clean = source.toLowerCase().replaceAll('_', '').replaceAll('-', '').replaceAll(' ', '');
    if (clean.contains('healthconnect') || clean.contains('googlefit') || clean.contains('google')) {
      return HealthMetricSource.healthConnect;
    }
    if (clean.contains('applehealth') || clean.contains('healthkit') || clean.contains('apple')) {
      return HealthMetricSource.appleHealth;
    }
    if (clean.contains('garmin')) return HealthMetricSource.garmin;
    if (clean.contains('fitbit')) return HealthMetricSource.fitbit;
    if (clean.contains('manual')) return HealthMetricSource.manual;
    return HealthMetricSource.mock;
  }
}

/// Unified physiological health metric record representing a single sync or timestamped telemetry reading.
class HealthMetricRecord {
  final String id;
  final String userId;
  final DateTime timestamp;
  final double? heartRate;
  final double? restingHeartRate;
  final double? hrv;
  final double? sleepHours;
  final int? steps;
  final double? caloriesBurned;
  final HealthMetricSource source;

  const HealthMetricRecord({
    required this.id,
    this.userId = 'usr_local',
    required this.timestamp,
    this.heartRate,
    this.restingHeartRate,
    this.hrv,
    this.sleepHours,
    this.steps,
    this.caloriesBurned,
    this.source = HealthMetricSource.mock,
  });

  /// Factory constructor to parse JSON database / cache representations.
  factory HealthMetricRecord.fromJson(Map<String, dynamic> json) {
    final rawDate = json['timestamp'] ?? json['date'] ?? json['created_at'];
    final parsedTimestamp = rawDate != null
        ? DateTime.tryParse(rawDate.toString()) ?? DateTime.now()
        : DateTime.now();

    return HealthMetricRecord(
      id: json['id'] as String? ?? 'metric_${parsedTimestamp.millisecondsSinceEpoch}',
      userId: json['userId'] as String? ?? (json['user_id'] as String? ?? 'usr_local'),
      timestamp: parsedTimestamp,
      heartRate: (json['heartRate'] as num? ?? (json['heart_rate'] as num?))?.toDouble(),
      restingHeartRate: (json['restingHeartRate'] as num? ?? (json['resting_heart_rate'] as num?))?.toDouble(),
      hrv: (json['hrv'] as num? ?? (json['heartRateVariability'] as num? ?? (json['heart_rate_variability'] as num?)))?.toDouble(),
      sleepHours: (json['sleepHours'] as num? ?? (json['sleep_hours'] as num?))?.toDouble(),
      steps: json['steps'] as int? ?? (json['step_count'] as int?),
      caloriesBurned: (json['caloriesBurned'] as num? ?? (json['calories_burned'] as num?))?.toDouble(),
      source: HealthMetricSource.fromString(json['source'] as String?),
    );
  }

  /// Converts record to JSON map for local cache and Supabase syncing.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'timestamp': timestamp.toIso8601String(),
      'heart_rate': heartRate,
      'resting_heart_rate': restingHeartRate,
      'hrv': hrv,
      'sleep_hours': sleepHours,
      'step_count': steps,
      'calories_burned': caloriesBurned,
      'source': source.name,
    };
  }

  /// Converts this record into domain `HealthMetrics` used across recovery engines.
  HealthMetrics toHealthMetrics() {
    return HealthMetrics(
      id: id,
      userId: userId,
      timestamp: timestamp,
      // Values the record does not have stay null; nothing is filled in.
      sleepHours: sleepHours,
      restingHeartRate: restingHeartRate,
      heartRateVariability: hrv,
      steps: steps ?? 0,
      caloriesBurned: caloriesBurned ?? 0.0,
      heartRateAverage: heartRate,
      sourceDevice: source.displayName,
      syncTimestamp: DateTime.now(),
    );
  }

  /// Converts this record into legacy `HealthMetric` for UI widget backwards compatibility.
  HealthMetric toHealthMetric() {
    return HealthMetric(
      timestamp: timestamp,
      steps: steps ?? 0,
      activeCalories: caloriesBurned ?? 0.0,
      heartRate: heartRate?.round(),
      restingHeartRate: restingHeartRate?.round(),
      sleepMinutes: sleepHours != null ? (sleepHours! * 60).round() : null,
      heartRateVariability: hrv,
      source: source.name,
    );
  }

  /// Creates a `HealthMetricRecord` from a `HealthMetrics` domain instance.
  factory HealthMetricRecord.fromHealthMetrics(HealthMetrics metrics) {
    return HealthMetricRecord(
      id: metrics.id,
      userId: metrics.userId,
      timestamp: metrics.timestamp,
      heartRate: metrics.heartRateAverage,
      restingHeartRate: metrics.restingHeartRate,
      hrv: metrics.heartRateVariability,
      sleepHours: metrics.sleepHours,
      steps: metrics.steps,
      caloriesBurned: metrics.caloriesBurned,
      source: HealthMetricSource.fromString(metrics.sourceDevice),
    );
  }

  /// Creates a `HealthMetricRecord` from a `HealthMetric` instance.
  factory HealthMetricRecord.fromHealthMetric(HealthMetric metric, {String userId = 'usr_local', String id = ''}) {
    return HealthMetricRecord(
      id: id.isNotEmpty ? id : 'metric_${metric.timestamp.millisecondsSinceEpoch}',
      userId: userId,
      timestamp: metric.timestamp,
      heartRate: metric.heartRate?.toDouble(),
      restingHeartRate: metric.restingHeartRate?.toDouble(),
      hrv: metric.heartRateVariability,
      sleepHours: metric.sleepMinutes != null ? metric.sleepMinutes! / 60.0 : null,
      steps: metric.steps,
      caloriesBurned: metric.activeCalories,
      source: HealthMetricSource.fromString(metric.source),
    );
  }

  HealthMetricRecord copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    double? heartRate,
    double? restingHeartRate,
    double? hrv,
    double? sleepHours,
    int? steps,
    double? caloriesBurned,
    HealthMetricSource? source,
  }) {
    return HealthMetricRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      heartRate: heartRate ?? this.heartRate,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      hrv: hrv ?? this.hrv,
      sleepHours: sleepHours ?? this.sleepHours,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      source: source ?? this.source,
    );
  }
}
