import 'coach_action.dart';
import 'nutrition_summary.dart';
import 'progress_summary.dart';
import 'recovery_summary.dart';
import 'workout_recommendation.dart';

/// Autonomous Daily AI Coach Brief synthesizing multi-domain athlete intelligence:
/// Health & Sleep, Recovery, Workouts, Nutrition deltas, Progress, and prioritized Coach Actions.
class DailyCoachBrief {
  final DateTime date;
  final String greeting;
  final List<CoachAction> actions;
  final RecoverySummary recovery;
  final NutritionSummary nutrition;
  final WorkoutRecommendation workout;
  final ProgressSummary progress;
  final String proactiveMessage;

  const DailyCoachBrief({
    required this.date,
    required this.greeting,
    required this.actions,
    required this.recovery,
    required this.nutrition,
    required this.workout,
    required this.progress,
    required this.proactiveMessage,
  });

  factory DailyCoachBrief.empty({DateTime? date}) {
    final now = date ?? DateTime.now();
    return DailyCoachBrief(
      date: now,
      greeting: 'Good day, Athlete.',
      actions: const [],
      recovery: const RecoverySummary(),
      nutrition: const NutritionSummary(),
      workout: WorkoutRecommendation.restDay(),
      progress: ProgressSummary.zero(),
      proactiveMessage:
          'Welcome to Atlas. Start logging your workouts and nutrition to unlock personalized autonomous coaching.',
    );
  }

  factory DailyCoachBrief.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] as List? ?? [];
    final actions = rawActions
        .map((a) => CoachAction.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList();

    return DailyCoachBrief(
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      greeting: json['greeting'] as String? ?? 'Good day.',
      actions: actions,
      recovery: json['recovery'] != null
          ? RecoverySummary.fromJson(
              Map<String, dynamic>.from(json['recovery'] as Map),
            )
          : const RecoverySummary(),
      nutrition: json['nutrition'] != null
          ? NutritionSummary.fromJson(
              Map<String, dynamic>.from(json['nutrition'] as Map),
            )
          : const NutritionSummary(),
      workout: json['workout'] != null
          ? WorkoutRecommendation.fromJson(
              Map<String, dynamic>.from(json['workout'] as Map),
            )
          : WorkoutRecommendation.restDay(),
      progress: json['progress'] != null
          ? ProgressSummary.fromJson(
              Map<String, dynamic>.from(json['progress'] as Map),
            )
          : ProgressSummary.zero(),
      proactiveMessage:
          json['proactiveMessage'] as String? ??
          (json['proactive_message'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'greeting': greeting,
    'actions': actions.map((a) => a.toJson()).toList(),
    'recovery': recovery.toJson(),
    'nutrition': nutrition.toJson(),
    'workout': workout.toJson(),
    'progress': progress.toJson(),
    'proactive_message': proactiveMessage,
  };

  DailyCoachBrief copyWith({
    DateTime? date,
    String? greeting,
    List<CoachAction>? actions,
    RecoverySummary? recovery,
    NutritionSummary? nutrition,
    WorkoutRecommendation? workout,
    ProgressSummary? progress,
    String? proactiveMessage,
  }) {
    return DailyCoachBrief(
      date: date ?? this.date,
      greeting: greeting ?? this.greeting,
      actions: actions ?? this.actions,
      recovery: recovery ?? this.recovery,
      nutrition: nutrition ?? this.nutrition,
      workout: workout ?? this.workout,
      progress: progress ?? this.progress,
      proactiveMessage: proactiveMessage ?? this.proactiveMessage,
    );
  }
}
