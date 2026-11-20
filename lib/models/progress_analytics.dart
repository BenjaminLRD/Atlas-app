import 'personal_record.dart';

enum GrowthStatus {
  growing('Growing'),
  maintaining('Maintaining'),
  undertrained('Undertrained'),
  overtrained('Overtrained');

  final String label;
  const GrowthStatus(this.label);
}

/// Point-in-time snapshot of athlete progress.
class ProgressSnapshot {
  final DateTime date;
  final double bodyWeight;
  final double totalVolume;
  final int workoutsCompleted;
  final double averageIntensity;
  final Map<String, double> muscleVolume;
  final List<PersonalRecord> prs;

  const ProgressSnapshot({
    required this.date,
    required this.bodyWeight,
    required this.totalVolume,
    required this.workoutsCompleted,
    required this.averageIntensity,
    required this.muscleVolume,
    required this.prs,
  });

  int get completedWorkouts => workoutsCompleted;
  int get totalSets => 0;
  int get totalReps => 0;
  Map<String, double> get muscleDistribution => muscleVolume;

  factory ProgressSnapshot.empty() => ProgressSnapshot(
    date: DateTime.now(),
    bodyWeight: 0.0,
    totalVolume: 0.0,
    workoutsCompleted: 0,
    averageIntensity: 0.0,
    muscleVolume: const {},
    prs: const [],
  );

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'bodyWeight': bodyWeight,
    'totalVolume': totalVolume,
    'workoutsCompleted': workoutsCompleted,
    'averageIntensity': averageIntensity,
    'muscleVolume': muscleVolume,
    'prs': prs.map((p) => p.toJson()).toList(),
  };

  factory ProgressSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPRs = json['prs'] as List?;
    return ProgressSnapshot(
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      bodyWeight: (json['bodyWeight'] as num?)?.toDouble() ?? 0.0,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0.0,
      workoutsCompleted: (json['workoutsCompleted'] as num?)?.toInt() ?? 0,
      averageIntensity: (json['averageIntensity'] as num?)?.toDouble() ?? 0.0,
      muscleVolume:
          (json['muscleVolume'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ) ??
          {},
      prs: rawPRs != null
          ? rawPRs
                .map(
                  (e) => PersonalRecord.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : [],
    );
  }
}

/// Exercise-specific strength progression metrics over time.
class StrengthProgress {
  final String exerciseName;
  final String exerciseId;
  final String muscleGroup;
  final double currentWeight;
  final double previousWeight;
  final double improvement;
  final double estimatedOneRepMax;
  final double percentageIncrease;
  final DateTime? lastLoggedDate;
  final List<double> weightHistory;
  final List<DateTime> dateHistory;

  const StrengthProgress({
    required this.exerciseName,
    this.exerciseId = '',
    this.muscleGroup = 'General',
    required this.currentWeight,
    required this.previousWeight,
    required this.improvement,
    required this.estimatedOneRepMax,
    required this.percentageIncrease,
    this.lastLoggedDate,
    this.weightHistory = const [],
    this.dateHistory = const [],
  });

  double get startingWeight =>
      weightHistory.isNotEmpty ? weightHistory.first : previousWeight;
  double get percentageImprovement => percentageIncrease;
  int get sessionsCompleted =>
      weightHistory.isNotEmpty ? weightHistory.length : 1;
  DateTime get lastLogged => lastLoggedDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'exerciseId': exerciseId,
    'muscleGroup': muscleGroup,
    'currentWeight': currentWeight,
    'previousWeight': previousWeight,
    'improvement': improvement,
    'estimatedOneRepMax': estimatedOneRepMax,
    'percentageIncrease': percentageIncrease,
    'lastLoggedDate': lastLoggedDate?.toIso8601String(),
    'weightHistory': weightHistory,
    'dateHistory': dateHistory.map((d) => d.toIso8601String()).toList(),
  };

  factory StrengthProgress.fromJson(Map<String, dynamic> json) {
    final rawDates = json['dateHistory'] as List?;
    final rawWeights = json['weightHistory'] as List?;
    return StrengthProgress(
      exerciseName: json['exerciseName'] as String? ?? 'Exercise',
      exerciseId: json['exerciseId'] as String? ?? '',
      muscleGroup: json['muscleGroup'] as String? ?? 'General',
      currentWeight: (json['currentWeight'] as num?)?.toDouble() ?? 0.0,
      previousWeight: (json['previousWeight'] as num?)?.toDouble() ?? 0.0,
      improvement: (json['improvement'] as num?)?.toDouble() ?? 0.0,
      estimatedOneRepMax:
          (json['estimatedOneRepMax'] as num?)?.toDouble() ?? 0.0,
      percentageIncrease:
          (json['percentageIncrease'] as num?)?.toDouble() ?? 0.0,
      lastLoggedDate: json['lastLoggedDate'] != null
          ? DateTime.tryParse(json['lastLoggedDate'] as String)
          : null,
      weightHistory: rawWeights != null
          ? rawWeights.map((e) => (e as num).toDouble()).toList()
          : const [],
      dateHistory: rawDates != null
          ? rawDates
                .map((d) => DateTime.tryParse(d as String) ?? DateTime.now())
                .toList()
          : const [],
    );
  }
}

