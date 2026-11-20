import '../../athlete/athlete_state_aggregator.dart';

/// Candidate action proposed by AI agents or decision engines before ranking.
class CandidateAction {
  final String id;
  final String title;
  final String category; // 'training', 'nutrition', 'recovery', 'habit'
  final String description;
  final double expectedBenefit; // 0.0 to 1.0 (physiological or habit yield)
  final double adherenceProbability; // 0.0 to 1.0 (likelihood athlete adheres)
  final double riskScore; // 0.0 to 1.0 (injury, fatigue, or friction risk)
  final double baseConfidence; // 0.0 to 1.0 (algorithmic certainty)
  final Map<String, dynamic> payload;

  const CandidateAction({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.expectedBenefit,
    required this.adherenceProbability,
    required this.riskScore,
    required this.baseConfidence,
    this.payload = const {},
  });

  factory CandidateAction.fromJson(Map<String, dynamic> json) {
    return CandidateAction(
      id:
          json['id']?.toString() ??
          'action_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'training',
      description: json['description']?.toString() ?? '',
      expectedBenefit: (json['expected_benefit'] as num?)?.toDouble() ?? 0.8,
      adherenceProbability:
          (json['adherence_probability'] as num?)?.toDouble() ?? 0.85,
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.1,
      baseConfidence: (json['base_confidence'] as num?)?.toDouble() ?? 0.9,
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'description': description,
    'expected_benefit': expectedBenefit,
    'adherence_probability': adherenceProbability,
    'risk_score': riskScore,
    'base_confidence': baseConfidence,
    'payload': payload,
  };
}

/// Final scored and ranked recommendation ready for presentation to the athlete.
class RankedRecommendation {
  final CandidateAction action;
  final int rank; // 1 (highest priority) to N
  final double compositeScore; // 0.0 to 1.0
  final int confidencePercentage; // 0 to 100% (e.g. 91%)
  final String reasoning;

  const RankedRecommendation({
    required this.action,
    required this.rank,
    required this.compositeScore,
    required this.confidencePercentage,
    required this.reasoning,
  });

  String get title => action.title;
  String get category => action.category;
  String get description => action.description;

  factory RankedRecommendation.fromJson(Map<String, dynamic> json) {
    return RankedRecommendation(
      action: CandidateAction.fromJson(
        Map<String, dynamic>.from(json['action'] as Map),
      ),
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      compositeScore: (json['composite_score'] as num?)?.toDouble() ?? 0.85,
      confidencePercentage:
          (json['confidence_percentage'] as num?)?.toInt() ?? 85,
      reasoning: json['reasoning']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'action': action.toJson(),
    'rank': rank,
    'composite_score': compositeScore,
    'confidence_percentage': confidencePercentage,
    'reasoning': reasoning,
  };
}

/// Recommendation Ranking Engine applying multi-criteria decision analysis (MCDA)
/// to prioritize coaching recommendations by expected benefit, adherence, risk, and confidence.
class RecommendationRankingService {
  static RecommendationRankingService? _instance;
  static RecommendationRankingService get instance =>
      _instance ??= RecommendationRankingService();

  static void resetInstance() {
    _instance = null;
  }

  RecommendationRankingService();

  /// Ranks candidate coaching actions in relation to athlete state snapshot.
  List<RankedRecommendation> rankRecommendations({
    required List<CandidateAction> candidates,
    required AthleteStateSnapshot state,
  }) {
    if (candidates.isEmpty) return const [];

    final scored = <MapEntry<CandidateAction, Map<String, dynamic>>>[];

    for (final candidate in candidates) {
      double benefit = candidate.expectedBenefit;
      double adherence = candidate.adherenceProbability;
      double risk = candidate.riskScore;
      double confidence = candidate.baseConfidence;

      // State Context Adjustments
      final isFatigued =
          state.overallReadinessTier == 'fatigued' ||
          state.overallReadinessTier == 'critical' ||
          state.recovery.isDeloadRecommended;

      if (isFatigued) {
        if (candidate.category == 'recovery' ||
            candidate.title.toLowerCase().contains('rest')) {
          benefit = (benefit * 1.3).clamp(0.0, 1.0);
          risk = (risk * 0.5).clamp(0.0, 1.0);
          confidence = (confidence * 1.1).clamp(0.0, 1.0);
        } else if (candidate.category == 'training' &&
            candidate.title.toLowerCase().contains('heavy')) {
          risk = (risk * 1.8).clamp(0.0, 1.0);
          benefit = (benefit * 0.7).clamp(0.0, 1.0);
        }
      }

      // Adherence modulation from athlete consistency
      final consistencyFraction = (state.behavior.consistencyScore / 100.0)
          .clamp(0.5, 1.0);
      adherence = (adherence * consistencyFraction).clamp(0.0, 1.0);

      // Multi-Criteria Weighted Scoring:
      // Benefit: 35%, Adherence: 25%, Risk Inversion: 20%, Confidence: 20%
      final riskInversion = (1.0 - risk).clamp(0.0, 1.0);
      final compositeScore =
          (0.35 * benefit) +
          (0.25 * adherence) +
          (0.20 * riskInversion) +
          (0.20 * confidence);

      final confidencePct = (confidence * 100).round().clamp(50, 99);

      String reasoning;
      if (isFatigued && candidate.category == 'recovery') {
        reasoning =
            'Prioritized due to elevated systemic fatigue (${state.recovery.readinessScore}/100 readiness). High recovery yield with minimal injury risk.';
      } else if (compositeScore >= 0.85) {
        reasoning =
            'Optimal alignment with current goal (${state.goal.primaryGoal}) and high historical adherence probability (${(adherence * 100).round()}%).';
      } else {
        reasoning =
            'Balanced recommendation providing positive training stimulus with controlled fatigue load.';
      }

      scored.add(
        MapEntry(candidate, {
          'composite': compositeScore,
          'confidencePct': confidencePct,
          'reasoning': reasoning,
        }),
      );
    }

    // Sort descending by composite score
    scored.sort(
      (a, b) => (b.value['composite'] as double).compareTo(
        a.value['composite'] as double,
      ),
    );

    final results = <RankedRecommendation>[];
    for (int i = 0; i < scored.length; i++) {
      final entry = scored[i];
      results.add(
        RankedRecommendation(
          action: entry.key,
          rank: i + 1,
          compositeScore: double.parse(
            (entry.value['composite'] as double).toStringAsFixed(3),
          ),
          confidencePercentage: entry.value['confidencePct'] as int,
          reasoning: entry.value['reasoning'] as String,
        ),
      );
    }

    return results;
  }
}
