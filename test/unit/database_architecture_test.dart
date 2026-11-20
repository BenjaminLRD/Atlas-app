import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/repositories/health_repository.dart';
import 'package:atlas/services/auth/secure_auth_storage.dart';
import 'package:atlas/services/supabase/database_models.dart';
import 'package:atlas/services/supabase/supabase_ai_repository.dart';
import 'package:atlas/services/supabase/supabase_auth_provider.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/services/supabase/supabase_community_repository.dart';
import 'package:atlas/services/supabase/supabase_health_repository.dart';
import 'package:atlas/services/supabase/supabase_nutrition_repository.dart';
import 'package:atlas/services/supabase/supabase_profile_repository.dart';
import 'package:atlas/services/supabase/supabase_workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClientManager clientManager;
  late SupabaseAuthProvider supabaseAuth;
  late SupabaseWorkoutRepository workoutRepo;
  late SupabaseNutritionRepository nutritionRepo;
  late SupabaseAIRepository aiRepo;
  late SupabaseHealthRepository healthRepo;
  late SupabaseProfileRepository profileRepo;
  late SupabaseCommunityRepository communityRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await SecureAuthStorage.instance.clearTokens();
    await LocalStorage.clearAppUser();

    clientManager = SupabaseClientManager.instance;
    clientManager.dbStore.clear();
    clientManager.setAuthUid(null);

    supabaseAuth = SupabaseAuthProvider(clientManager: clientManager);
    workoutRepo = SupabaseWorkoutRepository(clientManager: clientManager);
    nutritionRepo = SupabaseNutritionRepository(clientManager: clientManager);
    aiRepo = SupabaseAIRepository(clientManager: clientManager);
    healthRepo = SupabaseHealthRepository(clientManager: clientManager);
    profileRepo = SupabaseProfileRepository(clientManager: clientManager);
    communityRepo = SupabaseCommunityRepository(clientManager: clientManager);
  });

  group('1. Database Schema & Table Structure Tests', () {
    test('All Phase B.4 Supabase Table Names are registered and accessible', () {
      expect(SupabaseTableNames.profiles, equals('profiles'));
      expect(SupabaseTableNames.fitnessProfiles, equals('fitness_profiles'));
      expect(SupabaseTableNames.workoutSessions, equals('workout_sessions'));
      expect(SupabaseTableNames.workoutExercises, equals('workout_exercises'));
      expect(SupabaseTableNames.nutritionLogs, equals('nutrition_logs'));
      expect(SupabaseTableNames.mealEntries, equals('meal_entries'));
      expect(SupabaseTableNames.aiMemory, equals('ai_memory'));
      expect(SupabaseTableNames.healthMetrics, equals('health_metrics'));
      expect(SupabaseTableNames.posts, equals('posts'));
      expect(SupabaseTableNames.comments, equals('comments'));
    });

    test('Tables can receive structured CRUD operations', () async {
      final user = await supabaseAuth.signUp(
        email: 'schema_test@Atlas.com',
        password: 'Password123!',
        displayName: 'Schema Athlete',
      );

      // Insert directly to verify table existence and structure
      final profileRow = await clientManager.from(SupabaseTableNames.profiles).select('id', user.id);
      expect(profileRow.isNotEmpty, isTrue);
      expect(profileRow.first['email'], equals('schema_test@Atlas.com'));

      final fitnessProfileRow = await clientManager.from(SupabaseTableNames.fitnessProfiles).select('user_id', user.id);
      expect(fitnessProfileRow.isNotEmpty, isTrue);

      // Verify profileRepo saves correctly
      final updatedProfile = UserProfile.defaultProfile(email: user.email)..name = 'Updated Schema Athlete';
      await profileRepo.saveProfile(updatedProfile);
      final refetched = await clientManager.from(SupabaseTableNames.profiles).select('id', user.id);
      expect(refetched.first['full_name'], equals('Updated Schema Athlete'));
    });
  });

  group('2. Workout Database & Execution History Tests', () {
    test('WorkoutRepository saves session and normalizes workout_exercises', () async {
      final user = await supabaseAuth.signUp(
        email: 'workout_db@Atlas.com',
        password: 'Password123!',
      );

      final session = WorkoutSession(
        id: 'sess_db_001',
        workoutId: 'w_push_hypertrophy',
        workoutName: 'Push Hypertrophy Day',
        startTime: DateTime.now().subtract(const Duration(minutes: 45)),
        endTime: DateTime.now(),
        completedExercises: 1,
        totalVolume: 3200.0,
        caloriesBurned: 350.0,
        duration: const Duration(minutes: 45),
        exercises: [
          WorkoutSessionExercise(
            id: 'ex_bench_01',
            name: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            sets: [
              const WorkoutSessionSet(
                setNumber: 1,
                reps: 10,
                weight: 80.0,
                completed: true,
              ),
              const WorkoutSessionSet(
                setNumber: 2,
                reps: 8,
                weight: 85.0,
                completed: true,
              ),
            ],
          ),
        ],
      );

      await workoutRepo.saveWorkoutSessionModel(session, userId: user.id);

      // Verify workout_sessions row
      final sessionRows = await clientManager
          .from(SupabaseTableNames.workoutSessions)
          .select('id', 'sess_db_001');
      expect(sessionRows.isNotEmpty, isTrue);
      expect(sessionRows.first['workout_name'], equals('Push Hypertrophy Day'));
      expect(sessionRows.first['total_volume'], equals(3200.0));

      // Verify workout_exercises row
      final exerciseRows = await clientManager
          .from(SupabaseTableNames.workoutExercises)
          .select('session_id', 'sess_db_001');
      expect(exerciseRows.isNotEmpty, isTrue);
      expect(exerciseRows.first['exercise_name'], equals('Barbell Bench Press'));
      expect(exerciseRows.first['muscle_group'], equals('Chest'));
      expect(exerciseRows.first['volume'], equals(1480.0));
      expect(exerciseRows.first['max_weight'], equals(85.0));

      // Query via repository
      final history = await workoutRepo.getWorkoutSessions(userId: user.id);
      expect(history.length, equals(1));
      expect(history.first.workoutName, equals('Push Hypertrophy Day'));
    });
  });

  group('3. Nutrition Database & Meal Entries Tests', () {
    test('NutritionRepository saves daily log and normalized meal entries', () async {
      final user = await supabaseAuth.signUp(
        email: 'nutrition_db@Atlas.com',
        password: 'Password123!',
      );

      final dateStr = '2026-08-26';
      final foodItem = FoodItem(
        id: 'food_chicken_breast',
        name: 'Grilled Chicken Breast',
        category: 'Protein',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 3.6,
        servingSize: '100g',
      );

      final dailyNutrition = DailyNutrition(
        date: dateStr,
        targets: const MacroTarget(
          calories: 2400.0,
          proteinGrams: 180.0,
          carbsGrams: 260.0,
          fatGrams: 65.0,
        ),
        meals: [
          MealEntry(
            id: 'meal_lunch_01',
            mealType: MealCategory.lunch,
            date: DateTime.now(),
            consumedFoods: [
              ConsumedFood(
                food: foodItem,
                quantity: 2.0,
                unit: 'servings',
              ),
            ],
          ),
        ],
        waterLiters: 3.2,
      );

      await nutritionRepo.saveDailyNutrition(dailyNutrition, userId: user.id);

      // Verify nutrition_logs row
      final logRows = await clientManager
          .from(SupabaseTableNames.nutritionLogs)
          .select('user_id', user.id);
      expect(logRows.isNotEmpty, isTrue);
      expect(logRows.first['date'], equals(dateStr));
      expect(logRows.first['water_liters'], equals(3.2));

      // Verify meal_entries row
      final mealRows = await clientManager
          .from(SupabaseTableNames.mealEntries)
          .select();
      expect(mealRows.isNotEmpty, isTrue);
      expect(mealRows.first['food_name'], equals('Grilled Chicken Breast'));
      expect(mealRows.first['meal_type'], equals('lunch'));
      expect(mealRows.first['calories'], equals(330));
    });
  });

  group('4. AI Memory Database Tests', () {
    test('AIRepository persists and queries context, conversation, and preferences', () async {
      final user = await supabaseAuth.signUp(
        email: 'aimemory_db@Atlas.com',
        password: 'Password123!',
      );

      final memoryEntry = AIMemoryEntry(
        id: 'mem_ai_001',
        userId: user.id,
        memoryType: 'coaching_context',
        conversation: 'User discussed improving bench press technique.',
        fitnessContext: {
          'currentSplit': 'Push/Pull/Legs',
          'focusMuscle': 'Chest & Triceps',
        },
        preferences: {
          'preferredWarmup': 'Dynamic mobility',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await aiRepo.saveMemoryEntry(memoryEntry);

      final memories = await aiRepo.getMemoryEntries(userId: user.id);
      expect(memories.isNotEmpty, isTrue);
      expect(memories.first.id, equals('mem_ai_001'));
      expect(memories.first.conversation, equals('User discussed improving bench press technique.'));
      expect(memories.first.fitnessContext?['currentSplit'], equals('Push/Pull/Legs'));

      // Test Conversation messages
      final coachMsg = CoachMessage(
        id: 'msg_001',
        role: CoachRole.assistant,
        content: 'Keep your elbows tucked at a 45-degree angle during the bench press.',
        timestamp: DateTime.now(),
      );
      await aiRepo.saveConversationMessage(coachMsg, userId: user.id);

      final convos = await aiRepo.getConversations(userId: user.id);
      expect(convos.any((c) => c.content.contains('elbows tucked')), isTrue);
    });
  });

  group('5. Health Data Database Tests', () {
    test('HealthRepository stores and retrieves health metrics', () async {
      final user = await supabaseAuth.signUp(
        email: 'health_db@Atlas.com',
        password: 'Password123!',
      );

      final metric = HealthMetric(
        timestamp: DateTime.now(),
        steps: 10450,
        distanceKm: 8.2,
        activeCalories: 520.0,
        heartRate: 72,
        restingHeartRate: 58,
        sleepMinutes: 480, // 8 hours
        deepSleepMinutes: 120,
        source: 'smartwatch',
      );

      await healthRepo.saveHealthMetric(metric, userId: user.id);

      final retrieved = await healthRepo.getTodayHealthMetric(userId: user.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.steps, equals(10450));
      expect(retrieved.heartRate, equals(72));

      final history = await healthRepo.getHealthHistory(userId: user.id);
      expect(history.isNotEmpty, isTrue);
      expect(history.first.steps, equals(10450));
    });
  });

  group('6. Community Database Tests', () {
    test('CommunityRepository creates posts and retrieves public feed', () async {
      final user = await supabaseAuth.signUp(
        email: 'community_db@Atlas.com',
        password: 'Password123!',
        displayName: 'Community Hero',
      );

      final post = ActivityPost(
        id: 'post_comm_001',
        userId: user.id,
        userName: 'Community Hero',
        type: ActivityPostType.workout,
        title: 'Crushed new 100kg Bench PR!',
        description: 'Feeling stronger than ever thanks to AI coaching.',
        likes: 12,
        comments: 3,
        createdAt: DateTime.now(),
      );

      await communityRepo.createPost(post);

      final feed = await communityRepo.getCommunityFeed();
      expect(feed.any((p) => p.id == 'post_comm_001'), isTrue);
    });
  });

  group('7. Row Level Security (RLS) & Multi-User Isolation Tests', () {
    test('RLS blocks User B from accessing or mutating User A data across all tables', () async {
      // 1. User A creates private records
      final userA = await supabaseAuth.signUp(
        email: 'athlete_a@Atlas.com',
        password: 'Password123!',
        displayName: 'Athlete A',
      );

      // User A Workout
      final sessionA = WorkoutSession(
        id: 'sess_private_a',
        workoutId: 'w_a',
        workoutName: 'Athlete A Workout',
        startTime: DateTime.now(),
        completedExercises: 2,
        totalVolume: 2000.0,
        caloriesBurned: 200.0,
        duration: const Duration(minutes: 30),
      );
      await workoutRepo.saveWorkoutSessionModel(sessionA, userId: userA.id);

      // User A Nutrition
      final nutritionA = DailyNutrition(
        date: '2026-08-26',
        targets: const MacroTarget(
          calories: 2000,
          proteinGrams: 150,
          carbsGrams: 200,
          fatGrams: 50,
        ),
        meals: const [],
      );
      await nutritionRepo.saveDailyNutrition(nutritionA, userId: userA.id);

      // User A AI Memory
      final memoryA = AIMemoryEntry(
        id: 'mem_private_a',
        userId: userA.id,
        conversation: 'Private athlete A injury discussion.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await aiRepo.saveMemoryEntry(memoryA);

      // User A Health
      final healthA = HealthMetric(
        timestamp: DateTime.now(),
        steps: 8000,
      );
      await healthRepo.saveHealthMetric(healthA, userId: userA.id);

      // User A Community Post
      final postA = ActivityPost(
        id: 'post_public_a',
        userId: userA.id,
        userName: 'Athlete A',
        type: ActivityPostType.workout,
        title: 'Public post by Athlete A',
        description: 'Public post description by Athlete A',
        createdAt: DateTime.now(),
      );
      await communityRepo.createPost(postA);

      // 2. User B logs in
      await supabaseAuth.signOut();
      final userB = await supabaseAuth.signUp(
        email: 'athlete_b@Atlas.com',
        password: 'Password123!',
        displayName: 'Athlete B',
      );

      // Query verification: User B cannot see User A's private data
      final sessionsB = await workoutRepo.getWorkoutSessions(userId: userB.id);
      expect(sessionsB.any((s) => s.id == 'sess_private_a'), isFalse);

      final memoriesB = await aiRepo.getMemoryEntries(userId: userB.id);
      expect(memoriesB.any((m) => m.id == 'mem_private_a'), isFalse);

      // Mutation violations: User B attempts to forge User A data
      // RLS on workout_sessions
      expect(
        () => clientManager.from(SupabaseTableNames.workoutSessions).insert({
          'id': 'hacked_session',
          'user_id': userA.id,
          'workout_name': 'Forged Session',
        }),
        throwsA(isA<PostgresSecurityException>()),
      );

      // RLS on nutrition_logs
      expect(
        () => clientManager.from(SupabaseTableNames.nutritionLogs).insert({
          'id': 'hacked_nutrition',
          'user_id': userA.id,
          'date': '2026-08-26',
        }),
        throwsA(isA<PostgresSecurityException>()),
      );

      // RLS on ai_memory
      expect(
        () => clientManager.from(SupabaseTableNames.aiMemory).insert({
          'id': 'hacked_ai',
          'user_id': userA.id,
          'conversation': 'Hacked',
        }),
        throwsA(isA<PostgresSecurityException>()),
      );

      // RLS on health_metrics
      expect(
        () => clientManager.from(SupabaseTableNames.healthMetrics).insert({
          'id': 'hacked_health',
          'user_id': userA.id,
          'steps': 99999,
        }),
        throwsA(isA<PostgresSecurityException>()),
      );

      // RLS on updating User A's profile
      expect(
        () => clientManager.from(SupabaseTableNames.profiles).update(
          {'username': 'Hacked Name'},
          'id',
          userA.id,
        ),
        throwsA(isA<PostgresSecurityException>()),
      );

      // Community RLS: User B can read public post, but CANNOT update or delete it
      final feedForB = await communityRepo.getCommunityFeed();
      expect(feedForB.any((p) => p.id == 'post_public_a'), isTrue);

      expect(
        () => clientManager.from(SupabaseTableNames.posts).update(
          {'caption': 'Defaced Caption'},
          'id',
          'post_public_a',
        ),
        throwsA(isA<PostgresSecurityException>()),
      );

      expect(
        () => clientManager.from(SupabaseTableNames.posts).delete(
          'id',
          'post_public_a',
        ),
        throwsA(isA<PostgresSecurityException>()),
      );
    });
  });

  group('8. AppDependencies Layer Integration Tests', () {
    test('AppDependencies provides wired repositories in Supabase and Mock modes', () {
      AppDependencies.useSupabase();
      final deps = AppDependencies.instance;

      expect(deps.isUsingSupabase, isTrue);
      expect(deps.healthRepository, isA<SupabaseHealthRepository>());
      expect(deps.aiRepository, isA<SupabaseAIRepository>());
      expect(deps.profileRepository, isA<SupabaseProfileRepository>());

      AppDependencies.useMock();
      final mockDeps = AppDependencies.instance;
      expect(mockDeps.isUsingSupabase, isFalse);
      expect(mockDeps.healthRepository, isA<LocalHealthRepository>());
    });
  });
}
