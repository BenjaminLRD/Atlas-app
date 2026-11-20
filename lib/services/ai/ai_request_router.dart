import '../../models/fitness_context.dart';
import 'ai_guardrail_service.dart';
import 'goal_validation_service.dart';

/// Categorized user intent classification for AI routing.
enum AIRequestIntent {
  workoutRequest,
  nutritionQuestion,
  recoveryQuestion,
  progressQuestion,
  generalFitnessQuestion,
  offTopic,
}

/// Routing decision output specifying execution strategy and context requirements.
class RouteDecision {
  final AIRequestIntent intent;
  final bool needsLLM;
  final String? targetTool;
  final String? directResponse;
  final List<String> requiredContextKeys;
  final String reasoning;

  const RouteDecision({
    required this.intent,
    required this.needsLLM,
    this.targetTool,
    this.directResponse,
    this.requiredContextKeys = const [],
    required this.reasoning,
  });

  bool get isDirectAnswer => !needsLLM && directResponse != null;
}

/// Intelligent AI Request Router that directs user requests to the most efficient,
/// cost-effective, and lowest-latency execution path.
/// Eliminates redundant Gemini API calls by intercepting deterministic queries,
/// offline tools, cached domain knowledge, and off-topic requests.
class AIRequestRouter {
  const AIRequestRouter();

  static const AIRequestRouter instance = AIRequestRouter();

  /// Analyzes the user message and fitness context to determine the optimal execution route.
  RouteDecision route({
    required String message,
    required FitnessContext context,
  }) {
    final trimmed = message.trim();
    final lower = trimmed.toLowerCase();

    // 0. Off-Topic Check via Guardrails
    if (!AIGuardrailService.instance.isFitnessRelated(trimmed)) {
      return RouteDecision(
        intent: AIRequestIntent.offTopic,
        needsLLM: false,
        directResponse: AIGuardrailService.offTopicResponse,
        reasoning: 'Non-fitness query intercepted by guardrail rules.',
      );
    }

    // 0.1 Unsafe Goal Check via Guardrails
    if (AIGuardrailService.instance.containsUnsafeGoal(trimmed)) {
      final validation = GoalValidationService.instance.validateGoalQuery(
        trimmed,
      );
      return RouteDecision(
        intent: AIRequestIntent.generalFitnessQuestion,
        needsLLM: false,
        directResponse:
            validation.recommendation ??
            AIGuardrailService.instance.getSafetyResponse(validation.issue),
        reasoning:
            'Unsafe fitness goal intercepted with evidence-based safety guidance.',
      );
    }

    // 1. Direct Retrieval / Progress Intent (Answer from local context without LLM)
    if (_isLastWorkoutQuery(lower)) {
      final direct = _formatLastWorkoutResponse(context);
      return RouteDecision(
        intent: AIRequestIntent.progressQuestion,
        needsLLM: false,
        targetTool: 'ProgressTool',
        directResponse: direct,
        requiredContextKeys: const ['workoutHistory'],
        reasoning: 'Resolved directly from WorkoutHistory cache without LLM.',
      );
    }

    if (_isDailyNutritionStatusQuery(lower)) {
      final direct = _formatDailyNutritionResponse(context);
      return RouteDecision(
        intent: AIRequestIntent.nutritionQuestion,
        needsLLM: false,
        targetTool: 'NutritionTool',
        directResponse: direct,
        requiredContextKeys: const ['todayNutritionLog'],
        reasoning: 'Resolved directly from TodayNutritionLog without LLM.',
      );
    }

    if (_isDailyRecoveryStatusQuery(lower)) {
      final direct = _formatRecoveryStatusResponse(context);
      return RouteDecision(
        intent: AIRequestIntent.recoveryQuestion,
        needsLLM: false,
        targetTool: 'HealthTool',
        directResponse: direct,
        requiredContextKeys: const ['recoveryBreakdown', 'todayHealthMetric'],
        reasoning: 'Resolved directly from Recovery metrics without LLM.',
      );
    }

    if (_isStreakQuery(lower)) {
      final streak = context.userProgress.workoutStreak;
      final direct = streak > 0
          ? 'You are currently on a $streak-day workout streak! Keep up the great consistency.'
          : 'You currently have no active streak. Complete a workout today to start a new streak!';
      return RouteDecision(
        intent: AIRequestIntent.progressQuestion,
        needsLLM: false,
        directResponse: direct,
        requiredContextKeys: const ['userProgress'],
        reasoning: 'Resolved streak count directly from UserProgress.',
      );
    }

    // 2. Workout Generation / Modification Intent
    if (_isWorkoutRequest(lower)) {
      return RouteDecision(
        intent: AIRequestIntent.workoutRequest,
        needsLLM: true,
        targetTool: 'WorkoutTool',
        requiredContextKeys: const [
          'userGoal',
          'equipmentProfile',
          'workoutHistory',
          'userProfile',
        ],
        reasoning:
            'Workout generation / modification requires WorkoutTool & targeted context.',
      );
    }

    // 3. Nutrition Question Intent
    if (_isNutritionQuestion(lower)) {
      return RouteDecision(
        intent: AIRequestIntent.nutritionQuestion,
        needsLLM: true,
        targetTool: 'NutritionTool',
        requiredContextKeys: const [
          'userGoal',
          'todayNutritionLog',
          'nutritionSummary',
          'userProfile',
        ],
        reasoning: 'Complex nutrition guidance routed to Nutrition pipeline.',
      );
    }

    // 4. Recovery & Health Question Intent
    if (_isRecoveryQuestion(lower)) {
      return RouteDecision(
        intent: AIRequestIntent.recoveryQuestion,
        needsLLM: true,
        targetTool: 'HealthTool',
        requiredContextKeys: const [
          'recoveryBreakdown',
          'recoveryState',
          'todayHealthMetric',
          'workoutHistory',
        ],
        reasoning: 'Recovery & readiness analysis routed to Health pipeline.',
      );
    }

    // 5. General Fitness FAQ / Domain Knowledge Intent
    return RouteDecision(
      intent: AIRequestIntent.generalFitnessQuestion,
      needsLLM: true,
      requiredContextKeys: const ['userGoal', 'userProfile'],
      reasoning:
          'General fitness domain question routed with minimal prompt context.',
    );
  }

