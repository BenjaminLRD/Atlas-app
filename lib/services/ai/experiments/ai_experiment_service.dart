/// Categorized types of AI experiments.
enum AIExperimentType {
  promptVariant, // Tests different system prompt framings and directives
  responseStyle, // Tests concise vs scientific vs motivational response tone
  recommendationStrategy, // Tests conservative vs progressive volume/calorie pacing
}

/// Single variant in an active A/B/n experiment.
class ExperimentVariant {
  final String id;
  final String name;
  final Map<String, dynamic> config;
  int impressions;
  int acceptances;
  double totalQualityScore;

  ExperimentVariant({
    required this.id,
    required this.name,
    required this.config,
    this.impressions = 0,
    this.acceptances = 0,
    this.totalQualityScore = 0.0,
  });

  double get acceptanceRate =>
      impressions > 0 ? (acceptances / impressions) : 0.0;

  double get averageQualityScore =>
      impressions > 0 ? (totalQualityScore / impressions) : 0.0;

  factory ExperimentVariant.fromJson(Map<String, dynamic> json) {
    return ExperimentVariant(
      id: json['id']?.toString() ?? 'v_control',
      name: json['name']?.toString() ?? 'Control',
      config: (json['config'] as Map<String, dynamic>?) ?? const {},
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      acceptances: (json['acceptances'] as num?)?.toInt() ?? 0,
      totalQualityScore:
          (json['total_quality_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'config': config,
    'impressions': impressions,
    'acceptances': acceptances,
    'acceptance_rate': double.parse(acceptanceRate.toStringAsFixed(3)),
    'average_quality_score': double.parse(
      averageQualityScore.toStringAsFixed(1),
    ),
  };
}

/// Domain model representing an AI A/B experiment.
class AIExperiment {
  final String id;
  final String name;
  final String description;
  final AIExperimentType type;
  final bool isActive;
  final List<ExperimentVariant> variants;
  final DateTime startDate;
  String? winningVariantId;

  AIExperiment({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.isActive = true,
    required this.variants,
    required this.startDate,
    this.winningVariantId,
  });

  int get totalImpressions =>
      variants.fold<int>(0, (sum, v) => sum + v.impressions);

  factory AIExperiment.fromJson(Map<String, dynamic> json) {
    final rawVars = json['variants'] as List<dynamic>? ?? [];
    return AIExperiment(
      id:
          json['id']?.toString() ??
          'exp_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: AIExperimentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AIExperimentType.promptVariant,
      ),
      isActive: json['is_active'] != false,
      variants: rawVars
          .map(
            (e) =>
                ExperimentVariant.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      winningVariantId: json['winning_variant_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'is_active': isActive,
    'variants': variants.map((v) => v.toJson()).toList(),
    'start_date': startDate.toIso8601String(),
    'winning_variant_id': winningVariantId,
    'total_impressions': totalImpressions,
  };
}

/// AI Experiment Framework managing prompt experiments, response style variations,
/// and recommendation strategies to systematically test and scale coaching performance.
class AIExperimentService {
  static AIExperimentService? _instance;
  static AIExperimentService get instance =>
      _instance ??= AIExperimentService._internal();

  static void resetInstance() {
    _instance = null;
  }

  final Map<String, AIExperiment> _experiments = {};

  AIExperimentService._internal() {
    _initDefaultExperiments();
  }

  void _initDefaultExperiments() {
    // 1. Response Style Experiment
    final expStyle = AIExperiment(
      id: 'exp_response_style_01',
      name: 'Concise Gym Cues vs Scientific Depth',
      description:
          'Tests whether bulleted rapid cues outperform long-form scientific explanations.',
      type: AIExperimentType.responseStyle,
      isActive: true,
      startDate: DateTime.now().subtract(const Duration(days: 7)),
      variants: [
        ExperimentVariant(
          id: 'v_concise',
          name: 'Concise Bulleted Cues',
          config: {'style': 'concise', 'max_tokens': 150},
          impressions: 48,
          acceptances: 44,
          totalQualityScore: 4320.0,
        ),
        ExperimentVariant(
          id: 'v_scientific',
          name: 'Scientific Mechanism Depth',
          config: {'style': 'technical', 'max_tokens': 350},
          impressions: 52,
          acceptances: 43,
          totalQualityScore: 4420.0,
        ),
      ],
    );

    // 2. Prompt Directive Experiment
    final expPrompt = AIExperiment(
      id: 'exp_prompt_framing_02',
      name: 'Accountability vs Encouragement Framing',
      description:
          'Evaluates athlete retention when AI uses direct tough-love vs empathetic reinforcement.',
      type: AIExperimentType.promptVariant,
      isActive: true,
      startDate: DateTime.now().subtract(const Duration(days: 3)),
      variants: [
        ExperimentVariant(
          id: 'v_accountability',
          name: 'Direct Accountability',
          config: {'persona': 'direct'},
          impressions: 30,
          acceptances: 26,
          totalQualityScore: 2640.0,
        ),
        ExperimentVariant(
          id: 'v_supportive',
          name: 'Supportive Momentum',
          config: {'persona': 'supportive'},
          impressions: 32,
          acceptances: 30,
          totalQualityScore: 2880.0,
        ),
      ],
    );

    _experiments[expStyle.id] = expStyle;
    _experiments[expPrompt.id] = expPrompt;
  }

  /// Registers a new AI experiment.
  void registerExperiment(AIExperiment experiment) {
    _experiments[experiment.id] = experiment;
  }

  /// Returns list of all active experiments.
  List<AIExperiment> getActiveExperiments() {
    return _experiments.values.where((e) => e.isActive).toList();
  }

  /// Retrieves an experiment by its unique ID.
  AIExperiment? getExperiment(String id) => _experiments[id];

  /// Assigns a deterministic variant to a user session based on hash modulo.
  ExperimentVariant? assignVariant({
    required String experimentId,
    required String userId,
  }) {
    final exp = _experiments[experimentId];
    if (exp == null || !exp.isActive || exp.variants.isEmpty) return null;

    final hash = userId.hashCode.abs();
    final index = hash % exp.variants.length;
    final variant = exp.variants[index];
    variant.impressions++;
    return variant;
  }

  /// Records an outcome (acceptance and quality score) for a given experiment variant.
  void recordOutcome({
    required String experimentId,
    required String variantId,
    bool accepted = true,
    double qualityScore = 85.0,
  }) {
    final exp = _experiments[experimentId];
    if (exp == null) return;

    final variant = exp.variants.firstWhere(
      (v) => v.id == variantId,
      orElse: () => exp.variants.first,
    );

    if (accepted) {
      variant.acceptances++;
    }
    variant.totalQualityScore += qualityScore;
  }

  /// Computes performance comparison and statistical leader between variants.
  Map<String, dynamic> getExperimentResults(String experimentId) {
    final exp = _experiments[experimentId];
    if (exp == null) return {};

    ExperimentVariant? leader;
    double highestScore = -1.0;

    for (final v in exp.variants) {
      if (v.impressions > 0 && v.averageQualityScore > highestScore) {
        highestScore = v.averageQualityScore;
        leader = v;
      }
    }

    return {
      'experiment_id': exp.id,
      'experiment_name': exp.name,
      'total_impressions': exp.totalImpressions,
      'leader_variant_id': leader?.id,
      'leader_variant_name': leader?.name,
      'variants': exp.variants.map((v) => v.toJson()).toList(),
    };
  }

  /// Declares a permanent winning variant and completes the experiment.
  void declareWinner(String experimentId, String variantId) {
    final exp = _experiments[experimentId];
    if (exp != null) {
      exp.winningVariantId = variantId;
    }
  }
}
