import '../services/analytics_service.dart';
export 'personal_record.dart';
import 'personal_record.dart';

/// Structured summary of a top performed exercise
class TopExercise {
  final String exerciseName;
  final String muscleGroup;
  final int sessionsCompleted;
  final double maxWeight;
  final double totalVolume;
  final double percentageImprovement;

  const TopExercise({
    required this.exerciseName,
    required this.muscleGroup,
    required this.sessionsCompleted,
    required this.maxWeight,
    required this.totalVolume,
    required this.percentageImprovement,
  });

  factory TopExercise.fromStrengthProgression(
    StrengthProgression prog, {
    int sessionsCompleted = 1,
    double totalVolume = 0.0,
    String muscleGroup = 'General',
  }) {
    return TopExercise(
      exerciseName: prog.exerciseName,
      muscleGroup: muscleGroup,
      sessionsCompleted: sessionsCompleted,
      maxWeight: prog.latestWeight,
      totalVolume: totalVolume,
      percentageImprovement: prog.percentageImprovement,
    );
  }

  factory TopExercise.fromJson(Map<String, dynamic> json) {
    return TopExercise(
      exerciseName: json['exerciseName'] as String? ?? 'Exercise',
      muscleGroup: json['muscleGroup'] as String? ?? 'General',
      sessionsCompleted: (json['sessionsCompleted'] as num?)?.toInt() ?? 0,
      maxWeight: (json['maxWeight'] as num?)?.toDouble() ?? 0.0,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0.0,
      percentageImprovement:
          (json['percentageImprovement'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'sessionsCompleted': sessionsCompleted,
        'maxWeight': maxWeight,
        'totalVolume': totalVolume,
        'percentageImprovement': percentageImprovement,
      };
}

/// Unified Progress Summary model aggregating all analytics, gamification, and performance metrics.
class ProgressSummary {
  // Core
  final int totalWorkouts;
  final double totalVolume;
  final int totalTrainingMinutes;
  final String currentRank;
  final int currentXP;
  final int currentStreak;
  final int longestStreak;

  // Analytics
  final double weeklyVolume;
  final double monthlyVolume;

  // Comparison
  final double weeklyVolumeChangePercent;
  final double monthlyVolumeChangePercent;
  final int weeklyWorkoutChange;
  final double strengthGrowthPercent;
  final double consistencyScore;

  // Collections
  final List<PersonalRecord> personalRecords;
  final List<TopExercise> topExercises;

  // Distribution
  final Map<String, double> muscleGroupDistribution;

  // Metadata
  final DateTime lastUpdated;

  const ProgressSummary({
    required this.totalWorkouts,
    required this.totalVolume,
    required this.totalTrainingMinutes,
    required this.currentRank,
    required this.currentXP,
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyVolume,
    required this.monthlyVolume,
    required this.weeklyVolumeChangePercent,
    required this.monthlyVolumeChangePercent,
    required this.weeklyWorkoutChange,
    required this.strengthGrowthPercent,
    required this.consistencyScore,
    required this.personalRecords,
    required this.topExercises,
    required this.muscleGroupDistribution,
    required this.lastUpdated,
  });

  factory ProgressSummary.zero() => ProgressSummary(
        totalWorkouts: 0,
        totalVolume: 0.0,
        totalTrainingMinutes: 0,
        currentRank: 'Iron I',
        currentXP: 0,
        currentStreak: 0,
        longestStreak: 0,
        weeklyVolume: 0.0,
        monthlyVolume: 0.0,
        weeklyVolumeChangePercent: 0.0,
        monthlyVolumeChangePercent: 0.0,
        weeklyWorkoutChange: 0,
        strengthGrowthPercent: 0.0,
        consistencyScore: 0.0,
        personalRecords: const [],
        topExercises: const [],
        muscleGroupDistribution: const {
          'Legs': 35.0,
          'Chest': 25.0,
          'Back': 20.0,
          'Arms': 20.0,
        },
        lastUpdated: DateTime.now(),
      );

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    final rawPRs = json['personalRecords'] as List?;
    final prs = rawPRs != null
        ? rawPRs.map((e) => PersonalRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <PersonalRecord>[];

    final rawTop = json['topExercises'] as List?;
    final tops = rawTop != null
        ? rawTop.map((e) => TopExercise.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <TopExercise>[];

    final rawDist = json['muscleGroupDistribution'] as Map?;
    final dist = rawDist != null
        ? rawDist.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
        : <String, double>{};

    return ProgressSummary(
      totalWorkouts: (json['totalWorkouts'] as num?)?.toInt() ?? 0,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0.0,
      totalTrainingMinutes: (json['totalTrainingMinutes'] as num?)?.toInt() ?? 0,
      currentRank: json['currentRank'] as String? ?? 'Iron I',
      currentXP: (json['currentXP'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      weeklyVolume: (json['weeklyVolume'] as num?)?.toDouble() ?? 0.0,
      monthlyVolume: (json['monthlyVolume'] as num?)?.toDouble() ?? 0.0,
      weeklyVolumeChangePercent: (json['weeklyVolumeChangePercent'] as num?)?.toDouble() ?? 0.0,
      monthlyVolumeChangePercent: (json['monthlyVolumeChangePercent'] as num?)?.toDouble() ?? 0.0,
      weeklyWorkoutChange: (json['weeklyWorkoutChange'] as num?)?.toInt() ?? 0,
      strengthGrowthPercent: (json['strengthGrowthPercent'] as num?)?.toDouble() ?? 0.0,
      consistencyScore: (json['consistencyScore'] as num?)?.toDouble() ?? 0.0,
      personalRecords: prs,
      topExercises: tops,
      muscleGroupDistribution: dist,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalWorkouts': totalWorkouts,
        'totalVolume': totalVolume,
        'totalTrainingMinutes': totalTrainingMinutes,
        'currentRank': currentRank,
        'currentXP': currentXP,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'weeklyVolume': weeklyVolume,
        'monthlyVolume': monthlyVolume,
        'weeklyVolumeChangePercent': weeklyVolumeChangePercent,
        'monthlyVolumeChangePercent': monthlyVolumeChangePercent,
        'weeklyWorkoutChange': weeklyWorkoutChange,
        'strengthGrowthPercent': strengthGrowthPercent,
        'consistencyScore': consistencyScore,
        'personalRecords': personalRecords.map((e) => e.toJson()).toList(),
        'topExercises': topExercises.map((e) => e.toJson()).toList(),
        'muscleGroupDistribution': muscleGroupDistribution,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  ProgressSummary copyWith({
    int? totalWorkouts,
    double? totalVolume,
    int? totalTrainingMinutes,
    String? currentRank,
    int? currentXP,
    int? currentStreak,
    int? longestStreak,
    double? weeklyVolume,
    double? monthlyVolume,
    double? weeklyVolumeChangePercent,
    double? monthlyVolumeChangePercent,
    int? weeklyWorkoutChange,
    double? strengthGrowthPercent,
    double? consistencyScore,
    List<PersonalRecord>? personalRecords,
    List<TopExercise>? topExercises,
    Map<String, double>? muscleGroupDistribution,
    DateTime? lastUpdated,
  }) {
    return ProgressSummary(
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
      totalVolume: totalVolume ?? this.totalVolume,
      totalTrainingMinutes: totalTrainingMinutes ?? this.totalTrainingMinutes,
      currentRank: currentRank ?? this.currentRank,
      currentXP: currentXP ?? this.currentXP,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      weeklyVolume: weeklyVolume ?? this.weeklyVolume,
      monthlyVolume: monthlyVolume ?? this.monthlyVolume,
      weeklyVolumeChangePercent: weeklyVolumeChangePercent ?? this.weeklyVolumeChangePercent,
      monthlyVolumeChangePercent: monthlyVolumeChangePercent ?? this.monthlyVolumeChangePercent,
      weeklyWorkoutChange: weeklyWorkoutChange ?? this.weeklyWorkoutChange,
      strengthGrowthPercent: strengthGrowthPercent ?? this.strengthGrowthPercent,
      consistencyScore: consistencyScore ?? this.consistencyScore,
      personalRecords: personalRecords ?? this.personalRecords,
      topExercises: topExercises ?? this.topExercises,
      muscleGroupDistribution: muscleGroupDistribution ?? this.muscleGroupDistribution,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
