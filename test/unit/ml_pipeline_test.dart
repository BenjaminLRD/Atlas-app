import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/vision/pose_frame.dart';
import 'package:atlas/models/vision/pose_landmark.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ml/ml_data_collector.dart';
import 'package:atlas/services/ml/ml_feature_engineering_service.dart';
import 'package:atlas/services/ml/ml_inference_service.dart';
import 'package:atlas/services/ml/ml_privacy_manager.dart';
import 'package:atlas/services/ml/model_manager.dart';
import 'package:atlas/services/ml/models/exercise_classification_model.dart';
import 'package:atlas/services/ml/models/movement_quality_model.dart';
import 'package:atlas/services/ml/models/nutrition_prediction_model.dart';
import 'package:atlas/services/ml/models/workout_recommendation_model.dart';
import 'package:atlas/services/supabase/database_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    MLDataCollector.instance.reset();
    MLPrivacyManager.instance.setConsent(true);
  });

  group('Atlas Custom Machine Learning Pipeline (Phase F.2)', () {
    test(
      '1. MLPrivacyManager enforces consent gating and cryptographic anonymization',
      () {
        final privacy = MLPrivacyManager.instance;
        const rawUser = 'user_12345_sensitive';

        final anonId = privacy.anonymizeUserId(rawUser);
        expect(anonId, startsWith('anon_'));
        expect(anonId, isNot(contains('12345')));

        final sanitized = privacy.sanitizeFeatures({
          'name': 'John Doe',
          'email': 'john@example.com',
          'workout_volume': 12000.0,
          'reps': 30,
        });
        expect(sanitized.containsKey('name'), isFalse);
        expect(sanitized.containsKey('email'), isFalse);
        expect(sanitized['workout_volume'], equals(12000.0));

        // Test consent toggle
        privacy.setConsent(false);
        expect(privacy.hasConsent, isFalse);

        final collector = MLDataCollector.instance;
        final collected = collector.collectWorkoutData(
          rawUserId: rawUser,
          workoutName: 'Upper Body',
          split: 'Upper',
          exercises: ['Bench Press'],
          totalVolumeKg: 8000,
          totalSets: 12,
          totalReps: 96,
          averageWeightKg: 83.3,
          progressionRate: 0.05,
          durationMinutes: 45,
        );
        expect(collected, isFalse);
        expect(collector.trainingEvents.isEmpty, isTrue);
      },
    );

    test('2. MLDataCollector ingests multi-domain training telemetry', () {
      final collector = MLDataCollector.instance;
      const testUser = 'user_athlete_01';

      // 1. Workout telemetry
      final wCollected = collector.collectWorkoutData(
        rawUserId: testUser,
        workoutName: 'Push Hypertrophy',
        split: 'Push',
        exercises: ['Barbell Bench Press', 'Incline Dumbbell Press'],
        totalVolumeKg: 11500.0,
        totalSets: 16,
        totalReps: 128,
        averageWeightKg: 89.8,
        progressionRate: 0.04,
        durationMinutes: 52,
      );
      expect(wCollected, isTrue);

      // 2. Nutrition telemetry
      final nCollected = collector.collectNutritionData(
        rawUserId: testUser,
        caloriesConsumed: 2650,
        calorieTarget: 2700,
        proteinGrams: 185.0,
        proteinTarget: 180.0,
        carbsGrams: 310.0,
        fatGrams: 75.0,
        adherenceRate: 0.95,
      );
      expect(nCollected, isTrue);

      // 3. Recovery telemetry
      final rCollected = collector.collectRecoveryData(
        rawUserId: testUser,
        sleepHours: 7.8,
        hrvScore: 68.0,
        restingHeartRate: 58,
        readinessScore: 88.0,
      );
      expect(rCollected, isTrue);

      // 4. Behavior telemetry
      final bCollected = collector.collectBehaviorData(
        rawUserId: testUser,
        appUsageFrequency: 6.0,
        trainingConsistency: 0.94,
        preferredMuscleGroups: ['Chest', 'Shoulders'],
        favoriteExercises: ['Incline Dumbbell Press'],
      );
      expect(bCollected, isTrue);

      expect(collector.trainingEvents.length, equals(4));
      expect(collector.getEventsByDomain('workout').length, equals(1));
      expect(collector.getEventsByDomain('nutrition').length, equals(1));
      expect(collector.getEventsByDomain('recovery').length, equals(1));
      expect(collector.getEventsByDomain('behavior').length, equals(1));
    });

    test(
      '3. MLFeatureEngineeringService extracts numerical FeatureVector and tensor',
      () {
        final service = MLFeatureEngineeringService.instance;
        final features = service.extractFeatures(userId: 'usr_local');

        expect(features.trainingFrequency, greaterThanOrEqualTo(1.0));
        expect(features.averageVolumeKg, greaterThan(0));
        expect(features.recoveryScore, greaterThan(0));
        expect(features.nutritionAdherence, inInclusiveRange(0.0, 1.0));

        final tensor = features.toNormalizedTensor();
        expect(tensor.length, equals(7));
        for (final val in tensor) {
          expect(val, inInclusiveRange(0.0, 1.0));
        }

        final json = features.toJson();
        final fromJson = FeatureVector.fromJson(json);
        expect(fromJson.trainingFrequency, equals(features.trainingFrequency));
        expect(fromJson.averageVolumeKg, equals(features.averageVolumeKg));
      },
    );

    test(
      '4. WorkoutRecommendationModel prescribes splits, exercises, and volume adjustments',
      () {
        final model = WorkoutRecommendationModel.instance;

        // High recovery features
        const highRecoveryFeatures = FeatureVector(
          trainingFrequency: 4.0,
          averageVolumeKg: 10000.0,
          strengthProgression: 0.05,
          recoveryScore: 88.0,
          nutritionAdherence: 0.90,
          workoutCompletionRate: 0.95,
          exercisePreferenceScore: 0.90,
        );

        final rec1 = model.predict(highRecoveryFeatures);
        expect(rec1.recommendedSplit, equals('Upper/Lower split'));
        expect(rec1.targetFrequency, equals('4 days/week'));
        expect(rec1.selectedExercises, isNotEmpty);
        expect(rec1.chestSetsTarget, contains('12 sets'));
        expect(
          rec1.volumeAdjustmentDirective,
          contains('Increase primary lift intensity'),
        );

        // Low recovery features -> volume reduction directive
        const lowRecoveryFeatures = FeatureVector(
          trainingFrequency: 4.0,
          averageVolumeKg: 10000.0,
          strengthProgression: -0.02,
          recoveryScore: 52.0,
          nutritionAdherence: 0.75,
          workoutCompletionRate: 0.80,
          exercisePreferenceScore: 0.80,
        );

        final rec2 = model.predict(lowRecoveryFeatures);
        expect(
          rec2.volumeAdjustmentDirective,
          contains('Reduce training volume 15%'),
        );
        expect(rec2.targetIntensityRpe, equals(6.5));
        expect(rec2.targetVolumeKg, equals(8500.0));
      },
    );

    test(
      '5. ExerciseClassificationModel classifies poses from landmark geometry',
      () {
        final model = ExerciseClassificationModel.instance;

        // Standing pose -> Squat
        final standingSquat = PoseFrame(
          timestamp: DateTime.now(),
          landmarks: {
            PoseLandmarkType.leftHip: const PoseLandmark(
              type: PoseLandmarkType.leftHip,
              x: 0.5,
              y: 0.5,
            ),
            PoseLandmarkType.leftKnee: const PoseLandmark(
              type: PoseLandmarkType.leftKnee,
              x: 0.5,
              y: 0.75,
            ),
            PoseLandmarkType.leftAnkle: const PoseLandmark(
              type: PoseLandmarkType.leftAnkle,
              x: 0.5,
              y: 0.95,
            ),
            PoseLandmarkType.leftShoulder: const PoseLandmark(
              type: PoseLandmarkType.leftShoulder,
              x: 0.5,
              y: 0.25,
            ),
            PoseLandmarkType.leftElbow: const PoseLandmark(
              type: PoseLandmarkType.leftElbow,
              x: 0.5,
              y: 0.38,
            ),
            PoseLandmarkType.leftWrist: const PoseLandmark(
              type: PoseLandmarkType.leftWrist,
              x: 0.5,
              y: 0.5,
            ),
          },
        );

        final squatResult = model.classifyPose(poseFrame: standingSquat);
        expect(squatResult.exerciseName, equals('Squat'));
        expect(squatResult.confidenceScore, greaterThan(0.90));

        // Horizontal pose -> Push Up
        final pushUpPose = PoseFrame(
          timestamp: DateTime.now(),
          landmarks: {
            PoseLandmarkType.leftHip: const PoseLandmark(
              type: PoseLandmarkType.leftHip,
              x: 0.45,
              y: 0.5,
            ),
            PoseLandmarkType.leftShoulder: const PoseLandmark(
              type: PoseLandmarkType.leftShoulder,
              x: 0.20,
              y: 0.5,
            ),
            PoseLandmarkType.leftKnee: const PoseLandmark(
              type: PoseLandmarkType.leftKnee,
              x: 0.70,
              y: 0.5,
            ),
            PoseLandmarkType.leftAnkle: const PoseLandmark(
              type: PoseLandmarkType.leftAnkle,
              x: 0.95,
              y: 0.5,
            ),
            PoseLandmarkType.leftElbow: const PoseLandmark(
              type: PoseLandmarkType.leftElbow,
              x: 0.25,
              y: 0.65,
            ),
            PoseLandmarkType.leftWrist: const PoseLandmark(
              type: PoseLandmarkType.leftWrist,
              x: 0.25,
              y: 0.75,
            ),
          },
        );

        final pushUpResult = model.classifyPose(poseFrame: pushUpPose);
        expect(pushUpResult.exerciseName, equals('Push Up'));
        expect(pushUpResult.confidenceScore, greaterThan(0.90));
      },
    );

    test(
      '6. MovementQualityModel scores joint angles, velocity, ROM, and symmetry',
      () {
        final model = MovementQualityModel.instance;

        final qualityScore = model.evaluateMovementQuality(
          exerciseName: 'Squat',
          minJointAngle: 88.0,
          targetJointAngle: 90.0,
          repDurationSeconds: 2.4,
          targetDurationSeconds: 2.5,
          bilateralDeltaPercentage: 4.0,
          romCompletionPercentage: 92.0,
        );

        expect(qualityScore.exerciseName, equals('Squat'));
        expect(qualityScore.overallScore, equals(95));
        expect(qualityScore.rangeOfMotionScore, equals(92.0));
        expect(qualityScore.symmetryScore, equals(92.0));
        expect(qualityScore.qualityFeedback, isNotEmpty);
        expect(qualityScore.summaryString, equals('Squat: 95/100'));
      },
    );

    test(
      '7. NutritionPredictionModel forecasts goal adherence and macro consistency',
      () {
        final model = NutritionPredictionModel.instance;

        final prediction = model.predict(
          averageCaloriesConsumed: 2450.0,
          targetCalories: 2500.0,
          averageProteinGrams: 175.0,
          targetProteinGrams: 170.0,
          loggedDaysLast7Days: 6,
        );

        expect(prediction.goalAdherenceProbability, greaterThan(0.80));
        expect(prediction.proteinConsistencyScore, greaterThan(90.0));
        expect(prediction.calorieConsistencyScore, greaterThan(90.0));
        expect(prediction.predictedWeeklyDeficitOrSurplusKcal, equals(-350.0));
        expect(prediction.confidenceScore, greaterThan(0.90));
      },
    );

    test(
      '8. ModelManager and MLInferenceService coordinate on-device model execution',
      () async {
        final manager = ModelManager.instance;
        final inference = MLInferenceService.instance;

        expect(manager.isModelCached('workout_recommendation'), isTrue);
        expect(
          manager.getModelVersion('workout_recommendation'),
          equals('1.2.0'),
        );
        expect(inference.isModelAvailable('workout_recommendation'), isTrue);

        // Model update
        manager.updateModel(
          modelId: 'workout_recommendation',
          newVersion: '1.3.0',
        );
        expect(
          manager.getModelVersion('workout_recommendation'),
          equals('1.3.0'),
        );

        // Inference execution
        final result = inference.predict(
          modelName: 'workout_recommendation',
          input: FeatureVector.baseline(),
        );
        expect(result['status'], equals('success'));
        expect(result['prediction']['recommended_split'], isNotNull);

        // Movement quality inference
        final mqResult = inference.predict(
          modelName: 'movement_quality',
          input: {'exercise_name': 'Squat', 'min_joint_angle': 90.0},
        );
        expect(mqResult['status'], equals('success'));
        expect(mqResult['prediction']['overall_score'], isNotNull);
      },
    );

    test(
      '9. CoachPromptBuilder injects [ML PREDICTIONS] and hybrid intelligence directives',
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
          message: 'Why is my workout volume being adjusted today?',
          context: context,
        );

        expect(prompt, contains('[ML PREDICTIONS]'));
        expect(prompt, contains('Workout Recommendation Model:'));
        expect(prompt, contains('Biomechanical Movement Quality:'));
        expect(prompt, contains('Nutrition Adherence Model:'));
        expect(prompt, contains('Explain and elaborate on [ML PREDICTIONS]'));
      },
    );

    test('10. Database models and mappers serialize MLTrainingEventData', () {
      final event = MLTrainingEventData(
        id: 'mle_db_01',
        anonymizedUserId: 'anon_abcdef1234567890',
        domain: 'workout',
        eventType: 'workout_telemetry',
        featurePayload: {'total_volume_kg': 10500.0, 'split': 'Upper'},
        isAnonymized: true,
        consentVerified: true,
        timestamp: DateTime.now(),
      );

      final tableMap = SupabaseModelMappers.mlTrainingEventToTable(event);
      expect(tableMap['user_id'], equals('anon_abcdef1234567890'));
      expect(tableMap['domain'], equals('workout'));
      expect(tableMap['is_anonymized'], isTrue);
      expect(tableMap['consent_verified'], isTrue);

      expect(SupabaseTableNames.mlTrainingEvents, equals('ml_training_events'));
    });
  });
}
