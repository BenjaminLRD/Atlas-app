/// Domain model representing daily integrated health metrics (steps, sleep, heart rate, active minutes, wearable data).
class HealthMetrics {
  final String id;
  final DateTime date;
  final int steps;
  final double caloriesBurned;
  final double heartRateAverage;
  final double sleepHours;
  final int activeMinutes;
  final String sourceDevice;
  final double restingHeartRate;
  final double bloodOxygen;
  final double hrv;
  final DateTime? syncTimestamp;

  const HealthMetrics({
    required this.id,
    required this.date,
    this.steps = 0,
    this.caloriesBurned = 0.0,
    this.heartRateAverage = 0.0,
    this.sleepHours = 0.0,
    this.activeMinutes = 0,
    this.sourceDevice = 'Local Sensor',
    this.restingHeartRate = 60.0,
    this.bloodOxygen = 98.0,
    this.hrv = 55.0,
    this.syncTimestamp,
  });

  factory HealthMetrics.fromJson(Map<String, dynamic> json) {
    return HealthMetrics(
      id: json['id'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      steps: json['steps'] as int? ?? (json['step_count'] as int? ?? 0),
      caloriesBurned: (json['caloriesBurned'] as num? ??
              (json['calories_burned'] as num? ?? 0.0))
          .toDouble(),
      heartRateAverage: (json['heartRateAverage'] as num? ??
              (json['heart_rate_average'] as num? ?? 0.0))
          .toDouble(),
      sleepHours: (json['sleepHours'] as num? ??
              (json['sleep_hours'] as num? ?? 0.0))
          .toDouble(),
      activeMinutes: json['activeMinutes'] as int? ??
          (json['active_minutes'] as int? ?? 0),
      sourceDevice: json['sourceDevice'] as String? ??
          (json['source_device'] as String? ?? 'Local Sensor'),
      restingHeartRate: (json['restingHeartRate'] as num? ??
              (json['resting_heart_rate'] as num? ?? 60.0))
          .toDouble(),
      bloodOxygen: (json['bloodOxygen'] as num? ??
              (json['blood_oxygen'] as num? ?? 98.0))
          .toDouble(),
      hrv: (json['hrv'] as num? ?? 55.0).toDouble(),
      syncTimestamp: json['syncTimestamp'] != null
          ? DateTime.parse(json['syncTimestamp'] as String)
          : (json['sync_timestamp'] != null
              ? DateTime.parse(json['sync_timestamp'] as String)
              : null),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'steps': steps,
        'caloriesBurned': caloriesBurned,
        'heartRateAverage': heartRateAverage,
        'sleepHours': sleepHours,
        'activeMinutes': activeMinutes,
        'sourceDevice': sourceDevice,
        'restingHeartRate': restingHeartRate,
        'bloodOxygen': bloodOxygen,
        'hrv': hrv,
        'syncTimestamp': syncTimestamp?.toIso8601String(),
      };

  HealthMetrics copyWith({
    String? id,
    DateTime? date,
    int? steps,
    double? caloriesBurned,
    double? heartRateAverage,
    double? sleepHours,
    int? activeMinutes,
    String? sourceDevice,
    double? restingHeartRate,
    double? bloodOxygen,
    double? hrv,
    DateTime? syncTimestamp,
  }) {
    return HealthMetrics(
      id: id ?? this.id,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      heartRateAverage: heartRateAverage ?? this.heartRateAverage,
      sleepHours: sleepHours ?? this.sleepHours,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      bloodOxygen: bloodOxygen ?? this.bloodOxygen,
      hrv: hrv ?? this.hrv,
      syncTimestamp: syncTimestamp ?? this.syncTimestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthMetrics &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          steps == other.steps &&
          activeMinutes == other.activeMinutes &&
          sourceDevice == other.sourceDevice;

  @override
  int get hashCode =>
      id.hashCode ^ steps.hashCode ^ activeMinutes.hashCode ^ sourceDevice.hashCode;
}
