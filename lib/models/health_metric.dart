/// Domain model representing unified health telemetry from Health Connect,
/// smartwatches, fitness bands, or mock health providers.
class HealthMetric {
  final DateTime timestamp;
  final int steps;
  final double distanceKm;
  final double activeCalories;
  final int? heartRate; // Live / average BPM from connected smartwatch or band
  final int? sleepMinutes; // Total sleep in minutes
  final int? restingHeartRate;
  final int? deepSleepMinutes;
  final int? remSleepMinutes;
  final double? heartRateVariability; // HRV in ms
  final double? sleepQuality; // 0.0 - 100.0%
  final double? stressScore; // 0.0 - 100.0 (lower is calmer)
  final double? trainingLoad; // Acute load score
  final String
  source; // 'health_connect', 'wearable_smartwatch', 'fitness_band', 'apple_health', 'mock'

  const HealthMetric({
    required this.timestamp,
    this.steps = 0,
    this.distanceKm = 0.0,
    this.activeCalories = 0.0,
    this.heartRate,
    this.sleepMinutes,
    this.restingHeartRate,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.heartRateVariability,
    this.sleepQuality,
    this.stressScore,
    this.trainingLoad,
    this.source = 'none',
  });

  /// Alias getters for API compatibility
  double get distance => distanceKm;
  int? get averageHeartRate => heartRate;
  int? get sleepDuration => sleepMinutes;
  int? get deepSleep => deepSleepMinutes;

  /// Default baseline sample for active athletes
  factory HealthMetric.sample() {
    return HealthMetric(
      timestamp: DateTime.now(),
      steps: 8432,
      distanceKm: 5.2,
      activeCalories: 520.0,
      heartRate: 72,
      sleepMinutes: 440, // 7h 20m
      restingHeartRate: 64,
      deepSleepMinutes: 95,
      remSleepMinutes: 110,
      heartRateVariability: 68.0,
      sleepQuality: 88.0,
      stressScore: 18.0,
      trainingLoad: 420.0,
      source: 'health_connect',
    );
  }

  /// Clean zero/empty health telemetry baseline
  factory HealthMetric.zero({DateTime? date}) {
    return HealthMetric(
      timestamp: date ?? DateTime.now(),
      steps: 0,
      distanceKm: 0.0,
      activeCalories: 0.0,
      heartRate: null,
      sleepMinutes: null,
      restingHeartRate: null,
      deepSleepMinutes: null,
      remSleepMinutes: null,
      heartRateVariability: null,
      sleepQuality: null,
      stressScore: null,
      trainingLoad: null,
      source: 'local',
    );
  }

  /// Formatted sleep duration string (e.g. '7h 20m' or '--')
  String get formattedSleep {
    if (sleepMinutes == null || sleepMinutes! <= 0) return '--';
    final hours = sleepMinutes! ~/ 60;
    final mins = sleepMinutes! % 60;
    return '${hours}h ${mins}m';
  }

  /// Sleep duration in decimal hours (e.g. 7.33)
  double get sleepHours {
    if (sleepMinutes == null || sleepMinutes! <= 0) return 0.0;
    return sleepMinutes! / 60.0;
  }

  /// Formatted distance string (e.g. '5.2 km')
  String get formattedDistance {
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Formatted active calories string (e.g. '520 kcal')
  String get formattedCalories {
    return '${activeCalories.toStringAsFixed(0)} kcal';
  }

  /// Formatted heart rate string (e.g. '72 bpm')
  String get formattedHeartRate {
    if (heartRate == null || heartRate! <= 0) return '-- bpm';
    return '$heartRate bpm';
  }

  /// Copy with helper
  HealthMetric copyWith({
    DateTime? timestamp,
    int? steps,
    double? distanceKm,
    double? activeCalories,
    int? heartRate,
    int? sleepMinutes,
    int? restingHeartRate,
    int? deepSleepMinutes,
    int? remSleepMinutes,
    double? heartRateVariability,
    double? sleepQuality,
    double? stressScore,
    double? trainingLoad,
    String? source,
  }) {
    return HealthMetric(
      timestamp: timestamp ?? this.timestamp,
      steps: steps ?? this.steps,
      distanceKm: distanceKm ?? this.distanceKm,
      activeCalories: activeCalories ?? this.activeCalories,
      heartRate: heartRate ?? this.heartRate,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      deepSleepMinutes: deepSleepMinutes ?? this.deepSleepMinutes,
      remSleepMinutes: remSleepMinutes ?? this.remSleepMinutes,
      heartRateVariability: heartRateVariability ?? this.heartRateVariability,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      stressScore: stressScore ?? this.stressScore,
      trainingLoad: trainingLoad ?? this.trainingLoad,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'steps': steps,
      'distanceKm': distanceKm,
      'activeCalories': activeCalories,
      'heartRate': heartRate,
      'sleepMinutes': sleepMinutes,
      'restingHeartRate': restingHeartRate,
      'deepSleepMinutes': deepSleepMinutes,
      'remSleepMinutes': remSleepMinutes,
      'heartRateVariability': heartRateVariability,
      'sleepQuality': sleepQuality,
      'stressScore': stressScore,
      'trainingLoad': trainingLoad,
      'source': source,
    };
  }

  factory HealthMetric.fromJson(Map<String, dynamic> json) {
    return HealthMetric(
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      distanceKm:
          (json['distanceKm'] as num?)?.toDouble() ??
          (json['distance'] as num?)?.toDouble() ??
          0.0,
      activeCalories: (json['activeCalories'] as num?)?.toDouble() ?? 0.0,
      heartRate:
          (json['heartRate'] as num?)?.toInt() ??
          (json['averageHeartRate'] as num?)?.toInt(),
      sleepMinutes:
          (json['sleepMinutes'] as num?)?.toInt() ??
          (json['sleepDuration'] as num?)?.toInt(),
      restingHeartRate: (json['restingHeartRate'] as num?)?.toInt(),
      deepSleepMinutes:
          (json['deepSleepMinutes'] as num?)?.toInt() ??
          (json['deepSleep'] as num?)?.toInt(),
      remSleepMinutes: (json['remSleepMinutes'] as num?)?.toInt(),
      heartRateVariability:
          (json['heartRateVariability'] as num?)?.toDouble() ??
          (json['hrv'] as num?)?.toDouble() ??
          65.0,
      sleepQuality: (json['sleepQuality'] as num?)?.toDouble() ?? 85.0,
      stressScore: (json['stressScore'] as num?)?.toDouble() ?? 20.0,
      trainingLoad: (json['trainingLoad'] as num?)?.toDouble() ?? 350.0,
      source: json['source'] as String? ?? 'mock',
    );
  }
}
