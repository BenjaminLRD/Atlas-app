import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/nutrition_totals.dart';
import 'package:atlas/models/recovery_summary.dart';
import 'package:atlas/models/weight_goal.dart';
import 'package:atlas/models/workout_recommendation.dart';
import 'package:atlas/services/ai/action_planner/coach_action_planner.dart';
import 'package:atlas/services/ai/coach_notification_engine.dart';
import 'package:atlas/services/ai/coach_notification_service.dart';
import 'package:atlas/services/ai/daily_brief_service.dart';
import 'package:atlas/services/ai/decision_engine/coach_decision_engine.dart';
import 'package:atlas/services/ai/insights/ai_insight_engine.dart';
import 'package:atlas/services/ai/insights/insight_model.dart';
import 'package:atlas/services/ai/insights/insight_rule.dart';
import 'package:atlas/services/ai/weekly_athlete_review_service.dart';
import 'package:atlas/services/ai/weekly_coach_review_service.dart';
import 'package:atlas/services/analytics/workout_analytics_service.dart';
import 'package:atlas/services/athlete/athlete_state_aggregator.dart';
import 'package:atlas/services/health/health_service.dart';
import 'package:atlas/services/ml/ml_feature_engineering_service.dart';
import 'package:atlas/services/nutrition/weekly_nutrition_stats.dart';
import 'package:atlas/services/nutrition/weight_goal_status.dart';
import 'package:atlas/services/nutrition_analytics_service.dart';
import 'package:atlas/services/recommendation_service.dart';
import 'package:atlas/services/recovery/health_prediction_engine.dart';
import 'package:atlas/services/recovery/recovery_prediction_engine.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/widgets/nutrition_analytics/calorie_trend_card.dart';
import 'package:atlas/widgets/nutrition_analytics/macro_distribution_chart.dart';
import 'package:atlas/widgets/nutrition_analytics/nutrition_insight_section.dart';
import 'package:atlas/widgets/nutrition_analytics/nutrition_summary_card.dart';
import 'package:atlas/widgets/nutrition_analytics/protein_performance_card.dart';

/// Every consumer of nutrition values must treat a food with an unknown value
/// as unknown: a total from such foods is a minimum, so it may prove a target
/// was reached but never that intake is low, and it is never fed to a model
/// or a rule as if it were exact.

const _targets = MacroTarget(
  calories: 2200,
  proteinGrams: 150,
  carbsGrams: 250,
  fatGrams: 70,
);

String _today() => DateTime.now().toIso8601String().split('T')[0];

String _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day - n,
  ).toIso8601String().split('T')[0];
}

/// A day with [protein] g and [calories] kcal counted from foods, of which
/// [unknownProtein] / [unknownCalories] foods had no value.
DailyNutrition _day({
  double protein = 0,
  double calories = 0,
  int unknownProtein = 0,
  int unknownCalories = 0,
  int items = 1,
  String? date,
}) => DailyNutrition(date: date ?? _today(), targets: _targets, meals: const [])
    .withLogged(
      NutritionTotals(
        calories: calories,
        protein: protein,
        unknownProteinItems: unknownProtein,
        unknownCalorieItems: unknownCalories,
        itemCount: items,
      ),
    );

// --- foods ---------------------------------------------------------------

/// 130 kcal, protein unknown.
const _noProtein = FoodItem(
  id: 'np',
  name: 'Plain Rice',
  calories: 130,
  carbohydrates: 28,
  fats: 2,
  isPackaged: true,
  barcode: '2',
  unknownNutrients: {FoodItem.proteinKey},
);

/// Calories and protein both unknown.
const _noEnergy = FoodItem(
  id: 'ne',
  name: 'Mystery Bar',
  calories: 0,
  carbohydrates: 20,
  fats: 3,
  isPackaged: true,
  barcode: '4',
  unknownNutrients: {FoodItem.calorieKey, FoodItem.proteinKey},
);

/// 2,000 kcal and 200 g protein, all known.
const _bigMeal = FoodItem(
  id: 'big',
  name: 'Big Meal',
  calories: 2000,
  protein: 200,
  carbohydrates: 100,
  fats: 50,
);

MealEntry _meal(List<FoodItem> foods) => MealEntry(
  id: 'm',
  mealType: MealCategory.lunch,
  consumedFoods: [for (final f in foods) ConsumedFood(food: f)],
);

