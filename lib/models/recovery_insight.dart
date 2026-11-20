import 'sleep_record.dart';

/// Overall interpretation status of available recovery telemetry.
enum RecoveryStatus {
  optimal('Optimal recovery', '🟢'),
  good('Recovery looks good', '🟢'),
  moderate('Moderate recovery', '🟡'),
  needsRest('Consider lighter training', '🟠'),
  insufficientData('Not enough data yet', '⚪');

  final String label;
  final String icon;
  const RecoveryStatus(this.label, this.icon);
}

/// Factual interpretation of sleep and recovery data without arbitrary scores or medical claims.
class RecoveryInsight {
  final RecoveryStatus status;
  final String interpretation;
  final List<String> reasoningBullets;
  final SleepRecord? latestSleep;
  final double? restingHeartRate;
  final double? rhrDiffFromBaseline; // e.g. -3.0
  final double? hrv; // in ms
  final double? hrvPercentDiffFromBaseline; // e.g. 8.0 for +8%
  final HealthDataSource source;
  final bool hasSufficientData;
  final bool isEstimated;
  final DateTime generatedAt;

  const RecoveryInsight({
    required this.status,
    required this.interpretation,
    this.reasoningBullets = const [],
    this.latestSleep,
    this.restingHeartRate,
    this.rhrDiffFromBaseline,
    this.hrv,
    this.hrvPercentDiffFromBaseline,
    this.source = HealthDataSource.manual,
    this.hasSufficientData = true,
    this.isEstimated = false,
    required this.generatedAt,
  });

  /// Factory for new/fresh users who do not have any logged sleep or wearable data yet.
  factory RecoveryInsight.insufficientData() {
    return RecoveryInsight(
      status: RecoveryStatus.insufficientData,
      interpretation:
          'Not enough data yet. Log a few nights of sleep or connect a wearable to unlock recovery insights.',
      reasoningBullets: const [],
      latestSleep: null,
      restingHeartRate: null,
      hrv: null,
      hasSufficientData: false,
      isEstimated: false,
      source: HealthDataSource.manual,
      generatedAt: DateTime.now(),
    );
  }