  /// The intent of [message] using the same matchers as [route], without
  /// needing fitness context. Used to word the loading status.
  AIRequestIntent classifyIntent(String message) {
    final lower = message.trim().toLowerCase();
    if (_isWorkoutRequest(lower)) return AIRequestIntent.workoutRequest;
    if (_isNutritionQuestion(lower)) return AIRequestIntent.nutritionQuestion;
    if (_isRecoveryQuestion(lower)) return AIRequestIntent.recoveryQuestion;
    return AIRequestIntent.generalFitnessQuestion;
  }

  /// Neutral text shown while waiting for the model. It names the topic of
  /// the question but never claims a particular operation is running.
  static String loadingStatusFor(
    AIRequestIntent intent, {
    bool hasAttachment = false,
  }) {
    if (hasAttachment) return 'Atlas AI is looking at your photo…';
    switch (intent) {
      case AIRequestIntent.workoutRequest:
        return 'Atlas AI is thinking about your workout question…';
      case AIRequestIntent.nutritionQuestion:
        return 'Atlas AI is thinking about your nutrition question…';
      case AIRequestIntent.recoveryQuestion:
        return 'Atlas AI is thinking about your recovery question…';
      case AIRequestIntent.progressQuestion:
      case AIRequestIntent.generalFitnessQuestion:
      case AIRequestIntent.offTopic:
        return defaultLoadingStatus;
    }
  }

  static const String defaultLoadingStatus = 'Atlas AI is thinking…';

  bool _isLastWorkoutQuery(String text) {
    return text.contains('last workout') ||
        text.contains('previous workout') ||
        text.contains('what did i train last') ||
        text.contains('what was my last session');
  }

  bool _isDailyNutritionStatusQuery(String text) {
    return (text.contains('how much protein') &&
            (text.contains('today') ||
                text.contains('eaten') ||
                text.contains('consumed') ||
                text.contains('left') ||
                text.contains('remaining'))) ||
        (text.contains('calories') &&
            (text.contains('today') ||
                text.contains('eaten') ||
                text.contains('consumed') ||
                text.contains('left') ||
                text.contains('remaining')));
  }

  bool _isDailyRecoveryStatusQuery(String text) {
    return text == 'what is my recovery today' ||
        text == 'what is my recovery' ||
        text == 'what is my recovery score' ||
        text == 'show my recovery score' ||
        text == 'my recovery score today';
  }

  bool _isStreakQuery(String text) {
    return text.contains('what is my streak') ||
        text.contains('my current streak') ||
        text.contains('how many days streak') ||
        text.contains('show my streak');
  }

