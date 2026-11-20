import '../mocks/mock_health_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/weight_goal.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/ai/insights/ai_insight_engine.dart';
import 'package:atlas/services/ai/insights/insight_model.dart';
import 'package:atlas/services/ai/insights/insight_rule.dart';
import 'package:atlas/services/analytics/workout_analytics_service.dart';
import 'package:atlas/services/health/health_service.dart';
import 'package:atlas/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    HealthService.resetInstance();
    AppDependencies.useMock();
  });

  group('Proactive AI Insight Engine Tests', () {
    test(
      'RecoveryInsightRule detects low recovery score (<50) and generates recoveryWarning',
      () async {
        const rule = RecoveryInsightRule();
        final now = DateTime(2026, 8, 16, 8, 0);

        final context = InsightContext(
          recoveryMeasured: true,
          todayHealth: HealthMetric.sample(),
          recoveryScore: 42.0, // Low readiness
          isDeloadRecommended: false,
          dailyNutrition: DailyNutrition(
            date: '2026-08-16',
            targets: MacroTarget.defaultTarget(),
            meals: const [],
          ),
          workoutHistory: const [],
          volumeAnalytics: VolumeAnalytics.zero(),
          consistencyAnalytics: ConsistencyAnalytics.zero(),
          personalRecords: PersonalRecordSummary.zero(),
          now: now,
        );

        final insights = await rule.evaluate(context);

        expect(insights, isNotEmpty);
        expect(
          insights.any((i) => i.type == InsightType.recoveryWarning),
          isTrue,
        );
        final warning = insights.firstWhere(
          (i) => i.type == InsightType.recoveryWarning,
        );
        expect(warning.priority, equals(InsightPriority.critical));
        expect(warning.message, contains('42%'));
        expect(warning.actionType, equals(InsightActionType.reviewRecovery));
      },
    );

    test(
      'RecoveryInsightRule detects sleep deficit (<6.5h) and generates sleepRecommendation',
      () async {
        const rule = RecoveryInsightRule();
        final now = DateTime(2026, 8, 16, 8, 0);

        final healthMetric = HealthMetric(
          timestamp: now,
          steps: 8000,
          sleepMinutes: 324, // 5.4 hours
          restingHeartRate: 64,
          activeCalories: 450,
        );

        final context = InsightContext(
          recoveryMeasured: true,
          todayHealth: healthMetric,
          recoveryScore: 78.0,
          isDeloadRecommended: false,
          dailyNutrition: DailyNutrition(
            date: '2026-08-16',
            targets: MacroTarget.defaultTarget(),
            meals: const [],
          ),
          workoutHistory: const [],
          volumeAnalytics: VolumeAnalytics.zero(),
          consistencyAnalytics: ConsistencyAnalytics.zero(),
          personalRecords: PersonalRecordSummary.zero(),
          now: now,
        );

        final insights = await rule.evaluate(context);

        expect(insights, isNotEmpty);
        expect(
          insights.any((i) => i.type == InsightType.sleepRecommendation),
          isTrue,
        );
        final sleepRec = insights.firstWhere(
          (i) => i.type == InsightType.sleepRecommendation,
        );
        expect(sleepRec.priority, equals(InsightPriority.high));
        expect(sleepRec.message, contains('5h 24m'));
      },
    );

    test(
      'NutritionInsightRule detects protein deficit (>=35g remaining) and generates proteinReminder',
      () async {
        const rule = NutritionInsightRule();
        final now = DateTime(2026, 8, 16, 15, 0); // 3 PM

        // Only 60g of 160g target consumed (100g remaining)
        final dailyNutrition = DailyNutrition(
          date: '2026-08-16',
          targets: const MacroTarget(
            calories: 2400,
            proteinGrams: 160,
            carbsGrams: 250,
            fatGrams: 70,
          ),
          meals: [
            MealEntry(
              id: 'm1',
              mealType: MealType.breakfast,
              name: 'Breakfast',
              isCompleted: true,
              items: const [
                FoodItem(
                  id: 'f1',
                  name: 'Eggs & Oats',
                  calories: 450,
                  protein: 30,
                  carbohydrates: 50,
                  fats: 15,
                ),
              ],
            ),
            MealEntry(
              id: 'm2',
              mealType: MealType.lunch,
              name: 'Lunch',
              isCompleted: true,
              items: const [
                FoodItem(
                  id: 'f2',
                  name: 'Chicken Rice',
                  calories: 500,
                  protein: 30,
                  carbohydrates: 60,
                  fats: 18,
                ),
              ],
            ),
          ],
        );

        final context = InsightContext(
          recoveryMeasured: true,
          todayHealth: HealthMetric.sample(),
          recoveryScore: 85.0,
          isDeloadRecommended: false,
          dailyNutrition: dailyNutrition,
          workoutHistory: const [],
          volumeAnalytics: VolumeAnalytics.zero(),
          consistencyAnalytics: ConsistencyAnalytics.zero(),
          personalRecords: PersonalRecordSummary.zero(),
          now: now,
        );

        final insights = await rule.evaluate(context);

        expect(insights, isNotEmpty);
        expect(
          insights.any((i) => i.type == InsightType.proteinReminder),
          isTrue,
        );
        final proteinRem = insights.firstWhere(
          (i) => i.type == InsightType.proteinReminder,
        );
        expect(proteinRem.priority, equals(InsightPriority.medium));
        expect(proteinRem.actionType, equals(InsightActionType.logProtein));
      },
    );

    test(
      'NutritionInsightRule detects calorie surplus deviation during a cut',
      () async {
        const rule = NutritionInsightRule();
        final now = DateTime(2026, 8, 16, 19, 0);

        final weightGoal = WeightGoal(
          id: 'wg_1',
          userId: 'user_1',
          currentWeight: 80.0,
          targetWeight: 72.0,
          targetWeeks: 12,
          type: WeightGoalType.lose,
          diet: DietPreference.nonVegetarian,
          mealsPerDay: MealFrequency.fourMeals,
          budget: BudgetTier.medium,
          dailyCalorieTarget: 2000.0,
          proteinGrams: 160.0,
          carbsGrams: 200.0,
          fatGrams: 60.0,
          expectedWeeklyRateKg: 0.65,
          createdAt: now,
          updatedAt: now,
        );

        // Consumed 2600 kcal vs 2000 kcal target
        final dailyNutrition = DailyNutrition(
          date: '2026-08-16',
          targets: const MacroTarget(
            calories: 2000,
            proteinGrams: 160,
            carbsGrams: 200,
            fatGrams: 60,
          ),
          meals: [
            MealEntry(
              id: 'm1',
              mealType: MealType.dinner,
              name: 'Big Meal',
              isCompleted: true,
              items: const [
                FoodItem(
                  id: 'f1',
                  name: 'Feast',
                  calories: 2600,
                  protein: 120,
                  carbohydrates: 300,
                  fats: 90,
                ),
              ],
            ),
          ],
        );

        final context = InsightContext(
          recoveryMeasured: true,
          todayHealth: HealthMetric.sample(),
          recoveryScore: 80.0,
          isDeloadRecommended: false,
          dailyNutrition: dailyNutrition,
          weightGoal: weightGoal,
          workoutHistory: const [],
          volumeAnalytics: VolumeAnalytics.zero(),
          consistencyAnalytics: ConsistencyAnalytics.zero(),
          personalRecords: PersonalRecordSummary.zero(),
          now: now,
        );

        final insights = await rule.evaluate(context);

        expect(insights, isNotEmpty);
        expect(
          insights.any((i) => i.type == InsightType.calorieAdjustment),
          isTrue,
        );
      },
    );

    test('TrainingInsightRule detects missed workout gap (>=3 days)', () async {
      const rule = TrainingInsightRule();
      final now = DateTime(2026, 8, 16, 10, 0);
      final fourDaysAgo = now.subtract(const Duration(days: 4));

      final workoutHistory = [
        WorkoutHistory(
          workoutName: 'Upper Body Power',
          dateCompleted: fourDaysAgo,
          durationSeconds: 3000,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
        ),
      ];

      final context = InsightContext(
          recoveryMeasured: true,
        todayHealth: HealthMetric.sample(),
        recoveryScore: 78.0,
        isDeloadRecommended: false,
        dailyNutrition: DailyNutrition(
          date: '2026-08-16',
          targets: MacroTarget.defaultTarget(),
          meals: const [],
        ),
        workoutHistory: workoutHistory,
        volumeAnalytics: VolumeAnalytics.zero(),
        consistencyAnalytics: ConsistencyAnalytics.zero(),
        personalRecords: PersonalRecordSummary.zero(),
        now: now,
      );

      final insights = await rule.evaluate(context);

      expect(insights, isNotEmpty);
      expect(insights.any((i) => i.type == InsightType.missedWorkout), isTrue);
      final missed = insights.firstWhere(
        (i) => i.type == InsightType.missedWorkout,
      );
      expect(missed.priority, equals(InsightPriority.high));
      expect(missed.message, contains('4 days'));
      expect(missed.actionType, equals(InsightActionType.startWorkout));
    });

    test(
      'TrainingInsightRule detects Personal Record (PR) opportunity on optimal readiness',
      () async {
        const rule = TrainingInsightRule();
        final now = DateTime(2026, 8, 16, 10, 0);

        final context = InsightContext(
          recoveryMeasured: true,
          todayHealth: HealthMetric.sample(),
          recoveryScore: 92.0, // Peaked recovery
          isDeloadRecommended: false,
          dailyNutrition: DailyNutrition(
            date: '2026-08-16',
            targets: MacroTarget.defaultTarget(),
            meals: const [],
          ),
          workoutHistory: const [],
          volumeAnalytics: VolumeAnalytics.zero(),
          consistencyAnalytics: const ConsistencyAnalytics(
            workoutsThisWeek: 3,
            workoutsThisMonth: 12,
            averageWorkoutsPerWeek: 3.5,
            currentStreak: 3,
          ),
          personalRecords: PersonalRecordSummary.zero(),
          now: now,
        );

        final insights = await rule.evaluate(context);

        expect(insights, isNotEmpty);
        expect(
          insights.any((i) => i.type == InsightType.personalRecordOpportunity),
          isTrue,
        );
      },
    );

    test(
      'AIInsightEngine generates sorted active insights and supports dismissal',
      () async {
        final engine = AIInsightEngine();

        final insights = await engine.generateInsights();
        expect(insights, isA<List<CoachInsight>>());

        if (insights.isNotEmpty) {
          final firstId = insights.first.id;
          engine.dismissInsight(firstId);

          final updated = await engine.generateInsights();
          expect(updated.any((i) => i.id == firstId), isFalse);
        }
      },
    );

    test(
      'AIInsightEngine compiles DailyCoachBrief with holistic metrics',
      () async {
        final engine = AIInsightEngine();

        // No health data: no recovery score and no readiness tier is invented.
        HealthService.resetInstance();
        final none = await engine.generateDailyBrief(athleteName: 'Benjamin');
        expect(none.recoveryScore, isNull);
        expect(none.readinessTier, 'Readiness unavailable');

        // A recorded night of sleep makes the score real.
        HealthService.setInstance(MockHealthService());
        final brief = await AIInsightEngine().generateDailyBrief(
          athleteName: 'Benjamin',
        );

        expect(brief.greeting, contains('Benjamin'));
        expect(brief.recoveryScore, inInclusiveRange(0, 100));
        expect(brief.readinessTier, isNotEmpty);
        expect(brief.plannedWorkout, isNotEmpty);
        expect(brief.remainingProteinGrams, greaterThanOrEqualTo(0.0));
        expect(brief.keySuggestion, isNotEmpty);
      },
    );
  });
}
