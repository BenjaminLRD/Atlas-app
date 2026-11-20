import 'dart:async';
import '../../../models/fitness_context.dart';
import '../ai_response_cache.dart';
import '../evaluation/ai_response_evaluator.dart';
import '../optimization/ai_usage_optimization_service.dart';
import '../prompt/adaptive_prompt_builder.dart';

/// Execution priority tiers for AI requests.
enum AIRequestPriority {
  liveInteractive(1, 'P1 - Real-Time Live Coaching / Chat'),
  proactiveBriefing(2, 'P2 - Morning Briefing / Action Plan'),
  weeklyReview(3, 'P3 - Weekly Athlete Review'),
  backgroundMining(4, 'P4 - Pattern Discovery / Batch Telemetry');

  final int level;
  final String label;
  const AIRequestPriority(this.level, this.label);
}

/// Unified response wrapper emitted by the Atlas AI Gateway.
class AIGatewayResponse {
  final String query;
  final String responseContent;
  final String modelUsed;
  final bool isCacheHit;
  final int latencyMs;
  final int tokensConsumed;
  final bool isFallbackUsed;
  final AIQualityScore? qualityScore;
  final DateTime timestamp;

  const AIGatewayResponse({
    required this.query,
    required this.responseContent,
    required this.modelUsed,
    required this.isCacheHit,
    required this.latencyMs,
    required this.tokensConsumed,
    required this.isFallbackUsed,
    this.qualityScore,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'query': query,
    'response_content': responseContent,
    'model_used': modelUsed,
    'is_cache_hit': isCacheHit,
    'latency_ms': latencyMs,
    'tokens_consumed': tokensConsumed,
    'is_fallback_used': isFallbackUsed,
    if (qualityScore != null) 'quality_grade': qualityScore!.grade,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Enterprise Atlas AI Service Gateway.
/// Orchestrates model routing, prompt compilation, RAG knowledge retrieval,
/// memory ranking, response caching, exponential retries, and offline fallbacks.
class AtlasAIServiceGateway {
  static AtlasAIServiceGateway? _instance;
  static AtlasAIServiceGateway get instance =>
      _instance ??= AtlasAIServiceGateway();

  static void resetInstance() {
    _instance = null;
  }

  final AIResponseCache _cache;
  final AIUsageOptimizationService _optimizer;
  final AIResponseEvaluator _evaluator;

  AtlasAIServiceGateway({
    AIResponseCache? cache,
    AIUsageOptimizationService? optimizer,
    AIResponseEvaluator? evaluator,
  }) : _cache = cache ?? AIResponseCache.instance,
       _optimizer = optimizer ?? AIUsageOptimizationService.instance,
       _evaluator = evaluator ?? AIResponseEvaluator.instance;

  /// Executes an end-to-end AI request with caching, RAG retrieval, and automatic fallback.
  Future<AIGatewayResponse> executeRequest({
    required String userQuery,
    required FitnessContext context,
    CoachStyle? style,
    AIRequestPriority priority = AIRequestPriority.liveInteractive,
    int maxRetries = 2,
  }) async {
    final stopwatch = Stopwatch()..start();
    final now = DateTime.now();

    // 1. Response Cache Check
    final cached = _cache.get(userQuery);
    if (cached != null) {
      return AIGatewayResponse(
        query: userQuery,
        responseContent: cached,
        modelUsed: 'cache-edge-hit',
        isCacheHit: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        tokensConsumed: 0,
        isFallbackUsed: false,
        timestamp: now,
      );
    }

    // 2. Model Routing & Prompt Synthesis
    final optimalModel = _optimizer.selectOptimalModel(
      query: userQuery,
      requiresDeepReasoning: priority == AIRequestPriority.weeklyReview,
    );

    final prompt = AdaptivePromptBuilder.instance.buildTaskPrompt(
      userMessage: userQuery,
      context: context,
      style: style,
    );

    // 3. Resilient Model Invocation with Exponential Backoff
    String generatedContent = '';
    bool fallbackEngaged = false;
    int attempt = 0;

    while (attempt <= maxRetries) {
      try {
        // Mock / Provider execution
        generatedContent = await _invokeModelEndpoint(
          model: optimalModel,
          prompt: prompt,
          userQuery: userQuery,
        );
        break;
      } catch (e) {
        attempt++;
        if (attempt > maxRetries) {
          fallbackEngaged = true;
          generatedContent = _generateGracefulFallback(userQuery, context);
        } else {
          // Exponential backoff: 50ms * 2^attempt
          await Future.delayed(Duration(milliseconds: 50 * (1 << attempt)));
        }
      }
    }

    // 4. Cache & Quality Audit
    if (!fallbackEngaged) {
      _cache.put(userQuery, generatedContent);
    }

    final quality = _evaluator.evaluate(
      query: userQuery,
      response: generatedContent,
      context: context,
    );

    final tokens =
        (prompt.length / 4).round() + (generatedContent.length / 4).round();

    return AIGatewayResponse(
      query: userQuery,
      responseContent: generatedContent,
      modelUsed: fallbackEngaged ? 'offline-fallback' : optimalModel,
      isCacheHit: false,
      latencyMs: stopwatch.elapsedMilliseconds,
      tokensConsumed: tokens,
      isFallbackUsed: fallbackEngaged,
      qualityScore: quality,
      timestamp: now,
    );
  }

  Future<String> _invokeModelEndpoint({
    required String model,
    required String prompt,
    required String userQuery,
  }) async {
    // Standard execution response simulation
    final isTech = prompt.contains('Analytical, scientific');
    final prefix = isTech
        ? 'From a biomechanical and physiological standpoint: '
        : '';
    return '${prefix}Based on your current training load and recovery, continue progressive overload on your working sets with proper rest.';
  }

  String _generateGracefulFallback(String query, FitnessContext context) {
    return 'Atlas Coach is operating in high-resilience mode. Keep maintaining consistent progressive overload and ensure at least 1.6g/kg daily protein intake.';
  }
}
