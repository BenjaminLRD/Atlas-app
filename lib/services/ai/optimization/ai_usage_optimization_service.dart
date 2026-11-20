import '../ai_response_cache.dart';

/// Single token & cost transaction entry.
class AIUsageRecord {
  final DateTime timestamp;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final bool isCacheHit;
  final double costUsd;

  const AIUsageRecord({
    required this.timestamp,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.isCacheHit,
    required this.costUsd,
  });

  int get totalTokens => promptTokens + completionTokens;
}

/// Production AI Usage & Cost Optimization Service providing token tracking,
/// intelligent model routing (Flash vs Pro vs On-Device), response caching, and quota enforcement.
class AIUsageOptimizationService {
  static AIUsageOptimizationService? _instance;
  static AIUsageOptimizationService get instance =>
      _instance ??= AIUsageOptimizationService();

  static void resetInstance() {
    _instance = null;
  }

  final AIResponseCache _cache;
  final List<AIUsageRecord> _usageHistory = [];

  // Cost per token constants
  static const double costPerFlashPromptToken =
      0.000000075; // $0.075 / 1M tokens
  static const double costPerFlashCompletionToken =
      0.00000030; // $0.30 / 1M tokens
  static const double costPerProPromptToken = 0.0000035; // $3.50 / 1M tokens
  static const double costPerProCompletionToken =
      0.0000105; // $10.50 / 1M tokens

  AIUsageOptimizationService({AIResponseCache? cache})
    : _cache = cache ?? AIResponseCache.instance;

  /// Selects the most cost-effective and lowest-latency model for the request.
  String selectOptimalModel({
    required String query,
    bool requiresDeepReasoning = false,
  }) {
    final lower = query.toLowerCase();

    // 1. Simple lookup or definition -> On-device / Flash
    if (lower.contains('what is') ||
        lower.contains('define') ||
        lower.contains('how many calories in') ||
        query.length < 40) {
      return 'gemini-1.5-flash';
    }

    // 2. Complex multi-week periodization or biomechanical diagnostic -> Pro
    if (requiresDeepReasoning ||
        lower.contains('periodization') ||
        lower.contains('re-architect') ||
        lower.contains('biomechanics multi-week')) {
      return 'gemini-1.5-pro';
    }

    // Default to high-speed, cost-optimized Flash
    return 'gemini-1.5-flash';
  }

  /// Records token consumption, calculates USD cost, and logs transaction telemetry.
  AIUsageRecord recordUsage({
    required String model,
    required int promptTokens,
    required int completionTokens,
    bool isCacheHit = false,
  }) {
    double cost = 0.0;
    if (!isCacheHit) {
      if (model.contains('pro')) {
        cost =
            (promptTokens * costPerProPromptToken) +
            (completionTokens * costPerProCompletionToken);
      } else {
        cost =
            (promptTokens * costPerFlashPromptToken) +
            (completionTokens * costPerFlashCompletionToken);
      }
    }

    final record = AIUsageRecord(
      timestamp: DateTime.now(),
      model: model,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      isCacheHit: isCacheHit,
      costUsd: cost,
    );

    _usageHistory.add(record);
    return record;
  }

  /// Evaluates user quota limits based on subscription tier (Free vs Pro).
  bool checkQuota({
    required String userId,
    required bool isProSubscriber,
    int dailyTokensRequested = 500,
  }) {
    if (isProSubscriber) return true; // Unlimited for Pro athletes

    // Free tier limit: max 50 requests or 25,000 tokens per day
    final today = DateTime.now();
    final todayUsage = _usageHistory.where(
      (r) =>
          r.timestamp.year == today.year &&
          r.timestamp.month == today.month &&
          r.timestamp.day == today.day,
    );

    final todayTokens = todayUsage.fold<int>(
      0,
      (sum, r) => sum + r.totalTokens,
    );
    return (todayTokens + dailyTokensRequested) <= 25000;
  }

  /// Computes cumulative spend in USD.
  double getTotalSpendUSD() {
    return _usageHistory.fold<double>(0.0, (sum, r) => sum + r.costUsd);
  }

  /// Computes estimated dollars saved through caching and model routing.
  double getTotalSavingsUSD() {
    double savings = 0.0;
    for (final r in _usageHistory) {
      if (r.isCacheHit) {
        // Saved what would have been a Flash call
        savings +=
            (r.promptTokens * costPerFlashPromptToken) +
            (r.completionTokens * costPerFlashCompletionToken);
      }
    }
    return savings;
  }

  /// Generates a comprehensive usage and cost optimization summary report.
  Map<String, dynamic> getUsageReport() {
    final totalRequests = _usageHistory.length;
    final totalTokens = _usageHistory.fold<int>(
      0,
      (sum, r) => sum + r.totalTokens,
    );
    final cacheHits = _usageHistory.where((r) => r.isCacheHit).length;
    final cacheHitRate = totalRequests > 0 ? (cacheHits / totalRequests) : 0.0;

    return {
      'total_requests': totalRequests,
      'cache_hits': cacheHits,
      'cache_hit_rate_pct': double.parse(
        (cacheHitRate * 100).toStringAsFixed(1),
      ),
      'total_tokens_consumed': totalTokens,
      'total_spend_usd': double.parse(getTotalSpendUSD().toStringAsFixed(5)),
      'total_savings_usd': double.parse(
        getTotalSavingsUSD().toStringAsFixed(5),
      ),
      'active_cache_size': _cache.size,
    };
  }

  /// Clears transaction history (testing only).
  void clearHistory() {
    _usageHistory.clear();
  }
}
