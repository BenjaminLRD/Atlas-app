import '../ai_guardrail_service.dart';
import '../ai_provider.dart';
import '../ai_request_router.dart';
import '../gemini_ai_provider.dart';
import '../multimodal/chat_attachment.dart';
import '../tools/ai_tool.dart';
import '../tools/workout_tool.dart';
import '../tools/nutrition_tool.dart';
import '../tools/health_tool.dart';
import '../tools/progress_tool.dart';
import 'agent_action.dart';
import 'agent_result.dart';
import '../../../models/coach_message.dart';
import '../../../models/fitness_context.dart';

/// Central Agent Orchestrator managing tool calling, execution, and confirmation workflows.
class AIAgent {
  final AIProvider aiProvider;
  final List<AITool> tools;

  AIAgent({AIProvider? aiProvider, List<AITool>? tools})
    : aiProvider = aiProvider ?? GeminiAIProvider(),
      tools =
          tools ??
          [WorkoutTool(), NutritionTool(), HealthTool(), ProgressTool()];

  /// Finds an [AITool] by unique tool name.
  AITool? findTool(String name) {
    try {
      return tools.firstWhere((t) => t.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Processes user message through tool-aware agent pipeline.
  Future<AgentResult> processRequest({
    required String message,
    required FitnessContext context,
    List<CoachMessage> history = const [],
    AgentAction? confirmedAction,
    ChatAttachment? attachment,
  }) async {
    final trimmed = message.trim();

    // 0. Domain Restriction Guardrail: Check off-topic
    if (trimmed.isNotEmpty && attachment == null && confirmedAction == null) {
      final decision = AIRequestRouter.instance.route(
        message: trimmed,
        context: context,
      );
      if (decision.intent == AIRequestIntent.offTopic) {
        return AgentResult(
          responseText:
              decision.directResponse ?? AIGuardrailService.offTopicResponse,
          providerName: aiProvider.providerName,
        );
      }
    }

    // 1. Handle user-confirmed pending action execution
    if (confirmedAction != null) {
      final tool = findTool(confirmedAction.toolName);
      if (tool != null) {
        final confirmedArgs = Map<String, dynamic>.from(
          confirmedAction.arguments,
        )..['confirmed'] = true;
        final result = await tool.execute(confirmedArgs);
        final executedAction = confirmedAction.copyWith(
          arguments: confirmedArgs,
          result: result,
          isConfirmed: true,
          requiresConfirmation: false,
        );
        final messageText =
            result['message'] as String? ??
            'Action "${confirmedAction.action}" confirmed and executed successfully.';
        return AgentResult(
          responseText: messageText,
          actionsExecuted: [executedAction],
          providerName: aiProvider.providerName,
        );
      }
    }

    // 2. If Gemini provider is active and online, delegate to Gemini Function Calling
    if (aiProvider is GeminiAIProvider &&
        (aiProvider as GeminiAIProvider).isGeminiActive) {
      return (aiProvider as GeminiAIProvider).generateAgentResponse(
        message: message,
        context: context,
        history: history,
        tools: tools,
        attachment: attachment,
      );
    }

    // 3. Heuristic / Offline Agent Tool Calling
    return _processOfflineAgentRequest(
      message: message,
      context: context,
      history: history,
      attachment: attachment,
    );
  }

  Future<AgentResult> _processOfflineAgentRequest({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  }) async {
    final normalized = message.toLowerCase().trim();
    final actionsExecuted = <AgentAction>[];
    AgentAction? pendingAction;
    String extraContext = '';

    // A. Health / Recovery query intent
    if (normalized.contains('recovery') ||
        normalized.contains('train today') ||
        normalized.contains('can i train') ||
        normalized.contains('should i train') ||
        normalized.contains('readiness')) {
      final healthTool = findTool('health_tool') as HealthTool?;
      if (healthTool != null) {
        final res = await healthTool.execute({'action': 'get_recovery_score'});
        final action = AgentAction(
          id: 'act_${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'health_tool',
          action: 'get_recovery_score',
          arguments: {'action': 'get_recovery_score'},
          result: res,
          timestamp: DateTime.now(),
        );
        actionsExecuted.add(action);
        extraContext +=
            '\n[HEALTH TOOL DATA: Recovery Score: ${res['recovery_score']}%, Readiness: ${res['readiness_tier']}, Recommendation: ${res['recommendation']}]';
      }
    }

    // B. Sleep query intent
    if (normalized.contains('sleep') ||
        normalized.contains('how did i sleep')) {
      final healthTool = findTool('health_tool') as HealthTool?;
      if (healthTool != null) {
        final res = await healthTool.execute({'action': 'get_sleep_data'});
        final action = AgentAction(
          id: 'act_${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'health_tool',
          action: 'get_sleep_data',
          arguments: {'action': 'get_sleep_data'},
          result: res,
          timestamp: DateTime.now(),
        );
        actionsExecuted.add(action);
        extraContext +=
            '\n[HEALTH TOOL DATA: Sleep: ${res['formatted_sleep']}, Resting HR: ${res['resting_heart_rate_bpm']} bpm]';
      }
    }

    // C. Activity & Steps query intent
    if (normalized.contains('steps') ||
        normalized.contains('activity') ||
        normalized.contains('active calories')) {
      final healthTool = findTool('health_tool') as HealthTool?;
      if (healthTool != null) {
        final res = await healthTool.execute({'action': 'get_today_activity'});
        final action = AgentAction(
          id: 'act_${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'health_tool',
          action: 'get_today_activity',
          arguments: {'action': 'get_today_activity'},
          result: res,
          timestamp: DateTime.now(),
        );
        actionsExecuted.add(action);
        extraContext +=
            '\n[HEALTH TOOL DATA: Steps: ${res['steps']}/${res['step_goal']} (${res['progress_percent']}%), Active Burn: ${res['active_calories']} kcal]';
      }
    }

    // D. Workout generation intent
    if (normalized.contains('create') ||
        normalized.contains('generate') ||
        normalized.contains('plan a') ||
        normalized.contains('workout routine') ||
        (normalized.contains('push') && normalized.contains('workout')) ||
        (normalized.contains('pull') && normalized.contains('workout')) ||
        (normalized.contains('leg') &&
            (normalized.contains('workout') ||
                normalized.contains('session')))) {
      String muscle = 'full_body';
      if (normalized.contains('push')) muscle = 'push';
      if (normalized.contains('pull')) muscle = 'pull';
      if (normalized.contains('leg')) muscle = 'legs';
      if (normalized.contains('chest')) muscle = 'chest';

      final workoutTool = findTool('workout_tool') as WorkoutTool?;
      if (workoutTool != null) {
        final res = await workoutTool.execute({
          'action': 'generate_workout',
          'muscle_group': muscle,
          'duration_minutes': 45,
        });
        final action = AgentAction(
          id: 'act_${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'workout_tool',
          action: 'generate_workout',
          arguments: {'action': 'generate_workout', 'muscle_group': muscle},
          result: res,
          timestamp: DateTime.now(),
        );
        actionsExecuted.add(action);
        final workoutData = res['workout'] as Map<String, dynamic>?;
        if (workoutData != null) {
          final exercisesList = (workoutData['exercises'] as List?)
              ?.map((e) {
                final sets = e['sets'] is List
                    ? (e['sets'] as List).length
                    : e['sets'];
                return '- ${e['name']} ($sets sets x ${e['reps']} reps)';
              })
              .join('\n');
          final intelligence =
              workoutData['intelligence'] as Map<String, dynamic>?;
          final score = intelligence?['overallScore'] ?? 92;
          final notes =
              (workoutData['ai_explanation'] as List?)?.join(' ') ?? '';
          final adaptation = workoutData['adaptation'] as Map<String, dynamic>?;
          final hasAdaptation = adaptation?['hasAdaptations'] == true;
          final adaptationTag = hasAdaptation
              ? ' [ADAPTIVE TRAINING APPLIED]'
              : '';
          extraContext +=
              '\n[AI VERIFIED WORKOUT (Score: $score/100$adaptationTag):\nTitle: ${workoutData['title']}\nDuration: ${workoutData['duration_minutes']} mins\n$exercisesList\nCoach Notes: $notes]';
        }
      }
    }

    // E. Nutrition & Protein query intent
    if (normalized.contains('protein') ||
        normalized.contains('calories') ||
        normalized.contains('macros') ||
        normalized.contains('how much have i eaten') ||
        normalized.contains('meal')) {
      final nutritionTool = findTool('nutrition_tool') as NutritionTool?;
      if (nutritionTool != null) {
        if (normalized.contains('protein')) {
          final res = await nutritionTool.execute({
            'action': 'get_protein_intake',
          });
          final action = AgentAction(
            id: 'act_${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'nutrition_tool',
            action: 'get_protein_intake',
            arguments: {'action': 'get_protein_intake'},
            result: res,
            timestamp: DateTime.now(),
          );
          actionsExecuted.add(action);
          extraContext +=
              '\n[NUTRITION TOOL: Consumed: ${res['consumed_protein_g']}g / Target: ${res['target_protein_g']}g (Remaining: ${res['remaining_protein_g']}g)]';
        } else if (normalized.contains('meal')) {
          final res = await nutritionTool.execute({
            'action': 'generate_meal_suggestion',
            'meal_type': 'post_workout',
          });
          final action = AgentAction(
            id: 'act_${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'nutrition_tool',
            action: 'generate_meal_suggestion',
            arguments: {'action': 'generate_meal_suggestion'},
            result: res,
            timestamp: DateTime.now(),
          );
          actionsExecuted.add(action);
          extraContext +=
              '\n[NUTRITION TOOL MEAL: Recommended Items: ${res['recommended_items']}, Total Protein: ${res['total_meal_protein']}g]';
        } else {
          final res = await nutritionTool.execute({
            'action': 'get_today_calories',
          });
          final action = AgentAction(
            id: 'act_${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'nutrition_tool',
            action: 'get_today_calories',
            arguments: {'action': 'get_today_calories'},
            result: res,
            timestamp: DateTime.now(),
          );
          actionsExecuted.add(action);
          extraContext +=
              '\n[NUTRITION TOOL: Calories: ${res['consumed_calories']} / ${res['target_calories']} kcal (Remaining: ${res['remaining_calories']} kcal)]';
        }
      }
    }

    // F. Progress & PR query intent
    if (normalized.contains('pr') ||
        normalized.contains('personal record') ||
        normalized.contains('weight trend') ||
        normalized.contains('progress')) {
      final progressTool = findTool('progress_tool') as ProgressTool?;
      if (progressTool != null) {
        if (normalized.contains('pr') || normalized.contains('record')) {
          final res = await progressTool.execute({'action': 'get_pr_history'});
          final action = AgentAction(
            id: 'act_${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'progress_tool',
            action: 'get_pr_history',
            arguments: {'action': 'get_pr_history'},
            result: res,
            timestamp: DateTime.now(),
          );
          actionsExecuted.add(action);
          extraContext += '\n[PROGRESS TOOL PRS: ${res['personal_records']}]';
        } else {
          final res = await progressTool.execute({
            'action': 'analyze_progress',
          });
          final action = AgentAction(
            id: 'act_${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'progress_tool',
            action: 'analyze_progress',
            arguments: {'action': 'analyze_progress'},
            result: res,
            timestamp: DateTime.now(),
          );
          actionsExecuted.add(action);
          extraContext +=
              '\n[PROGRESS TOOL SUMMARY: Total Workouts: ${res['total_workouts']}, Volume: ${res['total_lifetime_volume_kg']}kg, Streak: ${res['current_streak_days']} days]';
        }
      }
    }

    // Generate conversational response using base provider + enriched tool context
    final responseText = await aiProvider.generateResponse(
      message: extraContext.isNotEmpty ? '$message\n$extraContext' : message,
      context: context,
      history: history,
      attachment: attachment,
    );

    return AgentResult(
      responseText: responseText,
      actionsExecuted: actionsExecuted,
      pendingConfirmationAction: pendingAction,
      isOfflineFallback: true,
      providerName: aiProvider.providerName,
    );
  }
}
