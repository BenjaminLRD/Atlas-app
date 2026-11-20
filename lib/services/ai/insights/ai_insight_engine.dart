import '../../../models/health_metrics.dart';
import '../../analytics/workout_analytics_service.dart';
import '../../health/health_service.dart';
import '../../recovery_intelligence_service.dart';
import '../../../data/local_storage.dart';
import '../../nutrition/nutrition_service.dart';
import '../../../data/workout_repository.dart';
import 'insight_model.dart';
import 'insight_rule.dart';

/// Central Proactive AI Coach Intelligence Engine.
/// Synthesizes multi-domain fitness telemetry into actionable coaching insights and daily briefs.
class AIInsightEngine {
  final HealthService _healthService;
  final RecoveryIntelligenceService _recoveryService;
  final NutritionService _nutritionService;
  final WorkoutRepository _workoutRepository;
  final WorkoutAnalyticsService _analyticsService;
  final List<InsightRule> _rules;

  final Set<String> _dismissedInsightIds = {};

  AIInsightEngine({
    HealthService? healthService,
    RecoveryIntelligenceService? recoveryService,
    NutritionService? nutritionService,
    WorkoutRepository? workoutRepository,
    WorkoutAnalyticsService? analyticsService,
    List<InsightRule>? rules,
  }) : _healthService = healthService ?? HealthService.instance,
       _recoveryService =
           recoveryService ?? RecoveryIntelligenceService.instance,
       _nutritionService = nutritionService ?? NutritionService(),
       _workoutRepository = workoutRepository ?? LocalWorkoutRepository(),
       _analyticsService = analyticsService ?? WorkoutAnalyticsService.instance,
       _rules =
           rules ??
           const [
             RecoveryInsightRule(),
             NutritionInsightRule(),
             TrainingInsightRule(),
           ];

  /// Dismisses an insight by ID so it is not shown again in active lists.
  void dismissInsight(String insightId) {
    _dismissedInsightIds.add(insightId);
  }

  /// Clears dismissed insights memory.
  void clearDismissedInsights() {
    _dismissedInsightIds.clear();
  }

  /// Evaluates all domain rules and returns sorted proactive insights.
  Future<List<CoachInsight>> generateInsights({DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();
    final context = await _buildInsightContext(now);

    final allInsights = <CoachInsight>[];
    for (final rule in _rules) {
      final results = await rule.evaluate(context);
      allInsights.addAll(results);
    }

    // Filter out dismissed insights
    final active = allInsights
        .where((i) => !_dismissedInsightIds.contains(i.id))
        .toList();

    // Sort by priority (critical first) and then by timestamp
    active.sort((a, b) {
      final priorityComp = b.priority.level.compareTo(a.priority.level);
      if (priorityComp != 0) return priorityComp;
      return b.timestamp.compareTo(a.timestamp);
    });

    return active;
  }

  /// Compiles a holistic morning / daily overview brief for the athlete.
  Future<DailyCoachBrief> generateDailyBrief({
    String? athleteName,
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final context = await _buildInsightContext(now);
    final insights = await generateInsights(nowOverride: now);

    final name = athleteName ?? context.userProfile?.name;
    final displayName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : 'Athlete';

    // Greeting according to time of day
    String greetingTime = 'Good morning';
    if (now.hour >= 12 && now.hour < 17) {
      greetingTime = 'Good afternoon';
    } else if (now.hour >= 17) {
      greetingTime = 'Good evening';
    }
    final greeting = '$greetingTime, $displayName.';

    // Readiness evaluation
    // A score and tier only when recorded data backs them.
    final measured = context.recoveryMeasured;
    final int? score = measured ? context.recoveryScore.round() : null;
    final tier = score == null
        ? 'Readiness unavailable'
        : (score >= 80
              ? 'Optimal Readiness'
              : (score >= 60 ? 'Moderate Readiness' : 'Low Readiness'));

    // Planned workout determination
    final split = context.userProfile?.fitnessGoal ?? 'Push Hypertrophy';
    final plannedWorkout = '$split Session';

    // Remaining macros
    final targetProtein = context.dailyNutrition.targets.proteinGrams > 0
        ? context.dailyNutrition.targets.proteinGrams
        : 150.0;
    // Null when some food logged today has no value: what is left is unknown.
    final remainingProtein = context.dailyNutrition.proteinRemaining(
      targetProtein,
    );

    final targetCals = context.dailyNutrition.targets.calories > 0
        ? context.dailyNutrition.targets.calories
        : 2400.0;
    final remainingCals = context.dailyNutrition.caloriesRemainingTo(
      targetCals,
    );

    // Synthesis of key recommendation
    String keySuggestion;
    if (measured && (score! < 50 || context.isDeloadRecommended)) {
      keySuggestion =
          'High systemic fatigue detected. Prioritize active recovery and light mobility today.';
    } else if (remainingProtein != null && remainingProtein > 45.0) {
      keySuggestion =
          'Focus on high-protein meal timing to hit your daily ${targetProtein.round()}g muscle target.';
    } else if (remainingProtein == null && (score == null || score < 85)) {
      // No claim about protein: some logged food has no protein value.
      keySuggestion =
          'Some logged foods have no protein value, so your protein total is incomplete. Add the missing values to track your target.';
    } else if (score != null && score >= 85) {
      keySuggestion =
          'Recovery is peaked! Great day to challenge progressive overload on main compound lifts.';
    } else {
      keySuggestion =
          'Maintain consistent training intensity, stay hydrated, and log all meals.';
    }

    return DailyCoachBrief(
      greeting: greeting,
      recoveryScore: score,
      readinessTier: tier,
      plannedWorkout: plannedWorkout,
      remainingProteinGrams: remainingProtein == null
          ? null
          : double.parse(remainingProtein.toStringAsFixed(1)),
      remainingCalories: remainingCals == null
          ? null
          : double.parse(remainingCals.toStringAsFixed(1)),
      keySuggestion: keySuggestion,
      topInsights: insights.take(3).toList(),
      generatedAt: now,
    );
  }

  Future<InsightContext> _buildInsightContext(DateTime now) async {
    final todayHealth = await _healthService.getTodayHealthMetric();
    final workouts = _workoutRepository.getWorkoutHistory();
    final dailyNutrition = _nutritionService.getDailyNutritionWithLogged();
    final weightGoal = LocalStorage.getWeightGoal();
    final userProfile = LocalStorage.getUserProfile();

    // The recovery state comes from workouts only. A step count is not a
    // recovery signal and no score is made up from it.
    final recoveryState = _recoveryService.analyzeRecoveryState(
      healthMetrics: HealthMetrics.fromUnified(todayHealth),
      workouts: workouts,
    );

    final volumeAnalytics = _analyticsService.calculateVolume(workouts, now);
    final consistencyAnalytics = _analyticsService.calculateConsistency(
      workouts,
      3,
      now,
    );
    final prSummary = _analyticsService.calculatePersonalRecords(workouts);

    return InsightContext(
      todayHealth: todayHealth,
      recoveryScore: recoveryState.recoveryScore.toDouble(),
      recoveryMeasured: recoveryState.isMeasured,
      isDeloadRecommended:
          recoveryState.isMeasured && recoveryState.isDeloadRecommended,
      dailyNutrition: dailyNutrition,
      weightGoal: weightGoal,
      userProfile: userProfile,
      workoutHistory: workouts,
      volumeAnalytics: volumeAnalytics,
      consistencyAnalytics: consistencyAnalytics,
      personalRecords: prSummary,
      now: now,
    );
  }
}
