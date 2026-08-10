import '../../models/fitness_context.dart';

/// Structured AI summary for a trainer evaluating an assigned athlete's context.
class MemberAISummary {
  final String memberName;
  final String readinessStatus; // 'Optimal Readiness', 'Moderate Fatigue', 'Overreached / Deload'
  final List<String> keyInsights;
  final String recommendedAction;
  final String summaryText;

  const MemberAISummary({
    required this.memberName,
    required this.readinessStatus,
    required this.keyInsights,
    required this.recommendedAction,
    required this.summaryText,
  });
}

/// AI Assistant analyzing member fitness context snapshots for gym trainers & coaches.
class TrainerAIAssistant {
  const TrainerAIAssistant();

  /// Evaluates athlete context and generates structured trainer insights.
  MemberAISummary generateMemberSummary({
    required FitnessContext context,
    String memberName = 'Athlete',
  }) {
    final recoveryScore = context.recoveryState?.recoveryScore ?? 82;
    final isDeload = context.recoveryState?.isDeloadRecommended ?? false;
    final workoutsCount = context.workoutHistory.length;
    final streak = context.userProgress.workoutStreak;
    final goal = context.userGoal?.goalType.name ?? 'muscle_gain';

    String readinessStatus = 'Optimal Readiness';
    String recommendedAction = 'Maintain progressive overload load progression.';

    if (isDeload || recoveryScore < 50) {
      readinessStatus = 'Overreached / Deload Recommended';
      recommendedAction = 'Prescribe active recovery or reduce volume by 40% this week.';
    } else if (recoveryScore < 70) {
      readinessStatus = 'Moderate Fatigue';
      recommendedAction = 'Keep working weight constant and focus on technique and sleep.';
    }

    final keyInsights = <String>[
      'Active Workout Streak: $streak days uninterrupted',
      'Completed Sessions: $workoutsCount total workouts recorded',
      'Recovery Baseline: $recoveryScore% (Deload Warning: ${isDeload ? "Active ⚠️" : "Inactive ✅"})',
      'Primary Focus: ${goal.toUpperCase().replaceAll('_', ' ')}',
    ];

    final summaryText =
        '$memberName is currently in $readinessStatus ($recoveryScore% recovery). '
        'With a $streak-day streak across $workoutsCount recorded sessions, the primary goal remains $goal. '
        'Coach Recommendation: $recommendedAction';

    return MemberAISummary(
      memberName: memberName,
      readinessStatus: readinessStatus,
      keyInsights: keyInsights,
      recommendedAction: recommendedAction,
      summaryText: summaryText,
    );
  }
}
