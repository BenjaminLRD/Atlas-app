import '../health_metrics.dart';

/// What a readiness or recovery result is built from.
///
/// A recovery score says something about the body only when a physiological
/// signal (sleep, HRV or heart rate) was actually recorded. Training history
/// alone describes training load, not recovery. Anything else is "no result":
/// there is no neutral default that stands in for a measurement.
enum ReadinessBasis {
  /// No sleep, HRV or heart-rate data and no workout history.
  none,

  /// No physiological signal, but workout history exists: training load can
  /// be described, recovery cannot be judged.
  trainingOnly,

  /// At least one physiological signal was recorded.
  physiological,
}

/// Which real inputs exist right now. Built from recorded values only.
class ReadinessInputs {
  final bool hasSleep;
  final bool hasHrv;
  final bool hasRestingHeartRate;
  final bool hasAverageHeartRate;
  final bool hasWorkoutHistory;
  final bool hasNutrition;
  final bool hasSteps;

  const ReadinessInputs({
    this.hasSleep = false,
    this.hasHrv = false,
    this.hasRestingHeartRate = false,
    this.hasAverageHeartRate = false,
    this.hasWorkoutHistory = false,
    this.hasNutrition = false,
    this.hasSteps = false,
  });

  /// Nothing is known.
  static const ReadinessInputs empty = ReadinessInputs();

  /// Inputs present in [metrics] (null = no health data at all).
  factory ReadinessInputs.fromMetrics(
    HealthMetrics? metrics, {
    bool hasWorkoutHistory = false,
    bool hasNutrition = false,
    bool hasSteps = false,
  }) {
    final sleep = metrics?.sleepHours;
    return ReadinessInputs(
      hasSleep: sleep != null && sleep > 0,
      hasHrv: (metrics?.heartRateVariability ?? 0) > 0,
      hasRestingHeartRate: (metrics?.restingHeartRate ?? 0) > 0,
      hasAverageHeartRate: (metrics?.heartRateAverage ?? 0) > 0,
      hasWorkoutHistory: hasWorkoutHistory,
      hasNutrition: hasNutrition,
      hasSteps: hasSteps,
    );
  }

  bool get hasHeartSignal =>
      hasHrv || hasRestingHeartRate || hasAverageHeartRate;

  bool get hasPhysiological => hasSleep || hasHeartSignal;

  ReadinessBasis get basis => hasPhysiological
      ? ReadinessBasis.physiological
      : (hasWorkoutHistory ? ReadinessBasis.trainingOnly : ReadinessBasis.none);

  /// Names of the physiological signals that are missing, for plain wording.
  List<String> get missingPhysiological => [
    if (!hasSleep) 'sleep',
    if (!hasHrv) 'HRV',
    if (!hasRestingHeartRate && !hasAverageHeartRate) 'heart rate',
  ];

  /// "sleep, HRV and heart rate", "sleep", ...
  static String joinNames(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  /// One sentence on what is needed, or null when readiness can be judged.
  String? get unavailableReason => hasPhysiological
      ? null
      : 'Readiness needs sleep or heart-rate data from a watch or Health Connect. None is recorded yet.';

  Map<String, dynamic> toJson() => {
    'sleep': hasSleep,
    'hrv': hasHrv,
    'restingHr': hasRestingHeartRate,
    'avgHr': hasAverageHeartRate,
    'workouts': hasWorkoutHistory,
    'nutrition': hasNutrition,
    'steps': hasSteps,
  };

  /// Missing keys read as "not available". Data saved before inputs were
  /// recorded therefore reads as unavailable, never as measured.
  factory ReadinessInputs.fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    return ReadinessInputs(
      hasSleep: j['sleep'] == true,
      hasHrv: j['hrv'] == true,
      hasRestingHeartRate: j['restingHr'] == true,
      hasAverageHeartRate: j['avgHr'] == true,
      hasWorkoutHistory: j['workouts'] == true,
      hasNutrition: j['nutrition'] == true,
      hasSteps: j['steps'] == true,
    );
  }
}
