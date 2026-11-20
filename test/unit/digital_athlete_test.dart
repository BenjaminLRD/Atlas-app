import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/digital_athlete.dart';
import 'package:atlas/models/exercise_form_report.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/athlete/athlete_state_engine.dart';
import 'package:atlas/services/athlete/biomechanics_analysis_service.dart';
import 'package:atlas/services/athlete/goal_prediction_engine.dart';
import 'package:atlas/services/athlete/insight_generation_service.dart';
import 'package:atlas/services/athlete/strength_prediction_engine.dart';
import 'package:atlas/services/supabase/database_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Atlas Digital Athlete Intelligence & Advanced AI Learning (Phase F.3)', () {
    test(
      '1. DigitalAthlete model serialization, deserialization, and copyWith roundtrip',
      () {
        final athlete = DigitalAthlete.initial('user_digital_01');

        expect(athlete.userId, equals('user_digital_01'));
        expect(athlete.physicalProfile.weightKg, equals(75.0));
        expect(athlete.strengthProfile.estimated1RM['Squat'], equals(130.0));
        expect(
          athlete.trainingProfile.trainingPersonality,
          equals('Methodical Powerbuilder'),
        );
        expect(athlete.recoveryProfile.averageRecoveryScore, equals(84.0));
        expect(athlete.nutritionProfile.adherenceRate, equals(0.92));
        expect(athlete.behaviorProfile.preferredWorkoutTime, equals('evening'));

        final json = athlete.toJson();
        final fromJson = DigitalAthlete.fromJson(json);

        expect(fromJson.userId, equals(athlete.userId));
        expect(
          fromJson.physicalProfile.age,
          equals(athlete.physicalProfile.age),
        );
        expect(
          fromJson.strengthProfile.strengthLevel,
          equals(athlete.strengthProfile.strengthLevel),
        );
        expect(
          fromJson.trainingProfile.preferredSplit,
          equals(athlete.trainingProfile.preferredSplit),
        );

        final modified = athlete.copyWith(
          physicalProfile: athlete.physicalProfile.copyWith(weightKg: 77.5),
          strengthProfile: athlete.strengthProfile.copyWith(
            progressionVelocityPercentage: 5.2,
          ),
        );
        expect(modified.physicalProfile.weightKg, equals(77.5));
        expect(
          modified.strengthProfile.progressionVelocityPercentage,
          equals(5.2),
        );
      },
    );

    test(
      '2. AthleteStateEngine updates digital twin across workout, nutrition, recovery, form, and conversation',
      () {
        final engine = AthleteStateEngine.instance;
        const testUser = 'user_digital_state_01';

        // 1. After workout update
        final athleteAfterWorkout = engine.updateAfterWorkout(
          userId: testUser,
          workoutName: 'Heavy Leg Day',
          split: 'Lower',
          totalVolumeKg: 14500.0,
          durationMinutes: 60,
          liftPerformances: {'Squat': 142.5},
          progressionRate: 0.04,
        );
        expect(
          athleteAfterWorkout.strengthProfile.estimated1RM['Squat'],
          equals(142.5),
        );
        expect(
          athleteAfterWorkout.trainingProfile.preferredSplit,
          equals('Lower'),
        );
        expect(
          athleteAfterWorkout.behaviorProfile.consistencyScore,
          greaterThan(90.0),
        );

        // 2. After nutrition update
        final athleteAfterNutrition = engine.updateAfterNutrition(
          userId: testUser,
          caloriesConsumed: 2750,
          proteinGrams: 185.0,
          carbsGrams: 320.0,
          fatGrams: 80.0,
          adherenceRate: 0.96,
        );
        expect(
          athleteAfterNutrition.nutritionProfile.dailyProteinGrams,
          greaterThan(175.0),
        );
        expect(
          athleteAfterNutrition.nutritionProfile.adherenceRate,
          greaterThan(0.90),
        );

        // 3. After recovery update
        final athleteAfterRecovery = engine.updateAfterRecovery(
          userId: testUser,
          sleepHours: 8.2,
          hrvScore: 74.0,
          restingHeartRate: 54,
          recoveryScore: 92.0,
        );
        expect(
          athleteAfterRecovery.recoveryProfile.averageRecoveryScore,
          greaterThan(85.0),
        );
        expect(
          athleteAfterRecovery.recoveryProfile.sleepDurationHours,
          greaterThan(7.7),
        );

        // 4. After form analysis report
        final formReport = ExerciseFormReport(
          id: 'report_squat_01',
          userId: testUser,
          exerciseName: 'Squat',
          videoPath: '/mock/squat.mp4',
          score: const FormScore(
            overallScore: 86.0,
            techniqueScore: 85.0,
            stabilityScore: 88.0,
            rangeOfMotionScore: 90.0,
            safetyScore: 92.0,
          ),
          detectedIssues: [
            const FormIssue(
              problem: 'Knee valgus under load',
              severity: 'medium',
              solution: 'Focus on pushing knees outward along toe angle during ascent',
            ),
          ],
          createdAt: DateTime.now(),
        );
        final athleteAfterForm = engine.updateAfterFormAnalysis(
          userId: testUser,
          formReport: formReport,
        );
        expect(athleteAfterForm.formScoreAverages['Squat'], isNotNull);
        expect(
          athleteAfterForm.biomechanicsWeaknesses,
          contains('Squat: Knee valgus under load'),
        );

        // 5. After AI conversation
        final athleteAfterAi = engine.updateAfterAiConversation(
          userId: testUser,
          trainingPersonality: 'High-Volume Hypertrophy Enthusiast',
          preferredWorkoutTime: 'morning',
        );
        expect(
          athleteAfterAi.trainingProfile.trainingPersonality,
          equals('High-Volume Hypertrophy Enthusiast'),
        );
        expect(
          athleteAfterAi.behaviorProfile.preferredWorkoutTime,
          equals('morning'),
        );
      },
    );

    test(
      '3. StrengthPredictionEngine forecasts 4, 8, and 12-week compound progression timeline',
      () {
        final engine = StrengthPredictionEngine.instance;
        final athlete = DigitalAthlete.initial('user_pred_01');

        final timeline = engine.predictProgression(athlete);

        expect(timeline.userId, equals('user_pred_01'));
        expect(timeline.predictions, isNotEmpty);
        expect(timeline.overallStrengthVelocity, greaterThan(0));
        expect(
          timeline.progressionPace,
          isIn(['accelerated', 'steady', 'plateaued']),
        );

        final squatPrediction = timeline.predictions.firstWhere(
          (p) => p.exerciseName == 'Squat',
        );
        expect(squatPrediction.current1RMKg, equals(130.0));
        expect(squatPrediction.predicted4WeeksKg, greaterThan(130.0));
        expect(
          squatPrediction.predicted8WeeksKg,
          greaterThan(squatPrediction.predicted4WeeksKg),
        );
        expect(
          squatPrediction.predicted12WeeksKg,
          greaterThan(squatPrediction.predicted8WeeksKg),
        );
        expect(squatPrediction.confidenceScore, greaterThan(0.90));
      },
    );

    test(
      '4. GoalPredictionEngine calculates target completion timeline and achievement probability',
      () {
        final engine = GoalPredictionEngine.instance;
        final athlete = DigitalAthlete.initial('user_goal_01').copyWith(
          goalProfile: const GoalProfile(
            primaryGoal: 'hypertrophy',
            targetWeightKg: 78.0, // current 75.0 -> +3kg
          ),
        );

        final result = engine.predictGoalAchievement(athlete);

        expect(result.currentMetric, equals(75.0));
        expect(result.targetMetric, equals(78.0));
        expect(result.successProbabilityPercentage, greaterThan(70.0));
        expect(result.daysRemaining, greaterThan(0));
        expect(result.keyMilestones.length, equals(3));
        expect(result.recommendedAdjustments, isNotEmpty);
      },
    );

    test(
      '5. BiomechanicsAnalysisService aggregates longitudinal form trends and weakness diagnostics',
      () {
        final service = BiomechanicsAnalysisService.instance;
        final athlete = DigitalAthlete.initial('user_bio_01').copyWith(
          formScoreAverages: {'Squat': 92.0, 'Bench Press': 76.0},
          biomechanicsWeaknesses: ['Bench Press: Excessive elbow flare'],
        );

        final trendReport = service.analyzeBiomechanics(athlete: athlete);

        expect(trendReport.averageFormScore, equals(84.0));
        expect(trendReport.monthOverMonthImprovementPercentage, greaterThan(0));
        expect(
          trendReport.persistentWeaknesses,
          contains('Bench Press: Excessive elbow flare'),
        );
        expect(
          trendReport.technicalStrengths.any((s) => s.contains('Squat')),
          isTrue,
        );
        expect(
          trendReport.correctiveDirectives.any(
            (d) => d.contains('Bench Press'),
          ),
          isTrue,
        );
      },
    );

    test(
      '6. InsightGenerationService generates proactive multi-domain athlete insights',
      () {
        final service = InsightGenerationService.instance;
        final athlete = DigitalAthlete.initial('user_insights_01');

        final insights = service.generateWeeklyInsights(athlete);

        expect(insights.length, greaterThanOrEqualTo(3));
        expect(insights.any((i) => i.category == 'strength'), isTrue);
        expect(insights.any((i) => i.category == 'recovery'), isTrue);
        expect(insights.any((i) => i.category == 'consistency'), isTrue);

        final strengthInsight = insights.firstWhere(
          (i) => i.category == 'strength',
        );
        expect(strengthInsight.title, contains('Squat'));
        expect(strengthInsight.significanceScore, greaterThan(0.85));
      },
    );

    test(
      '7. CoachPromptBuilder injects [DIGITAL ATHLETE PROFILE] and directive 17 into prompts',
      () {
        final builder = const CoachPromptBuilder();
        final context = FitnessContext(
          nutritionSummary: NutritionSummary.empty(),
          progressSummary: ProgressSummary.zero(),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          generatedAt: DateTime.now(),
        );

        final prompt = builder.buildPrompt(
          message: 'How should I structure my chest workouts this month?',
          context: context,
        );

        expect(prompt, contains('[DIGITAL ATHLETE PROFILE]'));
        // No workouts yet: the engine's seeded placeholders (for example a
        // 130 kg squat) must not be presented as the athlete's data.
        expect(prompt, contains('No athlete profile data recorded yet'));
        expect(prompt, isNot(contains('Squat: 130kg')));
        expect(prompt, isNot(contains('Training Personality:')));
        expect(
          prompt,
          contains('Deeply understand the [DIGITAL ATHLETE PROFILE]'),
        );

        // With real workout history the profile lines appear, still without
        // untouched placeholder strength numbers.
        final withHistory = context.copyWith(
          workoutHistory: [
            WorkoutHistory(
              workoutName: 'Push Day',
              dateCompleted: DateTime.now(),
              durationSeconds: 1800,
              exercisesCompleted: 3,
              completionPercentage: 100.0,
            ),
          ],
        );
        final promptWithHistory = builder.buildPrompt(
          message: 'How should I structure my chest workouts this month?',
          context: withHistory,
        );
        expect(promptWithHistory, contains('Training Personality:'));
        expect(promptWithHistory, isNot(contains('Squat: 130kg')));
      },
    );

    test(
      '8. Database models and mappers serialize Digital Athlete tables correctly',
      () {
        // 1. DigitalAthleteProfileData
        final profile = DigitalAthleteProfileData(
          userId: 'usr_db_digital_01',
          physicalProfile: {'weight_kg': 76.0},
          strengthProfile: {
            'estimated_1rm': {'Squat': 135.0},
          },
          updatedAt: DateTime.now(),
        );
        final profileMap = SupabaseModelMappers.digitalAthleteProfileToTable(
          profile,
        );
        expect(profileMap['user_id'], equals('usr_db_digital_01'));
        expect(profileMap['physical_profile']['weight_kg'], equals(76.0));

        // 2. AthleteInsightData
        final insight = AthleteInsightData(
          id: 'ins_01',
          userId: 'usr_db_digital_01',
          category: 'strength',
          title: 'Squat Gain',
          description: 'Squat up 8%',
          recommendation: 'Keep overloading',
          significanceScore: 0.95,
          createdAt: DateTime.now(),
        );
        final insightMap = SupabaseModelMappers.athleteInsightToTable(insight);
        expect(insightMap['title'], equals('Squat Gain'));
        expect(insightMap['significance_score'], equals(0.95));

        // 3. PredictionResultData
        final prediction = PredictionResultData(
          id: 'pred_01',
          userId: 'usr_db_digital_01',
          predictionType: 'strength_timeline',
          predictionPayload: {'squat_predicted_12w': 148.0},
          confidenceScore: 0.94,
          createdAt: DateTime.now(),
        );
        final predictionMap = SupabaseModelMappers.predictionResultToTable(
          prediction,
        );
        expect(predictionMap['prediction_type'], equals('strength_timeline'));
        expect(predictionMap['confidence_score'], equals(0.94));

        // Table constants
        expect(
          SupabaseTableNames.digitalAthleteProfiles,
          equals('digital_athlete_profiles'),
        );
        expect(SupabaseTableNames.athleteInsights, equals('athlete_insights'));
        expect(
          SupabaseTableNames.predictionResults,
          equals('prediction_results'),
        );
      },
    );
  });
}
