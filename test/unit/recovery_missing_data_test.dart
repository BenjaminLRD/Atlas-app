import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/health_metrics.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/recovery/readiness_inputs.dart';
import 'package:atlas/models/recovery/recovery_report.dart';
import 'package:atlas/models/recovery/training_readiness_score.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/recovery_summary.dart';
import 'package:atlas/models/training_state.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/coach_notification_engine.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/daily_coach_brief_service.dart';
import 'package:atlas/services/ai/decision_engine/coach_decision_engine.dart';
import 'package:atlas/services/ai/tools/health_tool.dart';
import 'package:atlas/services/ai/workout_intelligence_engine.dart';
import 'package:atlas/services/athlete/athlete_state_aggregator.dart';
import 'package:atlas/services/health/health_service.dart';
import 'package:atlas/services/health/recovery_service.dart';
import 'package:atlas/services/recovery/health_prediction_engine.dart';
import 'package:atlas/services/recovery/recovery_prediction_engine.dart';
import 'package:atlas/services/recovery_intelligence_service.dart';
import 'package:atlas/services/training_intelligence_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_health_service.dart';

WorkoutHistory workout(int daysAgo) => WorkoutHistory(
  workoutName: 'Session $daysAgo',
  dateCompleted: DateTime.now().subtract(Duration(days: daysAgo)),
  durationSeconds: 3600,
  totalVolume: 5000.0,
  caloriesBurned: 400,
  exercisesCompleted: 5,
  completionPercentage: 1.0,
);

FitnessContext context({RecoveryState? recovery, HealthMetric? health}) =>
    FitnessContext.initial().copyWith(
      recoveryState: recovery,
      todayHealthMetric: health,
    );

class _EmptyHealthService implements HealthService {
  @override
  Future<bool> hasPermissions() async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> isProviderAvailable() async => true;
  @override
  Future<HealthMetric> getTodayHealthMetric() async => HealthMetric.zero();
  @override
  Future<List<HealthMetric>> getWeeklyHealthHistory() async => [];
  @override
  Stream<int?> watchHeartRate() => const Stream.empty();
  @override
  Future<void> updateHealthMetric(HealthMetric metric) async {}
}

