import 'recovery_state.dart';

/// Structured recovery summary for the Daily AI Coach brief.
///
/// [isMeasured] says whether the figures come from recorded sleep, HRV or
/// heart-rate data. When it is false, [recoveryScore], [sleepQuality] and
/// [fatigueLevel] are placeholders for the engines and must never be shown or
/// quoted as a measurement; [sleepHours], [restingHeartRate] and [hrv] are
/// null when not recorded.
class RecoverySummary {
  final int recoveryScore; // 0 to 100 (meaningful only when [isMeasured])
  final double? sleepHours; // null = not recorded
  final double sleepQuality; // 0.0 to 1.0 (meaningful only when [isMeasured])
  final FatigueLevel fatigueLevel;
  final String
  readinessCategory; // 'Optimal', 'Moderate', 'Fatigued', 'Critical', 'Unavailable'
  final String statusMessage;
  final bool isDeloadRecommended;
  final double? restingHeartRate;
  final double? hrv;

  /// True only when a sleep, HRV or heart-rate reading backs the score.
  final bool isMeasured;

  const RecoverySummary({
    this.recoveryScore = 80,
    this.sleepHours,
    this.sleepQuality = 0.85,
    this.fatigueLevel = FatigueLevel.low,
    this.readinessCategory = 'Unavailable',
    this.statusMessage = unavailableMessage,
    this.isDeloadRecommended = false,
    this.restingHeartRate,
    this.hrv,
    this.isMeasured = false,
  });

  static const String unavailableMessage =
      'Recovery is unavailable: no sleep, HRV or heart-rate data is recorded.';

  /// Convenience alias for recoveryScore
  int get score => recoveryScore;

  /// The score, or null when it is not a measurement.
  int? get scoreOrNull => isMeasured ? recoveryScore : null;

  factory RecoverySummary.fromRecoveryState(
    RecoveryState state, {
    double? sleepHours,
    double? restingHeartRate,
    double? hrv,
  }) {
    if (!state.isMeasured) {
      return RecoverySummary(
        recoveryScore: state.recoveryScore,
        sleepHours: sleepHours,
        sleepQuality: state.sleepQuality,
        fatigueLevel: state.fatigueLevel,
        readinessCategory: 'Unavailable',
        statusMessage: unavailableMessage,
        isDeloadRecommended: false,
        restingHeartRate: restingHeartRate,
        hrv: hrv,
        isMeasured: false,
      );
    }

    String readiness = 'Optimal';
    String message = 'Ready to train with normal intensity.';

    if (state.recoveryScore >= 80) {
      readiness = 'Optimal';
      message =
          'Peak physiological readiness. Great day for heavy progressive overload.';
    } else if (state.recoveryScore >= 60) {
      readiness = 'Moderate';
      message =
          'Sufficient recovery. Maintain planned workout volume and monitor fatigue.';
    } else if (state.recoveryScore >= 40) {
      readiness = 'Fatigued';
      message =
          'Elevated fatigue detected. Consider reducing accessory volume or taking an active rest day.';
    } else {
      readiness = 'Critical';
      message =
          'High systemic fatigue. Rest day or light mobility is strongly recommended.';
    }

    if (state.isDeloadRecommended) {
      message =
          'Deload threshold reached. Reducing weights by 10-15% will restore nervous system balance.';
    }

    return RecoverySummary(
      recoveryScore: state.recoveryScore,
      sleepHours: sleepHours,
      sleepQuality: state.sleepQuality,
      fatigueLevel: state.fatigueLevel,
      readinessCategory: readiness,
      statusMessage: message,
      isDeloadRecommended: state.isDeloadRecommended,
      restingHeartRate: restingHeartRate,
      hrv: hrv,
      isMeasured: true,
    );
  }

  /// Saved summaries from before measured data was tracked read as
  /// unavailable, with no sleep, heart rate or HRV.
  factory RecoverySummary.fromJson(Map<String, dynamic> json) {
    final measured = json['isMeasured'] == true || json['is_measured'] == true;
    return RecoverySummary(
      recoveryScore:
          (json['recoveryScore'] as num?)?.toInt() ??
          (json['recovery_score'] as num?)?.toInt() ??
          80,
      sleepHours:
          (json['sleepHours'] as num?)?.toDouble() ??
          (json['sleep_hours'] as num?)?.toDouble(),
      sleepQuality:
          (json['sleepQuality'] as num?)?.toDouble() ??
          (json['sleep_quality'] as num?)?.toDouble() ??
          0.85,
      fatigueLevel: FatigueLevel.values.firstWhere(
        (e) =>
            e.name ==
            (json['fatigueLevel'] as String? ??
                json['fatigue_level'] as String? ??
                'low'),
        orElse: () => FatigueLevel.low,
      ),
      readinessCategory: measured
          ? (json['readinessCategory'] as String? ??
                json['readiness_category'] as String? ??
                'Unavailable')
          : 'Unavailable',
      statusMessage: measured
          ? (json['statusMessage'] as String? ??
                json['status_message'] as String? ??
                unavailableMessage)
          : unavailableMessage,
      isDeloadRecommended:
          measured &&
          (json['isDeloadRecommended'] as bool? ??
              json['is_deload_recommended'] as bool? ??
              false),
      restingHeartRate:
          (json['restingHeartRate'] as num?)?.toDouble() ??
          (json['resting_heart_rate'] as num?)?.toDouble(),
      hrv: (json['hrv'] as num?)?.toDouble(),
      isMeasured: measured,
    );
  }

  Map<String, dynamic> toJson() => {
    'recovery_score': recoveryScore,
    if (sleepHours != null) 'sleep_hours': sleepHours,
    'sleep_quality': sleepQuality,
    'fatigue_level': fatigueLevel.name,
    'readiness_category': readinessCategory,
    'status_message': statusMessage,
    'is_deload_recommended': isDeloadRecommended,
    'is_measured': isMeasured,
    if (restingHeartRate != null) 'resting_heart_rate': restingHeartRate,
    if (hrv != null) 'hrv': hrv,
  };

  RecoverySummary copyWith({
    int? recoveryScore,
    double? sleepHours,
    double? sleepQuality,
    FatigueLevel? fatigueLevel,
    String? readinessCategory,
    String? statusMessage,
    bool? isDeloadRecommended,
    double? restingHeartRate,
    double? hrv,
    bool? isMeasured,
  }) {
    return RecoverySummary(
      recoveryScore: recoveryScore ?? this.recoveryScore,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepQuality: sleepQuality ?? this.sleepQuality,
      fatigueLevel: fatigueLevel ?? this.fatigueLevel,
      readinessCategory: readinessCategory ?? this.readinessCategory,
      statusMessage: statusMessage ?? this.statusMessage,
      isDeloadRecommended: isDeloadRecommended ?? this.isDeloadRecommended,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      hrv: hrv ?? this.hrv,
      isMeasured: isMeasured ?? this.isMeasured,
    );
  }
}
