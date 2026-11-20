import 'dart:async';
import '../../models/coach_message.dart';
import '../../models/fitness_context.dart';
import '../../repositories/coach_conversation_repository.dart';
import 'agent/agent_action.dart';
import 'agent/agent_result.dart';
import 'agent/ai_agent.dart';
import 'ai_config.dart';
import 'ai_guardrail_service.dart';
import 'ai_provider.dart';
import 'ai_request_router.dart';
import 'ai_response_cache.dart';
import 'analytics/ai_usage_tracker.dart';
import 'gemini_ai_provider.dart';
import 'multimodal/chat_attachment.dart';

/// Orchestrates AI Coach chat operations, history loading, message generation,
/// error handling, tool-augmented agent actions, and persistence.
class CoachChatService {
  final AIProvider _aiProvider;
  final CoachConversationRepository _repository;

  CoachChatService({
    AIProvider? aiProvider,
    CoachConversationRepository? repository,
  }) : _aiProvider = aiProvider ?? GeminiAIProvider(),
       _repository = repository ?? const LocalCoachConversationRepository();

  /// The active AI provider instance.
  AIProvider get aiProvider => _aiProvider;

  /// Name of the active AI engine (e.g. 'Google Gemini' or 'Offline Fallback').
  String get activeProviderName => _aiProvider.providerName;

  /// Whether the active AI engine connects to a live remote service.
  bool get isOnline => _aiProvider.isOnline;

  /// Why the AI cannot be used right now (null when it can, or when the
  /// provider does not say).
  AIUnavailableReason? get unavailableReason {
    final provider = _aiProvider;
    return provider is GeminiAIProvider ? provider.unavailableReason : null;
  }

  /// Who and what a cached answer was generated for: the account, goal and
  /// the profile facts the prompt uses. A different account or an edited
  /// profile therefore never reuses an earlier answer.
  static String cacheSignature(FitnessContext context) {
    final profile = context.userProfile;
    final goal = context.userGoal?.goalType.name ?? profile?.fitnessGoal ?? '';
    return [
      profile?.userId ?? 'anonymous',
      goal,
      profile?.dob ?? '',
      profile?.height ?? '',
      profile?.weight ?? '',
    ].join('|');
  }

  /// Retrieves stored conversation messages.
  List<CoachMessage> getMessages() {
    return _repository.getMessages();
  }

  /// Sends a user message, passes current context to AI provider, creates response,
  /// and persists the conversation thread.
  Future<List<CoachMessage>> sendMessage({
    required String message,
    required FitnessContext context,
    List<CoachMessage>? currentMessages,
    ChatAttachment? attachment,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty && attachment == null) {
      return currentMessages ?? getMessages();
    }

    final messages = List<CoachMessage>.from(currentMessages ?? getMessages());

    // 1. Create user CoachMessage
    final userMessage = CoachMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      role: CoachRole.user,
      content: trimmed.isNotEmpty ? trimmed : 'Analyzing attached image...',
      timestamp: DateTime.now(),
      imagePath: attachment?.filePath,
      imageBase64: attachment?.base64Data,
      imageMimeType: attachment?.mimeType,
    );
    messages.add(userMessage);

    // Persist immediately after user message
    await _repository.saveMessages(messages);

    // 0. AI Request Router: check for direct deterministic answer or off-topic guardrail
    if (trimmed.isNotEmpty && attachment == null) {
      final routeDecision = AIRequestRouter.instance.route(
        message: trimmed,
        context: context,
      );

      if (routeDecision.isDirectAnswer) {
        AIUsageTracker.instance.recordCacheHit(feature: 'direct_router');
        final directMessage = CoachMessage(
          id: 'msg_assistant_${DateTime.now().millisecondsSinceEpoch}',
          role: CoachRole.assistant,
          content: routeDecision.directResponse!,
          timestamp: DateTime.now(),
          category: CoachReplySource.local,
        );
        messages.add(directMessage);
        await _repository.saveMessages(messages);
        return messages;
      }
    }

