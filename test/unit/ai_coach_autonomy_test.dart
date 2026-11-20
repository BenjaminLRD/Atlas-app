import 'package:atlas/models/recovery/readiness_inputs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/recovery_summary.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_recommendation.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/adaptation/goal_adaptation_engine.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/coach_notification_service.dart';
import 'package:atlas/services/ai/daily_coach_brief_service.dart';
import 'package:atlas/services/ai/decision_engine/ai_decision_engine.dart';
import 'package:atlas/services/ai/weekly_coach_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('1. Daily Coach Brief Generation — Multi-Domain Synthesis', () {
    test(
      'DailyCoachBriefService synthesizes recovery, nutrition delta, and workout split',
      () {
        final service = DailyCoachBriefService();

        final profile =
            UserProfile.defaultProfile(email: 'benjamin@example.com')
              ..name = 'Benjamin'
              ..fitnessGoal = 'Hypertrophy';

        final context = FitnessContext.initial().copyWith(
          userProfile: profile,
          recoveryState: RecoveryState(inputs: const ReadinessInputs(hasSleep: true, hasHrv: true), id: 'rec1',
            recoveryScore: 84,
            sleepQuality: 0.85,
            fatigueLevel: FatigueLevel.low,
            lastUpdated: DateTime.now(),
          ),
          nutritionSummary: const NutritionSummary(
            totalCaloriesConsumed: 1950,
            averageProtein: 118,
            proteinGoalHitPercentage: 75,
          ),
        );

        final brief = service.generateBrief(context: context);

        expect(brief.greeting, contains('Benjamin'));
        expect(brief.recovery.score, 84);
        expect(brief.workout.title, isNotEmpty);
        expect(brief.actions, isNotEmpty);
        expect(brief.actions.any((a) => a.category == 'workout'), isTrue);
        expect(brief.actions.any((a) => a.category == 'nutrition'), isTrue);
      },
    );
  });

  group('2. AI Decision Engine — Training, Nutrition & Recovery Evaluation', () {
    test('Decision Engine prescribes overload when recovery is high', () {
      final engine = AIDecisionEngine();

      final report = engine.evaluate(
        workoutHistory: [
          WorkoutHistory(
            workoutName: 'Upper Body Power',
            dateCompleted: DateTime.now().subtract(const Duration(days: 1)),
            durationSeconds: 3000,
            exercisesCompleted: 5,
            completionPercentage: 1.0,
            totalVolume: 7500.0,
            caloriesBurned: 400,
          ),
        ],
        recovery: const RecoverySummary(isMeasured: true, recoveryScore: 88, sleepHours: 8.2),
        todayNutrition: const DailyNutrition(
          date: '2026-08-24',
          targets: MacroTarget(
            calories: 2400,
            proteinGrams: 160,
            carbsGrams: 280,
            fatGrams: 70,
          ),
          meals: [],
          baseCalories: 2200,
          baseProtein: 145,
          baseCarbs: 250,
          baseFat: 60,
        ),
        recentHealthMetrics: const [],
        goal: 'hypertrophy',
      );

      expect(report.recommendRest, isFalse);
      expect(report.volumeMultiplier, 1.0);
      expect(report.trainingDecisions.first, contains('overload'));
      expect(report.recommendedCalorieAdjustment, 250);
    });

    test(
      'Decision Engine prescribes rest and volume reduction when recovery drops',
      () {
        final engine = AIDecisionEngine();

        final report = engine.evaluate(
          workoutHistory: const [],
          recovery: const RecoverySummary(isMeasured: true, recoveryScore: 38, sleepHours: 4.5),
          todayNutrition: null,
          recentHealthMetrics: const [],
        );

        expect(report.recommendRest, isTrue);
        expect(report.volumeMultiplier, lessThan(0.8));
        expect(
          report.recoveryDecisions.first,
          contains('Rest day recommended'),
        );
      },
    );
  });

  group('3. Autonomous Goal Adaptation Engine — Plateaus & Trajectories', () {
    test(
      'Weight Gain Goal adapts calories up (+200 kcal) when progression lags',
      () {
        final engine = GoalAdaptationEngine();

        final report = engine.evaluate(
          goalType: 'weight_gain',
          startWeight: 70.0,
          currentWeight: 70.8, // Only 0.8kg in 8 weeks (target was ~2.0kg)
          targetWeight: 80.0,
          weeksElapsed: 8,
        );

        expect(report.hasPlateau, isTrue);
        expect(report.calorieAdjustment, 200);
        expect(report.recommendedAction, contains('+200 kcal/day'));
      },
    );

    test(
      'Fat Loss Goal adapts calories down (-150 kcal) when plateaued >= 3 weeks',
      () {
        final engine = GoalAdaptationEngine();

        final report = engine.evaluate(
          goalType: 'fat_loss',
          startWeight: 90.0,
          currentWeight: 84.0,
          targetWeight: 78.0,
          weeksElapsed: 10,
          consecutivePlateauWeeks: 3,
        );

        expect(report.hasPlateau, isTrue);
        expect(report.calorieAdjustment, -150);
        expect(report.recommendedAction, contains('-150 kcal/day'));
      },
    );

    test(
      'Strength Goal adapts periodization and rep ranges on lift stagnation',
      () {
        final engine = GoalAdaptationEngine();

        final report = engine.evaluate(
          goalType: 'strength',
          startWeight: 80.0,
          currentWeight: 80.0,
          targetWeight: 80.0,
          weeksElapsed: 6,
          hasStrengthPlateau: true,
        );

        expect(report.hasPlateau, isTrue);
        expect(report.trainingModifications.containsKey('rep_range'), isTrue);
        expect(report.trainingModifications['rep_range'], '3-5 reps');
      },
    );
  });

  group('4. Weekly AI Review Generation', () {
    test('WeeklyCoachReviewService compiles 7-day retrospective analytics', () {
      final service = WeeklyCoachReviewService();
      final now = DateTime.now();

      final review = service.generateReview(
        workoutHistory: [
          WorkoutHistory(
            workoutName: 'Push Hypertrophy',
            dateCompleted: now.subtract(const Duration(days: 2)),
            durationSeconds: 3300,
            exercisesCompleted: 5,
            completionPercentage: 1.0,
            totalVolume: 8200.0,
            caloriesBurned: 450,
          ),
          WorkoutHistory(
            workoutName: 'Pull Power',
            dateCompleted: now.subtract(const Duration(days: 4)),
            durationSeconds: 3000,
            exercisesCompleted: 4,
            completionPercentage: 1.0,
            totalVolume: 7900.0,
            caloriesBurned: 420,
          ),
        ],
        nutritionHistory: [
          DailyNutrition(
            date: now.subtract(const Duration(days: 1)).toIso8601String(),
            targets: const MacroTarget(
              calories: 2400,
              proteinGrams: 160,
              carbsGrams: 280,
              fatGrams: 70,
            ),
            meals: const [],
            baseCalories: 2350,
            baseProtein: 155,
            baseCarbs: 260,
            baseFat: 65,
          ),
        ],
        healthMetrics: [
          HealthMetric(
            timestamp: now.subtract(const Duration(days: 1)),
            steps: 9200,
            sleepMinutes: 460, // 7.6h
          ),
        ],
        currentRecovery: const RecoverySummary(isMeasured: true, recoveryScore: 85,
          sleepHours: 7.6,
        ),
        currentWeight: 76.5,
        previousWeight: 76.0,
      );

      expect(review.workoutsCompleted, 2);
      expect(review.averageDailyCalories, 2350.0);
      expect(review.proteinConsistencyPercentage, 100.0);
      expect(review.weakAreasIdentified, contains('Lower Body / Legs volume'));
      expect(review.strengthSummary, isNotEmpty);
      expect(review.primaryRecommendation, isNotEmpty);
    });
  });

  group('5. AI Safety Rules & Medical Guardrails', () {
    test(
      'CoachChatService prepends safety advisory on medical injury questions',
      () async {
        final chatService = CoachChatService();

        final messages = await chatService.sendMessage(
          message:
              'I have severe chest pain and think I have a torn muscle. Can you diagnose me?',
          context: FitnessContext.initial(),
        );

        expect(messages.last.content, contains('Safety Advisory'));
        expect(messages.last.content, contains('healthcare specialist'));
      },
    );
  });

  group('6. Smart Notifications & FitnessProvider Integration', () {
    test(
      'CoachNotificationService generates capped, relevant smart notifications',
      () {
        final notifService = CoachNotificationService();

        final notifications = notifService.generateDailyNotifications(
          recovery: const RecoverySummary(isMeasured: true, recoveryScore: 42, sleepHours: 5.2),
          workout: const WorkoutRecommendation(
            id: 'w1',
            workoutTitle: 'Push Day',
            splitType: 'Push',
            isRestDay: false,
          ),
          todayNutrition: DailyNutrition(
            date: DateTime.now().toIso8601String(),
            targets: const MacroTarget(
              calories: 2400,
              proteinGrams: 150,
              carbsGrams: 250,
              fatGrams: 70,
            ),
            meals: const [],
            baseCalories: 1200,
            baseProtein: 80, // 70g remaining
            baseCarbs: 120,
            baseFat: 40,
          ),
          maxNotificationsPerDay: 3,
        );

        expect(notifications.length, lessThanOrEqualTo(3));
        expect(notifications.any((n) => n.category == 'recovery'), isTrue);
        expect(notifications.any((n) => n.category == 'workout'), isTrue);
        expect(notifications.any((n) => n.category == 'nutrition'), isTrue);
      },
    );

    test(
      'FitnessProvider evaluates AI decisions, goal adaptation, and weekly review',
      () {
        final provider = FitnessProvider();

        final decisions = provider.evaluateAIDecisions();
        // With no recorded sleep or heart data the engine says recovery cannot
        // be assessed instead of prescribing a recovery-based plan.
        expect(decisions.recoveryDecisions, isNotEmpty);

        final adaptation = provider.evaluateGoalAdaptation(
          goalType: 'weight_gain',
          startWeight: 70.0,
          currentWeight: 70.5,
          targetWeight: 80.0,
          weeksElapsed: 6,
        );
        expect(adaptation.goalType, contains('Weight Gain'));

        final review = provider.generateWeeklyCoachReview();
        expect(review.strengthSummary, isNotEmpty);

        final notifs = provider.getCoachNotifications();
        expect(notifs, isNotNull);
      },
    );
  });
}
