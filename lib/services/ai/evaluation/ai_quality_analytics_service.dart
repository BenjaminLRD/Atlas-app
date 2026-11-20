import 'ai_response_evaluator.dart';

/// Single telemetry event capturing quality, cost, latency, and user sentiment.
class AIQualityEvent {
  final String id;
  final DateTime timestamp;
  final String query;
  final String response;
  final AIQualityScore qualityScore;
  final String modelUsed;
  final int promptTokens;
  final int completionTokens;
  final int latencyMs;
  final double? userRating;
  final bool isSafetyViolation;
  final bool recommendationAccepted;
  final String category;

  const AIQualityEvent({
    required this.id,
    required this.timestamp,
    required this.query,
    required this.response,
    required this.qualityScore,
    this.modelUsed = 'gemini-1.5-flash',
    this.promptTokens = 250,
    this.completionTokens = 120,
    this.latencyMs = 450,
    this.userRating,
    this.isSafetyViolation = false,
    this.recommendationAccepted = true,
    this.category = 'general',
  });

  int get totalTokens => promptTokens + completionTokens;

  factory AIQualityEvent.fromJson(Map<String, dynamic> json) {
    return AIQualityEvent(
      id:
          json['id']?.toString() ??
          'event_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      query: json['query']?.toString() ?? '',
      response: json['response']?.toString() ?? '',
      qualityScore: json['quality_score'] != null
          ? AIQualityScore.fromJson(
              Map<String, dynamic>.from(json['quality_score'] as Map),
            )
          : const AIQualityScore(
              accuracy: 80,
              personalization: 80,
              safety: 100,
              completeness: 80,
              userSatisfaction: 80,
              overall: 84,
            ),
      modelUsed: json['model_used']?.toString() ?? 'gemini-1.5-flash',
      promptTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 250,
      completionTokens: (json['completion_tokens'] as num?)?.toInt() ?? 120,
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 450,
      userRating: (json['user_rating'] as num?)?.toDouble(),
      isSafetyViolation: json['is_safety_violation'] == true,
      recommendationAccepted: json['recommendation_accepted'] != false,
      category: json['category']?.toString() ?? 'general',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'query': query,
    'response': response,
    'quality_score': qualityScore.toJson(),
    'model_used': modelUsed,
    'prompt_tokens': promptTokens,
    'completion_tokens': completionTokens,
    'total_tokens': totalTokens,
    'latency_ms': latencyMs,
    if (userRating != null) 'user_rating': userRating,
    'is_safety_violation': isSafetyViolation,
    'recommendation_accepted': recommendationAccepted,
    'category': category,
  };
}

/// Central analytics engine tracking AI Coach response quality, token metrics,
/// safety incidents, and recommendation success rates across the platform.
class AIQualityAnalyticsService {
  static AIQualityAnalyticsService? _instance;
  static AIQualityAnalyticsService get instance =>
      _instance ??= AIQualityAnalyticsService();

  static void resetInstance() {
    _instance = null;
  }

  final List<AIQualityEvent> _events = [];
  static const int maxEventsStored = 250;

  AIQualityAnalyticsService();

  /// Logs an evaluated AI interaction event into the quality analytics buffer.
  void logEvent(AIQualityEvent event) {
    if (_events.length >= maxEventsStored) {
      _events.removeAt(0);
    }
    _events.add(event);
  }

  /// Convenience logger accepting raw fields and automatically creating an [AIQualityEvent].
  AIQualityEvent logEvaluation({
    required String query,
    required String response,
    required AIQualityScore qualityScore,
    String modelUsed = 'gemini-1.5-flash',
    int promptTokens = 250,
    int completionTokens = 120,
    int latencyMs = 450,
    double? userRating,
    bool recommendationAccepted = true,
    String category = 'general',
  }) {
    final isViolation = qualityScore.safety < 70;
    final event = AIQualityEvent(
      id: 'ai_qe_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      query: query,
      response: response,
      qualityScore: qualityScore,
      modelUsed: modelUsed,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      latencyMs: latencyMs,
      userRating: userRating,
      isSafetyViolation: isViolation,
      recommendationAccepted: recommendationAccepted,
      category: category,
    );

    logEvent(event);
    return event;
  }

  /// Returns unmodifiable list of all stored events.
  List<AIQualityEvent> get events => List.unmodifiable(_events);

