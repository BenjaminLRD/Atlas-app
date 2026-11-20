import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/memory/memory_event.dart';
import 'package:atlas/services/ai/personalization/training_preference_profile.dart';
import 'package:atlas/services/ai/personalization/workout_personalization_engine.dart';
import 'package:atlas/services/workout_generator_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await FitnessMemory.instance.initialize();
    await FitnessMemory.instance.clearMemory();

    final profile = UserProfile(
      name: 'Sarah Connor',
      email: 'sarah@example.com',
      phone: '+1 555-019-2834',
      dob: '1996-03-15',
      gender: 'Female',
      height: '168',
      weight: '62.0',
      fitnessGoal: 'Hypertrophy',
      workoutExperience: 'intermediate',
      preferredDays: ['Monday', 'Wednesday', 'Friday'],
      dietPreference: 'High Protein',
      massUnit: 'kg',
      lengthUnit: 'cm',
      subscription: 'Pro',
      privacy: 'Public',
      notificationsEnabled: true,
      profilePic: '',
    );

    final goal = UserGoal(
      id: 'goal_pers_01',
      goalType: FitnessGoalType.muscleGain,
      fitnessLevel: FitnessLevel.intermediate,
      activityLevel: ActivityLevel.moderate,
      age: 28,
      height: 168.0,
      currentWeight: 62.0,
      targetWeight: 65.0,
      targetCalories: 2300.0,
      targetProtein: 140.0,
      targetCarbohydrates: 260.0,
      targetFats: 60.0,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );

    final provider = FitnessProvider.instance;
    await provider.updateProfile(profile);
    await provider.saveGoal(goal);
    sampleContext = provider.buildFitnessContext();
  });

  group('Atlas AI Adaptive Workout Personalization Engine (Phase A.5)', () {
    test(
      '1. Exercise Preference Learning (Dumbbell vs Barbell habits)',
      () async {
        final memory = FitnessMemory.instance;

        // Simulate 20 dumbbell workout completions and 4 barbell completions
        for (int i = 0; i < 20; i++) {
          await memory.recordEvent(
            MemoryEvent(
              id: 'evt_db_$i',
              type: MemoryEventType.workoutCompleted,
              target: 'Incline Dumbbell Press',
              scoreDelta: 2,
              notes: 'Completed 3 sets: peak 24.0 kg, 30 total reps',
              timestamp: DateTime.now().subtract(Duration(days: 20 - i)),
            ),
          );
        }

        for (int i = 0; i < 4; i++) {
          await memory.recordEvent(
            MemoryEvent(
              id: 'evt_bb_$i',
              type: MemoryEventType.workoutCompleted,
              target: 'Barbell Bench Press',
              scoreDelta: 2,
              notes: 'Completed 3 sets: peak 60.0 kg, 24 total reps',
              timestamp: DateTime.now().subtract(Duration(days: 4 - i)),
            ),
          );
        }

        final profile = memory.getTrainingPreferenceProfile();

        expect(profile.equipmentPreference, equals('Dumbbells'));
        expect(profile.preferredTrainingStyle, contains('Dumbbell'));
        expect(
          profile.exerciseCompletionStats['Incline Dumbbell Press'],
          equals(20),
        );
        expect(
          profile.exerciseCompletionStats['Barbell Bench Press'],
          equals(4),
        );
      },
    );

    test('2. Workout Adaptation & Disliked Exercise Substitution', () async {
      final memory = FitnessMemory.instance;
      final engine = WorkoutPersonalizationEngine.instance;

      // User marks Barbell Back Squat as disliked/avoided
      await memory.recordExercisePreference(
        exercise: 'Barbell Back Squat',
        isPreferred: false,
      );

      final profile = memory.getTrainingPreferenceProfile();
      expect(profile.isExerciseAvoided('Barbell Back Squat'), isTrue);

      // Verify smart alternative selection for avoided squat
      const squatEx = Exercise(
        id: 'barbell_back_squat',
        name: 'Barbell Back Squat',
        category: 'Strength',
        muscleGroup: 'Quadriceps',
        equipment: 'Barbell',
        difficulty: 'Advanced',
      );

      final alternative = engine.findSmartAlternative(squatEx, profile);
      expect(alternative, isNotNull);
      expect(alternative!.name, isNot(equals('Barbell Back Squat')));
      expect(alternative.muscleGroup.toLowerCase(), contains('quad'));

      // Verify WorkoutGeneratorEngine automatically excludes disliked squat
      final generator = WorkoutGeneratorEngine();
      final exercises = generator.generateExercisesForWorkout(
        workoutName: 'Leg Day Strength',
        focus: 'legs',
      );

      final generatedNames = exercises.map((e) => e['name'] as String).toList();
      expect(generatedNames.contains('Barbell Back Squat'), isFalse);
      expect(generatedNames.length, equals(4));
      expect(
        generatedNames.any(
          (n) =>
              n.toLowerCase().contains('deadlift') ||
              n.toLowerCase().contains('squat') ||
              n.toLowerCase().contains('leg') ||
              n.toLowerCase().contains('lunge') ||
              n.toLowerCase().contains('sprint'),
        ),
        isTrue,
      );
    });

    test('3. Progressive Overload Calculation Engine', () async {
      final memory = FitnessMemory.instance;
      final engine = WorkoutPersonalizationEngine.instance;

      // Record progressive lift history for Bench Press (80kg -> 85kg)
      await memory.recordEvent(
        MemoryEvent(
          id: 'evt_bench_1',
          type: MemoryEventType.workoutCompleted,
          target: 'Bench Press',
          notes: 'Completed 3 sets: peak 80.0 kg, 24 total reps',
          timestamp: DateTime.now().subtract(const Duration(days: 14)),
        ),
      );
      await memory.recordEvent(
        MemoryEvent(
          id: 'evt_bench_2',
          type: MemoryEventType.workoutCompleted,
          target: 'Bench Press',
          notes: 'Completed 3 sets: peak 85.0 kg, 24 total reps',
          timestamp: DateTime.now().subtract(const Duration(days: 7)),
        ),
      );

      final overload = engine.calculateNextOverload(
        exerciseName: 'Bench Press',
        history: const [],
        memoryEvents: memory.getEvents(),
      );

      expect(overload, isNotNull);
      expect(overload!.currentWorkingWeight, equals(85.0));
      // Recommends +2.5kg upper body increment -> 87.5kg
      expect(overload.recommendedWeight, equals(87.5));
      expect(overload.rationale, contains('+2.5kg'));
    });

    test('4. Skipped Workout Pattern Detection & Proactive Insights', () async {
      final memory = FitnessMemory.instance;
      final engine = WorkoutPersonalizationEngine.instance;

      // User skips Leg Day 3 times
      await memory.recordSkippedWorkout(
        workoutName: 'Leg Day Blast',
        splitType: 'Legs',
        reason: 'Too fatigued and busy',
      );
      await memory.recordSkippedWorkout(
        workoutName: 'Lower Body Hypertrophy',
        splitType: 'Legs',
        reason: 'Ran out of time',
      );
      await memory.recordSkippedWorkout(
        workoutName: 'Heavy Quad Focus',
        splitType: 'Legs',
        reason: 'Sore knee',
      );

      final insight = engine.detectSkippedPatterns(
        history: const [],
        memoryEvents: memory.getEvents(),
      );

      expect(insight.requiresAdjustment, isTrue);
      expect(insight.splitName, equals('Leg Day'));
      expect(insight.skipCount, equals(3));
      expect(insight.recommendation, contains('frequently skipped'));
    });

    test(
      '5. Post-Workout Feedback Learning (Difficulty & Replacements)',
      () async {
        final memory = FitnessMemory.instance;

        // 5.1 Difficulty feedback
        await memory.recordWorkoutDifficultyFeedback(
          workoutId: 'wo_chest_101',
          difficultyRating: 'Too Hard',
          notes: 'Felt gassed on the 4th exercise',
        );

        final profile = memory.getTrainingPreferenceProfile();
        expect(profile.difficultyRatings.contains('Too Hard'), isTrue);

        // 5.2 Exercise enjoyment feedback with replacement request
        await memory.recordExerciseEnjoymentFeedback(
          exerciseName: 'Overhead Press',
          enjoyed: false,
          replacementRequested: 'Dumbbell Lateral Raise',
        );

        final updatedProfile = memory.getTrainingPreferenceProfile();
        expect(updatedProfile.isExerciseAvoided('Overhead Press'), isTrue);
        expect(
          updatedProfile.isExercisePreferred('Dumbbell Lateral Raise'),
          isTrue,
        );
      },
    );

    test(
      '6. Multi-Variable Exercise Recommendation Scoring & Explainable AI',
      () {
        final engine = WorkoutPersonalizationEngine.instance;

        const profile = TrainingPreferenceProfile(
          preferredExercises: ['Incline Dumbbell Press'],
          avoidedExercises: ['Barbell Back Squat'],
          equipmentPreference: 'Dumbbells',
          exerciseCompletionStats: {'Incline Dumbbell Press': 12},
        );

        const candidate = Exercise(
          id: 'incline_db_press',
          name: 'Incline Dumbbell Press',
          category: 'Strength',
          muscleGroup: 'Chest',
          equipment: 'Dumbbell',
          difficulty: 'Intermediate',
        );

        final score = engine.scoreExercise(
          exercise: candidate,
          profile: profile,
          context: sampleContext,
          focus: 'push',
        );

        expect(score.totalScore, greaterThanOrEqualTo(80));
        expect(score.isHighlyRecommended, isTrue);
        expect(score.reasons, isNotEmpty);
        expect(score.reasons.any((r) => r.contains('favorite')), isTrue);
        expect(score.reasons.any((r) => r.contains('12 times')), isTrue);
        expect(score.reasons.any((r) => r.contains('hypertrophy')), isTrue);
      },
    );

    test('7. AI Coach Prompt Integration with Personal Training Profile', () {
      const promptBuilder = CoachPromptBuilder();

      final prompt = promptBuilder.buildPrompt(
        message: 'What workout should I do today?',
        context: sampleContext,
        intent: AIRequestIntent.workoutRequest,
      );

      expect(prompt.contains('[PERSONAL TRAINING PROFILE]'), isTrue);
      expect(prompt.contains('Preferred Style:'), isTrue);
      expect(prompt.contains('Equipment Preference:'), isTrue);
    });
  });
}
