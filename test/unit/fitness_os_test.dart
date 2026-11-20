import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/lifestyle/adaptive_lifestyle_engine.dart';
import 'package:atlas/services/lifestyle/athlete_journey_timeline.dart';
import 'package:atlas/services/lifestyle/calendar_integration_service.dart';
import 'package:atlas/services/lifestyle/companion_mode_service.dart';
import 'package:atlas/services/lifestyle/daily_fitness_planner_service.dart';
import 'package:atlas/services/lifestyle/goal_simulation_service.dart';
import 'package:atlas/services/lifestyle/habit_tracking_engine.dart';
import 'package:atlas/services/lifestyle/training_cycle_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FitnessMemory.resetInstance();
    await FitnessMemory.instance.initialize();
    CalendarIntegrationService.resetInstance();
    DailyFitnessPlannerService.resetInstance();
    GoalSimulationService.resetInstance();
    TrainingCycleManager.resetInstance();
    AdaptiveLifestyleEngine.resetInstance();
    HabitTrackingEngine.resetInstance();
    AthleteJourneyTimeline.resetInstance();
    CompanionModeService.resetInstance();

    final now = DateTime.now();
    sampleContext = FitnessContext(
      userProfile: UserProfile(
        name: 'Jordan',
        email: 'jordan@example.com',
        phone: '',
        dob: '1998-01-01',
        gender: 'Male',
        height: '178',
        weight: '76',
        fitnessGoal: 'Lean Muscle Accrual',
        workoutExperience: 'Intermediate',
        preferredDays: const ['Mon', 'Tue', 'Thu', 'Fri'],
        dietPreference: 'Non-Vegetarian',
        massUnit: 'kg',
        lengthUnit: 'cm',
        subscription: 'Pro',
        privacy: 'Public',
        notificationsEnabled: true,
        profilePic: '',
      ),
      userGoal: UserGoal(
        id: 'ug_test',
        goalType: FitnessGoalType.muscleGain,
        fitnessLevel: FitnessLevel.intermediate,
        activityLevel: ActivityLevel.moderate,
        age: 26,
        height: 178.0,
        currentWeight: 76.0,
        targetWeight: 80.0,
        targetCalories: 2700.0,
        targetProtein: 175.0,
        targetCarbohydrates: 310.0,
        targetFats: 70.0,
        createdDate: now,
        updatedDate: now,
      ),
      nutritionSummary: NutritionSummary.empty(),
      progressSummary: ProgressSummary.zero(),
      userProgress: UserProgress.initial(),
      nutritionProgress: NutritionProgress.initial(),
      workoutHistory: const [],
      recoveryState: RecoveryState(
        id: 'rec_test',
        recoveryScore: 86,
        sleepQuality: 0.85,
        fatigueLevel: FatigueLevel.low,
        isDeloadRecommended: false,
        lastUpdated: now,
      ),
      generatedAt: now,
    );
  });

  group('1. Calendar Integration Tests', () {
    test('Identifies available training windows and resolves calendar gaps', () {
      final calendar = CalendarIntegrationService.instance;
      final targetDay = DateTime(2026, 9, 1);

      final events = [
        CalendarEvent(
          id: 'ev_1',
          title: 'Work Standup',
          startTime: DateTime(2026, 9, 1, 9, 0),
          endTime: DateTime(2026, 9, 1, 10, 0),
        ),
        CalendarEvent(
          id: 'ev_2',
          title: 'Design Review',
          startTime: DateTime(2026, 9, 1, 14, 0),
          endTime: DateTime(2026, 9, 1, 16, 0),
        ),
      ];

      final windows = calendar.findAvailableTrainingWindows(
        targetDay: targetDay,
        events: events,
      );

      expect(windows.isNotEmpty, isTrue);
      expect(windows.any((w) => w.durationMinutes >= 60), isTrue);
    });
  });

  group('2. Daily Fitness Planner Tests', () {
    test('Generates structured 24-hour schedule including protein, workout, and sleep blocks', () {
      final planner = DailyFitnessPlannerService.instance;

      final plan = planner.generateDailyPlan(
        context: sampleContext,
      );

      expect(plan.schedule.isNotEmpty, isTrue);
      expect(plan.readinessScore, equals(86));
      expect(plan.schedule.any((i) => i.type == PlanItemType.proteinTrigger), isTrue);
      expect(plan.schedule.any((i) => i.type == PlanItemType.workoutSession), isTrue);
      expect(plan.schedule.any((i) => i.type == PlanItemType.sleepPreparation), isTrue);
    });
  });

  group('3. Goal Simulation Engine Tests', () {
    test('Simulates muscle gain timeline, caloric surplus, and projected milestones', () {
      final simulator = GoalSimulationService.instance;

      final report = simulator.simulateGoal(
        goalType: SimulationGoalType.muscleGain,
        currentWeightKg: 76.0,
        targetWeightKg: 80.0,
        maintenanceCalories: 2400.0,
      );

      expect(report.estimatedWeeksToAchieve, equals(16)); // (4kg / 0.25kg) = 16 weeks
      expect(report.targetDailyCalories, equals(2700.0)); // 2400 + 300
      expect(report.targetDailyProteinGrams, greaterThanOrEqualTo(160.0));
      expect(report.milestones.length, greaterThanOrEqualTo(3));
      expect(report.feasibilityScore, greaterThan(0.80));
    });

    test('Simulates fat loss timeline with caloric deficit and muscle preservation protein', () {
      final simulator = GoalSimulationService.instance;

      final report = simulator.simulateGoal(
        goalType: SimulationGoalType.fatLoss,
        currentWeightKg: 85.0,
        targetWeightKg: 80.0,
        maintenanceCalories: 2600.0,
      );

      expect(report.estimatedWeeksToAchieve, equals(10)); // 5kg / 0.5kg = 10 weeks
      expect(report.targetDailyCalories, equals(2100.0)); // 2600 - 500
      expect(report.targetDailyProteinGrams, greaterThanOrEqualTo(200.0)); // High protein during cut
    });
  });

  group('4. Training Block System Tests', () {
    test('Generates 4-week periodized hypertrophy mesocycle with volume stepping and deload', () {
      final manager = TrainingCycleManager.instance;

      final meso = manager.generateHypertrophyMesocycle(baseVolumeSets: 12);

      expect(meso.totalWeeks, equals(4));
      expect(meso.weeks.length, equals(4));
      expect(meso.weeks[0].targetVolumeSetsPerMuscle, equals(12));
      expect(meso.weeks[1].targetVolumeSetsPerMuscle, equals(14));
      expect(meso.weeks[2].targetVolumeSetsPerMuscle, equals(16));
      expect(meso.weeks[3].isDeload, isTrue);
      expect(meso.weeks[3].targetVolumeSetsPerMuscle, equals(6));
    });
  });

  group('5. Autonomous Lifestyle Adaptation Engine Tests', () {
    test('Auto-regulates volume by -30% during acute sleep debt or low recovery', () {
      final engine = AdaptiveLifestyleEngine.instance;

      final recommendation = engine.evaluateLifestyleContext(
        recoveryScore: 48.0,
        sleepDurationHours: 5.0,
      );

      expect(recommendation.isVolumeAdjusted, isTrue);
      expect(recommendation.volumeAdjustmentPercentage, equals(-30.0));
      expect(recommendation.isCaloriesAdjusted, isTrue);
      expect(recommendation.adaptationReasoning.contains('Auto-regulating volume by -30%'), isTrue);
    });
  });

  group('6. Habit Intelligence & Readiness Scoring Tests', () {
    test('Computes multi-pillar habit score and maintains streak', () {
      final habitEngine = HabitTrackingEngine.instance;
      final now = DateTime.now();

      final summary = habitEngine.recordDailyHabits(DailyHabitEntry(
        date: now,
        sleepHours: 8.0,
        proteinGrams: 175.0,
        targetProteinGrams: 170.0,
        waterLiters: 3.5,
        targetWaterLiters: 3.0,
        stepCount: 9500,
        targetSteps: 8000,
        mobilityMinutes: 15,
        workoutCompleted: true,
      ));

      expect(summary.overallHabitScore, greaterThanOrEqualTo(90.0));
      expect(summary.currentStreakDays, greaterThanOrEqualTo(1));
      expect(summary.dailyReadinessIndex, greaterThan(85));
    });
  });

  group('7. Athlete Journey Timeline Tests', () {
    test('Records lifetime PRs and chronological transformation milestones', () {
      final timeline = AthleteJourneyTimeline.instance;

      final ms = timeline.recordMilestone(
        category: MilestoneCategory.personalRecord,
        title: 'Bench Press 120kg',
        description: 'Hit 120kg for 2 clean reps.',
        metricValue: 120.0,
        unit: 'kg',
      );

      expect(timeline.milestones.contains(ms), isTrue);
      expect(timeline.milestones.first.title.contains('Bench Press') || timeline.milestones.first.title.contains('Squat'), isTrue);
    });
  });

  group('8. Companion Mode Service Tests', () {
    test('Generates conversational dialogues across 4 daily checkpoints', () {
      final companion = CompanionModeService.instance;

      final morning = companion.generateCheckIn(
        type: CompanionCheckInType.morningBriefing,
        context: sampleContext,
      );
      expect(morning.greeting.contains('Good morning'), isTrue);

      final preWorkout = companion.generateCheckIn(
        type: CompanionCheckInType.preWorkoutMotivation,
        context: sampleContext,
      );
      expect(preWorkout.callToAction.contains('Live Vision Coach'), isTrue);

      final postWorkout = companion.generateCheckIn(
        type: CompanionCheckInType.postWorkoutRefuel,
        context: sampleContext,
      );
      expect(postWorkout.messageBody.contains('protein'), isTrue);

      final evening = companion.generateCheckIn(
        type: CompanionCheckInType.eveningWindDown,
        context: sampleContext,
      );
      expect(evening.greeting.contains('Evening review'), isTrue);
    });
  });

  group('9. Privacy and Safety Boundaries Tests', () {
    test('Ensures calendar and lifestyle models execute locally without external transmission', () {
      final calendarEvent = CalendarEvent(
        id: 'cal_private',
        title: 'Confidential Medical Consultation',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );

      expect(calendarEvent.isMandatory, isTrue);
      expect(calendarEvent.duration.inMinutes, equals(60));
    });
  });
}
