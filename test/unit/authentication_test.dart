import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/providers/auth_provider.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/repositories/auth_repository.dart';
import 'package:atlas/services/auth/auth_service.dart';
import 'package:atlas/services/auth/secure_auth_storage.dart';
import 'package:atlas/services/supabase/database_models.dart';
import 'package:atlas/services/supabase/supabase_ai_repository.dart';
import 'package:atlas/services/supabase/supabase_auth_provider.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/services/supabase/supabase_nutrition_repository.dart';
import 'package:atlas/services/supabase/supabase_profile_repository.dart';
import 'package:atlas/services/supabase/supabase_workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClientManager clientManager;
  late SupabaseAuthProvider supabaseAuth;
  late AuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await SecureAuthStorage.instance.clearTokens();
    await LocalStorage.clearAppUser();
    FitnessProvider.resetInstance();

    clientManager = SupabaseClientManager.instance;
    clientManager.dbStore.clear();
    clientManager.setAuthUid(null);

    supabaseAuth = SupabaseAuthProvider(clientManager: clientManager);
    authService = AuthService(provider: supabaseAuth);
    AuthService.setInstance(authService);
    AuthProvider.resetInstance();
  });

  group('1. Supabase Authentication Core Service Tests', () {
    test('signUp creates user, returns AppUser, and persists tokens', () async {
      final user = await authService.signUp(
        email: 'athlete@Atlas.com',
        password: 'Password123!',
        displayName: 'John Athlete',
      );

      expect(user.id.isNotEmpty, isTrue);
      expect(user.email, equals('athlete@Atlas.com'));
      expect(user.displayName, equals('John Athlete'));
      expect(authService.isAuthenticated, isTrue);

      final token = await SecureAuthStorage.instance.getAccessToken();
      expect(token, isNotNull);
      expect(token, contains(user.id));
    });

    test('signUp automatically creates profiles and fitness_profiles in Supabase', () async {
      final user = await authService.signUp(
        email: 'newuser@Atlas.com',
        password: 'Password123!',
        displayName: 'New Athlete',
      );

      // Verify profiles table
      final profiles = await clientManager
          .from(SupabaseTableNames.profiles)
          .select('id', user.id);
      expect(profiles.isNotEmpty, isTrue);
      expect(profiles.first['email'], equals('newuser@Atlas.com'));
      expect(profiles.first['username'], equals('New Athlete'));

      // Verify fitness_profiles table
      final fitnessProfiles = await clientManager
          .from(SupabaseTableNames.fitnessProfiles)
          .select('user_id', user.id);
      expect(fitnessProfiles.isNotEmpty, isTrue);
      expect(fitnessProfiles.first['user_id'], equals(user.id));
    });

    test('signUp rejects weak passwords and empty credentials', () async {
      expect(
        () => authService.signUp(email: '', password: '123'),
        throwsFormatException,
      );

      expect(
        () => authService.signUp(
          email: 'valid@Atlas.com',
          password: '123', // < 6 chars
        ),
        throwsFormatException,
      );
    });

    test('signUp rejects duplicate account registration', () async {
      await authService.signUp(
        email: 'duplicate@Atlas.com',
        password: 'Password123!',
      );

      expect(
        () => authService.signUp(
          email: 'duplicate@Atlas.com',
          password: 'Password123!',
        ),
        throwsFormatException,
      );
    });

    test('signIn authenticates existing user and sets active session', () async {
      await authService.signUp(
        email: 'loginuser@Atlas.com',
        password: 'Password123!',
        displayName: 'Login User',
      );
      await authService.signOut();
      expect(authService.isAuthenticated, isFalse);

      final loggedIn = await authService.signIn(
        email: 'loginuser@Atlas.com',
        password: 'Password123!',
      );

      expect(loggedIn.email, equals('loginuser@Atlas.com'));
      expect(loggedIn.displayName, equals('Login User'));
      expect(authService.isAuthenticated, isTrue);
      expect(clientManager.authenticatedUid, equals(loggedIn.id));
    });

    test('signOut clears active session, auth state, and tokens', () async {
      await authService.signUp(
        email: 'logoutuser@Atlas.com',
        password: 'Password123!',
      );
      expect(authService.isAuthenticated, isTrue);

      await authService.signOut();

      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);
      expect(clientManager.authenticatedUid, isNull);

      final token = await SecureAuthStorage.instance.getAccessToken();
      expect(token, isNull);
    });

    test('restoreSession restores session from persistent storage on app restart', () async {
      final user = await authService.signUp(
        email: 'persisted@Atlas.com',
        password: 'Password123!',
        displayName: 'Persisted Athlete',
      );

      // Simulate app restart: reinitialize provider & service
      clientManager.setAuthUid(null);
      final newAuthService = AuthService(provider: supabaseAuth);

      final restored = await newAuthService.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.id, equals(user.id));
      expect(restored.email, equals('persisted@Atlas.com'));
      expect(newAuthService.isAuthenticated, isTrue);
      expect(clientManager.authenticatedUid, equals(user.id));
    });
  });

  group('2. AuthProvider State Management Tests', () {
    test('AuthProvider transitions through Loading and Authenticated on signUp', () async {
      final provider = AuthProvider(authService: authService);
      expect(provider.isUnauthenticated, isTrue);

      final success = await provider.signUp(
        email: 'provider@Atlas.com',
        password: 'Password123!',
        displayName: 'Provider Athlete',
      );

      expect(success, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.state, isA<Authenticated>());
      expect(provider.email, equals('provider@Atlas.com'));
      expect(provider.userId, isNotNull);
      expect(provider.errorMessage, isNull);
    });

    test('AuthProvider transitions to Unauthenticated with errorMessage on invalid signIn', () async {
      final provider = AuthProvider(authService: authService);

      final success = await provider.signIn(
        email: '',
        password: '',
      );

      expect(success, isFalse);
      expect(provider.isUnauthenticated, isTrue);
      expect(provider.state, isA<Unauthenticated>());
      expect(provider.errorMessage, isNotNull);
    });

    test('AuthProvider signOut transitions to Unauthenticated state', () async {
      final provider = AuthProvider(authService: authService);
      await provider.signUp(
        email: 'signout@Atlas.com',
        password: 'Password123!',
      );
      expect(provider.isAuthenticated, isTrue);

      await provider.signOut();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.isUnauthenticated, isTrue);
      expect(provider.currentUser, isNull);
    });
  });

  group('3. User Data Isolation & Row Level Security (RLS) Tests', () {
    test('Users cannot access or modify each other\'s workout sessions', () async {
      // User 1: create workout
      final user1 = await authService.signUp(
        email: 'user1@Atlas.com',
        password: 'Password123!',
      );
      final workoutRepo = SupabaseWorkoutRepository(clientManager: clientManager);

      final session1 = WorkoutSession(
        id: 'sess_user1_01',
        workoutId: 'w_chest',
        workoutName: 'Chest Day',
        startTime: DateTime.now(),
        exercises: const [],
        completedExercises: 3,
        totalVolume: 1200.0,
        caloriesBurned: 250.0,
        duration: const Duration(seconds: 1800),
      );
      await workoutRepo.saveWorkoutSessionModel(session1, userId: user1.id);

      // User 2: logs in
      await authService.signOut();
      final user2 = await authService.signUp(
        email: 'user2@Atlas.com',
        password: 'Password123!',
      );

      // User 2 queries workout sessions: RLS isolates User 1 data
      final user2Sessions = await workoutRepo.getWorkoutSessions(userId: user2.id);
      expect(user2Sessions.any((s) => s.id == 'sess_user1_01'), isFalse);

      // User 2 cannot insert with User 1 user_id under RLS
      expect(
        () => clientManager.from(SupabaseTableNames.workoutSessions).insert({
          'id': 'malicious_sess_02',
          'user_id': user1.id, // Trying to forge User 1 data
          'workout_name': 'Hacked Session',
        }),
        throwsA(isA<PostgresSecurityException>()),
      );

      // User 2 cannot delete User 1 workout session under RLS
      expect(
        () => clientManager
            .from(SupabaseTableNames.workoutSessions)
            .delete('id', 'sess_user1_01'),
        throwsA(isA<PostgresSecurityException>()),
      );
    });

    test('Users cannot access or modify each other\'s nutrition logs', () async {
      // User 1 logs nutrition
      final user1 = await authService.signUp(
        email: 'nutrition1@Atlas.com',
        password: 'Password123!',
      );
      final nutritionRepo = SupabaseNutritionRepository(clientManager: clientManager);

      final nutrition = DailyNutrition(
        date: '2026-08-26',
        targets: const MacroTarget(
          calories: 2500,
          proteinGrams: 180,
          carbsGrams: 280,
          fatGrams: 70,
        ),
        meals: const [],
        waterLiters: 3.0,
      );
      await nutritionRepo.saveDailyNutrition(nutrition, userId: user1.id);

      // User 2 logs in
      await authService.signOut();
      final user2 = await authService.signUp(
        email: 'nutrition2@Atlas.com',
        password: 'Password123!',
      );

      // User 2 queries nutrition: does not see user1's records
      final user2Rows = await clientManager
          .from(SupabaseTableNames.nutritionLogs)
          .select('user_id', user2.id);
      expect(user2Rows.any((r) => r['user_id'] == user1.id), isFalse);

      // User 2 cannot mutate user 1 nutrition logs under RLS
      expect(
        () => clientManager.from(SupabaseTableNames.nutritionLogs).insert({
          'id': 'malicious_nutrition_log',
          'user_id': user1.id,
          'calories': 5000,
        }),
        throwsA(isA<PostgresSecurityException>()),
      );
    });

    test('AI Memory and conversation history is strictly isolated per user', () async {
      final user1 = await authService.signUp(
        email: 'aiuser1@Atlas.com',
        password: 'Password123!',
      );
      final aiRepo = SupabaseAIRepository(clientManager: clientManager);

      final entry1 = AIMemoryEntry(
        id: 'mem_user1_01',
        userId: user1.id,
        memoryType: 'preferences',
        memoryValue: {'preferredExercise': 'Bench Press'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await aiRepo.saveMemoryEntry(entry1);

      // User 2 logs in
      await authService.signOut();
      final user2 = await authService.signUp(
        email: 'aiuser2@Atlas.com',
        password: 'Password123!',
      );

      final user2Entries = await aiRepo.getMemoryEntries(userId: user2.id);
      expect(user2Entries.any((m) => m.id == 'mem_user1_01'), isFalse);

      // User 2 cannot insert AI memory with User 1 id
      expect(
        () => clientManager.from(SupabaseTableNames.aiMemory).insert({
          'id': 'hacked_ai_mem',
          'user_id': user1.id,
          'memory_type': 'preferences',
        }),
        throwsA(isA<PostgresSecurityException>()),
      );
    });
  });

  group('4. Fitness Profile & Onboarding Connection Tests', () {
    test('FitnessProfile updates propagate and feed user profile repositories', () async {
      final user = await authService.signUp(
        email: 'onboarding@Atlas.com',
        password: 'Password123!',
        displayName: 'Onboarding Athlete',
      );

      final profileRepo = SupabaseProfileRepository(clientManager: clientManager);

      final updatedProfile = UserProfile(
        name: 'Onboarding Athlete',
        email: user.email,
        phone: '1234567890',
        dob: '1998-05-15',
        gender: 'female',
        height: '168',
        weight: '62',
        fitnessGoal: 'fat_loss',
        workoutExperience: 'advanced',
        preferredDays: const ['Mon', 'Tue', 'Thu', 'Fri'],
        dietPreference: 'high_protein',
        massUnit: 'kg',
        lengthUnit: 'cm',
        subscription: 'Premium',
        privacy: 'Public',
        notificationsEnabled: true,
        profilePic: '',
      )..userId = user.id;

      await profileRepo.saveProfile(updatedProfile);

      // Verify fitness_profiles table in Supabase
      final fitnessProfiles = await clientManager
          .from(SupabaseTableNames.fitnessProfiles)
          .select('user_id', user.id);

      expect(fitnessProfiles.isNotEmpty, isTrue);
      final row = fitnessProfiles.first;
      expect(row['fitness_goal'], equals('fat_loss'));
      expect(row['height'], equals('168'));
      expect(row['weight'], equals('62'));
      expect(row['experience_level'], equals('advanced'));
    });
  });

  group('5. SupabaseAuthRepository & FitnessProvider End-to-End Tests', () {
    test('SupabaseAuthRepository operates cleanly with AuthService', () async {
      final repo = SupabaseAuthRepository(authService: authService);

      final user = await repo.signUp(
        email: 'repo_auth@Atlas.com',
        password: 'Password123!',
        displayName: 'Repo User',
      );

      expect(user.email, equals('repo_auth@Atlas.com'));
      expect(repo.isAuthenticated, isTrue);

      await repo.signOut();
      expect(repo.isAuthenticated, isFalse);

      final loggedIn = await repo.signIn(
        email: 'repo_auth@Atlas.com',
        password: 'Password123!',
      );
      expect(loggedIn.id, equals(user.id));
      expect(repo.isAuthenticated, isTrue);
    });

    test('FitnessProvider signup and login integrate with Supabase session', () async {
      final repo = SupabaseAuthRepository(authService: authService);
      final fitness = FitnessProvider(authRepository: repo);

      final user = await fitness.signup(
        email: 'fitness_provider@Atlas.com',
        password: 'Password123!',
        displayName: 'Fitness Provider User',
      );

      expect(user, isNotNull);
      expect(fitness.isLoggedIn, isTrue);
      expect(fitness.currentUser?.email, equals('fitness_provider@Atlas.com'));

      await fitness.logout();
      expect(fitness.isLoggedIn, isFalse);
      expect(fitness.currentUser, isNull);

      final loggedIn = await fitness.login(
        email: 'fitness_provider@Atlas.com',
        password: 'Password123!',
      );
      expect(loggedIn, isNotNull);
      expect(fitness.isLoggedIn, isTrue);
    });
  });
}