class _CountingModel implements HealthMLModel {
  int calls = 0;
  @override
  Future<double> predictReadinessScore(List<double> featureVector) async {
    calls++;
    return 50;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HealthService.resetInstance();
  });

  group('ReadinessInputs: what counts as recorded', () {
    test('nothing recorded: no basis', () {
      final i = ReadinessInputs.fromMetrics(null);
      expect(i.basis, ReadinessBasis.none);
      expect(i.hasPhysiological, isFalse);
      expect(i.missingPhysiological, ['sleep', 'HRV', 'heart rate']);
      expect(i.unavailableReason, contains('sleep or heart-rate'));
    });

    test('workouts alone are training load, not recovery', () {
      final i = ReadinessInputs.fromMetrics(null, hasWorkoutHistory: true);
      expect(i.basis, ReadinessBasis.trainingOnly);
      expect(i.hasPhysiological, isFalse);
    });

    test('a zero reading is missing data, not a measurement', () {
      final i = ReadinessInputs.fromMetrics(
        HealthMetrics(id: 'z', sleepHours: 0, heartRateVariability: 0, restingHeartRate: 0),
      );
      expect(i.hasPhysiological, isFalse);
    });

    test('any one of sleep, HRV or heart rate makes it physiological', () {
      expect(ReadinessInputs.fromMetrics(HealthMetrics(id: 'a', sleepHours: 6)).basis, ReadinessBasis.physiological);
      expect(ReadinessInputs.fromMetrics(HealthMetrics(id: 'b', hrv: 50)).basis, ReadinessBasis.physiological);
      expect(ReadinessInputs.fromMetrics(HealthMetrics(id: 'c', restingHeartRate: 58)).basis, ReadinessBasis.physiological);
      expect(ReadinessInputs.fromMetrics(HealthMetrics(id: 'd', steps: 9000)).basis, ReadinessBasis.none);
    });

    test('missing names list only what is missing', () {
      final i = ReadinessInputs.fromMetrics(HealthMetrics(id: 'a', sleepHours: 7));
      expect(i.missingPhysiological, ['HRV', 'heart rate']);
      expect(ReadinessInputs.joinNames(['sleep', 'HRV', 'heart rate']), 'sleep, HRV and heart rate');
      expect(ReadinessInputs.joinNames(['sleep']), 'sleep');
    });

    test('saved data without inputs reads as not recorded', () {
      expect(ReadinessInputs.fromJson(null).hasPhysiological, isFalse);
      expect(ReadinessInputs.fromJson(const {}).hasPhysiological, isFalse);
      const real = ReadinessInputs(hasSleep: true, hasHrv: true);
      expect(ReadinessInputs.fromJson(real.toJson()).hasHrv, isTrue);
    });
  });

  group('TrainingReadinessScore: missing inputs', () {
    test('no physiological data: unavailable, no score claims', () {
      final s = TrainingReadinessScore.calculate(
        inputs: const ReadinessInputs(hasWorkoutHistory: true),
        workoutRecovery: 95,
        trainingLoadScore: 100,
      );
      expect(s.isAvailable, isFalse);
      expect(s.status, 'Unavailable');
      expect(s.readinessGrade, 'Unavailable');
      expect(s.isHighReadiness, isFalse);
      expect(s.isLowReadiness, isFalse);
      expect(s.isModerateReadiness, isFalse);
      expect(s.suggestedVolumeMultiplier, 1.0);
      expect(s.sleepContribution, isNull);
      expect(s.hrvContribution, isNull);
      expect(s.explanation, contains('sleep or heart-rate'));
    });

    test('missing HRV: the score uses the known factors only', () {
      final s = TrainingReadinessScore.calculate(
        inputs: const ReadinessInputs(hasSleep: true),
        sleepScore: 100,
      );
      expect(s.isAvailable, isTrue);
      expect(s.score, 100.0); // not dragged down by an HRV that was never read
      expect(s.hrvContribution, isNull);
      expect(s.explanation, contains('Not recorded: HRV and heart rate'));
    });

    test('missing sleep: the score uses the HRV factor only', () {
      final s = TrainingReadinessScore.calculate(
        inputs: const ReadinessInputs(hasHrv: true),
        hrvScore: 60,
      );
      expect(s.score, 60.0);
      expect(s.sleepContribution, isNull);
      expect(s.explanation, contains('sleep'));
    });

    test('weights are rescaled over the known factors', () {
      final s = TrainingReadinessScore.calculate(
        inputs: const ReadinessInputs(hasSleep: true, hasWorkoutHistory: true),
        workoutRecovery: 80, // weight 0.30
        sleepScore: 40, // weight 0.25
      );
      expect(s.score, closeTo((80 * 0.30 + 40 * 0.25) / 0.55, 0.05));
    });

    test('a stored result from before inputs were recorded is unavailable', () {
      final old = TrainingReadinessScore.fromJson({
        'score': 80.0,
        'status': 'Ready to Train',
        'readinessGrade': 'Optimal',
        'sleepContribution': 80.0,
      });
      expect(old.isAvailable, isFalse);
      expect(old.status, 'Unavailable');
    });

    test('a measured result survives a JSON round trip', () {
      final s = TrainingReadinessScore.calculate(
        inputs: const ReadinessInputs(hasSleep: true),
        sleepScore: 85,
      );
      final back = TrainingReadinessScore.fromJson(s.toJson());
      expect(back.isAvailable, isTrue);
      expect(back.score, s.score);
      expect(back.hrvContribution, isNull);
    });
  });

  group('RecoveryPredictionEngine: missing sleep, HRV and incomplete inputs', () {
    const engine = RecoveryPredictionEngine();

    test('no data at all: unavailable, unknown fatigue, no deload', () {
      final r = engine.analyzeReadiness(userId: 'u', workoutHistory: const []);
      expect(r.readinessScore.isAvailable, isFalse);
      expect(r.fatigueLevel, 'unknown');
      expect(r.isDeloadRecommended, isFalse);
      expect(r.suggestedVolumeAdjustmentPercent, 0.0);
      expect(r.hasTrainingHistory, isFalse);
      expect(r.recommendation, startsWith('No recommendation yet'));
      expect(r.trainHardAnswer, startsWith('Can\'t tell yet'));
      expect(r.readinessScore.workoutRecoveryContribution, isNull);
      expect(r.readinessScore.trainingLoadContribution, isNull);
      expect(r.readinessScore.nutritionContribution, isNull);
    });

    test('workouts but no sleep or heart data: still unavailable, load is real', () {
      final r = engine.analyzeReadiness(
        userId: 'u',
        workoutHistory: [workout(1), workout(3)],
      );
      expect(r.readinessScore.isAvailable, isFalse);
      expect(r.hasTrainingHistory, isTrue);
      expect(r.readinessScore.workoutRecoveryContribution, isNotNull);
      expect(r.fatigueLevel, 'unknown');
    });

    test('sleep without HRV: available, HRV factor missing, not neutral', () {
      final r = engine.analyzeReadiness(
        userId: 'u',
        workoutHistory: const [],
        healthMetrics: HealthMetrics(id: 'm', sleepHours: 8.5),
      );
      expect(r.readinessScore.isAvailable, isTrue);
      expect(r.readinessScore.sleepContribution, 100.0);
      expect(r.readinessScore.hrvContribution, isNull);
      expect(r.readinessScore.score, 100.0);
      expect(r.fatigueLevel, 'low');
    });

    test('HRV without sleep: available, sleep factor missing', () {
      final r = engine.analyzeReadiness(
        userId: 'u',
        workoutHistory: const [],
        healthMetrics: HealthMetrics(id: 'm', hrv: 72),
      );
      expect(r.readinessScore.isAvailable, isTrue);
      expect(r.readinessScore.sleepContribution, isNull);
      expect(r.readinessScore.hrvContribution, 100.0);
    });

    test('real low sleep still lowers readiness and adds a risk factor', () {
      final r = engine.analyzeReadiness(
        userId: 'u',
        workoutHistory: const [],
        healthMetrics: HealthMetrics(id: 'm', sleepHours: 5.5),
      );
      expect(r.readinessScore.sleepContribution, 40.0);
      expect(r.riskFactors.any((f) => f.contains('Sub-optimal sleep')), isTrue);
      expect(r.readinessScore.score, 40.0);
      expect(r.isDeloadRecommended, isTrue);
    });

    test('a day with nothing logged is not under-fueling', () {
      const empty = DailyNutrition(
        date: '2026-11-14',
        targets: MacroTarget(calories: 2200, proteinGrams: 140, carbsGrams: 250, fatGrams: 70),
        meals: [],
      );
      final r = engine.analyzeReadiness(
        userId: 'u',
        workoutHistory: const [],
        healthMetrics: HealthMetrics(id: 'm', sleepHours: 8),
        todayNutrition: empty,
      );
      expect(r.readinessScore.nutritionContribution, isNull);
      expect(r.riskFactors.any((f) => f.contains('Under-fueling')), isFalse);
    });

    test('the unavailable report survives JSON and stays unavailable', () {
      final r = engine.analyzeReadiness(userId: 'u', workoutHistory: const []);
      final back = RecoveryReport.fromJson(r.toJson());
      expect(back.readinessScore.isAvailable, isFalse);
      expect(back.fatigueLevel, 'unknown');
      expect(back.hasTrainingHistory, isFalse);
      // Reports saved before this change have no inputs at all.
      final old = RecoveryReport.fromJson({
        'readinessScore': {'score': 82.0, 'status': 'Ready to Train', 'readinessGrade': 'Optimal'},
        'fatigueLevel': 'low',
      });
      expect(old.readinessScore.isAvailable, isFalse);
    });
  });

  group('HealthPredictionEngine: the ML model only sees real measurements', () {
    test('no sleep or HRV: the model is not run', () async {
      final model = _CountingModel();
      final engine = HealthPredictionEngine(mlModel: model);
      await engine.predictRecoveryAndReadiness(
        userId: 'u',
        workoutHistory: [workout(1)],
        healthMetrics: HealthMetrics(id: 'm', sleepHours: 7),
      );
      await engine.predictRecoveryAndReadiness(userId: 'u', workoutHistory: [workout(1)]);
      await engine.predictRecoveryAndReadiness(userId: 'u', workoutHistory: const []);
      expect(model.calls, 0);
    });

    test('sleep, HRV and workouts all recorded: the model runs', () async {
      final model = _CountingModel();
      final engine = HealthPredictionEngine(mlModel: model);
      await engine.predictRecoveryAndReadiness(
        userId: 'u',
        workoutHistory: [workout(1)],
        healthMetrics: HealthMetrics(id: 'm', sleepHours: 7, hrv: 60),
      );
      expect(model.calls, 1);
    });
  });

  group('RecoveryService: pillars and unavailable results', () {
    final svc = RecoveryService.instance;

    test('no sleep recorded: no recovery score', () {
      final b = svc.calculateRecovery(consecutiveTrainingDays: 2, stepsToday: 9000, restDaysLast7Days: 2);
      expect(b.isAvailable, isFalse);
      expect(b.totalScore, isNull);
      expect(b.sleepComponent, isNull);
      expect(b.formattedSummary, 'Recovery unavailable');
      expect(b.shouldReduceVolume, isFalse);
      expect(b.recommendation, contains('Record sleep'));
      // The other pillars are still reported where they are known.
      expect(b.trainingComponent, 30.0);
      expect(b.activityComponent, 20.0);
    });

    test('nothing recorded: every pillar is null', () {
      final b = svc.calculateRecovery();
      expect(b.totalScore, isNull);
      expect(b.trainingComponent, isNull);
      expect(b.activityComponent, isNull);
      expect(b.restDaysComponent, isNull);
    });

    test('sleep alone is scaled to 100, not diluted by unknown pillars', () {
      final b = svc.calculateRecovery(sleepMinutes: 480);
      expect(b.totalScore, 100);
      expect(b.trainingComponent, isNull);
      expect(b.restDaysComponent, isNull);
      final half = svc.calculateRecovery(sleepMinutes: 240);
      expect(half.totalScore, 43); // 240 min = 17.3 of 40 points, scaled to 100
    });

    test('zero sleep minutes count as not recorded', () {
      expect(svc.calculateRecovery(sleepMinutes: 0).isAvailable, isFalse);
    });

    test('from a health metric: no sleep, no score; no workouts, no training pillars', () {
      final none = svc.calculateFromHealthMetric(HealthMetric(timestamp: DateTime.now()));
      expect(none.isAvailable, isFalse);
      final slept = svc.calculateFromHealthMetric(
        HealthMetric(timestamp: DateTime.now(), sleepMinutes: 450),
        stepsToday: null,
      );
      expect(slept.isAvailable, isTrue);
      expect(slept.trainingComponent, isNull);
      expect(slept.activityComponent, isNull);
    });

    test('training days and rest days come from workout history, unknown when empty', () {
      final now = DateTime(2026, 11, 14, 12);
      expect(RecoveryService.consecutiveTrainingDays(const [], now), isNull);
      expect(RecoveryService.restDaysLast7(const [], now), isNull);
      final w = [
        WorkoutHistory(workoutName: 'a', dateCompleted: DateTime(2026, 11, 14, 8), durationSeconds: 1, exercisesCompleted: 1, completionPercentage: 1),
        WorkoutHistory(workoutName: 'b', dateCompleted: DateTime(2026, 11, 13, 8), durationSeconds: 1, exercisesCompleted: 1, completionPercentage: 1),
        WorkoutHistory(workoutName: 'c', dateCompleted: DateTime(2026, 11, 10, 8), durationSeconds: 1, exercisesCompleted: 1, completionPercentage: 1),
      ];
      expect(RecoveryService.consecutiveTrainingDays(w, now), 2);
      expect(RecoveryService.restDaysLast7(w, now), 4);
    });
  });

  group('Training and recovery state: measured or not', () {
    test('no recorded sleep or heart data: not measured, honest narrative', () {
      final t = TrainingIntelligenceService().analyzeTrainingState(workouts: const []);
      expect(t.isMeasured, isFalse);
      expect(t.recommendation, contains('cannot be judged'));
      expect(t.recommendedIntensity, isNot('heavy_training'));
      final r = RecoveryIntelligenceService().analyzeRecoveryState(trainingState: t);
      expect(r.isMeasured, isFalse);
    });

    test('heavy recent training without recovery data backs off, never boosts', () {
      final heavy = [for (var d = 0; d < 6; d++) workout(d)];
      final t = TrainingIntelligenceService().analyzeTrainingState(workouts: heavy);
      expect(t.isMeasured, isFalse);
      expect(['moderate_training', 'recovery', 'rest'], contains(t.recommendedIntensity));
    });

    test('recorded sleep makes both states measured', () {
      final metrics = HealthMetrics(id: 'm', sleepHours: 8.2);
      final t = TrainingIntelligenceService().analyzeTrainingState(workouts: const [], healthMetrics: metrics, recoveryScore: 85);
      expect(t.isMeasured, isTrue);
      final r = RecoveryIntelligenceService().analyzeRecoveryState(healthMetrics: metrics, trainingState: t);
      expect(r.isMeasured, isTrue);
    });

    test('saved states without inputs read as not measured', () {
      expect(RecoveryState.fromJson({'recovery_score': 90}).isMeasured, isFalse);
      expect(TrainingState.fromJson({'readiness_score': 90, 'recommendation': 'x'}).isMeasured, isFalse);
    });
  });

  group('Daily brief: missing sleep and incomplete inputs', () {
    final service = DailyCoachBriefService();

    test('no health data: the brief says recovery and sleep are unavailable', () {
      final brief = service.generateBrief(context: FitnessContext.initial());
      expect(brief.recovery.isMeasured, isFalse);
      expect(brief.recovery.sleepHours, isNull);
      expect(brief.recovery.scoreOrNull, isNull);
      expect(brief.recovery.readinessCategory, 'Unavailable');
      expect(brief.proactiveMessage, contains('Recovery and sleep are unavailable'));
      expect(brief.proactiveMessage, isNot(contains('slept')));
      expect(brief.proactiveMessage, isNot(contains('7.5')));
      expect(brief.proactiveMessage, isNot(contains('recovery score is')));
    });

    test('no targets set: no invented calorie or protein target', () {
      final brief = service.generateBrief(context: FitnessContext.initial());
      final nutrition = brief.actions.firstWhere((a) => a.category == 'nutrition');
      expect(nutrition.description, isNot(contains('2200')));
      expect(nutrition.description, isNot(contains('150')));
      expect(nutrition.description, contains('Log your meals'));
    });

    test('recorded sleep: quoted exactly, nothing derived from it', () {
      final brief = service.generateBrief(
        context: FitnessContext.initial(),
        healthMetrics: HealthMetrics(id: 'm', sleepHours: 6.46),
      );
      expect(brief.recovery.isMeasured, isTrue);
      expect(brief.recovery.sleepHours, 6.5);
      expect(brief.proactiveMessage, contains('You slept 6.5 hours.'));
    });

    test('HRV recorded but sleep missing: the score exists, sleep is "not available"', () {
      final brief = service.generateBrief(
        context: FitnessContext.initial(),
        healthMetrics: HealthMetrics(id: 'm', hrv: 55),
      );
      expect(brief.recovery.isMeasured, isTrue);
      expect(brief.recovery.sleepHours, isNull);
      expect(brief.proactiveMessage, contains('Sleep is not available.'));
      expect(brief.proactiveMessage, isNot(contains('slept')));
    });

    test('RecoverySummary read from old JSON is unavailable', () {
      final s = RecoverySummary.fromJson({'recovery_score': 82, 'sleep_hours': 7.5, 'status_message': 'Prime'});
      expect(s.isMeasured, isFalse);
      expect(s.readinessCategory, 'Unavailable');
      expect(s.scoreOrNull, isNull);
    });
  });

  group('Coach engines do not act on missing recovery data', () {
    const unmeasured = RecoveryStateSummary();
    AthleteStateSnapshot snapshot(RecoveryStateSummary recovery) => AthleteStateSnapshot(
      userId: 'u',
      timestamp: DateTime(2026, 11, 14, 8),
      overallReadinessTier: recovery.isMeasured ? 'critical' : 'unknown',
      workout: const WorkoutStateSummary(),
      nutrition: const NutritionStateSummary(),
      recovery: recovery,
      health: const HealthStateSummary(),
      behavior: const BehaviorStateSummary(),
      goal: const GoalStateSummary(),
    );

    test('no recovery verdict, no rest day, no volume change', () {
      final d = CoachDecisionEngine().evaluate(snapshot(unmeasured));
      expect(d.recommendRest, isFalse);
      expect(d.volumeMultiplier, 1.0);
      expect(d.reasoning.contains('Recovery cannot be assessed'), isTrue);
    });

    test('a measured critical state still triggers rest', () {
      const critical = RecoveryStateSummary(
        isMeasured: true,
        readinessScore: 30,
        sleepHours: 4.0,
        fatigueLevel: 'critical',
      );
      final d = CoachDecisionEngine().evaluate(snapshot(critical));
      expect(d.recommendRest, isTrue);
      expect(d.reasoning.contains('sleep at 4.0h'), isTrue);
    });

    test('measured by HRV only: sleep is reported as not recorded', () {
      const hrvOnly = RecoveryStateSummary(isMeasured: true, readinessScore: 40, hrvAverage: 30, fatigueLevel: 'critical');
      final d = CoachDecisionEngine().evaluate(snapshot(hrvOnly));
      expect(d.reasoning.contains('sleep not recorded'), isTrue);
    });

    test('no recovery warning notification without recovery data', () {
      final n = CoachNotificationEngine().generateNotifications(state: snapshot(unmeasured));
      expect(n.where((x) => x.title.contains('Recovery')), isEmpty);
    });

    test('the athlete snapshot prompt says readiness is unavailable', () {
      final text = snapshot(unmeasured).toPromptContext();
      expect(text, contains('Readiness: unavailable'));
      expect(text, contains('Sleep: not recorded'));
      expect(text, isNot(contains('Score:')));
    });

    test('recovery summary JSON round trip keeps measured state and nulls', () {
      final back = RecoveryStateSummary.fromJson(unmeasured.toJson());
      expect(back.isMeasured, isFalse);
      expect(back.sleepHours, isNull);
      expect(back.fatigueLevel, 'unknown');
      expect(RecoveryStateSummary.fromJson({'readiness_score': 90, 'fatigue_level': 'low'}).isMeasured, isFalse);
    });
  });

  group('Chatbot: recovery answers and AI tools', () {
    test('the direct recovery answer does not invent a score', () {
      final decision = AIRequestRouter.instance.route(
        message: 'what is my recovery score',
        context: context(recovery: RecoveryState(id: 'r', lastUpdated: DateTime.now())),
      );
      expect(decision.isDirectAnswer, isTrue);
      expect(decision.directResponse, contains('I do not have a recovery score'));
      expect(decision.directResponse, isNot(contains('%')));
      expect(decision.directResponse, isNot(contains('prime state')));
    });

    test('the direct recovery answer quotes a measured score and recorded sleep', () {
      final decision = AIRequestRouter.instance.route(
        message: 'what is my recovery score',
        context: context(
          recovery: RecoveryState(
            id: 'r',
            inputs: const ReadinessInputs(hasSleep: true),
            recoveryScore: 88,
            lastUpdated: DateTime.now(),
          ),
          health: HealthMetric(timestamp: DateTime.now(), sleepMinutes: 450),
        ),
      );
      expect(decision.directResponse, contains('**88%**'));
      expect(decision.directResponse, contains('7h 30m'));
    });

    test('the coach prompt marks recovery as not recorded without data', () {
      const builder = CoachPromptBuilder();
      final prompt = builder.buildPrompt(
        message: 'how is my recovery?',
        context: context(recovery: RecoveryState(id: 'r', lastUpdated: DateTime.now())),
      );
      expect(prompt, contains('Recovery Score: not recorded'));
      expect(prompt, contains('Training Readiness: unavailable'));
      expect(prompt, contains('Sleep: not recorded'));
      expect(prompt, isNot(contains('Recovery Score: 80%')));
    });

    test('the coach prompt quotes a measured score', () {
      const builder = CoachPromptBuilder();
      final prompt = builder.buildPrompt(
        message: 'how is my recovery?',
        context: context(
          recovery: RecoveryState(
            id: 'r',
            inputs: const ReadinessInputs(hasSleep: true),
            recoveryScore: 91,
            lastUpdated: DateTime.now(),
          ),
          health: HealthMetric(timestamp: DateTime.now(), sleepMinutes: 480),
        ),
      );
      expect(prompt, contains('Recovery Score: 91%'));
      expect(prompt, contains('Sleep: 8h 0m'));
    });

    test('get_recovery_score separates unavailable from measured', () async {
      HealthService.setInstance(_EmptyHealthService());
      final none = await HealthTool().execute({'action': 'get_recovery_score'});
      expect(none['readiness_available'], isFalse);
      expect(none['recovery_score'], isNull);
      expect(none['readiness_tier'], 'Unavailable');
      expect(none['recommendation'], contains('Do not estimate'));

      HealthService.setInstance(MockHealthService()); // a recorded night of sleep
      final some = await HealthTool().execute({'action': 'get_recovery_score'});
      expect(some['readiness_available'], isTrue);
      expect(some['recovery_score'], isA<int>());
    });
  });

  group('Workout intelligence without recovery data', () {
    test('no recovery score: the plan is not checked against recovery', () {
      final report = WorkoutIntelligenceEngine().evaluateWorkout(
        exercises: [
          {'id': 'bench', 'name': 'Barbell Bench Press', 'muscleGroup': 'Chest', 'equipment': 'Barbell', 'exerciseType': 'compound', 'sets': 3, 'reps': 8},
        ],
        focus: 'push',
        durationMinutes: 45,
      );
      expect(report.recoveryCompatibilityScore, isNull);
      expect(report.aiExplanation.any((e) => e.contains('not adjusted for recovery')), isTrue);
      expect(report.overallScore, inInclusiveRange(0, 100));
    });
  });
}
