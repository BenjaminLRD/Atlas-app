import '../../../models/fitness_context.dart';
import '../../../models/user_goal.dart';
import '../../athlete/athlete_state_aggregator.dart';
import '../../knowledge/rag_service.dart';
import '../../multimodal/multimodal_input_service.dart';
import '../../multimodal/sensor_fusion_engine.dart';
import '../memory/fitness_memory.dart';

/// Communication tone & pedagogical style of the AI Coach.
enum CoachStyle { supportive, technical, direct, concise }

/// Dynamic, modular prompt compiler synthesizing individualized AI instructions
/// based on athlete goal, training age, psychological style, recovery state, and learned memory.
class AdaptivePromptBuilder {
  const AdaptivePromptBuilder();

  static const AdaptivePromptBuilder instance = AdaptivePromptBuilder();

  /// Compiles a fully individualized system persona prompt.
  String buildAdaptiveSystemPrompt({
    required FitnessContext context,
    AthleteStateSnapshot? stateSnapshot,
    CoachStyle? styleOverride,
    String? currentQuery,
    RAGContext? ragContextOverride,
    bool enableRAG = true,
    MultimodalInputPayload? multimodalPayload,
    UnifiedAthleteState? unifiedState,
  }) {
    final buffer = StringBuffer();

    // 1. Core Identity & Autonomous Persona
    buffer.writeln(
      'YOU ARE ATLAS: The World-Class Autonomous AI Fitness Coach & Sports Scientist.',
    );
    buffer.writeln(
      'Your coaching is grounded in exercise physiology, progressive overload, energy balance, and autonomic recovery.',
    );

    // 2. Athlete Goal Calibration
    final goalType = context.userGoal?.goalType ?? FitnessGoalType.muscleGain;
    final level = context.userGoal?.fitnessLevel ?? FitnessLevel.intermediate;
    buffer.writeln('\n[ATHLETE PROFILE & TARGET OBJECTIVE]');
    buffer.writeln('Primary Goal: ${goalType.name.toUpperCase()}');
    buffer.writeln('Experience Level: ${level.name.toUpperCase()}');
    if (context.userGoal != null) {
      buffer.writeln(
        'Target Calories: ${context.userGoal!.targetCalories.round()} kcal | Protein: ${context.userGoal!.targetProtein.round()}g',
      );
      buffer.writeln(
        'Current Weight: ${context.userGoal!.currentWeight}kg -> Target: ${context.userGoal!.targetWeight}kg',
      );
    }

    // 3. Dynamic Coach Style & Tone Modulation
    final coachStyle = styleOverride ?? _detectCoachStyle(context);
    buffer.writeln('\n[COMMUNICATION STYLE DIRECTIVE]');
    switch (coachStyle) {
      case CoachStyle.technical:
        buffer.writeln(
          'Tone: Analytical, scientific, precise. Cite physiological mechanisms (RPE, motor unit recruitment, MPS, glycogen repletion).',
        );
        break;
      case CoachStyle.direct:
        buffer.writeln(
          'Tone: Direct, disciplined, authoritative. Hold the athlete accountable with firm, energetic guidance.',
        );
        break;
      case CoachStyle.concise:
        buffer.writeln(
          'Tone: Ultra-concise gym cues. Use bullet points and exact numbers (sets, reps, rest seconds). Zero fluff.',
        );
        break;
      case CoachStyle.supportive:
        buffer.writeln(
          'Tone: Encouraging, empathetic, positive. Reinforce consistency, celebrate wins, and reduce friction.',
        );
        break;
    }

    // 4. Evidence-Based Knowledge Context (RAG)
    if (enableRAG && currentQuery != null && currentQuery.trim().isNotEmpty) {
      final rag =
          ragContextOverride ??
          RAGService.instance.retrieveContext(
            query: currentQuery,
            context: context,
            stateSnapshot: stateSnapshot,
          );
      final kbBlock = rag.formatKnowledgeBlock();
      if (kbBlock.isNotEmpty) {
        buffer.writeln('\n$kbBlock');
      }
    }

    // 5. Physiological Recovery State Integration
    if (stateSnapshot != null) {
      buffer.writeln('\n${stateSnapshot.toPromptContext()}');
      if (stateSnapshot.recovery.isDeloadRecommended ||
          stateSnapshot.overallReadinessTier == 'critical') {
        buffer.writeln(
          'CRITICAL COACHING RULE: Athlete is severely fatigued. Prescribe reduced volume (-20% to -40%) or active recovery.',
        );
      } else if (stateSnapshot.overallReadinessTier == 'optimal') {
        buffer.writeln(
          'COACHING DIRECTIVE: Peak physiological readiness. Encourage heavy progressive overload and high intensity.',
        );
      }
    } else if (context.recoveryState != null) {
      buffer.writeln('\n[RECOVERY STATE]');
      buffer.writeln(
        'Recovery Score: ${context.recoveryState!.recoveryScore}/100 | Fatigue: ${context.recoveryState!.fatigueLevel.name}',
      );
    }

    // 6. Multimodal Athlete State Integration
    if (multimodalPayload != null || unifiedState != null) {
      buffer.writeln('\n[MULTIMODAL ATHLETE STATE]');
      if (multimodalPayload?.activeExerciseName != null) {
        buffer.writeln(
          'Active Exercise: ${multimodalPayload!.activeExerciseName}',
        );
      }
      if (multimodalPayload?.currentWeightKg != null ||
          multimodalPayload?.currentReps != null) {
        buffer.writeln(
          'Active Set Load: ${multimodalPayload?.currentWeightKg ?? "--"}kg x ${multimodalPayload?.currentReps ?? "--"} reps',
        );
      }
      if (unifiedState != null) {
        buffer.writeln(
          'Real-Time Heart Rate: ${unifiedState.currentHeartRateBpm.round()} bpm (${unifiedState.cardioZone.label})',
        );
        buffer.writeln(
          'Physiological Strain Index: ${unifiedState.physiologicalStrainIndex}/10.0 | Estimated RPE: ${unifiedState.realTimeRPE}',
        );
        buffer.writeln(
          'Velocity Loss: ${unifiedState.velocityLossPercentage.toStringAsFixed(1)}% | Recommended Rest: ${unifiedState.recommendedRestSeconds}s',
        );
      }
    }

    // 7. Long-Term Memory & Learned User Corrections
    final relevantMemories = currentQuery != null && currentQuery.isNotEmpty
        ? FitnessMemory.instance.formatMemoriesForPrompt(currentQuery)
        : '';
    if (relevantMemories.isNotEmpty) {
      buffer.writeln('\n$relevantMemories');
    }

    // 8. Safety & Clinical Non-Medical Guardrails
    buffer.writeln('\n[MANDATORY SAFETY GUARDRAILS]');
    buffer.writeln(
      '1. NEVER provide medical diagnoses or prescribe medications.',
    );
    buffer.writeln(
      '2. If user reports sharp joint/chest pain, advise consulting a physician immediately.',
    );
    buffer.writeln(
      '3. Never recommend volume load jumps exceeding 50% in a single session.',
    );
    buffer.writeln(
      '4. Always explain the "why" behind significant training or nutritional adjustments.',
    );

    return buffer.toString();
  }