/// Volume and development status for an individual muscle group.
class MuscleGrowthMetric {
  final String muscleGroup;
  final double weeklyVolume;
  final double previousVolume;
  final String
  status; // 'Growing', 'Maintaining', 'Undertrained', 'Overtrained'
  final double percentageChange;
  final double percentageOfTotal;

  const MuscleGrowthMetric({
    required this.muscleGroup,
    required this.weeklyVolume,
    required this.previousVolume,
    required this.status,
    required this.percentageChange,
    required this.percentageOfTotal,
  });

  GrowthStatus get growthStatus {
    switch (status.toLowerCase()) {
      case 'growing':
        return GrowthStatus.growing;
      case 'undertrained':
        return GrowthStatus.undertrained;
      case 'overtrained':
        return GrowthStatus.overtrained;
      default:
        return GrowthStatus.maintaining;
    }
  }

  Map<String, dynamic> toJson() => {
    'muscleGroup': muscleGroup,
    'weeklyVolume': weeklyVolume,
    'previousVolume': previousVolume,
    'status': status,
    'percentageChange': percentageChange,
    'percentageOfTotal': percentageOfTotal,
  };

  factory MuscleGrowthMetric.fromJson(Map<String, dynamic> json) {
    return MuscleGrowthMetric(
      muscleGroup: json['muscleGroup'] as String? ?? 'General',
      weeklyVolume: (json['weeklyVolume'] as num?)?.toDouble() ?? 0.0,
      previousVolume: (json['previousVolume'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'Maintaining',
      percentageChange: (json['percentageChange'] as num?)?.toDouble() ?? 0.0,
      percentageOfTotal: (json['percentageOfTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Diagnostic insight identifying stalled progression and prescribing fixes.
class PlateauInsight {
  final String exerciseName;
  final int weeksWithoutImprovement;
  final double currentPlateauWeight;
  final String severity; // 'Moderate', 'Significant'
  final String message;
  final List<String> suggestions;

  const PlateauInsight({
    required this.exerciseName,
    required this.weeksWithoutImprovement,
    required this.currentPlateauWeight,
    required this.severity,
    required this.message,
    required this.suggestions,
  });

  double get stalledWeight => currentPlateauWeight;
  int get weeksStalled => weeksWithoutImprovement;
  String get recommendation =>
      suggestions.isNotEmpty ? suggestions.first : message;
  int get sessionsAnalyzed => weeksWithoutImprovement;

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'weeksWithoutImprovement': weeksWithoutImprovement,
    'currentPlateauWeight': currentPlateauWeight,
    'severity': severity,
    'message': message,
    'suggestions': suggestions,
  };

  factory PlateauInsight.fromJson(Map<String, dynamic> json) {
    final rawSuggestions = json['suggestions'] as List?;
    return PlateauInsight(
      exerciseName: json['exerciseName'] as String? ?? 'Exercise',
      weeksWithoutImprovement:
          (json['weeksWithoutImprovement'] as num?)?.toInt() ?? 0,
      currentPlateauWeight:
          (json['currentPlateauWeight'] as num?)?.toDouble() ?? 0.0,
      severity: json['severity'] as String? ?? 'Moderate',
      message: json['message'] as String? ?? '',
      suggestions: rawSuggestions != null
          ? rawSuggestions.map((e) => e.toString()).toList()
          : const [],
    );
  }
}

/// Aggregated time bucket for volume trend visualizations.
class VolumeTrendPoint {
  final String periodLabel;
  final DateTime startDate;
  final DateTime endDate;
  final double volume;
  final int workoutsCount;
  final double changePercentage;

  const VolumeTrendPoint({
    required this.periodLabel,
    required this.startDate,
    required this.endDate,
    required this.volume,
    required this.workoutsCount,
    this.changePercentage = 0.0,
  });

  double get totalVolume => volume;

  Map<String, dynamic> toJson() => {
    'periodLabel': periodLabel,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'volume': volume,
    'workoutsCount': workoutsCount,
    'changePercentage': changePercentage,
  };

  factory VolumeTrendPoint.fromJson(Map<String, dynamic> json) {
    return VolumeTrendPoint(
      periodLabel: json['periodLabel'] as String? ?? '',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      workoutsCount: (json['workoutsCount'] as num?)?.toInt() ?? 0,
      changePercentage: (json['changePercentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Comprehensive Master Athlete Analytics Report.
class AthleteAnalyticsReport {
  final ProgressSnapshot currentSnapshot;
  final List<StrengthProgress> strengthProgressions;
  final List<MuscleGrowthMetric> muscleMetrics;
  final List<VolumeTrendPoint> volumeTrends;
  final List<PlateauInsight> plateauInsights;
  final double consistencyPercentage;
  final int currentStreak;
  final int longestStreak;
  final double weeklyVolumeDeltaPercent;
  final String aiCoachSummary;
  final DateTime generatedAt;

  const AthleteAnalyticsReport({
    required this.currentSnapshot,
    required this.strengthProgressions,
    required this.muscleMetrics,
    required this.volumeTrends,
    required this.plateauInsights,
    required this.consistencyPercentage,
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyVolumeDeltaPercent,
    required this.aiCoachSummary,
    required this.generatedAt,
  });

  List<MuscleGrowthMetric> get muscleGrowthMetrics => muscleMetrics;
  List<String> get recommendations => [aiCoachSummary];

  factory AthleteAnalyticsReport.empty() => AthleteAnalyticsReport(
    currentSnapshot: ProgressSnapshot.empty(),
    strengthProgressions: const [],
    muscleMetrics: const [],
    volumeTrends: const [],
    plateauInsights: const [],
    consistencyPercentage: 0.0,
    currentStreak: 0,
    longestStreak: 0,
    weeklyVolumeDeltaPercent: 0.0,
    aiCoachSummary:
        'Insufficient workout history recorded. Complete your first training session to unlock personalized AI progression coaching.',
    generatedAt: DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'currentSnapshot': currentSnapshot.toJson(),
    'strengthProgressions': strengthProgressions
        .map((s) => s.toJson())
        .toList(),
    'muscleMetrics': muscleMetrics.map((m) => m.toJson()).toList(),
    'volumeTrends': volumeTrends.map((v) => v.toJson()).toList(),
    'plateauInsights': plateauInsights.map((p) => p.toJson()).toList(),
    'consistencyPercentage': consistencyPercentage,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'weeklyVolumeDeltaPercent': weeklyVolumeDeltaPercent,
    'aiCoachSummary': aiCoachSummary,
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory AthleteAnalyticsReport.fromJson(Map<String, dynamic> json) {
    final rawStrength = json['strengthProgressions'] as List?;
    final rawMuscle = json['muscleMetrics'] as List?;
    final rawVolume = json['volumeTrends'] as List?;
    final rawPlateau = json['plateauInsights'] as List?;

    return AthleteAnalyticsReport(
      currentSnapshot: json['currentSnapshot'] != null
          ? ProgressSnapshot.fromJson(
              Map<String, dynamic>.from(json['currentSnapshot'] as Map),
            )
          : ProgressSnapshot.empty(),
      strengthProgressions: rawStrength != null
          ? rawStrength
                .map(
                  (s) => StrengthProgress.fromJson(
                    Map<String, dynamic>.from(s as Map),
                  ),
                )
                .toList()
          : const [],
      muscleMetrics: rawMuscle != null
          ? rawMuscle
                .map(
                  (m) => MuscleGrowthMetric.fromJson(
                    Map<String, dynamic>.from(m as Map),
                  ),
                )
                .toList()
          : const [],
      volumeTrends: rawVolume != null
          ? rawVolume
                .map(
                  (v) => VolumeTrendPoint.fromJson(
                    Map<String, dynamic>.from(v as Map),
                  ),
                )
                .toList()
          : const [],
      plateauInsights: rawPlateau != null
          ? rawPlateau
                .map(
                  (p) => PlateauInsight.fromJson(
                    Map<String, dynamic>.from(p as Map),
                  ),
                )
                .toList()
          : const [],
      consistencyPercentage:
          (json['consistencyPercentage'] as num?)?.toDouble() ?? 0.0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      weeklyVolumeDeltaPercent:
          (json['weeklyVolumeDeltaPercent'] as num?)?.toDouble() ?? 0.0,
      aiCoachSummary: json['aiCoachSummary'] as String? ?? '',
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