  /// Computes average overall AI quality score across recorded events.
  double getAverageQualityScore() {
    if (_events.isEmpty) return 88.0;
    final total = _events.fold<int>(
      0,
      (sum, e) => sum + e.qualityScore.overall,
    );
    return total / _events.length;
  }

  /// Computes average score across individual quality dimensions.
  Map<String, double> getDimensionAverages() {
    if (_events.isEmpty) {
      return {
        'accuracy': 88.0,
        'personalization': 84.0,
        'safety': 98.0,
        'completeness': 82.0,
        'userSatisfaction': 86.0,
        'overall': 88.0,
      };
    }

    final n = _events.length.toDouble();
    return {
      'accuracy':
          _events.map((e) => e.qualityScore.accuracy).reduce((a, b) => a + b) /
          n,
      'personalization':
          _events
              .map((e) => e.qualityScore.personalization)
              .reduce((a, b) => a + b) /
          n,
      'safety':
          _events.map((e) => e.qualityScore.safety).reduce((a, b) => a + b) / n,
      'completeness':
          _events
              .map((e) => e.qualityScore.completeness)
              .reduce((a, b) => a + b) /
          n,
      'userSatisfaction':
          _events
              .map((e) => e.qualityScore.userSatisfaction)
              .reduce((a, b) => a + b) /
          n,
      'overall':
          _events.map((e) => e.qualityScore.overall).reduce((a, b) => a + b) /
          n,
    };
  }

  /// Computes user recommendation acceptance rate (0.0 to 1.0).
  double getRecommendationSuccessRate() {
    if (_events.isEmpty) return 0.95;
    final accepted = _events.where((e) => e.recommendationAccepted).length;
    return accepted / _events.length;
  }

  /// Returns failed / rejected recommendations for diagnosis and improvement.
  List<AIQualityEvent> getFailedRecommendations() {
    return _events
        .where((e) => !e.recommendationAccepted || e.qualityScore.overall < 70)
        .toList();
  }

  /// Returns safety violations logged by the system.
  List<AIQualityEvent> getSafetyViolations() {
    return _events
        .where((e) => e.isSafetyViolation || e.qualityScore.safety < 70)
        .toList();
  }

  /// Returns top N highest-rated responses.
  List<AIQualityEvent> getMostSuccessfulResponses({int limit = 5}) {
    final sorted = List<AIQualityEvent>.from(
      _events,
    )..sort((a, b) => b.qualityScore.overall.compareTo(a.qualityScore.overall));
    return sorted.take(limit).toList();
  }

  /// Returns recent N events in reverse chronological order.
  List<AIQualityEvent> getRecentEvents({int limit = 10}) {
    return _events.reversed.take(limit).toList();
  }

  /// Aggregates high-level telemetry summary for dashboard reporting.
  Map<String, dynamic> getSummaryMetrics() {
    final totalQueries = _events.length;
    final totalTokens = _events.fold<int>(0, (sum, e) => sum + e.totalTokens);
    final avgLatency = _events.isEmpty
        ? 350.0
        : _events.fold<int>(0, (sum, e) => sum + e.latencyMs) / totalQueries;
    final violations = getSafetyViolations().length;

    // Estimate cost based on $0.075 per 1M input tokens + $0.30 per 1M output tokens (Gemini 1.5 Flash)
    final promptTokens = _events.fold<int>(0, (sum, e) => sum + e.promptTokens);
    final completionTokens = _events.fold<int>(
      0,
      (sum, e) => sum + e.completionTokens,
    );
    final estimatedCost =
        (promptTokens * 0.000000075) + (completionTokens * 0.0000003);

    return {
      'total_evaluations': totalQueries,
      'average_quality_score': double.parse(
        getAverageQualityScore().toStringAsFixed(1),
      ),
      'acceptance_rate': double.parse(
        (getRecommendationSuccessRate() * 100).toStringAsFixed(1),
      ),
      'safety_violations_count': violations,
      'total_tokens_consumed': totalTokens,
      'average_latency_ms': avgLatency.round(),
      'estimated_cost_usd': double.parse(estimatedCost.toStringAsFixed(5)),
      'dimension_averages': getDimensionAverages(),
    };
  }

  /// Clears stored events (used in tests or manual reset).
  void clearEvents() {
    _events.clear();
  }
}
