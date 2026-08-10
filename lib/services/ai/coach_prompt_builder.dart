import '../../models/fitness_context.dart';
import 'coach_memory.dart';

/// Formats rich context snapshots into structured system prompts for Gemini AI.
class CoachPromptBuilder {
  const CoachPromptBuilder();

  /// Builds a complete context-aware prompt combining system persona, athlete context, memory, and user message.
  String buildPrompt({
    required String message,
    required FitnessContext context,
    CoachMemory memory = const CoachMemory(),
  }) {
    final goal = context.userGoal?.goalType.name ?? 'build_muscle';
    final level = context.userGoal?.fitnessLevel.name ?? 'intermediate';

    final workoutsCount = context.workoutHistory.length;
    final lastWorkout = context.workoutHistory.isNotEmpty
        ? context.workoutHistory.first.workoutName
        : 'None recorded';

    final cals = context.nutritionSummary.totalCaloriesConsumed.toStringAsFixed(0);
    final calGoal = context.nutritionSummary.averageDailyCalories.toStringAsFixed(0);
    final protein = context.nutritionSummary.averageProtein.toStringAsFixed(0);

    final recoveryScore = context.recoveryState?.recoveryScore ?? 80;
    final fatigue = context.recoveryState?.fatigueLevel.name ?? 'low';
    final isDeload = context.recoveryState?.isDeloadRecommended ?? false;

    final completedWorkouts = context.userProgress.completedWorkouts;
    final rank = context.userProgress.fullRank;
    final totalXp = context.userProgress.totalXP;

    final preferences = memory.trainingPreferences.join(', ');
    final style = memory.preferredStyle;

    final systemPrompt = '''
You are the elite AI Fitness Coach for Aizawl Gym. You provide empathetic, science-backed, motivating advice on training, nutrition, recovery, and athlete performance.

[ATHLETE CONTEXT]
- Primary Goal: $goal
- Fitness Level: $level
- Current Rank: $rank ($completedWorkouts sessions completed, $totalXp XP)
- Workouts Completed: $workoutsCount sessions (Last session: $lastWorkout)
- Today's Nutrition: $cals / $calGoal kcal ($protein g protein)
- Recovery Status: $recoveryScore% score ($fatigue fatigue level, Deload Recommended: $isDeload)
- Memory Preferences: $preferences
- Coaching Tone Style: $style

[COACHING DIRECTIVES]
1. Give concise, actionable advice (2-4 sentences max unless detailed workout guidance is requested).
2. Directly reference athlete metrics (e.g. recovery score or workout streak) when relevant.
3. Be encouraging, authoritative, and direct.

[ATHLETE MESSAGE]
"$message"

[COACH RESPONSE]
''';

    return systemPrompt;
  }
}
