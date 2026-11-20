import 'dart:math' as math;

/// Types of continuous AI experiments.
enum ExperimentDomain {
  promptEngineering,
  recommendationStrategy,
  coachingStyle,
}

/// A specific variant within an active AI experiment.
class ExperimentArm {
  final String id;
  final String name;
  final Map<String, dynamic> config;
  int trials;
  int successes;
  double cumulativeReward;

  ExperimentArm({
    required this.id,
    required this.name,
    required this.config,
    this.trials = 0,
    this.successes = 0,
    this.cumulativeReward = 0.0,
  });

  double get winRate => trials > 0 ? (successes / trials) * 100.0 : 0.0;
  double get averageReward => trials > 0 ? cumulativeReward / trials : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trials': trials,
    'successes': successes,
    'win_rate': winRate,
    'average_reward': averageReward,
  };
}

/// Autonomous Multi-Armed Bandit Experimentation Engine.
/// Dynamically routes athlete traffic across prompt and coaching variants
/// to maximize long-term engagement, adherence, and satisfaction.
class AIExperimentEngine {
  static AIExperimentEngine? _instance;
  static AIExperimentEngine get instance => _instance ??= AIExperimentEngine();

  static void resetInstance() {
    _instance = null;
  }

  final Map<String, List<ExperimentArm>> _experiments = {};
  double epsilon = 0.15; // 15% exploration, 85% exploitation

  AIExperimentEngine() {
    _seedDefaultExperiments();
  }

  void _seedDefaultExperiments() {
    // 1. Coaching Style Bandit
    _experiments['coaching_style_bandit'] = [
      ExperimentArm(
        id: 'arm_supportive',
        name: 'Empathetic & Supportive',
        config: {'style': 'supportive', 'emoji_density': 'moderate'},
        trials: 42,
        successes: 36,
        cumulativeReward: 33.2,
      ),
      ExperimentArm(
        id: 'arm_technical',
        name: 'Scientific & Physiological',
        config: {'style': 'technical', 'cite_sources': true},
        trials: 38,
        successes: 31,
        cumulativeReward: 29.5,
      ),
      ExperimentArm(
        id: 'arm_direct',
        name: 'Direct & Disciplined',
        config: {'style': 'direct', 'concise': true},
        trials: 25,
        successes: 19,
        cumulativeReward: 17.8,
      ),
    ];

    // 2. Recommendation Strategy Bandit
    _experiments['recommendation_weighting_bandit'] = [
      ExperimentArm(
        id: 'arm_balanced',
        name: 'Balanced 4-Factor Ranking',
        config: {'benefit_weight': 0.35, 'risk_weight': 0.20},
        trials: 50,
        successes: 44,
        cumulativeReward: 41.0,
      ),
      ExperimentArm(
        id: 'arm_safety_first',
        name: 'Safety-Prioritized Ranking',
        config: {'benefit_weight': 0.25, 'risk_weight': 0.35},
        trials: 45,
        successes: 38,
        cumulativeReward: 35.5,
      ),
    ];
  }

  /// Selects an experiment arm using epsilon-greedy exploration/exploitation.
  ExperimentArm selectArm(String experimentId, {String? userId}) {
    final arms = _experiments[experimentId];
    if (arms == null || arms.isEmpty) {
      return ExperimentArm(id: 'default', name: 'Default', config: const {});
    }

    final random = math.Random(
      userId != null ? userId.hashCode : DateTime.now().millisecondsSinceEpoch,
    );

    // Epsilon exploration
    if (random.nextDouble() < epsilon) {
      return arms[random.nextInt(arms.length)];
    }

    // Exploitation (select arm with highest average reward)
    ExperimentArm bestArm = arms.first;
    for (final arm in arms) {
      if (arm.averageReward > bestArm.averageReward) {
        bestArm = arm;
      }
    }
    return bestArm;
  }

  /// Records feedback and reward for a selected arm.
  void recordArmOutcome({
    required String experimentId,
    required String armId,
    required bool success,
    required double rewardScore, // 0.0 to 1.0
  }) {
    final arms = _experiments[experimentId];
    if (arms == null) return;

    final arm = arms.firstWhere((a) => a.id == armId, orElse: () => arms.first);

    arm.trials++;
    if (success) arm.successes++;
    arm.cumulativeReward += rewardScore.clamp(0.0, 1.0);
  }

  /// Returns summary results of all active experiments.
  Map<String, dynamic> getExperimentReports() {
    final report = <String, dynamic>{};
    _experiments.forEach((expId, arms) {
      report[expId] = arms.map((a) => a.toJson()).toList();
    });
    return report;
  }
}
