import 'health_metric.dart';

/// Domain model representing daily integrated health metrics (sleep, resting heart rate, HRV, steps, stress, recovery).
class HealthMetrics {
  final String id;
  final String userId;
  final DateTime timestamp;
  // Null means the health store did not report the value. Never a stand-in.
  final double? sleepHours;
  final double? restingHeartRate;
  final double? heartRateVariability; // HRV in ms
  final int steps;
  final double? stressLevel; // 0.0 - 100.0 (lower is calmer)
  final int? recoveryScore; // 0 - 100
  final double caloriesBurned;
  final int activeMinutes;
  final String sourceDevice;
  final double? bloodOxygen;
  final double? heartRateAverage;
  final DateTime? syncTimestamp;

  HealthMetrics({
    required this.id,
    this.userId = 'usr_local',
    DateTime? timestamp,
    DateTime? date,
    this.sleepHours,
    this.restingHeartRate,
    double? heartRateVariability,
    double? hrv,
    this.steps = 0,
    this.stressLevel,
    this.recoveryScore,
    this.caloriesBurned = 0.0,
    this.activeMinutes = 0,
    this.sourceDevice = 'Local Sensor',
    this.bloodOxygen,
    this.heartRateAverage,
    this.syncTimestamp,
  })  : timestamp = timestamp ?? date ?? DateTime.now(),
        heartRateVariability = heartRateVariability ?? hrv;

  /// Alias getters for backwards compatibility across existing widgets & services
  DateTime get date => timestamp;
  double? get hrv => heartRateVariability;
  double? get stressScore => stressLevel;
  String get source => sourceDevice;

  /// Recovery-relevant readings of a unified [HealthMetric]. Values it does
  /// not have stay null.
  factory HealthMetrics.fromUnified(HealthMetric m) {
    final sleep = m.sleepHours;
    return HealthMetrics(
      id: 'unified_${m.timestamp.millisecondsSinceEpoch}',
      timestamp: m.timestamp,
      sleepHours: sleep > 0 ? sleep : null,
      restingHeartRate: (m.restingHeartRate ?? 0) > 0
          ? m.restingHeartRate!.toDouble()
          : null,
      heartRateVariability: (m.heartRateVariability ?? 0) > 0
          ? m.heartRateVariability
          : null,
      heartRateAverage: (m.heartRate ?? 0) > 0 ? m.heartRate!.toDouble() : null,
      steps: m.steps,
      caloriesBurned: m.activeCalories,
      sourceDevice: m.source,
    );
  }

  factory HealthMetrics.fromJson(Map<String, dynamic> json) {
    final rawDate = json['timestamp'] ?? json['date'] ?? json['created_at'];
    final parsedTimestamp = rawDate != null ? DateTime.parse(rawDate as String) : DateTime.now();

    return HealthMetrics(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? (json['user_id'] as String? ?? 'usr_local'),
      timestamp: parsedTimestamp,
      sleepHours: (json['sleepHours'] as num? ?? json['sleep_hours'] as num?)?.toDouble(),
      restingHeartRate: (json['restingHeartRate'] as num? ?? json['resting_heart_rate'] as num?)?.toDouble(),
      heartRateVariability: (json['heartRateVariability'] as num? ?? json['hrv'] as num?)?.toDouble(),
      steps: json['steps'] as int? ?? (json['step_count'] as int? ?? 0),
      stressLevel: (json['stressLevel'] as num? ?? json['stress_level'] as num? ?? json['stress_score'] as num?)?.toDouble(),
      recoveryScore: json['recoveryScore'] as int? ?? json['recovery_score'] as int?,
      caloriesBurned: (json['caloriesBurned'] as num? ?? (json['calories_burned'] as num? ?? 0.0)).toDouble(),
      activeMinutes: json['activeMinutes'] as int? ?? (json['active_minutes'] as int? ?? 0),
      sourceDevice: json['sourceDevice'] as String? ?? (json['source_device'] as String? ?? 'Local Sensor'),
      bloodOxygen: (json['bloodOxygen'] as num? ?? json['blood_oxygen'] as num?)?.toDouble(),
      heartRateAverage: (json['heartRateAverage'] as num? ?? json['heart_rate_average'] as num?)?.toDouble(),
      syncTimestamp: json['syncTimestamp'] != null
          ? DateTime.parse(json['syncTimestamp'] as String)
          : (json['sync_timestamp'] != null ? DateTime.parse(json['sync_timestamp'] as String) : null),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'user_id': userId,
    'timestamp': timestamp.toIso8601String(),
    'date': timestamp.toIso8601String(),
    'sleepHours': sleepHours,
    'sleep_hours': sleepHours,
    'restingHeartRate': restingHeartRate,
    'resting_heart_rate': restingHeartRate,
    'heartRateVariability': heartRateVariability,
    'hrv': heartRateVariability,
    'steps': steps,
    'step_count': steps,
    'stressLevel': stressLevel,
    'stress_level': stressLevel,
    'recoveryScore': recoveryScore,
    'recovery_score': recoveryScore,
    'caloriesBurned': caloriesBurned,
    'calories_burned': caloriesBurned,
    'activeMinutes': activeMinutes,
    'active_minutes': activeMinutes,
    'sourceDevice': sourceDevice,
    'source_device': sourceDevice,
    'bloodOxygen': bloodOxygen,
    'blood_oxygen': bloodOxygen,
    'heartRateAverage': heartRateAverage,
    'heart_rate_average': heartRateAverage,
    'syncTimestamp': syncTimestamp?.toIso8601String(),
    'sync_timestamp': syncTimestamp?.toIso8601String(),
  };

  HealthMetrics copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    double? sleepHours,
    double? restingHeartRate,
    double? heartRateVariability,
    int? steps,
    double? stressLevel,
    int? recoveryScore,
    double? caloriesBurned,
    int? activeMinutes,
    String? sourceDevice,
    double? bloodOxygen,
    double? heartRateAverage,
    DateTime? syncTimestamp,
  }) {
    return HealthMetrics(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      sleepHours: sleepHours ?? this.sleepHours,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      heartRateVariability: heartRateVariability ?? this.heartRateVariability,
      steps: steps ?? this.steps,
      stressLevel: stressLevel ?? this.stressLevel,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      bloodOxygen: bloodOxygen ?? this.bloodOxygen,
      heartRateAverage: heartRateAverage ?? this.heartRateAverage,
      syncTimestamp: syncTimestamp ?? this.syncTimestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthMetrics &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          steps == other.steps &&
          activeMinutes == other.activeMinutes &&
          sourceDevice == other.sourceDevice;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      steps.hashCode ^
      activeMinutes.hashCode ^
      sourceDevice.hashCode;
}
