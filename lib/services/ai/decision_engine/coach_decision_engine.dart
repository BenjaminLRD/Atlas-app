import '../../athlete/athlete_state_aggregator.dart';

/// Structured adjustment for training workouts.
class WorkoutAdjustment {
  final String
  type; // 'deload', 'overload', 'intensity_reduction', 'rest_day', 'maintain'
  final String description;
  final double volumeMultiplier;
  final bool recommendRest;
  final List<String> exerciseReplacements;

  const WorkoutAdjustment({
    required this.type,
    required this.description,
    this.volumeMultiplier = 1.0,
    this.recommendRest = false,
    this.exerciseReplacements = const [],
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'description': description,
    'volume_multiplier': volumeMultiplier,
    'recommend_rest': recommendRest,
    'exercise_replacements': exerciseReplacements,
  };
}

/// Structured recommendation for recovery and sleep.
class RecoveryRecommendation {
  final String protocol;
  final double sleepTargetHours;
  final String rationale;

  const RecoveryRecommendation({
    required this.protocol,
    this.sleepTargetHours = 8.0,
    required this.rationale,
  });

  Map<String, dynamic> toJson() => {
    'protocol': protocol,
    'sleep_target_hours': sleepTargetHours,
    'rationale': rationale,
  };
}

/// Structured suggestion for nutrition and caloric intake.
class NutritionSuggestion {
  final String
  type; // 'surplus', 'deficit', 'protein_boost', 'maintenance', 'hydration'
  final int calorieAdjustment;
  final double proteinTargetGrams;
  final String rationale;

  const NutritionSuggestion({
    required this.type,
    this.calorieAdjustment = 0,
    this.proteinTargetGrams = 150.0,
    required this.rationale,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'calorie_adjustment': calorieAdjustment,
    'protein_target_grams': proteinTargetGrams,
    'rationale': rationale,
  };
}

/// Structured behavioral nudge or schedule intervention.
class BehaviorIntervention {
  final String nudge;
  final String optimalWindow;
  final String habitContext;

  const BehaviorIntervention({
    required this.nudge,
    required this.optimalWindow,
    required this.habitContext,
  });

  Map<String, dynamic> toJson() => {
    'nudge': nudge,
    'optimal_window': optimalWindow,
    'habit_context': habitContext,
  };
}

/// Comprehensive output decision report from the [CoachDecisionEngine].
class CoachDecision {
  final List<WorkoutAdjustment> trainingAdjustments;
  final List<RecoveryRecommendation> recoveryRecommendations;
  final List<NutritionSuggestion> nutritionSuggestions;
  final List<BehaviorIntervention> behaviorInterventions;
  final String primaryFocus;
  final String reasoning;
  final String urgency; // 'low', 'medium', 'high', 'critical'
  final double volumeMultiplier;
  final bool recommendRest;
  final DateTime generatedAt;

  const CoachDecision({
    required this.trainingAdjustments,
    required this.recoveryRecommendations,
    required this.nutritionSuggestions,
    required this.behaviorInterventions,
    required this.primaryFocus,
    required this.reasoning,
    this.urgency = 'low',
    this.volumeMultiplier = 1.0,
    this.recommendRest = false,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'training_adjustments': trainingAdjustments.map((e) => e.toJson()).toList(),
    'recovery_recommendations': recoveryRecommendations
        .map((e) => e.toJson())
        .toList(),
    'nutrition_suggestions': nutritionSuggestions
        .map((e) => e.toJson())
        .toList(),
    'behavior_interventions': behaviorInterventions
        .map((e) => e.toJson())
        .toList(),
    'primary_focus': primaryFocus,
    'reasoning': reasoning,
    'urgency': urgency,
    'volume_multiplier': volumeMultiplier,
    'recommend_rest': recommendRest,
    'generated_at': generatedAt.toIso8601String(),
  };
}

/// Central AI Decision Engine analyzing holistic athlete telemetry to determine
/// workout adjustments, recovery protocols, nutritional tweaks, and behavioral interventions.
class CoachDecisionEngine {
  static CoachDecisionEngine? _instance;
  static CoachDecisionEngine get instance =>
      _instance ??= CoachDecisionEngine();

