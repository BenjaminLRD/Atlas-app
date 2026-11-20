import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local/nutrition_local_repository.dart';
import 'package:atlas/data/local/workout_local_repository.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await FitnessMemory.instance.initialize();
    await FitnessMemory.instance.clearMemory();

    AppDependencies.useMock();

    final profile = UserProfile(
      name: 'Maya Lin',
      email: 'maya@example.com',
      phone: '+1 555-019-2233',
      dob: '1996-04-12',
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
      id: 'goal_offline_01',
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
  });

  group('Atlas Offline-First Sync Architecture (Phase B.2)', () {
    test('1. Save Workout Offline (Instant Local Save)', () async {
      final workoutRepo = WorkoutLocalRepository();

      final session = WorkoutSession(
        id: 'sess_offline_99',
        workoutId: 'push_01',
        workoutName: 'Heavy Push Power',
        startTime: DateTime.now().subtract(const Duration(minutes: 50)),
        endTime: DateTime.now(),
        exercises: [
          const WorkoutSessionExercise(
            id: 'bench_press',
            name: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 80.0,
                reps: 8,
                completed: true,
              ),
              WorkoutSessionSet(
                setNumber: 2,
                weight: 85.0,
                reps: 6,
                completed: true,
              ),
            ],
            isCompleted: true,
          ),
        ],
        completedExercises: 1,
        totalVolume: 1150.0,
        caloriesBurned: 260.0,
        duration: const Duration(minutes: 50),
        personalRecords: const [
          'Barbell Bench Press: Weight PR 85.0 kg (+5.0 kg)',
        ],
        xpEarned: 350,
      );

      // Instant local save
      await workoutRepo.saveWorkoutSession(session);
      await workoutRepo.saveWorkoutCompletion(session.toWorkoutHistory());

      // 1. Verify saved immediately to LocalStorage without network
      final savedSessions = workoutRepo.getWorkoutSessions();
      expect(savedSessions.any((s) => s.id == 'sess_offline_99'), isTrue);

      final savedHistory = workoutRepo.getWorkoutHistory();
      expect(
        savedHistory.any((h) => h.workoutName == 'Heavy Push Power'),
        isTrue,
      );
    });

    test('6. Persist Nutrition & Meal Entries Offline', () async {
      final nutritionRepo = NutritionLocalRepository();
      const dateStr = '2026-08-26';

      final food = const FoodItem(
        id: 'food_whey_01',
        name: 'Whey Protein Isolate',
        calories: 120.0,
        protein: 25.0,
        carbohydrates: 2.0,
        fats: 1.0,
      );

      await nutritionRepo.logFoodItem(
        date: dateStr,
        category: MealCategory.snack,
        foodItem: food,
      );

      // Verify immediate local storage
      final daily = nutritionRepo.getDailyNutrition(dateStr);
      expect(
        daily.meals.any((m) => m.foods.any((f) => f.id == 'food_whey_01')),
        isTrue,
      );
    });

    test('8. AI Coach Offline Context & Preference Fallback', () async {
      final promptBuilder = const CoachPromptBuilder();

      // Ensure local workout history exists
      final workoutSession = WorkoutSession(
        id: 'sess_cached_01',
        workoutId: 'pull_01',
        workoutName: 'Pull & Core Hypertrophy',
        startTime: DateTime.now().subtract(const Duration(hours: 4)),
        endTime: DateTime.now().subtract(const Duration(hours: 3)),
        exercises: const [
          WorkoutSessionExercise(
            id: 'deadlift',
            name: 'Conventional Barbell Deadlift',
            muscleGroup: 'Back',
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 120.0,
                reps: 6,
                completed: true,
              ),
            ],
            isCompleted: true,
          ),
        ],
        completedExercises: 1,
        totalVolume: 720.0,
        caloriesBurned: 180.0,
        duration: const Duration(minutes: 45),
      );

      await LocalStorage.saveWorkoutSession(workoutSession);
      await LocalStorage.saveWorkoutCompletion(
        workoutSession.toWorkoutHistory(),
      );
      FitnessProvider.instance.refreshWorkoutHistory();

      // Offline query
      final prompt = promptBuilder.buildPrompt(
        message: 'What was my last workout volume and performance?',
        context: FitnessProvider.instance.buildFitnessContext(),
        intent: AIRequestIntent.workoutRequest,
      );

      // Verify AI Coach prompt is assembled from local memory without network dependencies
      expect(prompt.contains('[ATHLETE CONTEXT]'), isTrue);
      expect(prompt.contains('[RECENT PERFORMANCE]'), isTrue);
      expect(prompt.contains('Pull & Core Hypertrophy'), isTrue);
    });
  });
}
