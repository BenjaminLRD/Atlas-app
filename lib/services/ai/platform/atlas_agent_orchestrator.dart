import '../../../models/fitness_context.dart';

/// Autonomous specialized coaching agent domain.
enum AgentDomain {
  trainingAgent('Training & Volume Agent'),
  nutritionAgent('Metabolism & Nutrition Agent'),
  recoveryAgent('Physiological Recovery Agent'),
  behaviorAgent('Habit & Consistency Agent');

  final String label;
  const AgentDomain(this.label);
}

/// Standalone proposal emitted by a single specialized domain agent.
class AgentOpinion {
  final AgentDomain domain;
  final String proposal;
  final double confidence; // 0.0 to 1.0
  final int urgencyLevel; // 1 to 10
  final String reasoning;

  const AgentOpinion({
    required this.domain,
    required this.proposal,
    required this.confidence,
    required this.urgencyLevel,
    required this.reasoning,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain.name,
    'proposal': proposal,
    'confidence': confidence,
    'urgency': urgencyLevel,
    'reasoning': reasoning,
  };
}

/// Unified decision synthesized from multi-agent deliberation.
class MultiAgentConsensus {
  final String unifiedAction;
  final List<AgentOpinion> agentOpinions;
  final double consensusConfidence;
  final List<String> compromisesResolved;
  final DateTime consensusTimestamp;

  const MultiAgentConsensus({
    required this.unifiedAction,
    required this.agentOpinions,
    required this.consensusConfidence,
    required this.compromisesResolved,
    required this.consensusTimestamp,
  });

  Map<String, dynamic> toJson() => {
    'unified_action': unifiedAction,
    'opinions': agentOpinions.map((o) => o.toJson()).toList(),
    'consensus_confidence': consensusConfidence,
    'compromises': compromisesResolved,
    'timestamp': consensusTimestamp.toIso8601String(),
  };
}

/// Multi-Agent AI Coaching Orchestrator.
/// Facilitates distributed deliberation between specialized Training, Nutrition,
/// Recovery, and Behavioral agents to synthesize balanced athlete decisions.
class AtlasAgentOrchestrator {
  static AtlasAgentOrchestrator? _instance;
  static AtlasAgentOrchestrator get instance =>
      _instance ??= AtlasAgentOrchestrator();

  static void resetInstance() {
    _instance = null;
  }

  /// Deliberates across all 4 domain agents and produces a unified consensus.
  MultiAgentConsensus reachConsensus({required FitnessContext context}) {
    final recovery = context.recoveryState?.recoveryScore ?? 80;
    final isRecoveryCritical = recovery < 55;

    // 1. Training Agent Assessment
    final trainingOpinion = AgentOpinion(
      domain: AgentDomain.trainingAgent,
      proposal: isRecoveryCritical
          ? 'Reduce scheduled volume by 40% and cap intensity at 3 RIR.'
          : 'Execute scheduled Upper Hypertrophy with progressive overload (+2.5kg).',
      confidence: 0.92,
      urgencyLevel: isRecoveryCritical ? 8 : 6,
      reasoning: isRecoveryCritical
          ? 'Systemic readiness score is low; prevent neuromuscular overreaching.'
          : 'Athlete progressive overload curve is on track.',
    );

    // 2. Nutrition Agent Assessment
    final nutritionOpinion = AgentOpinion(
      domain: AgentDomain.nutritionAgent,
      proposal: isRecoveryCritical
          ? 'Increase dietary carbohydrates by +40g to expedite glycogen restoration.'
          : 'Maintain 175g protein target and 2600 kcal clean surplus.',
      confidence: 0.95,
      urgencyLevel: isRecoveryCritical ? 7 : 5,
      reasoning: 'Nutrient timing aligned with recovery demand.',
    );

    // 3. Recovery Agent Assessment
    final recoveryOpinion = AgentOpinion(
      domain: AgentDomain.recoveryAgent,
      proposal: isRecoveryCritical
          ? 'Veto high-intensity session; prescribe 20min mobility + early 8h sleep window.'
          : 'Readiness optimal. Cleared for maximum intensity.',
      confidence: 0.98,
      urgencyLevel: isRecoveryCritical ? 9 : 3,
      reasoning:
          'Autonomic nervous system strain evaluated from sleep and heart rate.',
    );

    // 4. Behavior Agent Assessment
    final behaviorOpinion = AgentOpinion(
      domain: AgentDomain.behaviorAgent,
      proposal:
          'Maintain gym habit momentum even if session is light mobility.',
      confidence: 0.88,
      urgencyLevel: 6,
      reasoning:
          'Adherence streak preservation is vital for long-term consistency.',
    );

    final opinions = [
      trainingOpinion,
      nutritionOpinion,
      recoveryOpinion,
      behaviorOpinion,
    ];
    final compromises = <String>[];
    String finalAction = '';

    if (isRecoveryCritical) {
      compromises.add(
        'Recovery Agent urgency (9/10) overrode standard Training Agent volume.',
      );
      compromises.add(
        'Behavior Agent satisfied by substituting light mobility instead of total gym absence.',
      );
      finalAction =
          'Autonomous Pivot: Switch to 30-min Light Mobility & Parasympathetic Recovery Session. '
          'Increase carbohydrate intake by 40g and target 8h sleep tonight.';
    } else {
      finalAction =
          'All Agents Aligned: Proceed with scheduled High-Intensity Hypertrophy session. '
          'Target 175g protein and standard 2,600 kcal target.';
    }

    return MultiAgentConsensus(
      unifiedAction: finalAction,
      agentOpinions: opinions,
      consensusConfidence: 0.94,
      compromisesResolved: compromises,
      consensusTimestamp: DateTime.now(),
    );
  }
}
