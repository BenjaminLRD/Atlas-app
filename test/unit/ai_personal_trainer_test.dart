import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/ai/coach_agent/adaptive_training_service.dart';
import 'package:atlas/services/ai/coach_agent/coach_agent_service.dart';
import 'package:atlas/services/ai/coach_agent/exercise_replacement_engine.dart';
import 'package:atlas/services/ai/coach_agent/motivation_intelligence_service.dart';
import 'package:atlas/services/ai/coach_agent/voice_coach_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Advanced AI Personal Trainer Tests (Phase E.2)', () {
    test('1. CoachAgentService parses all 6 user intents accurately', () {
      expect(CoachAgentIntent.parse('What should I eat for dinner?'), equals(CoachAgentIntent.nutritionAdvice));
      expect(CoachAgentIntent.parse('I have no cable machine available'), equals(CoachAgentIntent.exerciseSubstitution));
      expect(CoachAgentIntent.parse('Am I recovering well from yesterday?'), equals(CoachAgentIntent.recoveryAdvice));
      expect(CoachAgentIntent.parse('Check my bench press progress trend'), equals(CoachAgentIntent.progressAnalysis));
      expect(CoachAgentIntent.parse('Motivate me, I feel lazy today'), equals(CoachAgentIntent.motivation));
      expect(CoachAgentIntent.parse('What exercise should I do next?'), equals(CoachAgentIntent.workoutAdvice));
    });

    test('2. CoachAgentService provides short real-time cues during active workouts', () {
      final service = CoachAgentService.instance;
      const context = WorkoutSessionContext(
        workoutName: 'Upper Push Power',
        currentExercise: 'Barbell Bench Press',
        currentSetIndex: 2,
        totalSets: 4,
        currentWeightKg: 80.0,
        targetReps: 8,
        completedReps: 6, // Missed by 2 reps
        previousSessionWeightKg: 80.0,
        previousSessionReps: 8,
        completedVolumeKg: 1280.0,
        restTimerRemainingSeconds: 90,
      );

      final response = service.generateCoachingResponse(
        userQuery: 'How did that set look?',
        activeWorkout: context,
      );

      expect(response.mode, equals(CoachResponseMode.short));
      expect(response.textResponse, contains('Missed target by 2 reps'));
      expect(response.suggestedAction, equals('adjust_load'));
      expect(response.actionPayload?['deltaKg'], equals(-2.5));
    });

    test('3. CoachAgentService switches to detailed mode outside workouts', () {
      final service = CoachAgentService.instance;

      final response = service.generateCoachingResponse(
        userQuery: 'Analyze my nutrition and protein intake',
      );

      expect(response.mode, equals(CoachResponseMode.detailed));
      expect(response.intent, equals(CoachAgentIntent.nutritionAdvice));
      expect(response.textResponse.length, greaterThan(60));
      expect(response.textResponse, contains('protein'));
    });

    test('4. AdaptiveTrainingService proposes live weight drops on rep failure', () {
      final service = AdaptiveTrainingService.instance;

      final recommendation = service.evaluateLiveSet(
        exerciseName: 'Barbell Bench Press',
        currentWeightKg: 80.0,
        targetReps: 8,
        completedReps: 6, // Failed by 2 reps
        currentSet: 2,
        totalSets: 4,
      );

      expect(recommendation, isNotNull);
      expect(recommendation!.type, equals(TrainingAdjustmentType.decreaseWeight));
      expect(recommendation.suggestedValue, equals('75.0 kg'));
      expect(recommendation.isConfirmed, isFalse);

      final confirmed = recommendation.confirm();
      expect(confirmed.isConfirmed, isTrue);
    });

    test('5. AdaptiveTrainingService recommends rest extension on single rep miss', () {
      final service = AdaptiveTrainingService.instance;

      final recommendation = service.evaluateLiveSet(
        exerciseName: 'Incline Dumbbell Press',
        currentWeightKg: 28.0,
        targetReps: 10,
        completedReps: 9, // Missed by 1 rep
        currentSet: 3,
        totalSets: 4,
      );

      expect(recommendation, isNotNull);
      expect(recommendation!.type, equals(TrainingAdjustmentType.extendRest));
      expect(recommendation.suggestedValue, equals('+30 seconds'));
    });

    test('6. AdaptiveTrainingService proposes progressive overload when RPE is low', () {
      final service = AdaptiveTrainingService.instance;

      final recommendation = service.evaluateLiveSet(
        exerciseName: 'Barbell Back Squat',
        currentWeightKg: 100.0,
        targetReps: 6,
        completedReps: 6,
        currentSet: 1,
        totalSets: 4,
        rpe: 6.0, // Very easy
      );

      expect(recommendation, isNotNull);
      expect(recommendation!.type, equals(TrainingAdjustmentType.increaseWeight));
      expect(recommendation.suggestedValue, equals('102.5 kg'));
    });

    test('7. VoiceCoachService accurately parses workout voice commands and generates TTS cues', () {
      final voice = VoiceCoachService.instance;

      final start = voice.parseVoiceCommand('Start workout');
      expect(start.type, equals(VoiceCommandType.startWorkout));
      expect(start.ttsResponse, contains('Starting your workout'));

      final next = voice.parseVoiceCommand('Next exercise please');
      expect(next.type, equals(VoiceCommandType.nextExercise));

      final weight = voice.parseVoiceCommand('How much weight should I use?', activeExerciseName: 'Deadlift', activeWeightKg: 120.0);
      expect(weight.type, equals(VoiceCommandType.recommendWeight));
      expect(weight.ttsResponse, contains('120.0 kilograms'));

      final timer = voice.parseVoiceCommand('Start rest timer');
      expect(timer.type, equals(VoiceCommandType.startRestTimer));
      expect(timer.actionParams?['durationSeconds'], equals(90));

      final progress = voice.parseVoiceCommand('Am I progressing?');
      expect(progress.type, equals(VoiceCommandType.checkProgress));
      expect(progress.ttsResponse, contains('strength is up'));
    });

    test('8. ExerciseReplacementEngine suggests equipment-aware substitutes', () {
      final engine = ExerciseReplacementEngine.instance;

      final substitutes = engine.findSubstitutes(
        exerciseName: 'Cable Crossover',
        unavailableEquipment: ['cable_machine'],
      );

      expect(substitutes, isNotEmpty);
      expect(substitutes.any((s) => s.replacementExercise.contains('Dumbbell Fly') || s.replacementExercise.contains('Push-ups')), isTrue);

      final squatSubstitutes = engine.findSubstitutes(
        exerciseName: 'Barbell Back Squat',
      );
      expect(squatSubstitutes.any((s) => s.replacementExercise.contains('Goblet Squat') || s.replacementExercise.contains('Leg Press')), isTrue);
    });

    test('9. MotivationIntelligenceService crafts personalized milestone encouragement', () {
      final motivation = MotivationIntelligenceService.instance;

      final encouragement = motivation.generateEncouragement(
        completedWorkoutsThisWeek: 4,
        weeklyGoal: 5,
        currentStreakDays: 12,
      );

      expect(encouragement, contains('You have completed 4 workouts this week'));
      expect(encouragement, contains('One more session reaches your weekly goal'));

      final prEncouragement = motivation.generateEncouragement(
        completedWorkoutsThisWeek: 3,
        weeklyGoal: 4,
        recentPrExercise: 'Bench Press',
      );
      expect(prEncouragement, contains('Bench Press'));
    });
  });
}
