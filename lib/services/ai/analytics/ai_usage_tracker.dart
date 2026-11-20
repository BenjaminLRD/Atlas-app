import 'dart:math' as math;

/// Metrics summary representing AI API consumption, latency, and estimated operating cost.
class AIUsageSummary {
  final int totalRequests;
  final int cachedRequests;
  final int totalInputTokens;
  final int totalOutputTokens;
  final double averageLatencyMs;
  final double estimatedCostUsd;
  final Map<String, int> featureBreakdown;
  final DateTime recordedDate;

  const AIUsageSummary({
    required this.totalRequests,
    required this.cachedRequests,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.averageLatencyMs,
    required this.estimatedCostUsd,
    required this.featureBreakdown,
    required this.recordedDate,
  });

  double get cacheHitRate => totalRequests > 0
      ? (cachedRequests / totalRequests).clamp(0.0, 1.0)
      : 0.0;
}

/// Centralized usage tracker monitoring AI API volume, token burn rates,
/// feature-level breakdowns, and operating costs.
class AIUsageTracker {
  static final AIUsageTracker _instance = AIUsageTracker._internal();
  factory AIUsageTracker() => _instance;
  AIUsageTracker._internal();

  static AIUsageTracker get instance => _instance;

  int _totalRequests = 0;
  int _cachedRequests = 0;
  int _totalInputTokens = 0;
  int _totalOutputTokens = 0;
  final List<double> _latenciesMs = [];
  final Map<String, int> _featureCounts = {};

  // Gemini 1.5 Flash Pricing baseline ($0.075 per 1M input tokens, $0.30 per 1M output tokens)
  static const double _inputCostPerToken = 0.075 / 1000000;
  static const double _outputCostPerToken = 0.30 / 1000000;

  int get totalRequests => _totalRequests;
  int get cachedRequests => _cachedRequests;
  int get totalInputTokens => _totalInputTokens;
  int get totalOutputTokens => _totalOutputTokens;
  Map<String, int> get featureBreakdown => Map.unmodifiable(_featureCounts);

  double get averageLatencyMs {
    if (_latenciesMs.isEmpty) return 0.0;
    final sum = _latenciesMs.fold<double>(0.0, (a, b) => a + b);
    return sum / _latenciesMs.length;
  }

  double get estimatedCostUsd {
    return (_totalInputTokens * _inputCostPerToken) +
        (_totalOutputTokens * _outputCostPerToken);
  }

  /// Records an executed remote AI API call with token and latency metrics.
  void recordRequest({
    required String feature,
    required int inputTokens,
    required int outputTokens,
    required double latencyMs,
  }) {
    _totalRequests++;
    _totalInputTokens += inputTokens;
    _totalOutputTokens += outputTokens;
    _latenciesMs.add(latencyMs);
    if (_latenciesMs.length > 500) _latenciesMs.removeAt(0);

    _featureCounts[feature] = (_featureCounts[feature] ?? 0) + 1;
  }

  /// Records a request fulfilled instantaneously via local cache or deterministic router.
  void recordCacheHit({required String feature}) {
    _totalRequests++;
    _cachedRequests++;
    _featureCounts[feature] = (_featureCounts[feature] ?? 0) + 1;
  }

  /// Estimates token count based on text length (~4 characters per token).
  static int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return math.max(1, (text.length / 4).ceil());
  }

  /// Returns current snapshot summary of AI metrics.
  AIUsageSummary getSummary() {
    return AIUsageSummary(
      totalRequests: _totalRequests,
      cachedRequests: _cachedRequests,
      totalInputTokens: _totalInputTokens,
      totalOutputTokens: _totalOutputTokens,
      averageLatencyMs: averageLatencyMs,
      estimatedCostUsd: estimatedCostUsd,
      featureBreakdown: Map.from(_featureCounts),
      recordedDate: DateTime.now(),
    );
  }

  /// Clears in-memory tracker state (useful for tests).
  void reset() {
    _totalRequests = 0;
    _cachedRequests = 0;
    _totalInputTokens = 0;
    _totalOutputTokens = 0;
    _latenciesMs.clear();
    _featureCounts.clear();
  }
}
