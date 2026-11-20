import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/memory/memory_event.dart';
import 'package:atlas/services/ai/memory/preference_profile.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';
import 'package:atlas/services/health/health_service.dart';
import 'package:atlas/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    HealthService.resetInstance();
    FitnessMemory.resetInstance();
    AppDependencies.useMock();
  });

  group('AI Personalization & Learning Memory System Tests', () {
    test(
      'FitnessMemory records recommendation feedback and computes satisfaction rate',
      () async {
        final memory = FitnessMemory.instance;
        await memory.initialize();

        expect(memory.getPreferenceProfile().satisfactionRate, equals(1.0));

        await memory.recordRecommendationFeedback(
          recommendationId: 'rec_1',
          isHelpful: true,
          recommendationTitle: 'Add 20g protein',
        );
        await memory.recordRecommendationFeedback(
          recommendationId: 'rec_2',
          isHelpful: true,
          recommendationTitle: 'Deload week',
        );
        await memory.recordRecommendationFeedback(
          recommendationId: 'rec_3',
          isHelpful: false,
          recommendationTitle: 'Do 100 burpees',
        );

        final profile = memory.getPreferenceProfile();
        expect(profile.helpfulRecommendationsCount, equals(2));
        expect(profile.unhelpfulRecommendationsCount, equals(1));
        expect(profile.satisfactionRate, closeTo(0.666, 0.01));

        final events = memory.getEvents();
        expect(events.length, equals(3));
        expect(
          events.first.type,
          equals(MemoryEventType.recommendationHelpful),
        );
        expect(
          events.last.type,
          equals(MemoryEventType.recommendationUnhelpful),
        );
      },
    );

    test(
      'FitnessMemory score tracking adjusts when replacing exercises',
      () async {
        final memory = FitnessMemory.instance;
        await memory.initialize();

        // User replaces Bench Press with Dumbbell Press
        await memory.recordExerciseReplacement(
          oldExercise: 'Bench Press',
          newExercise: 'Dumbbell Press',
        );

        var profile = memory.getPreferenceProfile();
        expect(profile.exerciseScores['Bench Press'], equals(-1));
        expect(profile.exerciseScores['Dumbbell Press'], equals(1));
        expect(profile.preferredExercises, contains('Dumbbell Press'));
        expect(profile.dislikedExercises, contains('Bench Press'));

        // User replaces Bench Press again
        await memory.recordExerciseReplacement(
          oldExercise: 'Bench Press',
          newExercise: 'Incline Dumbbell Press',
        );

        profile = memory.getPreferenceProfile();
        expect(profile.exerciseScores['Bench Press'], equals(-2));
        expect(profile.dislikedExercises, contains('Bench Press'));
        expect(profile.preferredExercises, contains('Incline Dumbbell Press'));
      },
    );

    test(
      'FitnessMemory explicit preference updates for food and training duration',
      () async {
        final memory = FitnessMemory.instance;
        await memory.initialize();

        await memory.recordFoodPreference(food: 'Oatmeal', isPreferred: true);
        await memory.recordFoodPreference(food: 'Broccoli', isPreferred: false);
        await memory.updatePreferences(
          durationMinutes: 60,
          trainingStyle: 'powerlifting',
          coachPersonality: 'direct',
        );

        final profile = memory.getPreferenceProfile();
        expect(profile.preferredFoods, contains('Oatmeal'));
        expect(profile.dislikedFoods, contains('Broccoli'));
        expect(profile.preferredWorkoutDurationMinutes, equals(60));
        expect(profile.trainingStyle, equals('powerlifting'));
        expect(profile.coachPersonalityPreference, equals('direct'));
      },
    );

    test(
      'WorkoutTool avoids disliked exercises and prioritizes preferred exercises',
      () async {
        final memory = FitnessMemory.instance;
        await memory.initialize();

        // Mark Bench Press as disliked (-2) and Push-ups as preferred (+2)
        await memory.recordExercisePreference(
          exercise: 'Bench Press',
          isPreferred: false,
        );
        await memory.recordExercisePreference(
          exercise: 'Push-ups',
          isPreferred: true,
        );

        final tool = WorkoutTool(fitnessMemory: memory);
        final result = await tool.execute({
          'action': 'generate_workout',
          'muscle_group': 'push',
        });

        expect(result['status'], equals('success'));
        final exercises = (result['workout']['exercises'] as List<dynamic>)
            .map((e) => e['name'] as String)
            .toList();

        // Ensure disliked exercise is NOT in the generated workout
        expect(exercises.contains('Bench Press'), isFalse);
        // Ensure preferred exercise is present
        expect(exercises.contains('Push-ups'), isTrue);
      },
    );

    test(
      'WorkoutTool modify_workout automatically records learning memory event',
      () async {
        final memory = FitnessMemory.instance;
        await memory.initialize();

        final tool = WorkoutTool(fitnessMemory: memory);
        final result = await tool.execute({
          'action': 'modify_workout',
          'exercise_to_replace': 'Barbell Squat',
          'replacement_preference': 'bodyweight',
        });

        expect(result['status'], equals('success'));
        expect(result['suggested_replacements'], isNotEmpty);

        // Verify memory learned the replacement
        final profile = memory.getPreferenceProfile();
        expect(profile.exerciseScores['Barbell Squat'], equals(-1));
        expect(profile.dislikedExercises, contains('Barbell Squat'));

        final events = memory.getEvents();
        expect(
          events.any((e) => e.type == MemoryEventType.exerciseReplaced),
          isTrue,
        );
      },
    );

    test(
      'CoachPromptBuilder incorporates learned preferences and satisfaction history into prompt',
      () {
        const builder = CoachPromptBuilder();
        const profile = PreferenceProfile(
          preferredExercises: ['Dumbbell Incline Press', 'Weighted Pull-ups'],
          dislikedExercises: ['Barbell Squat'],
          preferredFoods: ['Eggs', 'Oatmeal'],
          dislikedFoods: ['Tofu'],
          preferredWorkoutDurationMinutes: 50,
          trainingStyle: 'hypertrophy',
          coachPersonalityPreference: 'analytical',
          helpfulRecommendationsCount: 9,
          unhelpfulRecommendationsCount: 1,
        );

        final context = FitnessContext.initial();

        final prompt = builder.buildPrompt(
          message: 'What workout should I do today?',
          context: context,
          preferenceProfile: profile,
        );

        expect(
          prompt,
          contains(
            'Learned Exercise Preferences: Favorite: [Dumbbell Incline Press, Weighted Pull-ups]',
          ),
        );
        expect(prompt, contains('Avoid / Disliked: [Barbell Squat]'));
        expect(prompt, contains('Preferred Training Duration: 50 mins'));
        expect(prompt, contains('9 helpful / 1 unhelpful (90% satisfaction)'));
        expect(
          prompt,
          contains(
            'NEVER prescribe exercises requiring equipment listed under Unavailable / Excluded Equipment or exercises in Avoid / Disliked.',
          ),
        );
      },
    );

    test(
      'PreferenceProfile JSON serialization and deserialization roundtrip',
      () {
        const original = PreferenceProfile(
          preferredExercises: ['Lat Pulldown'],
          dislikedExercises: ['Overhead Press'],
          preferredFoods: ['Chicken Breast'],
          dislikedFoods: ['Dairy'],
          preferredWorkoutDurationMinutes: 60,
          trainingStyle: 'strength',
          coachPersonalityPreference: 'direct',
          exerciseScores: {'Lat Pulldown': 3, 'Overhead Press': -3},
          foodScores: {'Chicken Breast': 2, 'Dairy': -2},
          helpfulRecommendationsCount: 15,
          unhelpfulRecommendationsCount: 2,
        );

        final json = original.toJson();
        final restored = PreferenceProfile.fromJson(json);

        expect(
          restored.preferredExercises,
          equals(original.preferredExercises),
        );
        expect(restored.dislikedExercises, equals(original.dislikedExercises));
        expect(restored.preferredFoods, equals(original.preferredFoods));
        expect(restored.dislikedFoods, equals(original.dislikedFoods));
        expect(restored.preferredWorkoutDurationMinutes, equals(60));
        expect(restored.trainingStyle, equals('strength'));
        expect(restored.coachPersonalityPreference, equals('direct'));
        expect(restored.exerciseScores, equals(original.exerciseScores));
        expect(restored.foodScores, equals(original.foodScores));
        expect(restored.helpfulRecommendationsCount, equals(15));
        expect(restored.unhelpfulRecommendationsCount, equals(2));
      },
    );
  });
}
