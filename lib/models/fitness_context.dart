import 'user_goal.dart';
import 'user_profile.dart';
import 'workout_history.dart';
import 'nutrition_summary.dart';
import 'progress_summary.dart';
import 'progress_analytics.dart';
import 'user_progress.dart';
import 'nutrition_progress.dart';
import 'nutrition_log.dart';
import 'daily_nutrition.dart';
import 'recovery_state.dart';
import 'user_equipment_profile.dart';
import 'equipment.dart';
import 'weight_goal.dart';
import 'activity_record.dart';
import 'health_metric.dart';
import '../services/health/recovery_service.dart';

/// Aggregated data context containing all user health, fitness, workout,
/// nutrition, progress, recovery, and gamification state for AI recommendations.
class FitnessContext {
  final UserGoal? userGoal;
  final WeightGoal? weightGoal;
  final UserProfile? userProfile;
  final List<WorkoutHistory> workoutHistory;
  final NutritionSummary nutritionSummary;
  final ProgressSummary progressSummary;
  final AthleteAnalyticsReport? athleteAnalytics;
  final UserProgress userProgress;
  final NutritionProgress nutritionProgress;
  final NutritionLog? todayNutritionLog;
  final DailyNutrition? todayNutrition;
  final RecoveryState? recoveryState;
  final RecoveryBreakdown? recoveryBreakdown;
  final UserEquipmentProfile? equipmentProfile;
  final ActivityRecord? todayActivity;
  final HealthMetric? todayHealthMetric;
  final int? stepGoal;

  /// Today's steps from the step service (phone sensor and Health Connect).
  /// Null means no reading: never read it as zero steps.
  final int? todaySteps;
  final String? todayStepsSource;
  final int? activityScore;
  final List<CardioSession> recentCardio;
  final DateTime generatedAt;

  const FitnessContext({
    this.userGoal,
    this.weightGoal,
    this.userProfile,
    this.workoutHistory = const [],
    required this.nutritionSummary,
    required this.progressSummary,
    this.athleteAnalytics,
    required this.userProgress,
    required this.nutritionProgress,
    this.todayNutritionLog,
    this.todayNutrition,
    this.recoveryState,
    this.recoveryBreakdown,
    this.equipmentProfile,
    this.todayActivity,
    this.todayHealthMetric,
    this.stepGoal,
    this.todaySteps,
    this.todayStepsSource,
    this.activityScore,
    this.recentCardio = const [],
    required this.generatedAt,
  });

  factory FitnessContext.initial() {
    return FitnessContext(
      userGoal: null,
      weightGoal: null,
      userProfile: null,
      workoutHistory: const [],
      nutritionSummary: NutritionSummary.empty(),
      progressSummary: ProgressSummary.zero(),
      userProgress: UserProgress.initial(),
      nutritionProgress: NutritionProgress.initial(),
      todayNutritionLog: null,
      todayNutrition: null,
      recoveryState: null,
      recoveryBreakdown: null,
      equipmentProfile: null,
      todayHealthMetric: null,
      generatedAt: DateTime.now(),
    );
  }