  /// Analyzes an [AthleteStateSnapshot] and outputs an explainable [CoachDecision].
  CoachDecision evaluate(AthleteStateSnapshot state) {
    final trainingAdjustments = <WorkoutAdjustment>[];
    final recoveryRecommendations = <RecoveryRecommendation>[];
    final nutritionSuggestions = <NutritionSuggestion>[];
    final behaviorInterventions = <BehaviorIntervention>[];

    final reasoningList = <String>[];
    String primaryFocus = 'Maintain consistent training and nutrition routine.';
    String urgency = 'low';
    double volumeMultiplier = 1.0;
    bool recommendRest = false;

    // -------------------------------------------------------------------------
    // 1. RECOVERY & PHYSIOLOGICAL READINESS EVALUATION
    // -------------------------------------------------------------------------
    // Recovery rules apply only to recorded data. With no sleep, HRV or
    // heart-rate reading none of them fires and nothing is adjusted.
    final measured = state.recovery.isMeasured;
    final readiness = state.recovery.readinessScore;
    final sleepHours = state.recovery.sleepHours;
    final fatigue = state.recovery.fatigueLevel;
    final sleepText = sleepHours == null
        ? 'sleep not recorded'
        : 'sleep at ${sleepHours.toStringAsFixed(1)}h';

    if (measured &&
        (readiness < 45 ||
            (sleepHours != null && sleepHours < 5.5) ||
            fatigue == 'critical')) {
      recommendRest = true;
      volumeMultiplier = 0.6;
      urgency = 'critical';
      primaryFocus = 'Active Recovery & Central Nervous System Rest';

      final reason =
          'Readiness is critical ($readiness%) with $sleepText. High systemic fatigue requires a rest day or gentle mobility to prevent overtraining.';
      reasoningList.add(reason);

      trainingAdjustments.add(
        WorkoutAdjustment(
          type: 'rest_day',
          description:
              'Substitute heavy compound lifts with active mobility or complete rest.',
          volumeMultiplier: 0.6,
          recommendRest: true,
        ),
      );

      recoveryRecommendations.add(
        RecoveryRecommendation(
          protocol: 'Early bedtime protocol (Aim for 8.5+ hours sleep)',
          sleepTargetHours: 8.5,
          rationale: 'Restore parasympathetic tone and hormonal recovery.',
        ),
      );
    } else if (measured &&
        (readiness < 65 ||
            (sleepHours != null && sleepHours < 6.5) ||
            fatigue == 'high')) {
      volumeMultiplier = 0.8;
      urgency = 'medium';
      primaryFocus = 'Reduced Volume & Fatigue Management';

      final reason =
          'Moderate autonomic readiness ($readiness%) with $sleepText. Reducing training volume by 20% to prevent fatigue accumulation.';
      reasoningList.add(reason);

      trainingAdjustments.add(
        WorkoutAdjustment(
          type: 'intensity_reduction',
          description:
              'Reduce total working sets by 20% and cap intensity at RPE 8.',
          volumeMultiplier: 0.8,
          recommendRest: false,
        ),
      );

      recoveryRecommendations.add(
        RecoveryRecommendation(
          protocol: '15-minute post-workout dynamic stretch & hydration',
          sleepTargetHours: 8.0,
          rationale:
              'Facilitate lactate clearance and reduce muscle stiffness.',
        ),
      );
    } else if (measured &&
        readiness >= 80 &&
        (sleepHours == null || sleepHours >= 7.0)) {
      volumeMultiplier = 1.05;
      urgency = 'low';
      primaryFocus = 'Progressive Overload & Peak Performance';

      final reason =
          'Prime autonomic readiness ($readiness%) with $sleepText. Athlete is physiologically primed for progressive overload.';
      reasoningList.add(reason);

      trainingAdjustments.add(
        WorkoutAdjustment(
          type: 'overload',
          description:
              'Add +2.5kg to primary compound lifts or perform 1 extra rep per set.',
          volumeMultiplier: 1.05,
          recommendRest: false,
        ),
      );

      recoveryRecommendations.add(
        RecoveryRecommendation(
          protocol: 'Standard recovery routine (7.5-8.0h sleep)',
          sleepTargetHours: 8.0,
          rationale: 'Maintain strong autonomic baseline.',
        ),
      );
    } else {
      volumeMultiplier = 1.0;
      urgency = 'low';
      primaryFocus = 'Steady Progression & Form Focus';

      reasoningList.add(
        measured
            ? 'Readiness is stable ($readiness%). Continue standard scheduled training volume.'
            : 'Recovery cannot be assessed: no sleep, HRV or heart-rate data is recorded. Training volume is not adjusted for recovery.',
      );

      trainingAdjustments.add(
        const WorkoutAdjustment(
          type: 'maintain',
          description: 'Execute scheduled workout sets with strict technique.',
          volumeMultiplier: 1.0,
          recommendRest: false,
        ),
      );

      recoveryRecommendations.add(
        const RecoveryRecommendation(
          protocol: 'Standard 7.5h sleep and daily hydration',
          sleepTargetHours: 7.5,
          rationale: 'Support ongoing muscle recovery.',
        ),
      );
    }

    // -------------------------------------------------------------------------
    // 2. TRAINING PROGRESSION & INACTIVITY EVALUATION
    // -------------------------------------------------------------------------
    if (state.workout.daysSinceLastWorkout >= 4 && !recommendRest) {
      reasoningList.add(
        '4+ days since last logged training session. Recommended starting with a thorough warm-up.',
      );
      trainingAdjustments.add(
        const WorkoutAdjustment(
          type: 're-entry',
          description: 'Include 8-minute comprehensive dynamic warm-up.',
          volumeMultiplier: 1.0,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // 3. NUTRITION & ENERGY BALANCE EVALUATION
    // -------------------------------------------------------------------------
    final targetProt = state.nutrition.targetProteinGrams;
    // Null when some food has no protein value: no claim of a shortfall.
    final protDelta = state.nutrition.proteinDelta;
    final goalType = state.goal.primaryGoal.toLowerCase();

    if (protDelta != null && protDelta > 25.0) {
      reasoningList.add(
        'Protein intake is currently behind by ${protDelta.round()}g. Prioritizing protein-dense refueling.',
      );
      nutritionSuggestions.add(
        NutritionSuggestion(
          type: 'protein_boost',
          proteinTargetGrams: targetProt,
          rationale:
              'Hit ${targetProt.round()}g daily target to maximize muscle protein synthesis.',
        ),
      );
    }

    if (goalType.contains('bulk') ||
        goalType.contains('gain') ||
        goalType.contains('hypertrophy')) {
      nutritionSuggestions.add(
        const NutritionSuggestion(
          type: 'surplus',
          calorieAdjustment: 250,
          rationale:
              'Maintain a lean surplus (+250 kcal) to fuel hypertrophy without excessive fat gain.',
        ),
      );
    } else if (goalType.contains('cut') ||
        goalType.contains('loss') ||
        goalType.contains('fat')) {
      nutritionSuggestions.add(
        const NutritionSuggestion(
          type: 'deficit',
          calorieAdjustment: -200,
          rationale:
              'Maintain a moderate deficit (-200 kcal) for lean tissue preservation.',
        ),
      );
    }

    // -------------------------------------------------------------------------
    // 4. BEHAVIOR & CIRCADIAN WINDOW EVALUATION
    // -------------------------------------------------------------------------
    final prefTime = state.behavior.preferredWorkoutTime.toLowerCase();
    String optimalWindow;
    if (prefTime == 'morning') {
      optimalWindow = readiness >= 80 ? '06:30 - 08:30' : '09:00 - 11:00';
    } else if (prefTime == 'afternoon') {
      optimalWindow = '14:00 - 16:30';
    } else {
      optimalWindow = '17:30 - 19:30';
    }

    behaviorInterventions.add(
      BehaviorIntervention(
        nudge:
            'Schedule training during your circadian power window ($optimalWindow).',
        optimalWindow: optimalWindow,
        habitContext:
            'Current consistency: ${state.behavior.consistencyScore.round()}% (${state.behavior.streakDays}-day streak)',
      ),
    );

    final fullReasoning = reasoningList.join(' ');

    return CoachDecision(
      trainingAdjustments: trainingAdjustments,
      recoveryRecommendations: recoveryRecommendations,
      nutritionSuggestions: nutritionSuggestions,
      behaviorInterventions: behaviorInterventions,
      primaryFocus: primaryFocus,
      reasoning: fullReasoning,
      urgency: urgency,
      volumeMultiplier: volumeMultiplier,
      recommendRest: recommendRest,
      generatedAt: DateTime.now(),
    );
  }
}