  /// Builds a focused, token-optimized task prompt for a specific user turn.
  String buildTaskPrompt({
    required String userMessage,
    required FitnessContext context,
    AthleteStateSnapshot? stateSnapshot,
    CoachStyle? style,
    MultimodalInputPayload? multimodalPayload,
    UnifiedAthleteState? unifiedState,
  }) {
    final systemPrompt = buildAdaptiveSystemPrompt(
      context: context,
      stateSnapshot: stateSnapshot,
      styleOverride: style,
      currentQuery: userMessage,
      multimodalPayload: multimodalPayload,
      unifiedState: unifiedState,
    );

    return '$systemPrompt\n\n[ATHLETE MESSAGE]\n$userMessage\n\n[COACH RESPONSE]';
  }

  /// Detects the athlete's preferred coaching persona from memory or defaults to supportive.
  CoachStyle _detectCoachStyle(FitnessContext context) {
    final prefProfile = FitnessMemory.instance.getPreferenceProfile();
    final pref = prefProfile.coachPersonalityPreference.toLowerCase();

    if (pref.contains('technical') || pref.contains('scientific')) {
      return CoachStyle.technical;
    }
    if (pref.contains('direct') ||
        pref.contains('tough') ||
        pref.contains('hardcore')) {
      return CoachStyle.direct;
    }
    if (pref.contains('concise') ||
        pref.contains('short') ||
        pref.contains('quick')) {
      return CoachStyle.concise;
    }
    return CoachStyle.supportive;
  }
}
