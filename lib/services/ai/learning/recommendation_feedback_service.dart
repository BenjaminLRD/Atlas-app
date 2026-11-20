/// The athlete's response to an AI-proposed recommendation.
enum UserActionOnRecommendation { accepted, modified, rejected, ignored }

/// Recorded outcome and measured real-world impact of a coaching recommendation.
class RecommendationOutcome {
  final String id;
  final String recommendationId;
  final String category; // 'training', 'nutrition', 'recovery', 'lifestyle'
  final String actionTitle;
  final UserActionOnRecommendation userAction;
  final double
  measuredImpactScore; // 0.0 to 1.0 based on physiological progress
  final String? feedbackNotes;
  final DateTime timestamp;

  const RecommendationOutcome({
    required this.id,
    required this.recommendationId,
    required this.category,
    required this.actionTitle,
    required this.userAction,
    required this.measuredImpactScore,
    this.feedbackNotes,
    required this.timestamp,
  });

  bool get isSuccessful =>
      (userAction == UserActionOnRecommendation.accepted ||
          userAction == UserActionOnRecommendation.modified) &&
      measuredImpactScore >= 0.6;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recommendation_id': recommendationId,
    'category': category,
    'action_title': actionTitle,
    'user_action': userAction.name,
    'measured_impact_score': measuredImpactScore,
    'feedback_notes': feedbackNotes,
    'timestamp': timestamp.toIso8601String(),
    'is_successful': isSuccessful,
  };
}

/// Closed-loop recommendation learning engine.
/// Continuously adapts coaching recommendation confidence weights
/// based on historical athlete adherence and measured physical outcomes.
class RecommendationFeedbackService {
  static RecommendationFeedbackService? _instance;
  static RecommendationFeedbackService get instance =>
      _instance ??= RecommendationFeedbackService();

  static void resetInstance() {
    _instance = null;
  }

  final List<RecommendationOutcome> _outcomes = [];

  List<RecommendationOutcome> get outcomes => List.unmodifiable(_outcomes);

  /// Records an outcome when an athlete interacts with a recommendation.
  RecommendationOutcome recordOutcome({
    required String recommendationId,
    required String category,
    required String actionTitle,
    required UserActionOnRecommendation userAction,
    required double measuredImpactScore,
    String? feedbackNotes,
  }) {
    final outcome = RecommendationOutcome(
      id: 'out_${DateTime.now().millisecondsSinceEpoch}_${_outcomes.length}',
      recommendationId: recommendationId,
      category: category.toLowerCase(),
      actionTitle: actionTitle,
      userAction: userAction,
      measuredImpactScore: measuredImpactScore.clamp(0.0, 1.0),
      feedbackNotes: feedbackNotes,
      timestamp: DateTime.now(),
    );

    _outcomes.add(outcome);
    return outcome;
  }

  /// Computes the historical success rate for a specific recommendation category (0.0 to 100.0).
  double getCategorySuccessRate(String category) {
    final cat = category.toLowerCase();
    final matching = _outcomes.where((o) => o.category == cat).toList();
    if (matching.isEmpty) return 75.0; // Neutral baseline

    final successes = matching.where((o) => o.isSuccessful).length;
    return (successes / matching.length) * 100.0;
  }

  /// Computes overall recommendation adherence rate across all categories.
  double getOverallAdherenceRate() {
    if (_outcomes.isEmpty) return 80.0;
    final accepted = _outcomes
        .where(
          (o) =>
              o.userAction == UserActionOnRecommendation.accepted ||
              o.userAction == UserActionOnRecommendation.modified,
        )
        .length;
    return (accepted / _outcomes.length) * 100.0;
  }

  /// Calculates an adaptive weight multiplier (0.7 to 1.3) for recommendation ranking algorithms.
  double getAdaptiveCategoryMultiplier(String category) {
    final successRate = getCategorySuccessRate(category);
    if (successRate >= 85.0) {
      return 1.25; // Strongly favored
    } else if (successRate >= 70.0) {
      return 1.10;
    } else if (successRate >= 50.0) {
      return 0.95;
    } else {
      return 0.75; // Deprioritized due to past friction
    }
  }
}
