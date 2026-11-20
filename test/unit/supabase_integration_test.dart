import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/auth/secure_auth_storage.dart';
import 'package:atlas/services/supabase/supabase_auth_provider.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/services/supabase/supabase_env.dart';
import 'package:atlas/services/supabase/supabase_nutrition_repository.dart';
import 'package:atlas/services/supabase/supabase_profile_repository.dart';
import 'package:atlas/services/supabase/supabase_service.dart';
import 'package:atlas/services/supabase/supabase_workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    SupabaseService.resetInstance();
  });

  group('1. SupabaseEnv Configuration Tests', () {
    test('Accepts a real-looking Supabase URL and anon key', () {
      final env = SupabaseEnv.prod(
        url: 'https://abcdefghijklmnop.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test-anon-key',
      );
      expect(env.supabaseUrl, contains('supabase.co'));
      expect(env.isValid, isTrue);
    });

    test('Falls back to placeholder credentials when nothing is defined', () {
      final env = SupabaseEnv.fromEnvironment();
      if (!_hasLiveBackend) {
        expect(env.isValid, isFalse);
      }
    });

    test('Validates placeholder or invalid credentials', () {
      const invalidEnv = SupabaseEnv(
        supabaseUrl: 'invalid-url',
        supabaseAnonKey: 'short',
      );
      expect(invalidEnv.isValid, isFalse);
    });
  });

  group('2. SupabaseService Lifecycle & Diagnostics Tests', () {
    test('SupabaseService initializes and exposes environment settings', () async {
      final service = SupabaseService.instance;
      await service.initialize();

      expect(service.isInitialized, isTrue);
      expect(service.env.supabaseUrl, isNotEmpty);
    }, skip: _liveBackendSkipReason);

    test('SupabaseService checkConnection returns status cleanly', () async {
      final service = SupabaseService.instance;
      await service.initialize();
      final connected = await service.checkConnection();
      expect(connected, isTrue);
    }, skip: _liveBackendSkipReason);
  });

  group('3. Supabase Authentication Layer Tests', () {
    test(
      'SupabaseAuthProvider performs sign up, stores session, and populates profiles',
      () async {
        final auth = SupabaseAuthProvider();

        final user = await auth.signUp(
          email: 'athlete@example.com',
          password: 'Password123!',
          displayName: 'Aizawl Lifter',
        );

        expect(user.id, isNotEmpty);
        expect(user.email, equals('athlete@example.com'));
        expect(user.displayName, equals('Aizawl Lifter'));

        final isAuth = await auth.isAuthenticated();
        expect(isAuth, isTrue);

        final token = await SecureAuthStorage.instance.getAccessToken();
        expect(token, isNotEmpty);
      },
    );

    test(
      'SupabaseAuthProvider sign in authenticates existing user and syncs profile',
      () async {
        final auth = SupabaseAuthProvider();

        final registered = await auth.signUp(
          email: 'member@example.com',
          password: 'SecurePassword123!',
          displayName: 'Mizo Strength',
        );

        await auth.signOut();
        expect(await auth.isAuthenticated(), isFalse);

        final loggedIn = await auth.signIn(
          email: 'member@example.com',
          password: 'SecurePassword123!',
        );

        expect(loggedIn.id, equals(registered.id));
        expect(await auth.isAuthenticated(), isTrue);
      },
    );
  });

  group('4. Database Repository Layer & Separation of Concerns Tests', () {
    test(
      'SupabaseProfileRepository performs CRUD operations isolated from UI',
      () async {
        final profileRepo = SupabaseProfileRepository();
        final profile = UserProfile.defaultProfile();
        profile.name = 'Vanlalruata';
        profile.email = 'vanlalruata@example.com';
        profile.fitnessGoal = 'Hypertrophy';

        await profileRepo.saveProfile(profile);

        final retrieved = profileRepo.getProfile();
        expect(retrieved.name, equals('Vanlalruata'));
        expect(retrieved.fitnessGoal, equals('Hypertrophy'));
      },
    );

    test(
      'SupabaseWorkoutRepository records and queries completed workout history',
      () async {
        final workoutRepo = SupabaseWorkoutRepository();
        final history = WorkoutHistory(
          workoutName: 'Heavy Push Day',
          dateCompleted: DateTime.now(),
          durationSeconds: 3000,
          exercisesCompleted: 4,
          completionPercentage: 100.0,
          totalVolume: 12450.0,
          caloriesBurned: 420.0,
        );

        await workoutRepo.saveWorkoutSession(history, userId: 'usr_sp_001');

        final historyList = await workoutRepo.getWorkoutHistory(
          userId: 'usr_sp_001',
        );
        expect(historyList.length, equals(1));
        expect(historyList.first.workoutName, equals('Heavy Push Day'));
        expect(historyList.first.totalVolume, equals(12450.0));
      },
    );

    test(
      'SupabaseNutritionRepository logs food entries and calculates daily totals',
      () async {
        final nutritionRepo = SupabaseNutritionRepository();
        final food = FoodItem(
          id: 'food_1',
          name: 'Grilled Chicken & Rice',
          calories: 650.0,
          protein: 55.0,
          carbohydrates: 70.0,
          fats: 12.0,
        );

        final meal = MealEntry(
          id: 'meal_sp_201',
          name: 'Lunch',
          foods: [food],
          isCompleted: true,
        );

        final daily = DailyNutrition(
          date:
              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
          targets: const MacroTarget(
            calories: 2500.0,
            proteinGrams: 160.0,
            carbsGrams: 280.0,
            fatGrams: 65.0,
          ),
          meals: [meal],
        );

        await nutritionRepo.saveDailyNutrition(daily, userId: 'usr_sp_001');

        final retrieved = await nutritionRepo.getTodayNutrition(
          userId: 'usr_sp_001',
        );
        expect(retrieved.meals.length, equals(1));
        expect(retrieved.meals.first.totalCalories, equals(650.0));
        expect(retrieved.meals.first.totalProtein, equals(55.0));
      },
    );
  });

  group('5. Offline Resilience & Connection Error Handling Tests', () {
    test(
      'Repository gracefully handles network errors with local storage preserved',
      () async {
        final clientManager = SupabaseClientManager.instance;
        clientManager.setSimulateNetworkError(true);

        final profileRepo = SupabaseProfileRepository();
        final profile = UserProfile.defaultProfile();
        profile.name = 'Offline Lifter';
        profile.email = 'offline@example.com';

        // Save locally first, cloud sync fails gracefully without throwing unhandled exceptions
        await profileRepo.saveProfile(profile);

        final localProfile = LocalStorage.getUserProfile();
        expect(localProfile.name, equals('Offline Lifter'));
      },
    );
  });

  group('6. AppDependencies Supabase Integration Tests', () {
    test('AppDependencies.useSupabase switches active stack to Supabase', () {
      AppDependencies.useSupabase();

      final deps = AppDependencies.instance;
      expect(deps.isUsingSupabase, isTrue);
      expect(deps.authProvider, isA<SupabaseAuthProvider>());
      expect(deps.profileRepository, isA<SupabaseProfileRepository>());
    });
  });
}

/// Live backend tests run only when SUPABASE_URL and SUPABASE_ANON_KEY are set
/// in the process environment, e.g. `SUPABASE_URL=... flutter test`.
bool get _hasLiveBackend {
  final url = Platform.environment['SUPABASE_URL'] ?? '';
  final key = Platform.environment['SUPABASE_ANON_KEY'] ?? '';
  return url.isNotEmpty && key.isNotEmpty;
}

String? get _liveBackendSkipReason => _hasLiveBackend
    ? null
    : 'Set SUPABASE_URL and SUPABASE_ANON_KEY to run live backend tests';
