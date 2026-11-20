import '../mocks/fake_step_sensor.dart';
import 'package:atlas/services/steps/step_counter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/recovery_summary.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/weight_goal.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/ai/action_planner/coach_action_planner.dart';
import 'package:atlas/services/ai/ai_safety_guardrails.dart';
import 'package:atlas/services/ai/coach_notification_engine.dart';
import 'package:atlas/services/ai/daily_coach_briefing_service.dart';
import 'package:atlas/services/ai/decision_engine/coach_decision_engine.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/memory/memory_item.dart';
import 'package:atlas/services/ai/tools/coach_tools.dart';
import 'package:atlas/services/ai/weekly_athlete_review_service.dart';
import 'package:atlas/services/athlete/athlete_state_aggregator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FitnessMemory.resetInstance();
    await FitnessMemory.instance.initialize();
  });

  group('1. Athlete State Aggregator Tests', () {
    test('Aggregates full athlete telemetry into AthleteStateSnapshot', () async {
      // Steps come from the step counter (a test sensor), not the health list.
      final stepSensor = FakeStepSensor();
      final counter = makeStepService(sensor: stepSensor);
      StepCounterService.setInstance(counter);
      addTearDown(StepCounterService.resetInstance);
      await counter.start();
      stepSensor.emit(500);
      stepSensor.emit(11000);

      final now = DateTime.now();
      final workouts = <WorkoutHistory>[
        WorkoutHistory(
          workoutName: 'Upper Body Power',
          dateCompleted: now.subtract(const Duration(days: 1)),
          durationSeconds: 3000,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalSets: 15,
          totalReps: 120,
          totalVolume: 3500.0,
          caloriesBurned: 400.0,
        ),
      ];

      final todayNutrition = DailyNutrition(
        date: now.toIso8601String().split('T').first,
        targets: const MacroTarget(
          calories: 2500,
          proteinGrams: 175,
          carbsGrams: 300,
          fatGrams: 70,
        ),
        meals: const [],
        baseCalories: 2400.0,
        baseProtein: 170.0,
        baseCarbs: 280.0,
        baseFat: 65.0,
      );

      final recovery = const RecoverySummary(isMeasured: true, recoveryScore: 88,
        sleepHours: 8.0,
        restingHeartRate: 58.0,
        hrv: 72.0,
        isDeloadRecommended: false,
      );

      final health = <HealthMetric>[
        HealthMetric(
          timestamp: now,
          steps: 10500,
          activeCalories: 520.0,
          sleepMinutes: 480,
          restingHeartRate: 58,
        ),
      ];

      final userGoal = UserGoal(
        id: 'ug_1',
        goalType: FitnessGoalType.muscleGain,
        fitnessLevel: FitnessLevel.intermediate,
        activityLevel: ActivityLevel.moderate,
        age: 25,
        height: 175.0,
        currentWeight: 75.0,
        targetWeight: 80.0,
        targetCalories: 2500.0,
        targetProtein: 175.0,
        targetCarbohydrates: 300.0,
        targetFats: 70.0,
        createdDate: now,
        updatedDate: now,
      );

      final weightGoal = WeightGoal(
        id: 'wg_1',
        userId: 'athlete_123',
        currentWeight: 76.0,
        targetWeight: 80.0,
        targetWeeks: 12,
        type: WeightGoalType.gain,
        diet: DietPreference.nonVegetarian,
        mealsPerDay: MealFrequency.fourMeals,
        dailyCalorieTarget: 2500.0,
        proteinGrams: 175.0,
        carbsGrams: 300.0,
        fatGrams: 70.0,
        expectedWeeklyRateKg: 0.5,
        createdAt: now,
        updatedAt: now,
      );

      final aggregator = AthleteStateAggregator.instance;
      final snapshot = aggregator.aggregateSnapshot(
        userId: 'athlete_123',
        workoutHistory: workouts,
        todayNutrition: todayNutrition,
        recovery: recovery,
        healthMetrics: health,
        userGoal: userGoal,
        weightGoal: weightGoal,
      );

      expect(snapshot.userId, 'athlete_123');
      expect(snapshot.overallReadinessTier, 'optimal');
      expect(snapshot.workout.totalWorkouts, 1);
      expect(snapshot.workout.lastWorkoutName, 'Upper Body Power');
      expect(snapshot.nutrition.caloriesConsumed, 2400);
      expect(snapshot.nutrition.proteinGramsConsumed, 170.0);
      expect(snapshot.recovery.readinessScore, 88);
      expect(snapshot.recovery.sleepHours, 8.0);
      expect(snapshot.health.todaySteps, 10500);

      // No step reading means no steps, not zero.
      StepCounterService.setInstance(makeStepService());
      final noSteps = aggregator.aggregateSnapshot(
        userId: 'athlete_123',
        workoutHistory: workouts,
        todayNutrition: todayNutrition,
        recovery: recovery,
        healthMetrics: health,
        userGoal: userGoal,
        weightGoal: weightGoal,
      );
      expect(noSteps.health.todaySteps, isNull);
      expect(noSteps.toPromptContext().contains('steps not recorded'), isTrue);

      // Test JSON and prompt conversion
      final json = snapshot.toJson();
      final fromJson = AthleteStateSnapshot.fromJson(json);
      expect(fromJson.userId, snapshot.userId);
      expect(fromJson.workout.lastWorkoutName, 'Upper Body Power');

      final promptContext = snapshot.toPromptContext();
      expect(promptContext.contains('ATHLETE STATE SNAPSHOT'), isTrue);
      expect(promptContext.contains('OPTIMAL'), isTrue);
    });

    test('Correctly identifies critical readiness tier when sleep and recovery are low', () {
      final recovery = const RecoverySummary(isMeasured: true, recoveryScore: 40,
        sleepHours: 4.5,
        restingHeartRate: 72.0,
        hrv: 35.0,
        isDeloadRecommended: true,
      );

      final aggregator = AthleteStateAggregator.instance;
      final snapshot = aggregator.aggregateSnapshot(
        userId: 'athlete_fatigued',
        recovery: recovery,
      );

      expect(snapshot.overallReadinessTier, 'critical');
      expect(snapshot.recovery.isDeloadRecommended, isTrue);
    });
  });

  group('2. Coach Decision Engine Tests', () {
    test('Recommends overload and high volume when athlete is well-recovered', () {
      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_ready',
        timestamp: DateTime.now(),
        overallReadinessTier: 'optimal',
        workout: const WorkoutStateSummary(
          totalWorkouts: 10,
          weeklyWorkoutsCompleted: 3,
          lastWorkoutName: 'Push Session',
          daysSinceLastWorkout: 1,
        ),
        nutrition: const NutritionStateSummary(
          caloriesConsumed: 2400,
          targetCalories: 2600,
          proteinGramsConsumed: 170.0,
          targetProteinGrams: 175.0,
        ),
        recovery: const RecoveryStateSummary(isMeasured: true, readinessScore: 88,
          sleepHours: 8.2,
          fatigueLevel: 'low',
          isDeloadRecommended: false,
        ),
        health: const HealthStateSummary(todaySteps: 9000),
        behavior: const BehaviorStateSummary(
          consistencyScore: 92.0,
          preferredWorkoutTime: 'morning',
          streakDays: 4,
        ),
        goal: const GoalStateSummary(primaryGoal: 'hypertrophy'),
      );

      final engine = CoachDecisionEngine.instance;
      final decision = engine.evaluate(snapshot);

      expect(decision.recommendRest, isFalse);
      expect(decision.volumeMultiplier, greaterThan(1.0));
      expect(decision.trainingAdjustments.first.type, 'overload');
      expect(decision.primaryFocus.contains('Overload'), isTrue);
      expect(decision.reasoning.isNotEmpty, isTrue);
      expect(decision.behaviorInterventions.first.optimalWindow.contains('06:30'), isTrue);
    });

    test('Recommends rest day and deload when sleep and recovery are critical', () {
      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_tired',
        timestamp: DateTime.now(),
        overallReadinessTier: 'critical',
        workout: const WorkoutStateSummary(
          totalWorkouts: 12,
          weeklyWorkoutsCompleted: 4,
          lastWorkoutName: 'Leg Day',
          daysSinceLastWorkout: 0,
        ),
        nutrition: const NutritionStateSummary(
          caloriesConsumed: 1800,
          targetCalories: 2400,
          proteinGramsConsumed: 120.0,
          targetProteinGrams: 160.0,
        ),
        recovery: const RecoveryStateSummary(isMeasured: true, readinessScore: 42,
          sleepHours: 4.8,
          fatigueLevel: 'critical',
          isDeloadRecommended: true,
        ),
        health: const HealthStateSummary(todaySteps: 4000),
        behavior: const BehaviorStateSummary(
          consistencyScore: 80.0,
          preferredWorkoutTime: 'evening',
          streakDays: 5,
        ),
        goal: const GoalStateSummary(primaryGoal: 'hypertrophy'),
      );

      final engine = CoachDecisionEngine.instance;
      final decision = engine.evaluate(snapshot);

      expect(decision.recommendRest, isTrue);
      expect(decision.volumeMultiplier, 0.6);
      expect(decision.urgency, 'critical');
      expect(decision.trainingAdjustments.first.type, 'rest_day');
      expect(decision.recoveryRecommendations.first.sleepTargetHours, 8.5);
      expect(decision.reasoning.contains('Readiness is critical'), isTrue);
    });

    test('Suggests protein boost and calorie adjustments based on goal', () {
      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_bulk',
        timestamp: DateTime.now(),
        overallReadinessTier: 'moderate',
        workout: const WorkoutStateSummary(),
        nutrition: const NutritionStateSummary(
          caloriesConsumed: 1500,
          targetCalories: 2600,
          proteinGramsConsumed: 110.0,
          targetProteinGrams: 180.0,
        ),
        recovery: const RecoveryStateSummary(isMeasured: true, readinessScore: 72, sleepHours: 7.0),
        health: const HealthStateSummary(),
        behavior: const BehaviorStateSummary(preferredWorkoutTime: 'afternoon'),
        goal: const GoalStateSummary(primaryGoal: 'hypertrophy'),
      );

      final engine = CoachDecisionEngine.instance;
      final decision = engine.evaluate(snapshot);

      expect(decision.nutritionSuggestions.any((s) => s.type == 'protein_boost'), isTrue);
      expect(decision.nutritionSuggestions.any((s) => s.type == 'surplus' && s.calorieAdjustment == 250), isTrue);
    });
  });

  group('3. Action Planner Tests', () {
    test('Plans actions and marks major plan modifications as requiring confirmation', () {
      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_plan',
        timestamp: DateTime.now(),
        overallReadinessTier: 'critical',
        workout: const WorkoutStateSummary(),
        nutrition: const NutritionStateSummary(
          proteinGramsConsumed: 100.0,
          targetProteinGrams: 160.0,
        ),
        recovery: const RecoveryStateSummary(isMeasured: true, readinessScore: 40, sleepHours: 4.5),
        health: const HealthStateSummary(),
        behavior: const BehaviorStateSummary(streakDays: 4),
        goal: const GoalStateSummary(),
      );

      final decision = CoachDecisionEngine.instance.evaluate(snapshot);
      final planner = CoachActionPlanner.instance;
      final actions = planner.planActions(state: snapshot, decision: decision);

      expect(actions.isNotEmpty, isTrue);

      // Workout modification for rest day requires confirmation
      final modifyAction = actions.firstWhere((a) => a.type == 'modify_workout');
      expect(modifyAction.requiresConfirmation, isTrue);
      expect(modifyAction.confirmationPrompt, isNotNull);

      // Meal suggestion does not require confirmation
      final mealAction = actions.firstWhere((a) => a.type == 'suggest_meal');
      expect(mealAction.requiresConfirmation, isFalse);

      // Challenge action requires confirmation
      final challengeAction = actions.firstWhere((a) => a.type == 'start_challenge');
      expect(challengeAction.requiresConfirmation, isTrue);
    });

    test('Execution fails when confirmation is missing for gated actions', () async {
      final gatedAction = PlannedCoachAction(
        id: 'act_gated',
        type: 'modify_workout',
        title: 'Deload Plan',
        description: 'Reduce volume by 40%',
        requiresConfirmation: true,
        confirmationPrompt: 'Confirm plan change?',
        reasoning: 'Recovery fatigue',
        createdAt: DateTime.now(),
      );

      final planner = CoachActionPlanner.instance;
      final unconfirmedResult = await planner.executeAction(gatedAction, confirmed: false);
      expect(unconfirmedResult['status'], 'confirmation_required');

      final confirmedResult = await planner.executeAction(gatedAction, confirmed: true);
      expect(confirmedResult['status'], 'success');
    });
  });

  group('4. Daily Coach Briefing Service Tests', () {
    test('Generates complete morning briefing report with all required sections', () {
      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_morning',
        timestamp: DateTime.now(),
        overallReadinessTier: 'optimal',
        workout: const WorkoutStateSummary(lastWorkoutName: 'Chest & Back Hypertrophy'),
        nutrition: const NutritionStateSummary(
          targetCalories: 2600,
          targetProteinGrams: 180.0,
        ),
        recovery: const RecoveryStateSummary(isMeasured: true, readinessScore: 86, sleepHours: 8.0),
        health: const HealthStateSummary(),
        behavior: const BehaviorStateSummary(preferredWorkoutTime: 'morning'),
        goal: const GoalStateSummary(primaryGoal: 'hypertrophy'),
      );

      final service = DailyCoachBriefingService.instance;
      final briefing = service.generateBriefing(
        userId: 'athlete_morning',
        stateSnapshot: snapshot,
        athleteName: 'Jordan',
      );

      expect(briefing.greeting.contains('Jordan'), isTrue);
      expect(briefing.recoveryScore, 86);
      expect(briefing.readinessTier, 'optimal');
      expect(briefing.sleepHours, 8.0);
      expect(briefing.workoutRecommendation.contains('Chest & Back Hypertrophy'), isTrue);
      expect(briefing.nutritionTarget.contains('2600 kcal'), isTrue);
      expect(briefing.mainFocus.isNotEmpty, isTrue);
      expect(briefing.proactiveMessage.contains('Today\'s Focus'), isTrue);
      expect(briefing.actions.isNotEmpty, isTrue);

      final json = briefing.toJson();
      expect(json['recovery_score'], 86);
      expect(json['actions'], isA<List>());
    });
  });

  group('5. Weekly Athlete Review Service Tests', () {
    test('Compiles 7-day trailing data and generates graded weekly report', () {
      final now = DateTime.now();
      final workouts = <WorkoutHistory>[
        WorkoutHistory(
          workoutName: 'Upper Power',
          dateCompleted: now.subtract(const Duration(days: 6)),
          durationSeconds: 2700,
          exercisesCompleted: 4,
          completionPercentage: 100.0,
          totalSets: 12,
          totalReps: 100,
          totalVolume: 3000.0,
          caloriesBurned: 350.0,
        ),
        WorkoutHistory(
          workoutName: 'Lower Hypertrophy',
          dateCompleted: now.subtract(const Duration(days: 4)),
          durationSeconds: 3200,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalSets: 15,
          totalReps: 120,
          totalVolume: 4200.0,
          caloriesBurned: 420.0,
        ),
        WorkoutHistory(
          workoutName: 'Push Power',
          dateCompleted: now.subtract(const Duration(days: 2)),
          durationSeconds: 3000,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalSets: 15,
          totalReps: 110,
          totalVolume: 3800.0,
          caloriesBurned: 390.0,
        ),
        WorkoutHistory(
          workoutName: 'Pull & Arms',
          dateCompleted: now.subtract(const Duration(days: 1)),
          durationSeconds: 2800,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalSets: 14,
          totalReps: 115,
          totalVolume: 3600.0,
          caloriesBurned: 370.0,
        ),
      ];

      final nutrition = <DailyNutrition>[
        DailyNutrition(
          date: now.subtract(const Duration(days: 1)).toIso8601String(),
          targets: const MacroTarget(calories: 2500, proteinGrams: 175, carbsGrams: 300, fatGrams: 70),
          meals: const [],
          baseCalories: 2500.0,
          baseProtein: 175.0,
          baseCarbs: 300.0,
          baseFat: 70.0,
        ),
        DailyNutrition(
          date: now.subtract(const Duration(days: 2)).toIso8601String(),
          targets: const MacroTarget(calories: 2500, proteinGrams: 175, carbsGrams: 300, fatGrams: 70),
          meals: const [],
          baseCalories: 2450.0,
          baseProtein: 170.0,
          baseCarbs: 290.0,
          baseFat: 68.0,
        ),
      ];

      final healthMetrics = <HealthMetric>[
        HealthMetric(
          timestamp: now.subtract(const Duration(days: 1)),
          steps: 9500,
          sleepMinutes: 480, // 8.0h
          activeCalories: 450.0,
        ),
        HealthMetric(
          timestamp: now.subtract(const Duration(days: 2)),
          steps: 10200,
          sleepMinutes: 460, // 7.6h
          activeCalories: 480.0,
        ),
      ];

      final service = WeeklyAthleteReviewService.instance;
      final report = service.generateReport(
        userId: 'athlete_weekly',
        workoutHistory: workouts,
        nutritionHistory: nutrition,
        healthMetrics: healthMetrics,
        currentRecovery: const RecoverySummary(isMeasured: true, recoveryScore: 85),
        currentWeight: 75.2,
        previousWeight: 75.0,
      );

      expect(report.workoutsCompleted, 4);
      expect(report.consistencyPercentage, 100.0);
      expect(report.totalVolumeKg, 14600.0);
      expect(report.grade, anyOf('A+', 'A'));
      expect(report.strengths.isNotEmpty, isTrue);
      expect(report.nextWeekFocus.isNotEmpty, isTrue);
      expect(report.summaryText.contains('Weekly Performance Grade'), isTrue);
    });
  });

  group('6. Advanced AI Memory Tests', () {
    test('Stores and retrieves 4 core memory types with importance scoring', () async {
      final memory = FitnessMemory.instance;

      // 1. Behavior Pattern
      final item1 = await memory.recordBehaviorPattern(
        title: 'Friday Evening Skip Tendency',
        pattern: 'Athlete frequently misses Friday sessions after 18:00 due to social/work commitments.',
        tags: ['friday', 'schedule', 'skip'],
      );
      expect(item1.category, MemoryCategory.behaviorPattern);
      expect(item1.importanceScore, greaterThanOrEqualTo(5.0));

      // 2. Successful Strategy
      final item2 = await memory.recordSuccessfulStrategy(
        title: '10-Min Dynamic Shoulder Warm-up',
        strategy: 'Band dislocates and face pulls eliminated front delt impingement on bench press.',
        userConfirmed: true,
        tags: ['shoulder', 'bench_press', 'warmup'],
      );
      expect(item2.category, MemoryCategory.successfulStrategy);
      expect(item2.importanceScore, greaterThan(8.0));

      // 3. Training Preference
      final item3 = await memory.recordTrainingPreferenceItem(
        title: 'Prefers Incline Dumbbell over Barbell',
        preference: 'Favors 30-degree incline dumbbell press for superior pectoral activation.',
        tags: ['chest', 'dumbbell', 'preference'],
      );
      expect(item3.category, MemoryCategory.trainingPreference);

      // 4. Historical Decision
      final item4 = await memory.recordHistoricalDecision(
        title: 'Deload Prescribed Week 34',
        decision: 'Reduced compound volume by 25% due to 45% recovery score.',
        tags: ['deload', 'recovery'],
      );
      expect(item4.category, MemoryCategory.historicalDecision);

      // Retrieval filtering
      final strategies = memory.retrieveMemories(category: MemoryCategory.successfulStrategy);
      expect(strategies.length, 1);
      expect(strategies.first.title.contains('Shoulder Warm-up'), isTrue);

      final allItems = memory.getMemoryItems();
      expect(allItems.length, 4);
    });

    test('Context ranking scores and returns most relevant memories for query', () async {
      final memory = FitnessMemory.instance;

      await memory.recordSuccessfulStrategy(
        title: 'Bench Press Shoulder Warm-up',
        strategy: 'Performing band face pulls before bench press prevents shoulder pain.',
        tags: ['bench', 'chest', 'shoulder'],
      );

      await memory.recordTrainingPreferenceItem(
        title: 'Prefers Morning Running',
        preference: 'Runs 5k outdoors at 6:30am.',
        tags: ['cardio', 'running', 'morning'],
      );

      final ranked = memory.rankMemoriesForContext('I feel shoulder discomfort during bench press today');
      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.title.contains('Bench Press Shoulder Warm-up'), isTrue);

      final promptString = memory.formatMemoriesForPrompt('bench press shoulder');
      expect(promptString.contains('ATHLETE LONG-TERM COACHING MEMORY'), isTrue);
      expect(promptString.contains('Bench Press Shoulder Warm-up'), isTrue);
    });
  });

  group('7. AI Coach Tools System Tests', () {
    test('Provides read-only access and enforces safe permissions on mutating actions', () async {
      final tools = CoachTools.instance;

      // 1. Get Workout History
      final historyRes = await tools.getWorkoutHistory(limit: 5);
      expect(historyRes['status'], 'success');
      expect(historyRes['tool'], 'getWorkoutHistory');

      // 2. Get Nutrition Status
      final nutritionRes = await tools.getNutritionStatus();
      expect(nutritionRes['status'], 'success');
      expect(nutritionRes.containsKey('calories'), isTrue);

      // 3. Get Recovery Status
      final recoveryRes = await tools.getRecoveryStatus();
      expect(recoveryRes['status'], 'success');
      expect(recoveryRes.containsKey('readiness_score'), isTrue);

      // 4. Generate Progress Report
      final progressRes = await tools.generateProgressReport(days: 7);
      expect(progressRes['status'], 'success');
      expect(progressRes.containsKey('lifetime_volume_kg'), isTrue);

      // 5. Modify Workout Plan — Unconfirmed requires confirmation
      final unconfirmedMod = await tools.modifyWorkoutPlan(
        workoutId: 'wo_upper_1',
        changes: {'description': 'Reduce sets from 4 to 3'},
        confirmed: false,
      );
      expect(unconfirmedMod['status'], 'confirmation_required');
      expect(unconfirmedMod['requires_confirmation'], isTrue);

      // 6. Modify Workout Plan — Confirmed executes successfully
      final confirmedMod = await tools.modifyWorkoutPlan(
        workoutId: 'wo_upper_1',
        changes: {'description': 'Reduce sets from 4 to 3'},
        confirmed: true,
      );
      expect(confirmedMod['status'], 'success');
    });
  });

  group('8. Proactive Notification Engine Tests', () {
    test('Generates recovery warnings, personalized workout reminders, and achievement alerts', () {
      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_notif',
        timestamp: DateTime.now(),
        overallReadinessTier: 'fatigued',
        workout: const WorkoutStateSummary(lastWorkoutName: 'Push Power'),
        nutrition: const NutritionStateSummary(
          proteinGramsConsumed: 120.0,
          targetProteinGrams: 165.0,
        ),
        recovery: const RecoveryStateSummary(isMeasured: true, readinessScore: 46, sleepHours: 5.2),
        health: const HealthStateSummary(),
        behavior: const BehaviorStateSummary(
          preferredWorkoutTime: 'morning',
          streakDays: 4,
        ),
        goal: const GoalStateSummary(),
      );

      final engine = CoachNotificationEngine.instance;
      final notifications = engine.generateNotifications(state: snapshot, maxPerDay: 3);

      expect(notifications.length, lessThanOrEqualTo(3));
      // Should include high priority recovery warning
      expect(notifications.any((n) => n.type == NotificationType.recoveryWarning), isTrue);
      // Should include streak achievement alert
      expect(notifications.any((n) => n.type == NotificationType.achievementAlert), isTrue);
    });
  });

  group('9. AI Safety System Tests', () {
    test('Rejects medical diagnosis requests and provides clinical disclaimer', () {
      final safety = AISafetyGuardrails.instance;

      final check1 = safety.validateUserQuery('Can you diagnose my sharp chest pain?');
      expect(check1.isSafe, isFalse);
      expect(check1.violationType, 'medical_diagnosis');
      expect(check1.sanitizedResponse?.contains('Medical Advisory'), isTrue);

      final check2 = safety.validateUserQuery('I think I have a torn ligament in my knee');
      expect(check2.isSafe, isFalse);
      expect(check2.violationType, 'medical_diagnosis');

      final safeQuery = safety.validateUserQuery('What is the best rep range for hypertrophy?');
      expect(safeQuery.isSafe, isTrue);
    });

    test('Rejects unsafe training jumps and training through active injuries', () {
      final safety = AISafetyGuardrails.instance;

      // >50% load jump is unsafe
      final checkLoad = safety.validateTrainingAdjustment(
        currentVolumeOrLoad: 100.0,
        proposedVolumeOrLoad: 160.0, // +60% jump
        recoveryScore: 80,
      );
      expect(checkLoad.isSafe, isFalse);
      expect(checkLoad.violationType, 'unsafe_training');

      // Heavy overload during critical fatigue
      final checkFatigue = safety.validateTrainingAdjustment(
        currentVolumeOrLoad: 100.0,
        proposedVolumeOrLoad: 105.0,
        recoveryScore: 35, // Critical
      );
      expect(checkFatigue.isSafe, isFalse);

      // Training through injury
      final checkInjury = safety.validateTrainingAdjustment(
        currentVolumeOrLoad: 100.0,
        proposedVolumeOrLoad: 100.0,
        recoveryScore: 80,
        isInjuryReported: true,
      );
      expect(checkInjury.isSafe, isFalse);
    });

    test('Validates mandatory reasoning and permission enforcement', () {
      final safety = AISafetyGuardrails.instance;

      final reasoningMissing = safety.validateReasoning(
        recommendation: 'Rest today',
        reasoning: '',
      );
      expect(reasoningMissing.isSafe, isFalse);
      expect(reasoningMissing.violationType, 'missing_reasoning');

      final planUnconfirmed = safety.validatePlanModification(
        modificationType: 'Split Revamp',
        isConfirmed: false,
      );
      expect(planUnconfirmed.isSafe, isFalse);
      expect(planUnconfirmed.violationType, 'unauthorized_plan_change');
    });

    test('Sanitizes response text by stripping harmful injury advice', () {
      final safety = AISafetyGuardrails.instance;

      const unsafeText = 'You should ignore your injury and train harder through the sharp pain.';
      final sanitized = safety.sanitizeResponse(unsafeText);

      expect(sanitized.contains('ignore your injury'), isFalse);
      expect(sanitized.contains('consult a qualified medical professional'), isTrue);
    });
  });
}