    // Check AIResponseCache for an instant answer (text only). Personal
    // questions bypass the cache entirely (see AIResponseCache.isPersonalQuery).
    if (attachment == null) {
      final cache = AIResponseCache.instance;
      // An answer generated for this user and profile, else verified
      // preloaded knowledge for a near-identical question.
      final cached =
          cache.lookup(
            AIResponseCache.generateKey(trimmed, cacheSignature(context)),
          ) ??
          cache.lookup(AIResponseCache.generateKey(trimmed));
      if (cached != null) {
        AIUsageTracker.instance.recordCacheHit(feature: 'coach_chat');
        final cachedAssistantMessage = CoachMessage(
          id: 'msg_assistant_${DateTime.now().millisecondsSinceEpoch}',
          role: CoachRole.assistant,
          content: cached.response,
          timestamp: DateTime.now(),
          // Preloaded knowledge was never generated by the model.
          category: cached.isImmutableKnowledge
              ? CoachReplySource.local
              : CoachReplySource.ai,
        );
        messages.add(cachedAssistantMessage);
        await _repository.saveMessages(messages);
        return messages;
      }
    }

    final stopwatch = Stopwatch()..start();
    try {
      // 2. Query the AI provider (through the ai-proxy Edge Function) with the
      // one shared client-side limit.
      final responseText = await _aiProvider
          .generateResponse(
            message: trimmed.isNotEmpty
                ? trimmed
                : 'Analyze this image and provide coaching details.',
            context: context,
            history: List.unmodifiable(messages),
            attachment: attachment,
          )
          .timeout(AIConfig.requestTimeout);
      stopwatch.stop();

      // Record API consumption metrics
      final inputTokens = AIUsageTracker.estimateTokens(trimmed);
      final outputTokens = AIUsageTracker.estimateTokens(responseText);
      AIUsageTracker.instance.recordRequest(
        feature: 'coach_chat',
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
      );

      // Cache successful response for future repeated queries
      if (attachment == null) {
        AIResponseCache.instance.put(
          AIResponseCache.generateKey(trimmed, cacheSignature(context)),
          responseText,
        );
      }

      // 3. Create assistant CoachMessage with AI Safety Verification
      final sanitizedResponse = _applySafetyGuardrails(responseText, trimmed);
      final assistantMessage = CoachMessage(
        id: 'msg_assistant_${DateTime.now().millisecondsSinceEpoch}',
        role: CoachRole.assistant,
        content: sanitizedResponse,
        timestamp: DateTime.now(),
        category: CoachReplySource.ai,
      );
      messages.add(assistantMessage);
    } catch (e) {
      stopwatch.stop();
      final String errorContent;
      if (e is TimeoutException) {
        errorContent = AIConfig.timeoutMessage;
      } else if (e is GeminiApiException) {
        errorContent = e.message;
      } else {
        errorContent =
            'Unable to reach Atlas AI. Please check your internet connection and try again.';
      }

      final sanitizedError = _applySafetyGuardrails(errorContent, trimmed);
      final errorMessage = CoachMessage(
        id: 'msg_error_${DateTime.now().millisecondsSinceEpoch}',
        role: CoachRole.assistant,
        content: sanitizedError,
        timestamp: DateTime.now(),
        category: CoachReplySource.error,
      );
      messages.add(errorMessage);
    }

    // 4. Persist complete conversation thread
    await _repository.saveMessages(messages);
    return messages;
  }

  /// Processes a user request through the action-capable [AIAgent] orchestrator.
  Future<AgentResult> sendAgentMessage({
    required String message,
    required FitnessContext context,
    AgentAction? confirmedAction,
    ChatAttachment? attachment,
  }) async {
    final agent = AIAgent(aiProvider: _aiProvider);
    final history = getMessages();

    final result = await agent.processRequest(
      message: message.isNotEmpty
          ? message
          : 'Analyze this image and provide workout/diet guidance.',
      context: context,
      history: history,
      confirmedAction: confirmedAction,
      attachment: attachment,
    );

    final updated = List<CoachMessage>.from(history);
    if (confirmedAction == null) {
      updated.add(
        CoachMessage(
          id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
          role: CoachRole.user,
          content: message.isNotEmpty ? message : 'Attached Image',
          timestamp: DateTime.now(),
          imagePath: attachment?.filePath,
          imageBase64: attachment?.base64Data,
          imageMimeType: attachment?.mimeType,
        ),
      );
    }
    updated.add(
      CoachMessage(
        id: 'msg_assistant_${DateTime.now().millisecondsSinceEpoch}',
        role: CoachRole.assistant,
        content: result.responseText,
        timestamp: DateTime.now(),
      ),
    );
    await _repository.saveMessages(updated);

    return result;
  }

  /// Clears stored conversation thread.
  Future<void> clearConversation() async {
    await _repository.clearConversation();
  }

  /// Evaluates input query and response against AI safety protocols.
  String _applySafetyGuardrails(String response, String userQuery) {
    return AIGuardrailService.instance.sanitizeAIResponse(response, userQuery);
  }
}