  bool _isWorkoutRequest(String text) {
    return text.contains('workout') ||
        text.contains('exercise') ||
        text.contains('routine') ||
        text.contains('split') ||
        text.contains('chest day') ||
        text.contains('leg day') ||
        text.contains('push day') ||
        text.contains('pull day') ||
        text.contains('bench press') ||
        text.contains('squat') ||
        text.contains('substitute') ||
        text.contains('make me a') ||
        text.contains('build me a') ||
        text.contains('generate');
  }

  bool _isNutritionQuestion(String text) {
    return text.contains('protein') ||
        text.contains('calorie') ||
        text.contains('macro') ||
        text.contains('diet') ||
        text.contains('meal') ||
        text.contains('food') ||
        text.contains('carbs') ||
        text.contains('fats') ||
        text.contains('creatine') ||
        text.contains('supplement') ||
        text.contains('shake') ||
        text.contains('eat');
  }

  bool _isRecoveryQuestion(String text) {
    return text.contains('recover') ||
        text.contains('sleep') ||
        text.contains('sore') ||
        text.contains('fatigue') ||
        text.contains('readiness') ||
        text.contains('train today') ||
        text.contains('rest day') ||
        text.contains('deload') ||
        text.contains('heart rate') ||
        text.contains('hrv');
  }

  String _formatLastWorkoutResponse(FitnessContext context) {
    if (context.workoutHistory.isEmpty) {
      return 'You haven\'t logged any workouts yet. Once you complete your first session, details like volume and exercises will be recorded here!';
    }
    final last = context.workoutHistory.first;
    final prText = last.personalRecords.isNotEmpty
        ? ' PRs achieved: ${last.personalRecords.join(', ')}.'
        : '';
    return 'Your last workout was **${last.workoutName}** (${last.totalVolume.toInt()} kg lifted across ${last.exercisesCompleted} exercises).$prText';
  }

  String _formatDailyNutritionResponse(FitnessContext context) {
    final log = context.todayNutritionLog;
    if (log == null) {
      return 'No nutrition data logged for today yet. Tap the + icon on the nutrition tab to log your meals!';
    }
    final cal = log.dailyCaloriesLabel;
    final unknown = log.unknownCalorieItems;
    final targetCal = log.calorieGoal.toInt();
    final prot = log.dailyProtein.toInt();
    final protLabel = log.dailyProteinLabel;
    final unknownProt = log.unknownProteinItems;
    final targetProt = log.proteinGoal.toInt();
    final remainingProt = (targetProt - prot).clamp(0, 500);

    final note = unknown > 0
        ? ' Calories are a minimum: $unknown logged '
              '${unknown == 1 ? 'item has' : 'items have'} unknown calories '
              '(not counted as 0 kcal).'
        : '';
    final protNote = unknownProt > 0
        ? ' Protein is a minimum: $unknownProt logged '
              '${unknownProt == 1 ? 'item has' : 'items have'} unknown protein '
              '(not counted as 0 g).'
        : '';
    return 'Today you have consumed **$cal / $targetCal kcal** and **$protLabel / ${targetProt}g protein** ($remainingProt g protein remaining).$note$protNote';
  }

  String _formatRecoveryStatusResponse(FitnessContext context) {
    // A score is quoted only when it comes from recorded sleep, HRV or heart
    // rate. Otherwise the answer says there is none; it never guesses.
    final stateScore = (context.recoveryState?.isMeasured ?? false)
        ? context.recoveryState!.recoveryScore
        : null;
    final score = context.recoveryBreakdown?.totalScore ?? stateScore;
    final sleepMinutes = context.todayHealthMetric?.sleepMinutes;
    final sleep = (sleepMinutes != null && sleepMinutes > 0)
        ? context.todayHealthMetric!.formattedSleep
        : 'not recorded';
    if (score == null) {
      return 'I do not have a recovery score for today because no sleep, HRV or heart-rate data is recorded (Sleep: $sleep). Log your last night of sleep or connect a watch through Health Connect and I can work one out.';
    }
    final verdict = score >= 80
        ? 'You are in a prime state for athletic performance.'
        : (score >= 60
              ? 'You are recovered enough to train as planned.'
              : 'Recovery is low, so keep today lighter.');
    return 'Your recovery score today is **$score%** (Sleep: $sleep). $verdict';
  }
}
