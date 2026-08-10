import 'user_goal.dart';
import 'user_profile.dart';
import 'workout_history.dart';
import 'nutrition_summary.dart';
import 'progress_summary.dart';
import 'user_progress.dart';
import 'nutrition_progress.dart';
import 'recovery_state.dart';

/// Aggregated data context containing all user health, fitness, workout,
/// nutrition, progress, recovery, and gamification state for AI recommendations.
class FitnessContext {
  final UserGoal? userGoal;
  final UserProfile? userProfile;
  final List<WorkoutHistory> workoutHistory;
  final NutritionSummary nutritionSummary;
  final ProgressSummary progressSummary;
  final UserProgress userProgress;
  final NutritionProgress nutritionProgress;
  final RecoveryState? recoveryState;
  final DateTime generatedAt;

  const FitnessContext({
    this.userGoal,
    this.userProfile,
    this.workoutHistory = const [],
    required this.nutritionSummary,
    required this.progressSummary,
    required this.userProgress,
    required this.nutritionProgress,
    this.recoveryState,
    required this.generatedAt,
  });

  factory FitnessContext.initial() {
    return FitnessContext(
      userGoal: null,
      userProfile: null,
      workoutHistory: const [],
      nutritionSummary: NutritionSummary.empty(),
      progressSummary: ProgressSummary.zero(),
      userProgress: UserProgress.initial(),
      nutritionProgress: NutritionProgress.initial(),
      recoveryState: null,
      generatedAt: DateTime.now(),
    );
  }

  factory FitnessContext.fromJson(Map<String, dynamic> json) {
    return FitnessContext(
      userGoal: json['userGoal'] != null
          ? UserGoal.fromJson(json['userGoal'] as Map<String, dynamic>)
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
              json['nutritionSummary'] as Map<String, dynamic>)
          : NutritionSummary.empty(),
      progressSummary: json['progressSummary'] != null
          ? ProgressSummary.fromJson(
              json['progressSummary'] as Map<String, dynamic>)
          : ProgressSummary.zero(),
      userProgress: json['userProgress'] != null
          ? UserProgress.fromJson(json['userProgress'] as Map<String, dynamic>)
          : UserProgress.initial(),
      nutritionProgress: json['nutritionProgress'] != null
          ? NutritionProgress.fromJson(
              json['nutritionProgress'] as Map<String, dynamic>)
          : NutritionProgress.initial(),
      recoveryState: json['recoveryState'] != null
          ? RecoveryState.fromJson(json['recoveryState'] as Map<String, dynamic>)
          : null,
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (userGoal != null) 'userGoal': userGoal!.toJson(),
        if (userProfile != null) 'userProfile': userProfile!.toJson(),
        'workoutHistory': workoutHistory.map((e) => e.toJson()).toList(),
        'nutritionSummary': nutritionSummary.toJson(),
        'progressSummary': progressSummary.toJson(),
        'userProgress': userProgress.toJson(),
        'nutritionProgress': nutritionProgress.toJson(),
        if (recoveryState != null) 'recoveryState': recoveryState!.toJson(),
        'generatedAt': generatedAt.toIso8601String(),
      };

  FitnessContext copyWith({
    UserGoal? userGoal,
    UserProfile? userProfile,
    List<WorkoutHistory>? workoutHistory,
    NutritionSummary? nutritionSummary,
    ProgressSummary? progressSummary,
    UserProgress? userProgress,
    NutritionProgress? nutritionProgress,
    RecoveryState? recoveryState,
    DateTime? generatedAt,
  }) {
    return FitnessContext(
      userGoal: userGoal ?? this.userGoal,
      userProfile: userProfile ?? this.userProfile,
      workoutHistory: workoutHistory ?? this.workoutHistory,
      nutritionSummary: nutritionSummary ?? this.nutritionSummary,
      progressSummary: progressSummary ?? this.progressSummary,
      userProgress: userProgress ?? this.userProgress,
      nutritionProgress: nutritionProgress ?? this.nutritionProgress,
      recoveryState: recoveryState ?? this.recoveryState,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}
