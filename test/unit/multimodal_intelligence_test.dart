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
import 'package:atlas/services/ai/prompt/adaptive_prompt_builder.dart';
import 'package:atlas/services/form_detection/pose_models.dart';
import 'package:atlas/services/multimodal/body_progress_analysis_service.dart';
import 'package:atlas/services/multimodal/live_workout_coach_mode.dart';
import 'package:atlas/services/multimodal/multimodal_input_service.dart';
import 'package:atlas/services/multimodal/sensor_fusion_engine.dart';
import 'package:atlas/services/multimodal/vision_coach_service.dart';
import 'package:atlas/services/multimodal/voice_coach_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FitnessMemory.resetInstance();
    await FitnessMemory.instance.initialize();
    MultimodalInputService.resetInstance();
    VisionCoachService.resetInstance();
    VoiceCoachService.resetInstance();
    SensorFusionEngine.resetInstance();
    LiveWorkoutCoachMode.resetInstance();
    BodyProgressAnalysisService.resetInstance();

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
        fitnessGoal: 'Strength & Hypertrophy',
        workoutExperience: 'Advanced',
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
        fitnessLevel: FitnessLevel.advanced,
        activityLevel: ActivityLevel.veryActive,
        age: 26,
        height: 178.0,
        currentWeight: 76.0,
        targetWeight: 80.0,
        targetCalories: 2800.0,
        targetProtein: 180.0,
        targetCarbohydrates: 320.0,
        targetFats: 75.0,
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
        recoveryScore: 84,
        sleepQuality: 0.85,
        fatigueLevel: FatigueLevel.low,
        isDeloadRecommended: false,
        lastUpdated: now,
      ),
      generatedAt: now,
    );
  });

  group('1. Multimodal Input Stream Tests', () {
    test('Ingests unified multi-stream payloads and maintains rolling buffer', () {
      final inputService = MultimodalInputService.instance;

      final payload = MultimodalInputPayload(
        sessionId: 'sess_123',
        voiceTranscript: 'Start set 100kg',
        heartRateBpm: 142.0,
        movementVelocityMs: 0.68,
        currentReps: 5,
        currentWeightKg: 100.0,
        activeExerciseName: 'Squat',
        timestamp: DateTime.now(),
      );

      inputService.ingestPayload(payload);

      expect(inputService.latestPayload, isNotNull);
      expect(inputService.latestPayload!.hasVoice, isTrue);
      expect(inputService.latestPayload!.hasWearable, isTrue);
      expect(inputService.latestPayload!.hasWorkoutData, isTrue);
      expect(inputService.inputHistory.length, equals(1));
    });
  });

  group('2. Vision Coach Kinematics & Fault Detection Tests', () {
    test('Evaluates squat kinematics, detects knee valgus, and tracks reps', () {
      final vision = VisionCoachService.instance;

      // Create a squat pose frame with knee valgus (knees closer than ankles)
      final valgusFrame = PoseFrame(
        frameIndex: 0,
        timestampMs: 0.0,
        landmarks: {
          PoseLandmarkType.leftShoulder: const PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 0.45, y: 0.20),
          PoseLandmarkType.rightShoulder: const PoseLandmark(type: PoseLandmarkType.rightShoulder, x: 0.55, y: 0.20),
          PoseLandmarkType.leftHip: const PoseLandmark(type: PoseLandmarkType.leftHip, x: 0.46, y: 0.50),
          PoseLandmarkType.rightHip: const PoseLandmark(type: PoseLandmarkType.rightHip, x: 0.54, y: 0.50),
          PoseLandmarkType.leftKnee: const PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0.49, y: 0.70), // Caving in
          PoseLandmarkType.rightKnee: const PoseLandmark(type: PoseLandmarkType.rightKnee, x: 0.51, y: 0.70), // Caving in
          PoseLandmarkType.leftAnkle: const PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0.40, y: 0.90),
          PoseLandmarkType.rightAnkle: const PoseLandmark(type: PoseLandmarkType.rightAnkle, x: 0.60, y: 0.90),
        },
      );

      final eval = vision.evaluateFrame(valgusFrame, exerciseHint: VisionExerciseType.squat);

      expect(eval.detectedFaults.contains(FormFaultType.kneeValgus), isTrue);
      expect(eval.liveCue.contains('knees out'), isTrue);
      expect(eval.overallFormScore, lessThan(95.0));
    });
  });

  group('3. Voice Coach & Speech Parsing Tests', () {
    test('Accurately parses voice commands and extracts parameters', () {
      final voice = VoiceCoachService.instance;

      final cmd1 = voice.parseVoiceCommand('log set 120 kg for 8 reps');
      expect(cmd1.intent, equals(VoiceCommandIntent.logSet));
      expect(cmd1.extractedWeightKg, equals(120.0));
      expect(cmd1.extractedReps, equals(8));

      final cmd2 = voice.parseVoiceCommand('start timer 90 seconds');
      expect(cmd2.intent, equals(VoiceCommandIntent.startTimer));
      expect(cmd2.extractedRestSeconds, equals(90));

      final cmd3 = voice.parseVoiceCommand('start workout');
      expect(cmd3.intent, equals(VoiceCommandIntent.startWorkout));

      final cmd4 = voice.parseVoiceCommand('next exercise');
      expect(cmd4.intent, equals(VoiceCommandIntent.nextExercise));

      final speechFeedback = voice.synthesizeSpeechFeedback(
        message: 'Great set!',
        style: CoachStyle.technical,
      );
      expect(speechFeedback.contains('Atlas Analysis'), isTrue);
    });
  });

  group('4. Sensor Fusion Engine Tests', () {
    test('Fuses heart rate, rep velocity, and fatigue into unified athlete state', () {
      final fusion = SensorFusionEngine.instance;

      final state = fusion.fuseTelemetry(
        heartRateBpm: 155.0,
        athleteAge: 26,
        initialRepVelocityMs: 0.80,
        currentRepVelocityMs: 0.55, // Significant velocity loss (31.25%)
        setsCompletedInSession: 4,
      );

      expect(state.cardioZone, equals(CardioZone.zone4Threshold));
      expect(state.velocityLossPercentage, greaterThan(30.0));
      expect(state.physiologicalStrainIndex, greaterThan(8.0));
      expect(state.realTimeRPE, greaterThanOrEqualTo(9.0));
      expect(state.recommendedRestSeconds, greaterThanOrEqualTo(120)); // Extended rest for high strain
    });
  });

  group('5. Live Workout Coach Mode Tests', () {
    test('Orchestrates full workout lifecycle with voice commands and set completion', () {
      final liveCoach = LiveWorkoutCoachMode.instance;

      liveCoach.startSession(workoutName: 'Heavy Lower Body', initialExercise: 'Squat');
      expect(liveCoach.state, equals(LiveCoachState.idle));

      // User says "Start workout"
      final voiceResponse1 = liveCoach.handleVoiceInput('start workout');
      expect(liveCoach.state, equals(LiveCoachState.activeSet));
      expect(voiceResponse1.contains('Starting set 1'), isTrue);

      // User logs set "log set 140kg for 6 reps"
      final voiceResponse2 = liveCoach.handleVoiceInput('log set 140kg for 6 reps');
      expect(liveCoach.state, equals(LiveCoachState.resting));
      expect(liveCoach.completedSets.length, equals(1));
      expect(liveCoach.completedSets.first.weightKg, equals(140.0));
      expect(liveCoach.completedSets.first.repsCompleted, equals(6));
      expect(voiceResponse2.contains('Rest timer started'), isTrue);

      // Finish session
      final summary = liveCoach.finishSession();
      expect(liveCoach.state, equals(LiveCoachState.sessionCompleted));
      expect(summary.totalSets, equals(1));
      expect(summary.totalVolumeKg, equals(840.0));
    });
  });

  group('6. Body Progress Analysis Tests', () {
    test('Calculates 7-day EMA weight, waist-to-height ratio, and recomposition trajectory', () {
      final bodyService = BodyProgressAnalysisService.instance;
      final now = DateTime.now();

      final entries = [
        BodyMeasurementEntry(date: now.subtract(const Duration(days: 20)), scaleWeightKg: 78.0, waistCircumferenceCm: 84.0),
        BodyMeasurementEntry(date: now.subtract(const Duration(days: 14)), scaleWeightKg: 77.2, waistCircumferenceCm: 83.0),
        BodyMeasurementEntry(date: now.subtract(const Duration(days: 7)), scaleWeightKg: 76.5, waistCircumferenceCm: 81.5),
        BodyMeasurementEntry(date: now, scaleWeightKg: 76.0, waistCircumferenceCm: 80.0),
      ];

      final trend = bodyService.analyzeBodyProgress(
        measurements: entries,
        heightCm: 178.0,
        squatMaxKg: 150.0,
        benchMaxKg: 110.0,
        deadliftMaxKg: 200.0,
      );

      expect(trend.sevenDayEmaWeightKg, closeTo(77.1, 0.5));
      expect(trend.thirtyDayWeightDeltaKg, lessThan(0.0)); // Weight lost
      expect(trend.waistToHeightRatio, lessThan(0.50)); // Visceral health optimal (<0.50)
      expect(trend.strengthToWeightRatio, greaterThan(5.0)); // 460kg total / 76kg = 6.05
      expect(trend.recompositionPhase.contains('Fat Loss') || trend.recompositionPhase.contains('Recomposition'), isTrue);
    });
  });

  group('7. Multimodal AI Context Generation Tests', () {
    test('AdaptivePromptBuilder injects [MULTIMODAL ATHLETE STATE] into system prompt', () {
      const promptBuilder = AdaptivePromptBuilder.instance;

      final payload = MultimodalInputPayload(
        sessionId: 'sess_live_1',
        activeExerciseName: 'Barbell Back Squat',
        currentWeightKg: 140.0,
        currentReps: 5,
        timestamp: DateTime.now(),
      );

      final unifiedState = SensorFusionEngine.instance.fuseTelemetry(
        heartRateBpm: 160.0,
        athleteAge: 26,
      );

      final prompt = promptBuilder.buildAdaptiveSystemPrompt(
        context: sampleContext,
        multimodalPayload: payload,
        unifiedState: unifiedState,
      );

      expect(prompt.contains('[MULTIMODAL ATHLETE STATE]'), isTrue);
      expect(prompt.contains('Active Exercise: Barbell Back Squat'), isTrue);
      expect(prompt.contains('140.0kg x 5 reps'), isTrue);
      expect(prompt.contains('Real-Time Heart Rate: 160 bpm'), isTrue);
      expect(prompt.contains('Physiological Strain Index:'), isTrue);
    });
  });

  group('8. Privacy and Safety Boundaries Tests', () {
    test('Supports immediate purging of multimodal frame and audio history', () {
      final inputService = MultimodalInputService.instance;

      inputService.ingestPayload(MultimodalInputPayload(
        sessionId: 'sess_private',
        voiceTranscript: 'private audio sample',
        heartRateBpm: 120,
        timestamp: DateTime.now(),
      ));

      expect(inputService.inputHistory.isNotEmpty, isTrue);

      inputService.clearHistory();

      expect(inputService.inputHistory.isEmpty, isTrue);
      expect(inputService.latestPayload, isNull);
    });
  });
}
