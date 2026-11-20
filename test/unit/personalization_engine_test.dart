import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/ml/engagement_prediction_engine.dart';
import 'package:atlas/services/ai/ml/exercise_recommendation_engine.dart';
import 'package:atlas/services/ai/ml/feature_engineering_service.dart';
import 'package:atlas/services/ai/ml/model_inference_service.dart';
import 'package:atlas/services/ai/ml/workout_recommendation_model.dart';
import 'package:atlas/services/analytics/user_behavior_tracker.dart';
import 'package:atlas/services/supabase/database_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    UserBehaviorTracker.instance.reset();
  });

  group('Atlas AI Personalization & Predictive Intelligence Engine (Phase F.1)', () {
    test(
      '1. UserBehaviorTracker records multi-domain events and discovers habits',
      () {
        final tracker = UserBehaviorTracker.instance;
        const testUser = 'usr_test_behavior';

        // Log workout completions (mostly evening)
        tracker.trackWorkoutCompleted(
          userId: testUser,
          workoutId: 'w1',
          split: 'Push',
          durationMinutes: 48,
          timeOfDay: 'evening',
          exercisesCompleted: ['Bench Press', 'Incline Dumbbell Press'],
        );
        tracker.trackWorkoutCompleted(
          userId: testUser,
          workoutId: 'w2',
          split: 'Pull',
          durationMinutes: 52,
          timeOfDay: 'evening',
          exercisesCompleted: ['Barbell Row', 'Lat Pulldown'],
        );
        tracker.trackWorkoutCompleted(
          userId: testUser,
          workoutId: 'w3',
          split: 'Legs',
          durationMinutes: 45,
          timeOfDay: 'morning',
        );

        // Log skipped workout
        tracker.trackWorkoutSkipped(
          userId: testUser,
          workoutId: 'w4',
          reason: 'Work fatigue',
        );

        // Log exercise preference
        tracker.trackPreferredExercise(
          userId: testUser,
          exerciseName: 'Incline Dumbbell Press',
          muscleGroup: 'Chest',
          isFavorite: true,
        );

        // Log meal & food preference
        tracker.trackMealLogged(
          userId: testUser,
          mealType: 'Dinner',
          calories: 750,
          proteinGrams: 55.0,
          isAdherentToGoal: true,
        );
        tracker.trackPreferredFood(
          userId: testUser,
          foodName: 'Grilled Chicken Breast',
          mealType: 'Dinner',
        );

        // Log coach interaction & question
        tracker.trackAiCoachInteraction(
          userId: testUser,
          intent: 'workoutAdvice',
          recommendationAccepted: true,
        );
        tracker.trackAiQuestionAsked(
          userId: testUser,
          question: 'What is the optimal rest time between bench sets?',
          intent: 'technique',
        );

        // Log community actions
        tracker.trackChallengeJoined(
          userId: testUser,
          challengeId: 'ch_chest_blaster',
          challengeName: '30-Day Chest Blaster',
        );
        tracker.trackCommunityEngagement(
          userId: testUser,
          actionType: 'shared_workout',
        );

        final events = tracker.getEventsForUser(testUser);
        expect(events.length, equals(11));

        // Check discoveries
        final discoveries = tracker.computeBehavioralDiscoveries(testUser);
        expect(discoveries, isNotEmpty);
        expect(discoveries.any((d) => d.title.contains('Evening')), isTrue);
        expect(discoveries.any((d) => d.id == 'insight_duration'), isTrue);
        expect(
          discoveries.any((d) => d.id == 'insight_sleep_recovery'),
          isTrue,
        );
        expect(discoveries.any((d) => d.id == 'insight_progression'), isTrue);
        expect(
          discoveries.any((d) => d.id == 'insight_weekday_consistency'),
          isTrue,
        );
      },
    );

    test(
      '2. FeatureEngineeringService extracts normalized feature vectors',
      () {
        final tracker = UserBehaviorTracker.instance;
        const testUser = 'usr_feature_test';

        tracker.trackWorkoutCompleted(
          userId: testUser,
          workoutId: 'w1',
          split: 'Upper',
          durationMinutes: 50,
          timeOfDay: 'evening',
        );
        tracker.trackWorkoutCompleted(
          userId: testUser,
          workoutId: 'w2',
          split: 'Lower',
          durationMinutes: 46,
          timeOfDay: 'evening',
        );

        final vector = FeatureEngineeringService.instance.extractFeatureVector(
          userId: testUser,
          tracker: tracker,
        );

        expect(
          vector.trainingConsistency,
          equals(1.0),
        ); // 2 completed / 2 total
        expect(vector.avgWorkoutDurationMinutes, equals(48.0));
        expect(vector.optimalTrainingTime, equals('evening'));
        expect(vector.engagementScore, greaterThan(0));

        final json = vector.toJson();
        final fromJson = UserFeatureVector.fromJson(json);
        expect(fromJson.optimalTrainingTime, equals('evening'));
      },
    );

    test(
      '3. WorkoutRecommendationModel prescribes adaptive splits and volume',
      () {
        final model = WorkoutRecommendationModel.instance;
        final vector = UserFeatureVector.baseline();

        final rec = model.generateRecommendation(
          featureVector: vector,
          goal: 'Hypertrophy',
          fitnessLevel: 'Intermediate',
          recoveryScore: 85.0,
        );

        expect(rec.split, contains('Push Hypertrophy'));
        expect(rec.recommendedIntensityRpe, equals(8.5));
        expect(rec.targetVolumeKg, greaterThan(8000));
        expect(rec.completionProbability, greaterThan(0.70));
      },
    );

    test(
      '4. ExerciseRecommendationEngine regresses/substitutes exercises on failure or injury',
      () {
        final engine = ExerciseRecommendationEngine.instance;

        // Shoulder injury substitution
        final shoulderSub = engine.recommendExercise(
          targetMovement: 'Barbell Bench Press',
          injuredAreas: ['Shoulder Impingement'],
        );
        expect(shoulderSub.isSubstitution, isTrue);
        expect(shoulderSub.recommendedExercise, contains('Floor Press'));

        // High failure rate plateau substitution
        final plateauSub = engine.recommendExercise(
          targetMovement: 'Barbell Bench Press',
          historicalFailureRate: 0.50,
        );
        expect(plateauSub.isSubstitution, isTrue);
        expect(plateauSub.recommendedExercise, contains('Machine Chest Press'));

        // Form score degradation substitution
        final formSub = engine.recommendExercise(
          targetMovement: 'Conventional Deadlift',
          recentFormScore: 65.0,
        );
        expect(formSub.isSubstitution, isTrue);
        expect(formSub.recommendedExercise, contains('Romanian Deadlift'));

        // Clean normal movement
        final normalEx = engine.recommendExercise(
          targetMovement: 'Incline Dumbbell Press',
        );
        expect(normalEx.isSubstitution, isFalse);
        expect(normalEx.recommendedExercise, equals('Incline Dumbbell Press'));
      },
    );

    test(
      '5. EngagementPredictionEngine forecasts churn risk and suggests habit rescues',
      () {
        final engine = EngagementPredictionEngine.instance;

        // Active user -> Low Risk
        final lowRisk = engine.predictRetentionRisk(
          daysSinceLastWorkout: 1,
          missedGoalsLast14Days: 0,
          recentEngagementScore: 90.0,
          nutritionLoggingAdherence: 0.90,
        );
        expect(lowRisk.churnRisk, equals(ChurnRiskLevel.low));
        expect(lowRisk.riskProbability, lessThan(0.30));

        // Inactive user -> High Risk
        final highRisk = engine.predictRetentionRisk(
          daysSinceLastWorkout: 6,
          missedGoalsLast14Days: 3,
          recentEngagementScore: 20.0,
          nutritionLoggingAdherence: 0.20,
        );
        expect(highRisk.churnRisk, equals(ChurnRiskLevel.high));
        expect(highRisk.riskProbability, greaterThanOrEqualTo(0.55));
        expect(
          highRisk.retentionInterventions.any((i) => i.contains('15-Minute')),
          isTrue,
        );
      },
    );

    test(
      '6. ModelInferenceService executes pluggable ML model predictions',
      () {
        final inference = ModelInferenceService.instance;

        // Workout Recommendation Model
        final workoutPred = inference.predict(
          modelName: 'workout_recommendation_model',
          inputFeatures: {
            'goal': 'Strength & Power',
            'fitness_level': 'Advanced',
            'recovery_score': 90.0,
          },
        );
        expect(workoutPred['model'], equals('workout_recommendation_model'));
        expect(workoutPred['prediction'], isNotNull);

        // Churn Prediction Model
        final churnPred = inference.predict(
          modelName: 'churn_prediction_model',
          inputFeatures: {'days_since_last_workout': 2, 'missed_goals': 1},
        );
        expect(churnPred['model'], equals('churn_prediction_model'));
        expect(churnPred['confidence'], greaterThan(0.0));
      },
    );

    test(
      '7. CoachPromptBuilder includes [USER BEHAVIOR CONTEXT] in generated prompts',
      () {
        final tracker = UserBehaviorTracker.instance;
        const testUser = 'usr_local';

        tracker.trackWorkoutCompleted(
          userId: testUser,
          workoutId: 'w1',
          split: 'Push',
          durationMinutes: 48,
          timeOfDay: 'evening',
        );
        tracker.trackWorkoutCompleted(
          userId: testUser,
          workoutId: 'w2',
          split: 'Pull',
          durationMinutes: 52,
          timeOfDay: 'evening',
        );

        final builder = const CoachPromptBuilder();
        final context = FitnessContext(
          nutritionSummary: NutritionSummary.empty(),
          progressSummary: ProgressSummary.zero(),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          generatedAt: DateTime.now(),
        );

        final prompt = builder.buildPrompt(
          message: 'How should I structure my chest workout today?',
          context: context,
        );

        expect(prompt, contains('[USER BEHAVIOR CONTEXT]'));
        expect(prompt, contains('Evening Peak Performance'));
      },
    );

    test(
      '8. DatabaseModels and SupabaseModelMappers serialize ML & Personalization models',
      () {
        final behaviorEvent = UserBehaviorEventData(
          id: 'be_test_1',
          userId: 'usr_db_test',
          domain: 'workout',
          eventType: 'workout_completed',
          payload: {'duration_minutes': 50, 'split': 'Push'},
          timestamp: DateTime.now(),
        );
        final eventTable = SupabaseModelMappers.userBehaviorEventToTable(
          behaviorEvent,
        );
        expect(eventTable['domain'], equals('workout'));
        expect(eventTable['event_type'], equals('workout_completed'));

        final prediction = ModelPredictionData(
          id: 'mp_test_1',
          userId: 'usr_db_test',
          modelName: 'workout_recommendation_model',
          predictionOutput: {'split': 'Upper Hypertrophy'},
          confidenceScore: 0.95,
          createdAt: DateTime.now(),
        );
        final predTable = SupabaseModelMappers.modelPredictionToTable(
          prediction,
        );
        expect(predTable['model_name'], equals('workout_recommendation_model'));
        expect(predTable['confidence_score'], equals(0.95));

        final profile = PersonalizationProfileData(
          userId: 'usr_db_test',
          featureVector: {'training_consistency': 0.95},
          preferredTrainingTime: 'evening',
          churnRisk: 'low',
          discoveredInsights: ['Evening Peak Performance'],
          updatedAt: DateTime.now(),
        );
        final profileTable = SupabaseModelMappers.personalizationProfileToTable(
          profile,
        );
        expect(profileTable['user_id'], equals('usr_db_test'));
        expect(profileTable['preferred_training_time'], equals('evening'));
        expect(profileTable['churn_risk'], equals('low'));

        expect(
          SupabaseTableNames.userBehaviorEvents,
          equals('user_behavior_events'),
        );
        expect(
          SupabaseTableNames.modelPredictions,
          equals('model_predictions'),
        );
        expect(
          SupabaseTableNames.personalizationProfiles,
          equals('personalization_profiles'),
        );
      },
    );
  });
}
