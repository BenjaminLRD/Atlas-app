import '../memory/fitness_memory.dart';
import '../memory/preference_profile.dart';

/// Supported user intents for the autonomous AI Coach Agent.
enum CoachAgentIntent {
  workoutAdvice,
  nutritionAdvice,
  recoveryAdvice,
  exerciseSubstitution,
  progressAnalysis,
  motivation;

  static CoachAgentIntent parse(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('substitute') ||
        lower.contains('replace') ||
        lower.contains('alternative') ||
        lower.contains('instead of') ||
        lower.contains('no cable') ||
        lower.contains('no barbell')) {
      return CoachAgentIntent.exerciseSubstitution;
    }
    if (lower.contains('diet') ||
        lower.contains('protein') ||
        lower.contains('calorie') ||
        lower.contains('macro') ||
        lower.contains('meal') ||
        lower.contains('food') ||
        lower.contains('eat')) {
      return CoachAgentIntent.nutritionAdvice;
    }
    if (lower.contains('recover') ||
        lower.contains('sore') ||
        lower.contains('sleep') ||
        lower.contains('tired') ||
        lower.contains('hrv') ||
        lower.contains('readiness') ||
        lower.contains('fatigue')) {
      return CoachAgentIntent.recoveryAdvice;
    }
    if (lower.contains('progress') ||
        lower.contains('pr') ||
        lower.contains('stronger') ||
        lower.contains('analytics') ||
        lower.contains('improvement') ||
        lower.contains('volume trend')) {
      return CoachAgentIntent.progressAnalysis;
    }
    if (lower.contains('motivat') ||
        lower.contains('encourage') ||
        lower.contains('lazy') ||
        lower.contains('streak') ||
        lower.contains('mindset') ||
        lower.contains('push me')) {
      return CoachAgentIntent.motivation;
    }
    return CoachAgentIntent.workoutAdvice;
  }
}

/// Active coaching output mode based on workout state.
enum CoachResponseMode {
  /// Ultra-concise, 1-2 sentence real-time feedback during an active workout.
  short,

  /// In-depth, analytical educational coaching outside active sessions.
  detailed,
}

/// Real-time live workout session context payload for the AI Coach.
class WorkoutSessionContext {
  final String workoutName;
  final String currentExercise;
  final int currentSetIndex;
  final int totalSets;
  final double currentWeightKg;
  final int targetReps;
  final int? completedReps;
  final double? previousSessionWeightKg;
  final int? previousSessionReps;
  final double completedVolumeKg;
  final int restTimerRemainingSeconds;
  final double athleteFatigueScore; // 0-100 (100 = fresh, 0 = exhausted)

  const WorkoutSessionContext({
    required this.workoutName,
    required this.currentExercise,
    required this.currentSetIndex,
    required this.totalSets,
    required this.currentWeightKg,
    required this.targetReps,
    this.completedReps,
    this.previousSessionWeightKg,
    this.previousSessionReps,
    this.completedVolumeKg = 0.0,
    this.restTimerRemainingSeconds = 0,
    this.athleteFatigueScore = 80.0,
  });

  /// Formats real-time workout state into an AI context prompt string.
  String toPromptContext() {
    final buffer = StringBuffer();
    buffer.writeln('[ACTIVE WORKOUT SESSION CONTEXT]');
    buffer.writeln('Workout: $workoutName');
    buffer.writeln(
      'Current Exercise: $currentExercise (Set $currentSetIndex of $totalSets)',
    );
    buffer.writeln(
      'Prescribed Load: ${currentWeightKg.toStringAsFixed(1)} kg for $targetReps reps',
    );
    if (completedReps != null) {
      buffer.writeln(
        'Last Set Performance: ${currentWeightKg.toStringAsFixed(1)} kg x $completedReps reps',
      );
    }
    if (previousSessionWeightKg != null && previousSessionReps != null) {
      buffer.writeln(
        'Previous Benchmark Session: ${previousSessionWeightKg!.toStringAsFixed(1)} kg x $previousSessionReps reps',
      );
    }
    buffer.writeln(
      'Cumulative Session Volume: ${completedVolumeKg.toStringAsFixed(0)} kg',
    );
    if (restTimerRemainingSeconds > 0) {
      buffer.writeln(
        'Active Rest Timer: ${restTimerRemainingSeconds}s remaining',
      );
    }
    buffer.writeln(
      'Calculated Session Fatigue Score: ${athleteFatigueScore.toStringAsFixed(0)}/100',
    );
    return buffer.toString().trim();
  }
}

/// Result returned by the Coach Agent.
class CoachAgentResponse {
  final CoachAgentIntent intent;
  final CoachResponseMode mode;
  final String textResponse;
  final String? suggestedAction;
  final Map<String, dynamic>? actionPayload;

  const CoachAgentResponse({
    required this.intent,
    required this.mode,
    required this.textResponse,
    this.suggestedAction,
    this.actionPayload,
  });
}

