import '../athlete/athlete_state_aggregator.dart';
import 'action_planner/coach_action_planner.dart';
import 'decision_engine/coach_decision_engine.dart';

/// Structured morning summary report produced by [DailyCoachBriefingService].
class DailyBriefingReport {
  final DateTime date;
  final String greeting;

  /// Null when readiness is not measured (no sleep, HRV or heart-rate data).
  final int? recoveryScore;
  final String readinessTier;

  /// Null when no sleep is recorded.
  final double? sleepHours;
  final String workoutRecommendation;
  final String nutritionTarget;
  final String mainFocus;
  final String proactiveMessage;
  final List<PlannedCoachAction> actions;

  const DailyBriefingReport({
    required this.date,
    required this.greeting,
    required this.recoveryScore,
    required this.readinessTier,
    required this.sleepHours,
    required this.workoutRecommendation,
    required this.nutritionTarget,
    required this.mainFocus,
    required this.proactiveMessage,
    required this.actions,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'greeting': greeting,
    if (recoveryScore != null) 'recovery_score': recoveryScore,
    'readiness_tier': readinessTier,
    if (sleepHours != null) 'sleep_hours': sleepHours,
    'workout_recommendation': workoutRecommendation,
    'nutrition_target': nutritionTarget,
    'main_focus': mainFocus,
    'proactive_message': proactiveMessage,
    'actions': actions.map((a) => a.toJson()).toList(),
  };
}

/// Autonomous Daily AI Coach Briefing Service delivering morning athlete summaries,
/// readiness assessments, workout recommendations, nutrition targets, and main focus directives.
class DailyCoachBriefingService {
  static DailyCoachBriefingService? _instance;
  static DailyCoachBriefingService get instance =>
      _instance ??= DailyCoachBriefingService();

  final AthleteStateAggregator _aggregator;
  final CoachDecisionEngine _decisionEngine;
  final CoachActionPlanner _actionPlanner;

  DailyCoachBriefingService({
    AthleteStateAggregator? aggregator,
    CoachDecisionEngine? decisionEngine,
    CoachActionPlanner? actionPlanner,
  }) : _aggregator = aggregator ?? AthleteStateAggregator.instance,
       _decisionEngine = decisionEngine ?? CoachDecisionEngine.instance,
       _actionPlanner = actionPlanner ?? CoachActionPlanner.instance;

  /// Generates a comprehensive [DailyBriefingReport] for an athlete.
  DailyBriefingReport generateBriefing({
    required String userId,
    AthleteStateSnapshot? stateSnapshot,
    String? athleteName,
    DateTime? date,
  }) {
    final now = date ?? DateTime.now();
    final snapshot =
        stateSnapshot ??
        _aggregator.aggregateSnapshot(userId: userId, timestamp: now);
    final decision = _decisionEngine.evaluate(snapshot);
    final actions = _actionPlanner.planActions(
      state: snapshot,
      decision: decision,
    );

    // 1. GREETING
    final name = (athleteName != null && athleteName.trim().isNotEmpty)
        ? athleteName.trim()
        : 'Athlete';
    final timeGreeting = _getTimeGreeting(now.hour);
    final greeting = '$timeGreeting, $name.';

    // 2. RECOVERY & READINESS
    final int? recScore = snapshot.recovery.isMeasured
        ? snapshot.recovery.readinessScore
        : null;
    final readinessTier = snapshot.overallReadinessTier;
    final double? sleepHours = snapshot.recovery.sleepHours;

    // 3. WORKOUT RECOMMENDATION
    String workoutRec;
    if (decision.recommendRest) {
      workoutRec =
          'Active Recovery & Mobility Flow (15-20 mins) — Systemic fatigue management';
    } else {
      final intensityTag = decision.volumeMultiplier > 1.0
          ? 'Peak Intensity (Overload +2.5kg)'
          : (decision.volumeMultiplier < 1.0
                ? 'Reduced Volume (${((1.0 - decision.volumeMultiplier) * 100).round()}% deload)'
                : 'Standard Intensity');
      final lastSplit = snapshot.workout.lastWorkoutName.isNotEmpty
          ? snapshot.workout.lastWorkoutName
          : 'Full Body Split';
      workoutRec = '$lastSplit Training Session — $intensityTag';
    }

    // 4. NUTRITION TARGET
    final targetCal = snapshot.nutrition.targetCalories;
    final targetProt = snapshot.nutrition.targetProteinGrams.round();
    final surplusOrDeficit =
        decision.nutritionSuggestions.any((s) => s.type == 'surplus')
        ? ' (+250 kcal lean surplus)'
        : (decision.nutritionSuggestions.any((s) => s.type == 'deficit')
              ? ' (-200 kcal lean cut)'
              : '');
    final nutritionTarget =
        '$targetCal kcal | ${targetProt}g Protein$surplusOrDeficit';

    // 5. MAIN FOCUS
    final mainFocus = decision.primaryFocus;

    // 6. PROACTIVE NARRATIVE MESSAGE
    final proactiveMessage = _buildProactiveNarrative(
      greeting: greeting,
      recoveryScore: recScore,
      sleepHours: sleepHours,
      readinessTier: readinessTier,
      workoutRecommendation: workoutRec,
      nutritionTarget: nutritionTarget,
      mainFocus: mainFocus,
      reasoning: decision.reasoning,
    );

    return DailyBriefingReport(
      date: now,
      greeting: greeting,
      recoveryScore: recScore,
      readinessTier: readinessTier,
      sleepHours: sleepHours,
      workoutRecommendation: workoutRec,
      nutritionTarget: nutritionTarget,
      mainFocus: mainFocus,
      proactiveMessage: proactiveMessage,
      actions: actions,
    );
  }

  String _getTimeGreeting(int hour) {
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Hello';
  }

  String _buildProactiveNarrative({
    required String greeting,
    required int? recoveryScore,
    required double? sleepHours,
    required String readinessTier,
    required String workoutRecommendation,
    required String nutritionTarget,
    required String mainFocus,
    required String reasoning,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(greeting);
    final sleepText = sleepHours == null
        ? 'Sleep is not recorded.'
        : 'You slept ${sleepHours.toStringAsFixed(1)} hours.';
    buffer.writeln(
      recoveryScore == null
          ? 'Readiness is unavailable: no sleep, HRV or heart-rate data is recorded. $sleepText'
          : 'Your autonomic readiness score is $recoveryScore% (${readinessTier.toUpperCase()}). $sleepText',
    );
    buffer.writeln();
    buffer.writeln('🎯 Today\'s Focus: $mainFocus');
    buffer.writeln('🏋️ Workout: $workoutRecommendation');
    buffer.writeln('🥩 Nutrition: $nutritionTarget');
    buffer.writeln();
    buffer.writeln('Coach Rationale: $reasoning');
    return buffer.toString();
  }
}