  factory FitnessContext.fromJson(Map<String, dynamic> json) {
    return FitnessContext(
      userGoal: json['userGoal'] != null
          ? UserGoal.fromJson(json['userGoal'] as Map<String, dynamic>)
          : null,
      weightGoal: json['weightGoal'] != null
          ? WeightGoal.fromJson(json['weightGoal'] as Map<String, dynamic>)
          : null,
      userProfile: json['userProfile'] != null
          ? UserProfile.fromJson(json['userProfile'] as Map<String, dynamic>)
          : null,
      workoutHistory: json['workoutHistory'] != null
          ? (json['workoutHistory'] as List)
                .map((e) => WorkoutHistory.fromJson(e as Map<String, dynamic>))
                .toList()
          : const [],
      nutritionSummary: json['nutritionSummary'] != null
          ? NutritionSummary.fromJson(
              json['nutritionSummary'] as Map<String, dynamic>,
            )
          : NutritionSummary.empty(),
      progressSummary: json['progressSummary'] != null
          ? ProgressSummary.fromJson(
              json['progressSummary'] as Map<String, dynamic>,
            )
          : ProgressSummary.zero(),
      athleteAnalytics: json['athleteAnalytics'] != null
          ? AthleteAnalyticsReport.fromJson(
              json['athleteAnalytics'] as Map<String, dynamic>,
            )
          : null,
      userProgress: json['userProgress'] != null
          ? UserProgress.fromJson(json['userProgress'] as Map<String, dynamic>)
          : UserProgress.initial(),
      nutritionProgress: json['nutritionProgress'] != null
          ? NutritionProgress.fromJson(
              json['nutritionProgress'] as Map<String, dynamic>,
            )
          : NutritionProgress.initial(),
      todayNutritionLog: json['todayNutritionLog'] != null
          ? NutritionLog.fromJson(
              json['todayNutritionLog'] as Map<String, dynamic>,
            )
          : null,
      todayNutrition: json['todayNutrition'] != null
          ? DailyNutrition.fromJson(
              json['todayNutrition'] as Map<String, dynamic>,
            )
          : null,
      recoveryState: json['recoveryState'] != null
          ? RecoveryState.fromJson(
              json['recoveryState'] as Map<String, dynamic>,
            )
          : null,
      equipmentProfile: json['equipmentProfile'] != null
          ? UserEquipmentProfile.fromJson(
              json['equipmentProfile'] as Map<String, dynamic>,
            )
          : null,
      todayActivity: json['todayActivity'] != null
          ? ActivityRecord.fromJson(
              json['todayActivity'] as Map<String, dynamic>,
            )
          : null,
      todayHealthMetric: json['todayHealthMetric'] != null
          ? HealthMetric.fromJson(
              json['todayHealthMetric'] as Map<String, dynamic>,
            )
          : null,
      stepGoal: (json['stepGoal'] as num?)?.toInt(),
      todaySteps: (json['todaySteps'] as num?)?.toInt(),
      todayStepsSource: json['todayStepsSource'] as String?,
      activityScore: (json['activityScore'] as num?)?.toInt(),
      recentCardio: json['recentCardio'] != null
          ? (json['recentCardio'] as List)
                .map((e) => CardioSession.fromJson(e as Map<String, dynamic>))
                .toList()
          : const [],
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (userGoal != null) 'userGoal': userGoal!.toJson(),
    if (weightGoal != null) 'weightGoal': weightGoal!.toJson(),
    if (userProfile != null) 'userProfile': userProfile!.toJson(),
    'workoutHistory': workoutHistory.map((e) => e.toJson()).toList(),
    'nutritionSummary': nutritionSummary.toJson(),
    'progressSummary': progressSummary.toJson(),
    if (athleteAnalytics != null)
      'athleteAnalytics': athleteAnalytics!.toJson(),
    'userProgress': userProgress.toJson(),
    'nutritionProgress': nutritionProgress.toJson(),
    if (todayNutritionLog != null)
      'todayNutritionLog': todayNutritionLog!.toJson(),
    if (todayNutrition != null) 'todayNutrition': todayNutrition!.toJson(),
    if (recoveryState != null) 'recoveryState': recoveryState!.toJson(),
    if (equipmentProfile != null)
      'equipmentProfile': equipmentProfile!.toJson(),
    if (todayActivity != null) 'todayActivity': todayActivity!.toJson(),
    if (todayHealthMetric != null)
      'todayHealthMetric': todayHealthMetric!.toJson(),
    if (stepGoal != null) 'stepGoal': stepGoal,
    if (todaySteps != null) 'todaySteps': todaySteps,
    if (todayStepsSource != null) 'todayStepsSource': todayStepsSource,
    if (activityScore != null) 'activityScore': activityScore,
    'recentCardio': recentCardio.map((e) => e.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
  };

  /// Names of all available gym and home equipment
  List<String> get availableEquipmentNames {
    if (userProfile != null && userProfile!.equipment.isNotEmpty) {
      return userProfile!.equipment;
    }
    if (equipmentProfile == null) return const ['All standard gym equipment'];
    final catalog = Equipment.masterCatalog();
    final names = equipmentProfile!.availableEquipmentIds.map((id) {
      for (final item in catalog) {
        if (item.id == id) return item.name;
      }
      return id;
    }).toList();
    return names.isNotEmpty ? names : const ['None'];
  }

  /// Names of all unavailable/excluded equipment
  List<String> get unavailableEquipmentNames {
    if (equipmentProfile == null) return const [];
    final catalog = Equipment.masterCatalog();
    return catalog
        .where((e) => !equipmentProfile!.isEquipmentAvailable(e.id))
        .map((e) => e.name)
        .toList();
  }

  FitnessContext copyWith({
    UserGoal? userGoal,
    WeightGoal? weightGoal,
    UserProfile? userProfile,
    List<WorkoutHistory>? workoutHistory,
    NutritionSummary? nutritionSummary,
    ProgressSummary? progressSummary,
    AthleteAnalyticsReport? athleteAnalytics,
    UserProgress? userProgress,
    NutritionProgress? nutritionProgress,
    NutritionLog? todayNutritionLog,
    DailyNutrition? todayNutrition,
    RecoveryState? recoveryState,
    RecoveryBreakdown? recoveryBreakdown,
    UserEquipmentProfile? equipmentProfile,
    ActivityRecord? todayActivity,
    HealthMetric? todayHealthMetric,
    int? stepGoal,
    int? todaySteps,
    String? todayStepsSource,
    int? activityScore,
    List<CardioSession>? recentCardio,
    DateTime? generatedAt,
  }) {
    return FitnessContext(
      userGoal: userGoal ?? this.userGoal,
      weightGoal: weightGoal ?? this.weightGoal,
      userProfile: userProfile ?? this.userProfile,
      workoutHistory: workoutHistory ?? this.workoutHistory,
      nutritionSummary: nutritionSummary ?? this.nutritionSummary,
      progressSummary: progressSummary ?? this.progressSummary,
      athleteAnalytics: athleteAnalytics ?? this.athleteAnalytics,
      userProgress: userProgress ?? this.userProgress,
      nutritionProgress: nutritionProgress ?? this.nutritionProgress,
      todayNutritionLog: todayNutritionLog ?? this.todayNutritionLog,
      todayNutrition: todayNutrition ?? this.todayNutrition,
      recoveryState: recoveryState ?? this.recoveryState,
      recoveryBreakdown: recoveryBreakdown ?? this.recoveryBreakdown,
      equipmentProfile: equipmentProfile ?? this.equipmentProfile,
      todayActivity: todayActivity ?? this.todayActivity,
      todayHealthMetric: todayHealthMetric ?? this.todayHealthMetric,
      stepGoal: stepGoal ?? this.stepGoal,
      todaySteps: todaySteps ?? this.todaySteps,
      todayStepsSource: todayStepsSource ?? this.todayStepsSource,
      activityScore: activityScore ?? this.activityScore,
      recentCardio: recentCardio ?? this.recentCardio,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}
