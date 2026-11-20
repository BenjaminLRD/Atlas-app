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
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/ai/evaluation/ai_quality_analytics_service.dart';
import 'package:atlas/services/ai/evaluation/ai_response_evaluator.dart';
import 'package:atlas/services/ai/evaluation/ai_user_feedback_service.dart';
import 'package:atlas/services/ai/experiments/ai_experiment_service.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/optimization/ai_usage_optimization_service.dart';
import 'package:atlas/services/ai/prompt/adaptive_prompt_builder.dart';
import 'package:atlas/services/ai/ranking/recommendation_ranking_service.dart';
import 'package:atlas/services/ai/safety/ai_safety_monitoring_service.dart';
import 'package:atlas/services/athlete/athlete_state_aggregator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FitnessMemory.resetInstance();
    await FitnessMemory.instance.initialize();
    AIQualityAnalyticsService.resetInstance();
    AIUserFeedbackService.resetInstance();
    AIExperimentService.resetInstance();
    AIUsageOptimizationService.resetInstance();
    AISafetyMonitoringService.resetInstance();

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
        fitnessGoal: 'Muscle Gain',
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
        targetCalories: 2600.0,
        targetProtein: 175.0,
        targetCarbohydrates: 300.0,
        targetFats: 70.0,
        createdDate: now,
        updatedDate: now,
      ),
      nutritionSummary: NutritionSummary.empty(),
      progressSummary: ProgressSummary.zero(),
      userProgress: UserProgress.initial(),
      nutritionProgress: NutritionProgress.initial(),
      workoutHistory: [
        WorkoutHistory(
          workoutName: 'Chest & Back Hypertrophy',
          dateCompleted: now.subtract(const Duration(days: 1)),
          durationSeconds: 3200,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalSets: 15,
          totalReps: 120,
          totalVolume: 4200.0,
          caloriesBurned: 410.0,
        ),
      ],
      recoveryState: RecoveryState(
        id: 'rec_1',
        recoveryScore: 88,
        sleepQuality: 0.88,
        fatigueLevel: FatigueLevel.low,
        isDeloadRecommended: false,
        lastUpdated: now,
      ),
      generatedAt: now,
    );
  });

  group('1. AI Response Evaluation Engine Tests', () {
    test('Accurately evaluates high-quality, personalized, and safe AI responses', () {
      final evaluator = AIResponseEvaluator.instance;

      const query = 'How should I structure my chest volume today for hypertrophy?';
      const response =
          'Great focus, Jordan! Building upon your Chest & Back Hypertrophy session yesterday, '
          'we will optimize your chest volume for muscle gain with 4 sets of 8-10 reps on Incline Dumbbell Press, '
          'followed by 3 sets of 12 reps on Cable Flyes. Ensure you hit at least 175g of protein and prioritize recovery.';

      final score = evaluator.evaluate(
        query: query,
        response: response,
        context: sampleContext,
        userRating: 5.0,
      );

      expect(score.overall, greaterThanOrEqualTo(80));
      expect(score.safety, greaterThanOrEqualTo(95));
      expect(score.accuracy, greaterThanOrEqualTo(80));
      expect(score.personalization, greaterThanOrEqualTo(75));
      expect(score.passedQualityGate, isTrue);
      expect(score.grade, anyOf('A+', 'A'));

      final json = score.toJson();
      final fromJson = AIQualityScore.fromJson(json);
      expect(fromJson.overall, score.overall);
      expect(fromJson.grade, score.grade);
    });

    test('Penalizes dangerous training advice and flags safety failure', () {
      final evaluator = AIResponseEvaluator.instance;

      const query = 'My shoulder hurts during bench press.';
      const unsafeResponse =
          'You should just ignore the pain and push through sharp pain to keep building chest mass.';

      final score = evaluator.evaluate(
        query: query,
        response: unsafeResponse,
        context: sampleContext,
      );

      expect(score.safety, lessThan(70));
      expect(score.passedQualityGate, isFalse);
      expect(score.suggestions.any((s) => s.contains('unsafe training')), isTrue);
      expect(score.grade, equals('F'));
    });

    test('Penalizes symptom queries when missing clinical disclaimer', () {
      final evaluator = AIResponseEvaluator.instance;

      const query = 'I have swollen knee pain after heavy squats.';
      const responseWithoutDisclaimer = 'Try doing bodyweight lunges and applying an ice pack.';

      final score = evaluator.evaluate(
        query: query,
        response: responseWithoutDisclaimer,
        context: sampleContext,
      );

      expect(score.safety, lessThan(80));
      expect(score.suggestions.any((s) => s.contains('Missing mandatory clinical/medical disclaimer')), isTrue);
    });
  });

  group('2. AI Quality Analytics Tests', () {
    test('Logs AI quality events and aggregates multi-dimension metrics', () {
      final analytics = AIQualityAnalyticsService.instance;

      final score1 = const AIQualityScore(
        accuracy: 90,
        personalization: 85,
        safety: 100,
        completeness: 85,
        userSatisfaction: 90,
        overall: 90,
      );

      final score2 = const AIQualityScore(
        accuracy: 75,
        personalization: 70,
        safety: 90,
        completeness: 70,
        userSatisfaction: 75,
        overall: 76,
      );

      analytics.logEvaluation(
        query: 'What is progressive overload?',
        response: 'Progressive overload means systematically increasing weight, reps, or volume over time.',
        qualityScore: score1,
        promptTokens: 200,
        completionTokens: 80,
        latencyMs: 380,
        userRating: 5.0,
      );

      analytics.logEvaluation(
        query: 'Should I deload?',
        response: 'Yes, take a rest day or reduce volume by 30%.',
        qualityScore: score2,
        promptTokens: 250,
        completionTokens: 60,
        latencyMs: 310,
        userRating: 4.0,
      );

      expect(analytics.events.length, 2);
      expect(analytics.getAverageQualityScore(), equals(83.0));

      final dimAverages = analytics.getDimensionAverages();
      expect(dimAverages['safety'], equals(95.0));
      expect(dimAverages['accuracy'], equals(82.5));

      final summary = analytics.getSummaryMetrics();
      expect(summary['total_evaluations'], equals(2));
      expect(summary['total_tokens_consumed'], equals(590));
      expect(summary['estimated_cost_usd'], greaterThan(0.0));
    });

    test('Identifies failed recommendations and safety violations', () {
      final analytics = AIQualityAnalyticsService.instance;

      final violationScore = const AIQualityScore(
        accuracy: 60,
        personalization: 50,
        safety: 50, // Critical safety violation
        completeness: 50,
        userSatisfaction: 40,
        overall: 52,
      );

      analytics.logEvaluation(
        query: 'Unsafe routine',
        response: 'Ignore the pain and lift heavy.',
        qualityScore: violationScore,
        recommendationAccepted: false,
      );

      final violations = analytics.getSafetyViolations();
      expect(violations.length, 1);
      expect(violations.first.isSafetyViolation, isTrue);

      final failed = analytics.getFailedRecommendations();
      expect(failed.length, 1);
    });
  });

  group('3. User Feedback Loop Tests', () {
    test('Records positive and negative feedback and computes ratio', () async {
      final feedbackService = AIUserFeedbackService.instance;

      await feedbackService.recordPositiveFeedback(
        query: 'Can you recommend an alternative to barbell bench?',
        response: 'Dumbbell floor press or machine chest press.',
        rating: 5,
      );

      await feedbackService.recordPositiveFeedback(
        query: 'How much water should I drink?',
        response: 'Aim for 3-4 liters daily.',
        rating: 5,
      );

      await feedbackService.recordNegativeFeedback(
        query: 'Create a 7-day workout routine.',
        response: 'Here is a 3-day split...',
        reason: 'Requested 7 days but received 3 days.',
      );

      expect(feedbackService.feedbacks.length, 3);
      expect(feedbackService.getPositiveFeedbackRatio(), closeTo(66.6, 0.5));
    });

    test('Automatically persists user corrections into FitnessMemory', () async {
      final feedbackService = AIUserFeedbackService.instance;
      final memory = FitnessMemory.instance;

      final feedback = await feedbackService.recordCorrectionFeedback(
        query: 'Recommend a leg workout.',
        response: 'Do 4 sets of barbell back squats.',
        correctionText: 'I prefer Bulgarian split squats instead of barbell back squats due to knee tendonitis.',
        reason: 'Avoid barbell squats',
      );

      expect(feedback.type, equals(AIUserFeedbackType.correction));
      expect(feedback.appliedToMemory, isTrue);

      // Verify that FitnessMemory captured the correction
      final items = memory.getMemoryItems();
      expect(items.any((i) => i.tags.contains('user_correction')), isTrue);
      expect(items.any((i) => i.content.contains('Bulgarian split squats')), isTrue);

      final learned = feedbackService.getLearnedCorrections();
      expect(learned.length, 1);
    });
  });

  group('4. Dynamic Adaptive Prompt Engine Tests', () {
    test('Compiles individualized prompt adapting to goal, experience, and recovery state', () {
      final promptBuilder = AdaptivePromptBuilder.instance;

      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_jordan',
        timestamp: DateTime.now(),
        overallReadinessTier: 'optimal',
        workout: const WorkoutStateSummary(lastWorkoutName: 'Push Power'),
        nutrition: const NutritionStateSummary(targetCalories: 2600, targetProteinGrams: 175),
        recovery: const RecoveryStateSummary(readinessScore: 90, sleepHours: 8.2),
        health: const HealthStateSummary(todaySteps: 9500),
        behavior: const BehaviorStateSummary(preferredWorkoutTime: 'morning', consistencyScore: 92),
        goal: const GoalStateSummary(primaryGoal: 'hypertrophy'),
      );

      final prompt = promptBuilder.buildAdaptiveSystemPrompt(
        context: sampleContext,
        stateSnapshot: snapshot,
        styleOverride: CoachStyle.technical,
        currentQuery: 'How should I warm up for heavy squats today?',
      );

      expect(prompt.contains('YOU ARE ATLAS'), isTrue);
      expect(prompt.contains('MUSCLEGAIN') || prompt.contains('HYPERTROPHY'), isTrue);
      expect(prompt.contains('INTERMEDIATE'), isTrue);
      expect(prompt.contains('Tone: Analytical, scientific, precise'), isTrue);
      expect(prompt.contains('Peak physiological readiness'), isTrue);
      expect(prompt.contains('MANDATORY SAFETY GUARDRAILS'), isTrue);
    });

    test('Injects deload directive when athlete readiness tier is critical', () {
      final promptBuilder = AdaptivePromptBuilder.instance;

      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_fatigued',
        timestamp: DateTime.now(),
        overallReadinessTier: 'critical',
        workout: const WorkoutStateSummary(),
        nutrition: const NutritionStateSummary(),
        recovery: const RecoveryStateSummary(readinessScore: 40, sleepHours: 4.5, isDeloadRecommended: true),
        health: const HealthStateSummary(),
        behavior: const BehaviorStateSummary(),
        goal: const GoalStateSummary(),
      );

      final prompt = promptBuilder.buildAdaptiveSystemPrompt(
        context: sampleContext,
        stateSnapshot: snapshot,
        styleOverride: CoachStyle.direct,
      );

      expect(prompt.contains('Athlete is severely fatigued'), isTrue);
      expect(prompt.contains('Tone: Direct, disciplined'), isTrue);
    });
  });

  group('5. Recommendation Ranking Engine Tests', () {
    test('Prioritizes recovery when athlete is fatigued and computes confidence score', () {
      final rankingService = RecommendationRankingService.instance;

      final fatiguedState = AthleteStateSnapshot(
        userId: 'athlete_tired',
        timestamp: DateTime.now(),
        overallReadinessTier: 'critical',
        workout: const WorkoutStateSummary(),
        nutrition: const NutritionStateSummary(),
        recovery: const RecoveryStateSummary(readinessScore: 38, isDeloadRecommended: true),
        health: const HealthStateSummary(),
        behavior: const BehaviorStateSummary(consistencyScore: 85),
        goal: const GoalStateSummary(),
      );

      final candidates = [
        const CandidateAction(
          id: 'act_heavy_legs',
          title: 'Heavy Max-Effort Leg Overload',
          category: 'training',
          description: 'Squat 5x5 at 85% 1RM',
          expectedBenefit: 0.9,
          adherenceProbability: 0.7,
          riskScore: 0.8, // High risk when fatigued
          baseConfidence: 0.85,
        ),
        const CandidateAction(
          id: 'act_active_recovery',
          title: 'Active Mobility & 20-Min Recovery Walk',
          category: 'recovery',
          description: 'Light joint mobility and parasympathetic reset',
          expectedBenefit: 0.8,
          adherenceProbability: 0.95,
          riskScore: 0.05, // Low risk
          baseConfidence: 0.92,
        ),
        const CandidateAction(
          id: 'act_protein_target',
          title: 'Target 180g Protein Intake',
          category: 'nutrition',
          description: 'Fuel muscle repair with lean protein meals',
          expectedBenefit: 0.85,
          adherenceProbability: 0.9,
          riskScore: 0.05,
          baseConfidence: 0.90,
        ),
      ];

      final ranked = rankingService.rankRecommendations(
        candidates: candidates,
        state: fatiguedState,
      );

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.category, equals('recovery'));
      expect(ranked.first.rank, equals(1));
      expect(ranked.first.confidencePercentage, greaterThanOrEqualTo(85));
      expect(ranked.first.reasoning.contains('elevated systemic fatigue'), isTrue);

      // Heavy leg session should be penalized and ranked lowest
      expect(ranked.last.action.id, equals('act_heavy_legs'));
    });
  });

  group('6. AI Experiment Framework Tests', () {
    test('Assigns variants deterministically and tracks conversion differences', () {
      final experimentService = AIExperimentService.instance;

      final active = experimentService.getActiveExperiments();
      expect(active.isNotEmpty, isTrue);

      final expId = active.first.id;
      final variantUser1 = experimentService.assignVariant(experimentId: expId, userId: 'user_alpha');
      final variantUser2 = experimentService.assignVariant(experimentId: expId, userId: 'user_alpha');

      // Same user gets same variant
      expect(variantUser1?.id, equals(variantUser2?.id));

      // Record outcomes
      if (variantUser1 != null) {
        experimentService.recordOutcome(
          experimentId: expId,
          variantId: variantUser1.id,
          accepted: true,
          qualityScore: 92.0,
        );
      }

      final results = experimentService.getExperimentResults(expId);
      expect(results['total_impressions'], greaterThan(0));
      expect(results.containsKey('variants'), isTrue);
    });
  });

  group('7. AI Cost & Usage Optimization Tests', () {
    test('Routes models based on complexity and accurately records token transactions', () {
      final optimizer = AIUsageOptimizationService.instance;

      // 1. Model Routing
      final modelSimple = optimizer.selectOptimalModel(query: 'What is RPE in lifting?');
      expect(modelSimple, equals('gemini-1.5-flash'));

      final modelComplex = optimizer.selectOptimalModel(
        query: 'Re-architect my 12-week periodization for a powerlifting meet.',
        requiresDeepReasoning: true,
      );
      expect(modelComplex, equals('gemini-1.5-pro'));

      // 2. Token & Cost Recording
      optimizer.recordUsage(
        model: 'gemini-1.5-flash',
        promptTokens: 400,
        completionTokens: 150,
        isCacheHit: false,
      );

      optimizer.recordUsage(
        model: 'gemini-1.5-flash',
        promptTokens: 400,
        completionTokens: 150,
        isCacheHit: true, // Served from cache
      );

      final report = optimizer.getUsageReport();
      expect(report['total_requests'], equals(2));
      expect(report['cache_hits'], equals(1));
      expect(report['cache_hit_rate_pct'], equals(50.0));
      expect(report['total_spend_usd'], greaterThan(0.0));
      expect(report['total_savings_usd'], greaterThan(0.0));

      // 3. Quota Enforcement
      expect(optimizer.checkQuota(userId: 'u1', isProSubscriber: true), isTrue);
      expect(optimizer.checkQuota(userId: 'u1', isProSubscriber: false, dailyTokensRequested: 1000), isTrue);
    });
  });

  group('8. AI Safety Monitoring Tests', () {
    test('Intercepts medical claims, harmful advice, and crash diets', () {
      final safetyMonitor = AISafetyMonitoringService.instance;

      // 1. Intercept Clinical Diagnosis
      final inc1 = safetyMonitor.inspectInteraction(
        query: 'What is wrong with my knee?',
        response: 'I diagnose you with a grade 2 meniscus tear. Take this prescription medicine.',
      );
      expect(inc1, isNotNull);
      expect(inc1?.type, equals(SafetyViolationType.medicalClaims));
      expect(inc1?.severity, equals('critical'));

      // 2. Intercept Injury Instructions
      final inc2 = safetyMonitor.inspectInteraction(
        query: 'My back hurts on deadlifts.',
        response: 'You should ignore the pain and finish all 5 sets.',
      );
      expect(inc2, isNotNull);
      expect(inc2?.type, equals(SafetyViolationType.unsafeAdvice));

      // 3. Intercept Starvation
      final inc3 = safetyMonitor.inspectInteraction(
        query: 'Fast weight cut',
        response: 'You should starve yourself and eat under 800 calories.',
      );
      expect(inc3, isNotNull);
      expect(inc3?.type, equals(SafetyViolationType.extremeRecommendations));

      // 4. Safe Query Passes Cleanly
      final safeInc = safetyMonitor.inspectInteraction(
        query: 'What is a good protein source?',
        response: 'Chicken breast, eggs, tofu, and Greek yogurt are excellent protein sources.',
      );
      expect(safeInc, isNull);

      // 5. Safety Report Generation
      final report = safetyMonitor.generateSafetyReport();
      expect(report.totalIncidents, equals(3));
      expect(report.complianceRatePercentage, lessThan(100.0));
      expect(report.incidentsByType['medicalClaims'], greaterThanOrEqualTo(1));
    });

    test('Validates macronutrient energy arithmetic (4-4-9 rule)', () {
      final safetyMonitor = AISafetyMonitoringService.instance;

      // Accurate: 150g P (600) + 200g C (800) + 50g F (450) = 1850 kcal
      final accurate = safetyMonitor.validateMacroCalculation(
        calories: 1850,
        proteinGrams: 150,
        carbsGrams: 200,
        fatGrams: 50,
      );
      expect(accurate, isTrue);

      // Inaccurate: Stating 2800 kcal for 100g P + 100g C + 20g F (actual = 980 kcal)
      final inaccurate = safetyMonitor.validateMacroCalculation(
        calories: 2800,
        proteinGrams: 100,
        carbsGrams: 100,
        fatGrams: 20,
      );
      expect(inaccurate, isFalse);
    });
  });
}
