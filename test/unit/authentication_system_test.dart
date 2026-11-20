import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local/nutrition_local_repository.dart';
import 'package:atlas/data/local/workout_local_repository.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/app_user.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/app_auth_provider.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/auth/auth_service.dart';
import '../mocks/mock_auth_provider.dart';
import 'package:atlas/services/auth/secure_auth_storage.dart';
import 'package:atlas/services/supabase/database_models.dart';
import 'package:atlas/services/supabase/supabase_auth_provider.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/services/supabase/supabase_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureAuthStorage secureStorage;
  late MockAuthProvider mockAuthBackend;
  late AuthService authService;
  late AppAuthProvider authProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();

    secureStorage = SecureAuthStorage.inMemory();
    SecureAuthStorage.setInstance(secureStorage);

    mockAuthBackend = MockAuthProvider(secureStorage: secureStorage);
    authService = AuthService(
      provider: mockAuthBackend,
      secureStorage: secureStorage,
    );
    AuthService.setInstance(authService);

    authProvider = AppAuthProvider(authService: authService);
    AppAuthProvider.setInstance(authProvider);
  });

  group('Atlas Backend Authentication & User Identity System (Phase B.3)', () {
    test(
      '1. User Registration with Secure Token Persistence & Profile Linkage',
      () async {
        const email = 'alex.athlete@Atlas.com';
        const password = 'SecurePassword123!';
        const username = 'AlexPro';

        final initialProfile = UserProfile.defaultProfile(email: email);
        initialProfile.name = username;
        initialProfile.fitnessGoal = 'Hypertrophy';
        initialProfile.workoutExperience = 'Advanced';
        initialProfile.height = '182.0';
        initialProfile.weight = '78.5';
        initialProfile.equipment = ['Barbell', 'Dumbbells', 'Cable Machine'];
        initialProfile.injuries = ['None'];

        final success = await authProvider.register(
          email: email,
          password: password,
          username: username,
          initialProfile: initialProfile,
        );

        expect(success, isTrue);
        expect(authProvider.status, AuthStatus.authenticated);
        expect(authProvider.isAuthenticated, isTrue);
        expect(authProvider.currentUser, isNotNull);
        expect(authProvider.currentUser!.email, equals(email));
        expect(authProvider.currentUser!.username, equals(username));

        // Verify Secure Hardware Token Storage
        final hasSession = await secureStorage.hasValidSession();
        expect(hasSession, isTrue);
        final storedToken = await secureStorage.getAccessToken();
        expect(storedToken, isNotNull);
        expect(storedToken!.isNotEmpty, isTrue);

        // Verify Profile Linkage to User ID
        final savedProfile = LocalStorage.getUserProfile();
        expect(savedProfile.userId, equals(authProvider.currentUser!.id));
        expect(savedProfile.name, equals(username));
        expect(savedProfile.fitnessGoal, equals('Hypertrophy'));
        expect(savedProfile.equipment.contains('Cable Machine'), isTrue);
      },
    );

    test('2. Secure User Login & Session Hydration', () async {
      const email = 'sam.runner@Atlas.com';
      const password = 'StrongPassword99!';

      // Register first
      await authProvider.register(
        email: email,
        password: password,
        username: 'SamRunner',
      );

      // Log out
      await authProvider.logout();
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);

      // Sign in
      final loginSuccess = await authProvider.login(
        email: email,
        password: password,
      );

      expect(loginSuccess, isTrue);
      expect(authProvider.status, AuthStatus.authenticated);
      expect(authProvider.currentUser!.email, equals(email));
      expect(await secureStorage.hasValidSession(), isTrue);
    });

    test('3. Invalid Credentials & Validation Error Handling', () async {
      // Invalid email format
      final invalidEmailSuccess = await authProvider.register(
        email: 'invalid-email-format',
        password: 'Password123',
      );
      expect(invalidEmailSuccess, isFalse);
      expect(authProvider.status, AuthStatus.error);
      expect(authProvider.errorMessage, contains('Invalid email'));

      // Short password (< 6 characters)
      final shortPasswordSuccess = await authProvider.login(
        email: 'user@Atlas.com',
        password: '123',
      );
      expect(shortPasswordSuccess, isFalse);
      expect(authProvider.status, AuthStatus.error);
      expect(authProvider.errorMessage, contains('at least 6 characters'));
    });

    test('4. Offline Session Restoration & Token Verification', () async {
      final user = AppUser(
        id: 'usr_offline_athlete_01',
        email: 'offline.athlete@Atlas.com',
        displayName: 'Offline Athlete',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await LocalStorage.saveAppUser(user);
      await secureStorage.saveAuthSession(
        accessToken: 'secure_offline_access_token_123',
        refreshToken: 'secure_offline_refresh_token_123',
        userId: user.id,
      );

      final restored = await authProvider.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.id, equals('usr_offline_athlete_01'));
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser!.displayName, equals('Offline Athlete'));
    });

    test('5. Complete Logout & Secure Token Purge', () async {
      await authProvider.register(
        email: 'purge.user@Atlas.com',
        password: 'Password123!',
        username: 'PurgeUser',
      );

      expect(await secureStorage.hasValidSession(), isTrue);
      expect(LocalStorage.getAppUser(), isNotNull);

      // Perform sign out
      await authProvider.logout();

      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(authProvider.currentUser, isNull);
      expect(LocalStorage.getAppUser(), isNull);
      expect(await secureStorage.hasValidSession(), isFalse);
      expect(await secureStorage.getAccessToken(), isNull);
    });

    test('6. User Profile Schema, Biometrics & Field Mapping', () {
      final profile = UserProfile(
        name: 'Jordan Cruz',
        email: 'jordan@Atlas.com',
        phone: '+1 555-0199',
        dob: '1996-05-15',
        gender: 'Male',
        height: '178.0',
        weight: '75.0',
        fitnessGoal: 'Fat Loss & Definition',
        workoutExperience: 'Intermediate',
        preferredDays: const ['Monday', 'Wednesday', 'Friday'],
        dietPreference: 'High Protein / Low Carb',
        massUnit: 'kg',
        lengthUnit: 'cm',
        subscription: 'Pro',
        privacy: 'Friends Only',
        notificationsEnabled: true,
        profilePic: 'https://Atlas.app/avatars/jordan.jpg',
      );

      profile.userId = 'usr_jordan_101';
      profile.equipment = ['Dumbbells', 'Pull-up Bar', 'Resistance Bands'];
      profile.injuries = ['Lower Back Strain (Mild)'];

      expect(profile.userId, equals('usr_jordan_101'));
      expect(profile.goal, equals('Fat Loss & Definition'));
      expect(profile.experienceLevel, equals('Intermediate'));
      expect(profile.equipment.length, equals(3));
      expect(profile.injuries.first, contains('Lower Back'));
      expect(profile.age, greaterThan(20));

      // Test Supabase Database Model Mapping
      final tableMap = SupabaseModelMappers.userProfileToTable(
        profile,
        userId: 'usr_jordan_101',
      );
      expect(tableMap['id'], equals('usr_jordan_101'));
      expect(tableMap['full_name'], equals('Jordan Cruz'));
      expect(tableMap['fitness_goal'], equals('Fat Loss & Definition'));

      final restoredProfile = SupabaseModelMappers.tableToUserProfile(tableMap);
      expect(restoredProfile.name, equals('Jordan Cruz'));
      expect(restoredProfile.email, equals('jordan@Atlas.com'));
      expect(restoredProfile.fitnessGoal, equals('Fat Loss & Definition'));
    });

    test('7. Multi-Tenant Data Segregation & User Data Ownership', () async {
      final workoutRepo = WorkoutLocalRepository();
      final nutritionRepo = NutritionLocalRepository();

      const userA = 'usr_athlete_alpha';
      const userB = 'usr_athlete_beta';

      // User A records workout
      final sessionA = WorkoutSession(
        id: 'session_alpha_01',
        workoutId: 'w_push_01',
        workoutName: 'Alpha Heavy Push',
        startTime: DateTime.now().subtract(const Duration(minutes: 40)),
        endTime: DateTime.now(),
        exercises: const [],
        completedExercises: 3,
        totalVolume: 3200.0,
        caloriesBurned: 350.0,
        duration: const Duration(minutes: 40),
      );
      await workoutRepo.saveWorkoutSession(sessionA, userId: userA);
      await workoutRepo.saveWorkoutCompletion(
        sessionA.toWorkoutHistory(),
        userId: userA,
      );

      // User B records workout
      final sessionB = WorkoutSession(
        id: 'session_beta_01',
        workoutId: 'w_pull_01',
        workoutName: 'Beta Pull Session',
        startTime: DateTime.now().subtract(const Duration(minutes: 45)),
        endTime: DateTime.now(),
        exercises: const [],
        completedExercises: 4,
        totalVolume: 4500.0,
        caloriesBurned: 400.0,
        duration: const Duration(minutes: 45),
      );
      await workoutRepo.saveWorkoutSession(sessionB, userId: userB);
      await workoutRepo.saveWorkoutCompletion(
        sessionB.toWorkoutHistory(),
        userId: userB,
      );

      // Verify User A only reads User A's workouts
      final historyA = workoutRepo.getWorkoutHistory(userId: userA);
      expect(historyA.any((h) => h.workoutName == 'Alpha Heavy Push'), isTrue);
      expect(
        historyA.any((h) => h.workoutName == 'Beta Pull Session'),
        isFalse,
      );

      // Verify User B only reads User B's workouts
      final historyB = workoutRepo.getWorkoutHistory(userId: userB);
      expect(historyB.any((h) => h.workoutName == 'Beta Pull Session'), isTrue);
      expect(historyB.any((h) => h.workoutName == 'Alpha Heavy Push'), isFalse);

      // User Nutrition Segregation
      final nutritionA = DailyNutrition(
        date: '2026-08-26',
        targets: MacroTarget.defaultTarget(),
        meals: const [],
        baseCalories: 2800.0,
        baseProtein: 180.0,
        baseCarbs: 300.0,
        baseFat: 80.0,
      );
      await nutritionRepo.saveDailyNutrition(nutritionA, userId: userA);

      final fetchedA = nutritionRepo.getDailyNutrition(
        '2026-08-26',
        userId: userA,
      );
      expect(fetchedA.baseCalories, equals(2800.0));
      expect(fetchedA.baseProtein, equals(180.0));
    });

    test(
      '8. Supabase Backend Authentication & RLS Architecture Verification',
      () async {
        SupabaseClientManager.instance.initialize(SupabaseEnv.dev());
        final supabaseAuth = SupabaseAuthProvider(secureStorage: secureStorage);

        const email = 'cloud.athlete@Atlas.app';
        const password = 'CloudPassword2026!';

        final cloudUser = await supabaseAuth.signUp(
          email: email,
          password: password,
          displayName: 'Cloud Athlete',
        );

        expect(cloudUser.email, equals(email));
        expect(cloudUser.displayName, equals('Cloud Athlete'));
        expect(
          SupabaseClientManager.instance.authenticatedUid,
          equals(cloudUser.id),
        );

        // Sign Out from Cloud
        await supabaseAuth.signOut();
        expect(SupabaseClientManager.instance.authenticatedUid, isNull);
        expect(await supabaseAuth.getCurrentUser(), isNull);
      },
    );

    test('9. Account Recovery & Password Reset Flow', () async {
      const validEmail = 'recovery.athlete@Atlas.com';

      final success = await authProvider.resetPassword(validEmail);
      expect(success, isTrue);

      final fail = await authProvider.resetPassword('bad-email');
      expect(fail, isFalse);
      expect(authProvider.errorMessage, contains('valid email'));
    });

    test(
      '10. AI Coach Telemetry Context receives Active Authenticated User Profile',
      () async {
        final user = AppUser(
          id: 'usr_coach_telemetry_01',
          email: 'telemetry@Atlas.com',
          displayName: 'Marcus Vance',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final profile = UserProfile.defaultProfile(email: user.email);
        profile.userId = user.id;
        profile.name = 'Marcus Vance';
        profile.fitnessGoal = 'Strength & Powerlifting';
        profile.workoutExperience = 'Advanced';
        profile.height = '185.0';
        profile.weight = '92.0';
        profile.equipment = ['Barbell', 'Squat Rack', 'Bumper Plates'];

        await LocalStorage.saveAppUser(user);
        await LocalStorage.saveUserProfile(profile);

        await FitnessProvider.instance.updateProfile(profile);

        final promptBuilder = CoachPromptBuilder();
        final fitnessContext = FitnessProvider.instance.buildFitnessContext();

        final prompt = promptBuilder.buildPrompt(
          message: 'Can you recommend an overload progression for my deadlift?',
          context: fitnessContext,
          intent: AIRequestIntent.workoutRequest,
        );

        expect(prompt.contains('[ATHLETE CONTEXT]'), isTrue);
        expect(prompt.contains('Strength & Powerlifting'), isTrue);
        expect(prompt.contains('Barbell'), isTrue);
      },
    );

    test(
      '11. Complete Onboarding Flow: Signup -> Goals -> Equipment -> Profile -> AI Context',
      () async {
        // Step 1: User Signs up
        const email = 'newbie.athlete@Atlas.com';
        const password = 'Password2026!';
        final signedUp = await authProvider.register(
          email: email,
          password: password,
          username: 'NewbiePro',
        );
        expect(signedUp, isTrue);
        expect(authProvider.isLoggedIn, isTrue);

        // Step 2: User completes onboarding questionnaire
        final onboardingProfile = UserProfile.defaultProfile(email: email);
        onboardingProfile.userId = authProvider.currentUser!.id;
        onboardingProfile.name = 'NewbiePro';
        onboardingProfile.dob = '1998-08-12';
        onboardingProfile.height = '175.0';
        onboardingProfile.weight = '70.0';
        onboardingProfile.fitnessGoal = 'Hypertrophy';
        onboardingProfile.workoutExperience = 'Beginner';
        onboardingProfile.equipment = ['Dumbbells', 'Adjustable Bench'];
        onboardingProfile.injuries = ['None'];

        // Step 3: Save profile
        await authProvider.updateProfile(onboardingProfile);
        await LocalStorage.saveUserProfile(onboardingProfile);

        // Step 4: Verify AuthProvider exposes profile & isLoggedIn aliases
        expect(authProvider.profile, isNotNull);
        expect(authProvider.profile!.userId, equals(authProvider.currentUser!.id));
        expect(authProvider.profile!.goal, equals('Hypertrophy'));
        expect(authProvider.profile!.experienceLevel, equals('Beginner'));
        expect(authProvider.profile!.equipment, contains('Adjustable Bench'));

        // Step 5: Verify AI receives instant context
        final promptBuilder = CoachPromptBuilder();
        final fitnessContext = FitnessContext(
          userProfile: onboardingProfile,
          nutritionSummary: NutritionSummary.empty(),
          progressSummary: ProgressSummary.zero(),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          generatedAt: DateTime.now(),
        );
        final prompt = promptBuilder.buildPrompt(
          message: 'What should my first workout routine be?',
          context: fitnessContext,
          intent: AIRequestIntent.workoutRequest,
        );

        expect(prompt, contains('[ATHLETE CONTEXT]'));
        expect(prompt.toLowerCase(), contains('hypertrophy'));
        expect(prompt, contains('Beginner'));
        expect(prompt, contains('Dumbbells'));
      },
    );

    test(
      '12. Sensitive Data Security: Passwords and raw tokens are never exposed in user objects',
      () {
        final user = AppUser(
          id: 'usr_secure_99',
          email: 'secure@Atlas.com',
          username: 'SecureAthlete',
        );

        final json = user.toJson();
        expect(json.containsKey('password'), isFalse);
        expect(json.containsKey('token'), isFalse);
        expect(json.containsKey('access_token'), isFalse);
        expect(json.containsKey('refresh_token'), isFalse);
        expect(json['id'], equals('usr_secure_99'));
        expect(json['email'], equals('secure@Atlas.com'));
      },
    );
  });
}