NutritionLog _log(List<FoodItem> foods, {String? date}) => NutritionLog(
  id: 'log_${date ?? _today()}',
  date: DateTime.parse(date ?? _today()),
  meals: [_meal(foods)],
  calorieGoal: 2200,
  proteinGoal: 150,
);

// --- agent state ---------------------------------------------------------

AthleteStateSnapshot _snapshot({required NutritionStateSummary nutrition}) =>
    AthleteStateSnapshot(
      userId: 'u',
      timestamp: DateTime.now(),
      overallReadinessTier: 'optimal',
      workout: const WorkoutStateSummary(),
      nutrition: nutrition,
      recovery: const RecoveryStateSummary(readinessScore: 80, sleepHours: 8),
      health: const HealthStateSummary(),
      behavior: const BehaviorStateSummary(),
      goal: const GoalStateSummary(primaryGoal: 'general'),
    );

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    HealthService.resetInstance();
    AppDependencies.useMock();
  });

  group('completeness and what is left', () {
    test('a total is complete only when no food lacks the value', () {
      const complete = NutritionTotals(
        calories: 500,
        protein: 30,
        itemCount: 2,
      );
      const partial = NutritionTotals(
        calories: 500,
        protein: 30,
        unknownProteinItems: 1,
        itemCount: 2,
      );
      expect(complete.proteinComplete, isTrue);
      expect(complete.hasUnknownValues, isFalse);
      expect(partial.proteinComplete, isFalse);
      expect(partial.caloriesComplete, isTrue);
      expect(partial.hasUnknownValues, isTrue);
    });

    test('what is left is unknown, not the shown figure, when incomplete', () {
      const partial = NutritionTotals(
        calories: 500,
        protein: 30,
        unknownProteinItems: 1,
        unknownCalorieItems: 1,
        itemCount: 2,
      );
      expect(partial.proteinRemaining(150), isNull);
      expect(partial.caloriesRemaining(2200), isNull);
      const complete = NutritionTotals(
        calories: 500,
        protein: 30,
        itemCount: 1,
      );
      expect(complete.proteinRemaining(150), 120);
      expect(complete.caloriesRemaining(2200), 1700);
      expect(complete.proteinRemaining(20), 0);
    });

    test('a day with nothing logged is complete (zero is not unknown)', () {
      final empty = _day(items: 0);
      expect(empty.proteinRemaining(150), 150);
    });
  });

  group('recovery engine', () {
    const engine = RecoveryPredictionEngine();
    List<String> risks(DailyNutrition nutrition) => engine
        .analyzeReadiness(
          userId: 'u',
          workoutHistory: const [],
          todayNutrition: nutrition,
          referenceDate: DateTime(2026, 10, 25, 8),
        )
        .riskFactors;

    test('a complete low intake is under-fueling', () {
      expect(
        risks(_day(protein: 20, calories: 800)),
        contains(startsWith('Under-fueling')),
      );
    });

    test('the same low figures from foods with unknown values are not', () {
      expect(
        risks(
          _day(
            protein: 20,
            calories: 800,
            unknownProtein: 1,
            unknownCalories: 1,
          ),
        ),
        isNot(contains(startsWith('Under-fueling'))),
      );
    });

    test(
      'a complete low calorie total still counts when protein is unknown',
      () {
        expect(
          risks(_day(protein: 90, calories: 800, unknownProtein: 1)),
          contains(startsWith('Under-fueling')),
        );
      },
    );

    test('a minimum already high enough is not penalised', () {
      expect(
        risks(
          _day(
            protein: 120,
            calories: 1900,
            unknownProtein: 1,
            unknownCalories: 1,
          ),
        ),
        isNot(contains(startsWith('Under-fueling'))),
      );
    });
  });

  group('ML inputs use an explicit missing-value rule', () {
    test('protein feature: no data and unknown are the neutral value', () {
      expect(HealthPredictionEngine.proteinFeature(null), 100);
      expect(
        HealthPredictionEngine.proteinFeature(
          _day(protein: 0, unknownProtein: 1),
        ),
        HealthPredictionEngine.neutralProteinGrams,
      );
      expect(
        HealthPredictionEngine.proteinFeature(
          _day(protein: 40, unknownProtein: 1),
        ),
        100,
      );
    });

    test('protein feature: a known value is kept, a high minimum too', () {
      expect(HealthPredictionEngine.proteinFeature(_day(protein: 80)), 80);
      expect(HealthPredictionEngine.proteinFeature(_day(protein: 0)), 0);
      expect(
        HealthPredictionEngine.proteinFeature(
          _day(protein: 130, unknownProtein: 1),
        ),
        130,
      );
    });

    test('adherence: no log or no complete part is the neutral value', () {
      expect(
        MLFeatureEngineeringService.nutritionAdherenceOf(null),
        MLFeatureEngineeringService.neutralNutritionAdherence,
      );
      expect(
        MLFeatureEngineeringService.nutritionAdherenceOf(_log([_noEnergy])),
        MLFeatureEngineeringService.neutralNutritionAdherence,
      );
    });

    test('adherence: unknown protein is left out, not read as 0 g', () {
      final log = _log([_noProtein]);
      final calorieOnly = 1.0 - (1.0 - (log.dailyCalories / 2200)).abs();
      final adherence = MLFeatureEngineeringService.nutritionAdherenceOf(log);
      expect(adherence, closeTo(calorieOnly, 1e-9));
      // Reading the missing protein as 0 g would have halved it.
      final asZero =
          (calorieOnly + (1.0 - (1.0 - 0.0).abs())) / 2.0; // protein 0 g
      expect(adherence, isNot(closeTo(asZero, 1e-6)));
    });

    test('adherence: complete data uses both parts as before', () {
      final log = _log([_bigMeal]);
      final cal = 1.0 - (1.0 - (2000 / 2200)).abs();
      final prot = 1.0 - (1.0 - (200 / 150).clamp(0.0, 1.5)).abs();
      expect(
        MLFeatureEngineeringService.nutritionAdherenceOf(log),
        closeTo((cal + prot) / 2, 1e-9),
      );
    });
  });

  group('insight rules', () {
    InsightContext context(DailyNutrition nutrition, {WeightGoal? goal}) =>
        InsightContext(
          todayHealth: HealthMetric.sample(),
          recoveryScore: 85,
          isDeloadRecommended: false,
          dailyNutrition: nutrition,
          workoutHistory: const [],
          volumeAnalytics: VolumeAnalytics.zero(),
          consistencyAnalytics: ConsistencyAnalytics.zero(),
          personalRecords: PersonalRecordSummary.zero(),
          weightGoal: goal,
          now: DateTime(2026, 10, 25, 9),
        );

    WeightGoal cutGoal() => WeightGoal(
      id: 'g',
      userId: 'u',
      currentWeight: 80,
      targetWeight: 75,
      targetWeeks: 10,
      type: WeightGoalType.lose,
      diet: DietPreference.noRestrictions,
      mealsPerDay: MealFrequency.fourMeals,
      dailyCalorieTarget: 2000,
      proteinGrams: 150,
      carbsGrams: 200,
      fatGrams: 60,
      expectedWeeklyRateKg: 0.5,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

    test('the protein reminder fires on a complete shortfall', () async {
      final insights = await const NutritionInsightRule().evaluate(
        context(_day(protein: 40)),
      );
      expect(
        insights.any((i) => i.type == InsightType.proteinReminder),
        isTrue,
      );
    });

    test('no protein reminder when some food has no protein value', () async {
      final insights = await const NutritionInsightRule().evaluate(
        context(_day(protein: 40, unknownProtein: 1)),
      );
      expect(
        insights.any((i) => i.type == InsightType.proteinReminder),
        isFalse,
      );
    });

    test(
      'a calorie surplus from a minimum is reported as "at least"',
      () async {
        final insights = await const NutritionInsightRule().evaluate(
          context(
            _day(calories: 2800, unknownCalories: 1, protein: 150),
            goal: cutGoal(),
          ),
        );
        final alert = insights.singleWhere(
          (i) => i.type == InsightType.calorieAdjustment,
        );
        expect(alert.message, contains('at least 800 kcal above'));
      },
    );

    test('an exact calorie surplus is stated plainly', () async {
      final insights = await const NutritionInsightRule().evaluate(
        context(_day(calories: 2800, protein: 150), goal: cutGoal()),
      );
      final alert = insights.singleWhere(
        (i) => i.type == InsightType.calorieAdjustment,
      );
      expect(alert.message, contains('is 800 kcal above'));
      expect(alert.message, isNot(contains('at least')));
    });
  });

  group('daily coach brief', () {
    Future<DailyCoachBrief> briefFor(List<FoodItem> foods) async {
      await LocalStorage.saveNutritionLog(_log(foods));
      return AIInsightEngine().generateDailyBrief(athleteName: 'Sam');
    }

    test(
      'what is left is null when a logged food has no protein value',
      () async {
        final brief = await briefFor([_noProtein]);
        expect(brief.remainingProteinGrams, isNull);
        expect(brief.remainingCalories, isNotNull);
        expect(brief.keySuggestion, isNot(contains('hit your daily')));
      },
    );

    test('calories left are null when a food has no calorie value', () async {
      final brief = await briefFor([_noEnergy]);
      expect(brief.remainingCalories, isNull);
      expect(brief.remainingProteinGrams, isNull);
    });

    test('with all values known what is left is a number', () async {
      final brief = await briefFor([_bigMeal]);
      expect(brief.remainingProteinGrams, 0);
      expect(brief.remainingCalories, isNotNull);
    });

    test('a brief saved without those figures keeps them unknown', () {
      const json = {
        'greeting': 'Hi',
        'recoveryScore': 70,
        'readinessTier': 'Moderate Readiness',
        'plannedWorkout': 'Push',
        'keySuggestion': 'x',
        'generatedAt': '2026-10-25T08:00:00.000',
      };
      final brief = DailyCoachBrief.fromJson(json);
      expect(brief.remainingProteinGrams, isNull);
      expect(brief.remainingCalories, isNull);
      expect(brief.toJson().containsKey('remainingProteinGrams'), isFalse);
    });
  });

  group('smart notifications', () {
    List<CoachSmartNotification> notifications(DailyNutrition nutrition) =>
        CoachNotificationService().generateDailyNotifications(
          recovery: const RecoverySummary(recoveryScore: 80, sleepHours: 8),
          workout: const WorkoutRecommendation(
            id: 'w1',
            workoutTitle: 'Push Day',
            splitType: 'Push',
            isRestDay: false,
          ),
          todayNutrition: nutrition,
          maxNotificationsPerDay: 5,
        );

    test('a complete protein shortfall reminds', () {
      expect(
        notifications(_day(protein: 60)).any((n) => n.category == 'nutrition'),
        isTrue,
      );
    });

    test('an incomplete protein total does not', () {
      expect(
        notifications(
          _day(protein: 60, unknownProtein: 1),
        ).any((n) => n.category == 'nutrition'),
        isFalse,
      );
    });
  });

  group('athlete state and the coach engines', () {
    NutritionStateSummary nutrition({required bool proteinComplete}) =>
        NutritionStateSummary(
          proteinGramsConsumed: 60,
          targetProteinGrams: 160,
          proteinComplete: proteinComplete,
        );

    test('the aggregator records that totals are minimums', () {
      final snapshot = AthleteStateAggregator.instance.aggregateSnapshot(
        userId: 'u',
        workoutHistory: const [],
        todayNutrition: _day(
          protein: 60,
          calories: 900,
          unknownProtein: 1,
          unknownCalories: 1,
        ),
      );
      expect(snapshot.nutrition.proteinComplete, isFalse);
      expect(snapshot.nutrition.caloriesComplete, isFalse);
      expect(snapshot.nutrition.proteinDelta, isNull);
      final json = snapshot.nutrition.toJson();
      expect(json['protein_complete'], false);
      expect(NutritionStateSummary.fromJson(json).proteinComplete, isFalse);
    });

    test(
      'complete totals leave the flags off the JSON and the delta known',
      () {
        final n = nutrition(proteinComplete: true);
        expect(n.proteinDelta, 100);
        expect(n.toJson().containsKey('protein_complete'), isFalse);
        expect(
          NutritionStateSummary.fromJson(n.toJson()).proteinComplete,
          isTrue,
        );
      },
    );

    test('the decision engine only calls protein low on a complete total', () {
      final complete = CoachDecisionEngine.instance.evaluate(
        _snapshot(nutrition: nutrition(proteinComplete: true)),
      );
      final partial = CoachDecisionEngine.instance.evaluate(
        _snapshot(nutrition: nutrition(proteinComplete: false)),
      );
      expect(complete.reasoning, contains('behind by 100g'));
      expect(partial.reasoning, isNot(contains('behind')));
      expect(
        partial.nutritionSuggestions.any((s) => s.type == 'protein_boost'),
        isFalse,
      );
    });

    test('the action planner does not rank an unknown shortfall as high', () {
      PlannedCoachAction meal(bool complete) {
        final snapshot = _snapshot(
          nutrition: nutrition(proteinComplete: complete),
        );
        final decision = CoachDecisionEngine.instance.evaluate(snapshot);
        return CoachActionPlanner.instance
            .planActions(state: snapshot, decision: decision)
            .firstWhere((a) => a.type == 'suggest_meal');
      }

      expect(meal(true).priority, 'high');
      final partial = meal(false);
      expect(partial.priority, 'medium');
      expect(partial.payload.containsKey('protein_delta_g'), isFalse);
      expect(partial.payload['protein_total_incomplete'], isTrue);
    });

    test('the proactive notifications skip an unknown protein shortfall', () {
      bool hasNutrition(bool complete) => CoachNotificationEngine.instance
          .generateNotifications(
            state: _snapshot(nutrition: nutrition(proteinComplete: complete)),
            maxPerDay: 10,
          )
          .any((n) => n.route == '/nutrition');
      expect(hasNutrition(true), isTrue);
      expect(hasNutrition(false), isFalse);
    });
  });

  group('weekly reviews leave unknown days out instead of using 0', () {
    // 200 g protein clears 85% of the 150 g target; 20 g does not.
    final complete = _day(protein: 200, calories: 2400, date: _today());
    final incomplete = _day(
      protein: 0,
      calories: 500,
      unknownProtein: 1,
      unknownCalories: 1,
      date: _daysAgo(1),
    );

    test('stats: averages and rates use complete days only', () {
      final stats = WeeklyNutritionStats.from([complete, incomplete]);
      expect(stats.days, 2);
      expect(stats.averageCalories, 2400);
      expect(stats.proteinHitPercent, 100);
      expect(stats.calorieDaysExcluded, 1);
      expect(stats.excludedNote, contains('1 day without complete calories'));
    });

    test('stats: no complete day gives no figure, not 0', () {
      final stats = WeeklyNutritionStats.from([incomplete]);
      expect(stats.averageCalories, isNull);
      expect(stats.proteinHitPercent, isNull);
    });

    test('athlete report: the unknown day does not lower the rates', () {
      final report = WeeklyAthleteReviewService.instance.generateReport(
        userId: 'u',
        nutritionHistory: [complete, incomplete],
      );
      expect(report.averageDailyCalories, 2400);
      expect(report.proteinAdherencePercentage, 100);
    });

    test('athlete report: with no complete day protein is not graded', () {
      final report = WeeklyAthleteReviewService.instance.generateReport(
        userId: 'u',
        nutritionHistory: [incomplete],
      );
      expect(report.summaryText, contains('could not be checked'));
      expect(
        report.growthAreas.any((g) => g.contains('Protein could not be')),
        isTrue,
      );
      expect(
        report.growthAreas.any((g) => g.contains('Protein target missed')),
        isFalse,
      );
    });

    test(
      'coach review: figures come from complete days and say what was left out',
      () {
        final review = WeeklyCoachReviewService.instance.generateReview(
          workoutHistory: const [],
          nutritionHistory: [complete, incomplete],
          healthMetrics: const [],
          currentRecovery: const RecoverySummary(
            recoveryScore: 80,
            sleepHours: 8,
          ),
        );
        expect(review.averageDailyCalories, 2400);
        expect(review.proteinConsistencyPercentage, 100);
        expect(review.nutritionSummary, contains('Left out of the figures'));
      },
    );

    test('coach review: nothing known says so and gives no protein advice', () {
      final review = WeeklyCoachReviewService.instance.generateReview(
        workoutHistory: const [],
        nutritionHistory: [incomplete],
        healthMetrics: const [],
        currentRecovery: const RecoverySummary(
          recoveryScore: 80,
          sleepHours: 8,
        ),
      );
      expect(review.nutritionSummary, contains('could not be averaged'));
      expect(review.nutritionSummary, contains('cannot be checked'));
      expect(
        review.actionItems.any((a) => a.contains('protein pacing')),
        isFalse,
      );
    });

    test('a day whose only foods are unknown still counts as logged', () async {
      await LocalStorage.saveNutritionLog(_log([_noEnergy]));
      final history = LocalStorage.getNutritionHistory();
      expect(history, hasLength(1));
      expect(history.single.totalsConsumed.hasUnknownValues, isTrue);
    });
  });

  group('weekly analytics summary', () {
    const service = NutritionAnalyticsService();

    test('averages and rates use complete days, the total is a minimum', () {
      final complete = _log([_bigMeal], date: _today());
      final partial = _log([_noProtein], date: _daysAgo(1));
      expect(complete.dailyProtein, 200);
      final s = service.calculateSummary([complete, partial]);

      expect(s.daysCounted, 2);
      expect(s.unknownProteinDays, 1);
      expect(s.unknownCalorieDays, 0);
      expect(s.proteinKnown, isTrue);
      expect(s.averageProtein, 200);
      expect(s.proteinGoalHitPercentage, 100);
      // Old behaviour: (200 + 0) / 2 = 100 g and a 50% hit rate.
      expect(s.totalCaloriesConsumed, 2000 + partial.dailyCalories);
    });

    test('no complete protein day: no average or rate is claimed', () {
      final s = service.calculateSummary([
        _log([_noProtein]),
      ]);
      expect(s.proteinKnown, isFalse);
      expect(s.unknownProteinDays, 1);
      expect(s.macroBalanceKnown, isFalse);
    });

    test('weekly calories mark a day that is only a minimum', () {
      final s = service.calculateSummary([
        _log([_bigMeal], date: _daysAgo(1)),
        _log([_noEnergy], date: _today()),
      ]);
      expect(s.weeklyCaloriesPartial[6], isTrue); // today
      expect(s.weeklyCaloriesPartial[5], isFalse); // yesterday
      expect(s.unknownCalorieDays, 1);
      expect(s.caloriesKnown, isTrue);
    });

    test('macro split needs a day with protein, carbs and fat all known', () {
      final onlyPartial = service.calculateSummary([
        _log([_noProtein]),
      ]);
      expect(onlyPartial.macroBalanceKnown, isFalse);
      final withFull = service.calculateSummary([
        _log([_noProtein], date: _daysAgo(1)),
        _log([_bigMeal]),
      ]);
      expect(withFull.macroBalanceKnown, isTrue);
      expect(withFull.unknownMacroDays, 1);
    });

    test('the new fields round-trip and an older summary reads as known', () {
      final s = service.calculateSummary([
        _log([_bigMeal], date: _today()),
        _log([_noProtein], date: _daysAgo(1)),
      ]);
      final back = NutritionSummary.fromJson(s.toJson());
      expect(back, s);
      final legacy = NutritionSummary.fromJson({
        'averageProtein': 120.0,
        'proteinGoalHitPercentage': 60.0,
      });
      expect(legacy.proteinKnown, isTrue);
      expect(legacy.caloriesKnown, isTrue);
      expect(legacy.macroBalanceKnown, isTrue);
      expect(legacy.toJson().containsKey('daysCounted'), isFalse);
    });
  });

  group('analytics screens', () {
    const noProteinDays = NutritionSummary(
      totalCaloriesConsumed: 130,
      averageDailyCalories: 130,
      daysCounted: 1,
      unknownProteinDays: 1,
      unknownMacroDays: 1,
      weeklyCaloriesPartial: [false, false, false, false, false, false, false],
    );

    testWidgets('protein card shows a dash and says why, not 0%', (t) async {
      await t.pumpWidget(
        _host(const ProteinPerformanceCard(summary: noProteinDays)),
      );
      expect(find.text('0%'), findsNothing);
      expect(find.text('—'), findsWidgets);
      expect(find.byKey(const Key('protein_unknown_note')), findsOneWidget);
    });

    testWidgets('protein card keeps its numbers when days are complete', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          const ProteinPerformanceCard(
            summary: NutritionSummary(
              averageProtein: 140,
              proteinGoalHitPercentage: 60,
              daysCounted: 3,
            ),
          ),
        ),
      );
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('140g avg'), findsOneWidget);
      expect(find.byKey(const Key('protein_unknown_note')), findsNothing);
    });

    testWidgets('insights do not call protein low when it is unknown', (
      t,
    ) async {
      await t.pumpWidget(
        _host(const NutritionInsightSection(summary: noProteinDays)),
      );
      expect(find.text('Protein Total Incomplete'), findsOneWidget);
      expect(find.text('Protein Intake Boost Required'), findsNothing);
    });

    testWidgets('macro split is not drawn from the default when unknown', (
      t,
    ) async {
      await t.pumpWidget(
        _host(const MacroDistributionChart(summary: noProteinDays)),
      );
      expect(find.byKey(const Key('macro_balance_unknown')), findsOneWidget);
      expect(find.textContaining('Tap segment'), findsNothing);
    });

    testWidgets('calorie trend marks a minimum day with a plus', (t) async {
      await t.pumpWidget(
        _host(
          const CalorieTrendCard(
            summary: NutritionSummary(
              weeklyCalories: [0, 0, 0, 0, 0, 2000, 900],
              weeklyCaloriesPartial: [
                false,
                false,
                false,
                false,
                false,
                false,
                true,
              ],
              averageDailyCalories: 2000,
              daysCounted: 2,
              unknownCalorieDays: 1,
            ),
          ),
        ),
      );
      expect(find.text('900+'), findsOneWidget);
      expect(find.text('2000'), findsOneWidget);
    });

    testWidgets('the calories card shows a plus for a minimum total', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          const NutritionSummaryCard(
            summary: NutritionSummary(
              totalCaloriesConsumed: 1500,
              averageDailyCalories: 1500,
              daysCounted: 2,
              unknownCalorieDays: 1,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('1500+'), findsOneWidget);
    });

    testWidgets('the calories card shows a dash, not 0, when unknown', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          const NutritionSummaryCard(
            summary: NutritionSummary(
              averageDailyCalories: 0,
              daysCounted: 2,
              unknownCalorieDays: 2,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('recommendations and briefs built from the summary', () {
    FitnessContext contextWith(NutritionSummary summary) =>
        FitnessContext.initial().copyWith(nutritionSummary: summary);

    const unknownProtein = NutritionSummary(
      proteinGoalHitPercentage: 0,
      daysCounted: 3,
      unknownProteinDays: 3,
    );
    const lowProtein = NutritionSummary(
      proteinGoalHitPercentage: 20,
      daysCounted: 3,
    );

    test('a low hit rate recommends protein only when it is known', () {
      bool recommends(NutritionSummary s) => const RecommendationService()
          .evaluateContext(contextWith(s))
          .any((r) => r.id == 'rec_nutrition_protein_boost');
      expect(recommends(lowProtein), isTrue);
      expect(recommends(unknownProtein), isFalse);
    });

    test('the daily brief does not claim a protein hit rate it lacks', () {
      final brief = DailyBriefService().generateBrief(
        contextWith(
          const NutritionSummary(
            proteinGoalHitPercentage: 95,
            daysCounted: 3,
            unknownProteinDays: 3,
          ),
        ),
      );
      expect(brief.headline, isNot('Nutritional Targets On Track!'));
      expect(
        brief.items.any((i) => i.title == 'Optimal Protein Adherence'),
        isFalse,
      );
    });
  });

  group('weight-goal banner', () {
    test('every food known: how much is left, as before', () {
      expect(
        weightGoalCalorieStatus(
          targetCalories: 2800,
          totals: const NutritionTotals(calories: 1000, itemCount: 1),
          isSurplusGoal: true,
        ),
        '1800 kcal remaining for today\'s surplus',
      );
      expect(
        weightGoalCalorieStatus(
          targetCalories: 2000,
          totals: const NutritionTotals(calories: 2100, itemCount: 1),
          isSurplusGoal: false,
        ),
        'Daily calorie target reached!',
      );
    });

    test('some food unknown: no remaining figure is claimed', () {
      final text = weightGoalCalorieStatus(
        targetCalories: 2800,
        totals: const NutritionTotals(
          calories: 1000,
          unknownCalorieItems: 1,
          itemCount: 2,
        ),
        isSurplusGoal: true,
      );
      expect(text, contains('At least 1000 kcal logged'));
      expect(text, contains('remaining is unknown'));
      expect(text, isNot(contains('kcal remaining for')));
    });

    test('a minimum at or over the target still proves it was reached', () {
      expect(
        weightGoalCalorieStatus(
          targetCalories: 2000,
          totals: const NutritionTotals(
            calories: 2000,
            unknownCalorieItems: 1,
            itemCount: 2,
          ),
          isSurplusGoal: false,
        ),
        'Daily calorie target reached!',
      );
    });

    test('only unknown calories logged: says they are unknown', () {
      final text = weightGoalCalorieStatus(
        targetCalories: 2000,
        totals: const NutritionTotals(unknownCalorieItems: 2, itemCount: 2),
        isSurplusGoal: false,
      );
      expect(text, contains('unknown for the foods you logged'));
    });
  });
}