  /// Calculates a factual recovery insight from available sleep records and physiological signals.
  factory RecoveryInsight.fromTelemetry({
    required SleepRecord? latestSleep,
    List<SleepRecord> history = const [],
    double? restingHeartRate,
    double? baselineRhr,
    double? hrv,
    double? baselineHrv,
    HealthDataSource source = HealthDataSource.manual,
  }) {
    if (latestSleep == null) {
      return RecoveryInsight.insufficientData();
    }

    final bullets = <String>[];

    // Compute baseline RHR from history if not explicitly provided
    double? effectiveBaselineRhr = baselineRhr;
    if (effectiveBaselineRhr == null && history.length >= 2) {
      final rhrRecords =
          history.where((r) => r.restingHeartRate != null).toList();
      if (rhrRecords.isNotEmpty) {
        final total = rhrRecords.fold<double>(
          0.0,
          (sum, r) => sum + r.restingHeartRate!,
        );
        effectiveBaselineRhr = total / rhrRecords.length;
      }
    }

    // Compute baseline HRV from history if not explicitly provided
    double? effectiveBaselineHrv = baselineHrv;
    if (effectiveBaselineHrv == null && history.length >= 2) {
      final hrvRecords = history.where((r) => r.hrv != null).toList();
      if (hrvRecords.isNotEmpty) {
        final total = hrvRecords.fold<double>(
          0.0,
          (sum, r) => sum + r.hrv!,
        );
        effectiveBaselineHrv = total / hrvRecords.length;
      }
    }

    double? rhrDiff;
    if (restingHeartRate != null &&
        effectiveBaselineRhr != null &&
        effectiveBaselineRhr > 0) {
      rhrDiff = restingHeartRate - effectiveBaselineRhr;
    }

    double? hrvPercentDiff;
    if (hrv != null &&
        effectiveBaselineHrv != null &&
        effectiveBaselineHrv > 0) {
      hrvPercentDiff =
          ((hrv - effectiveBaselineHrv) / effectiveBaselineHrv) * 100.0;
    }

    // Evaluate duration
    final durationMins = latestSleep.durationMinutes;
    final hours = durationMins ~/ 60;
    final mins = durationMins % 60;
    final sleepDurationStr = '${hours}h ${mins}m sleep';

    if (durationMins >= 450) {
      // >= 7.5h
      bullets.add('$sleepDurationStr (close to 8h goal)');
    } else if (durationMins >= 360) {
      // 6h - 7.5h
      bullets.add('$sleepDurationStr (moderate duration)');
    } else {
      bullets.add('$sleepDurationStr (below target)');
    }

    // Consistency & Quality
    if (latestSleep.consistency == SleepConsistency.optimal ||
        latestSleep.consistency == SleepConsistency.good) {
      bullets.add('${latestSleep.consistency.label} sleep consistency');
    }

    if (restingHeartRate != null) {
      if (rhrDiff != null && rhrDiff.abs() <= 3.0) {
        bullets.add('Resting HR near baseline ($restingHeartRate bpm)');
      } else if (rhrDiff != null && rhrDiff < -3.0) {
        bullets.add('Resting HR below baseline (favorable recovery)');
      } else if (rhrDiff != null && rhrDiff > 4.0) {
        bullets.add('Resting HR elevated (+${rhrDiff.toStringAsFixed(0)} bpm)');
      }
    }

    if (hrv != null) {
      if (hrvPercentDiff != null && hrvPercentDiff >= 0) {
        bullets.add('HRV is stable / elevated (${hrv.toStringAsFixed(0)} ms)');
      }
    }

    // Determine status & plain-English interpretation
    RecoveryStatus status;
    String interpretation;

    if (durationMins >= 450 && (rhrDiff == null || rhrDiff <= 2)) {
      status = RecoveryStatus.good;
      interpretation =
          'Your sleep duration was close to your goal and your physiological signals are stable. Your planned workout looks reasonable today.';
    } else if (durationMins >= 420) {
      status = RecoveryStatus.good;
      interpretation =
          'Your sleep duration and recovery markers look solid. You are in good condition for training.';
    } else if (durationMins >= 360) {
      status = RecoveryStatus.moderate;
      interpretation =
          'Your sleep was slightly shorter than your target. Consider moderating high-intensity volume if feeling fatigued.';
    } else {
      status = RecoveryStatus.needsRest;
      interpretation =
          'Short sleep duration logged. Consider a lighter active recovery session or focusing on restful sleep tonight.';
    }

    return RecoveryInsight(
      status: status,
      interpretation: interpretation,
      reasoningBullets: bullets,
      latestSleep: latestSleep,
      restingHeartRate: restingHeartRate,
      rhrDiffFromBaseline: rhrDiff,
      hrv: hrv,
      hrvPercentDiffFromBaseline: hrvPercentDiff,
      source: source,
      hasSufficientData: true,
      isEstimated: source == HealthDataSource.manual || source == HealthDataSource.showcase,
      generatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'interpretation': interpretation,
        'reasoningBullets': reasoningBullets,
        'latestSleep': latestSleep?.toJson(),
        'restingHeartRate': restingHeartRate,
        'rhrDiffFromBaseline': rhrDiffFromBaseline,
        'hrv': hrv,
        'hrvPercentDiffFromBaseline': hrvPercentDiffFromBaseline,
        'source': source.name,
        'hasSufficientData': hasSufficientData,
        'isEstimated': isEstimated,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory RecoveryInsight.fromJson(Map<String, dynamic> json) {
    return RecoveryInsight(
      status: RecoveryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RecoveryStatus.good,
      ),
      interpretation: json['interpretation'] as String? ?? 'Recovery looks good',
      reasoningBullets: (json['reasoningBullets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      latestSleep: json['latestSleep'] != null
          ? SleepRecord.fromJson(json['latestSleep'] as Map<String, dynamic>)
          : null,
      restingHeartRate: (json['restingHeartRate'] as num?)?.toDouble(),
      rhrDiffFromBaseline: (json['rhrDiffFromBaseline'] as num?)?.toDouble(),
      hrv: (json['hrv'] as num?)?.toDouble(),
      hrvPercentDiffFromBaseline: (json['hrvPercentDiffFromBaseline'] as num?)?.toDouble(),
      source: HealthDataSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => HealthDataSource.manual,
      ),
      hasSufficientData: json['hasSufficientData'] as bool? ?? true,
      isEstimated: json['isEstimated'] as bool? ?? false,
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }
}