/// Central AI Coach Agent orchestrating intent detection, context assembly, and personalized coaching response generation.
class CoachAgentService {
  static CoachAgentService? _instance;
  static CoachAgentService get instance => _instance ??= CoachAgentService();

  /// Processes user query, incorporating active workout context and athlete memory preferences.
  CoachAgentResponse generateCoachingResponse({
    required String userQuery,
    WorkoutSessionContext? activeWorkout,
    CoachResponseMode? forcedMode,
    PreferenceProfile? preferenceProfile,
  }) {
    final intent = CoachAgentIntent.parse(userQuery);
    final isDuringWorkout = activeWorkout != null;
    final mode =
        forcedMode ??
        (isDuringWorkout
            ? CoachResponseMode.short
            : CoachResponseMode.detailed);
    final profile =
        preferenceProfile ?? FitnessMemory.instance.getPreferenceProfile();

    String responseText;
    String? suggestedAction;
    Map<String, dynamic>? payload;

    switch (intent) {
      case CoachAgentIntent.exerciseSubstitution:
        responseText = mode == CoachResponseMode.short
            ? 'Switching to Dumbbell Bench Press. Maintain 3 sets of 8-10 reps with controlled 2s eccentric.'
            : 'Based on your available equipment, you can replace this movement with Dumbbell Bench Press or Deficit Push-ups. Both effectively target the sternal chest while minimizing anterior shoulder stress.';
        suggestedAction = 'replace_exercise';
        payload = {
          'replacement': 'Dumbbell Bench Press',
          'targetMuscle': 'Chest',
        };
        break;

      case CoachAgentIntent.recoveryAdvice:
        if (activeWorkout != null && activeWorkout.athleteFatigueScore < 50) {
          responseText = mode == CoachResponseMode.short
              ? 'Fatigue elevated. Recommend dropping 5kg on next set and resting 120s.'
              : 'Your physiological indicators show high systemic fatigue today. Consider reducing working weights by 5-10% and extending rest intervals to 2-3 minutes to preserve technique.';
          suggestedAction = 'reduce_weight';
          payload = {'deltaKg': -5.0};
        } else {
          responseText = mode == CoachResponseMode.short
              ? 'Recovery is optimal. Execute scheduled sets with full intensity.'
              : 'Your autonomic recovery score and sleep quality are solid. You are primed for progressive overload today.';
        }
        break;

      case CoachAgentIntent.progressAnalysis:
        responseText = mode == CoachResponseMode.short
            ? 'Bench Press strength is up 8% over last 4 weeks. Keep progressing!'
            : 'Looking at your 30-day training history, your compound volume is trending upward by 8% with consistent 1RM increases. Excellent progressive overload discipline.';
        break;

      case CoachAgentIntent.nutritionAdvice:
        responseText = mode == CoachResponseMode.short
            ? 'Target 40g post-workout protein and 500ml water within 45 mins.'
            : 'To maximize muscle protein synthesis after today\'s session, aim for 35-45g of high-quality protein paired with complex carbohydrates to replenish glycogen stores.';
        break;

      case CoachAgentIntent.motivation:
        final streakCount = profile.helpfulRecommendationsCount;
        responseText = mode == CoachResponseMode.short
            ? 'Strong mindset! Lock in on this next set and control every rep.'
            : (streakCount > 0
                  ? 'You\'ve logged $streakCount helpful coaching sessions. Every clean rep builds long-term athletic resilience. Let\'s make this session count!'
                  : 'You\'ve shown remarkable consistency this month. Every clean rep builds long-term athletic resilience. Let\'s make this session count!');
        break;

      case CoachAgentIntent.workoutAdvice:
        if (isDuringWorkout &&
            activeWorkout.completedReps != null &&
            activeWorkout.completedReps! < activeWorkout.targetReps) {
          final drop = activeWorkout.targetReps - activeWorkout.completedReps!;
          responseText = mode == CoachResponseMode.short
              ? 'Missed target by $drop reps. Drop weight by 2.5kg or extend rest by 30s.'
              : 'You completed ${activeWorkout.completedReps} of ${activeWorkout.targetReps} target reps. To maintain quality volume, consider a 2.5kg reduction or adding 30s rest before set ${activeWorkout.currentSetIndex + 1}.';
          suggestedAction = 'adjust_load';
          payload = {'deltaKg': -2.5, 'extraRestSec': 30};
        } else if (isDuringWorkout) {
          responseText = mode == CoachResponseMode.short
              ? 'Solid execution! Rest ${activeWorkout.restTimerRemainingSeconds > 0 ? activeWorkout.restTimerRemainingSeconds : 90}s then begin set ${activeWorkout.currentSetIndex + 1}.'
              : 'Great form and pacing on ${activeWorkout.currentExercise}. Take a full 90-second rest before your next set to allow ATP replenishment.';
        } else {
          responseText =
              'Ready to train. Let\'s review today\'s programmed split and lock in your warm-up sets.';
        }
        break;
    }

    return CoachAgentResponse(
      intent: intent,
      mode: mode,
      textResponse: responseText,
      suggestedAction: suggestedAction,
      actionPayload: payload,
    );
  }
}
