import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/auth/secure_auth_storage.dart';
import 'package:atlas/services/supabase/database_models.dart';
import 'package:atlas/services/supabase/supabase_auth_provider.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/services/supabase/supabase_workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseClientManager clientManager;
  late SecureAuthStorage secureStorage;
  late SupabaseAuthProvider authProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    clientManager = SupabaseClientManager.instance;
    clientManager.clearData();
    secureStorage = SecureAuthStorage.inMemory();
    SecureAuthStorage.setInstance(secureStorage);
    authProvider = SupabaseAuthProvider(
      clientManager: clientManager,
      secureStorage: secureStorage,
    );
  });

  group('Phase 2 & 3 — Supabase Authentication & Profile Lifecycle', () {
    test(
      'Register creates auth user, profile row, and stores tokens securely',
      () async {
        final user = await authProvider.signUp(
          email: 'lalremruata@example.com',
          password: 'Password@123',
          displayName: 'Lalremruata',
        );

        expect(user.id, startsWith('sp_usr_'));
        expect(user.email, equals('lalremruata@example.com'));
        expect(user.displayName, equals('Lalremruata'));

        // Check session in SecureAuthStorage
        expect(await secureStorage.hasValidSession(), isTrue);
        expect(await secureStorage.getUserId(), equals(user.id));
        expect(await secureStorage.getAccessToken(), isNotNull);

        // Check profiles table in Supabase
        final profileRows = await clientManager
            .from(SupabaseTableNames.profiles)
            .select('id', user.id);
        expect(profileRows.isNotEmpty, isTrue);
        expect(profileRows.first['full_name'], equals('Lalremruata'));
        expect(profileRows.first['email'], equals('lalremruata@example.com'));
        // Zero passwords or secrets in table
        expect(profileRows.first.containsKey('password'), isFalse);
        expect(profileRows.first.containsKey('token'), isFalse);
      },
    );

    test(
      'Login authenticates user, retrieves profile, and sets active session',
      () async {
        // 1. Sign up user
        final registered = await authProvider.signUp(
          email: 'zothana@aizawlgym.com',
          password: 'Password@123',
          displayName: 'Zothana Sailo',
        );

        // 2. Sign out
        await authProvider.signOut();
        expect(await authProvider.isAuthenticated(), isFalse);
        expect(await secureStorage.hasValidSession(), isFalse);

        // 3. Sign in
        final loggedIn = await authProvider.signIn(
          email: 'zothana@aizawlgym.com',
          password: 'Password@123',
        );

        expect(loggedIn.id, equals(registered.id));
        expect(await authProvider.isAuthenticated(), isTrue);
        expect(await secureStorage.hasValidSession(), isTrue);

        final cachedProfile = LocalStorage.getUserProfile();
        expect(cachedProfile.email, equals('zothana@aizawlgym.com'));
      },
    );

    test('Logout clears session, secure tokens, and local cache', () async {
      await authProvider.signUp(
        email: 'logout_test@example.com',
        password: 'Password@123',
      );
      expect(await authProvider.isAuthenticated(), isTrue);

      await authProvider.signOut();
      expect(await authProvider.isAuthenticated(), isFalse);
      expect(await secureStorage.getAccessToken(), isNull);
      expect(await secureStorage.getUserId(), isNull);
      expect(LocalStorage.getAppUser(), isNull);
    });
  });

  group('Phase 5, 6 & 7 — Row Level Security (RLS) & Isolation Policies', () {
    test(
      'User A cannot read User B private health and workout records',
      () async {
        final userAId = 'usr_alice_01';
        final userBId = 'usr_bob_02';

        // Insert private records for User B
        clientManager.setAuthUid(userBId);
        await clientManager.from(SupabaseTableNames.healthMetrics).insert({
          'id': 'hm_bob_today',
          'user_id': userBId,
          'metric_date': '2026-08-16',
          'steps': 12000,
          'heart_rate': 68,
        });

        await clientManager.from(SupabaseTableNames.workoutSessions).insert({
          'id': 'ws_bob_legday',
          'user_id': userBId,
          'workout_name': 'Heavy Squats',
          'duration_seconds': 3600,
        });

        // Switch auth context to User A
        clientManager.setAuthUid(userAId);

        // User A queries healthMetrics -> RLS filters to 0 rows
        final visibleHealth = await clientManager
            .from(SupabaseTableNames.healthMetrics)
            .select();
        expect(visibleHealth.isEmpty, isTrue);

        // User A queries workoutSessions -> RLS filters to 0 rows
        final visibleWorkouts = await clientManager
            .from(SupabaseTableNames.workoutSessions)
            .select();
        expect(visibleWorkouts.isEmpty, isTrue);
      },
    );

    test('User A cannot modify or delete User B workout records', () async {
      final userAId = 'usr_alice_01';
      final userBId = 'usr_bob_02';

      clientManager.setAuthUid(userBId);
      await clientManager.from(SupabaseTableNames.workoutSessions).insert({
        'id': 'ws_bob_bench',
        'user_id': userBId,
        'workout_name': 'Chest Day',
      });

      // Switch auth context to User A
      clientManager.setAuthUid(userAId);

      // User A tries to update User B's record -> throws PostgresSecurityException
      expect(
        () async => await clientManager
            .from(SupabaseTableNames.workoutSessions)
            .update({'workout_name': 'Hacked Name'}, 'id', 'ws_bob_bench'),
        throwsA(isA<PostgresSecurityException>()),
      );

      // User A tries to delete User B's record -> throws PostgresSecurityException
      expect(
        () async => await clientManager
            .from(SupabaseTableNames.workoutSessions)
            .delete('id', 'ws_bob_bench'),
        throwsA(isA<PostgresSecurityException>()),
      );
    });

    test(
      'Community posts are publicly readable but editable only by author',
      () async {
        final authorId = 'usr_creator_01';
        final otherUserId = 'usr_viewer_02';

        clientManager.setAuthUid(authorId);
        await clientManager.from(SupabaseTableNames.communityPosts).insert({
          'id': 'post_100',
          'user_id': authorId,
          'author_name': 'Champion Athlete',
          'post_type': 'achievement',
          'caption': 'Hit a 200kg Deadlift PR!',
          'likes_count': 15,
        });

        // Switch to other user
        clientManager.setAuthUid(otherUserId);

        // Public read succeeds
        final posts = await clientManager
            .from(SupabaseTableNames.communityPosts)
            .select();
        expect(posts.length, equals(1));
        expect(posts.first['caption'], equals('Hit a 200kg Deadlift PR!'));

        // Non-author update fails with RLS exception
        expect(
          () async => await clientManager
              .from(SupabaseTableNames.communityPosts)
              .update({'caption': 'Modified'}, 'id', 'post_100'),
          throwsA(isA<PostgresSecurityException>()),
        );
      },
    );
  });

  group('Phase 8 & 9 — Supabase Storage & Realtime Features', () {
    test('Storage bucket enforces owner upload and delete policies', () async {
      final userId = 'usr_avatar_owner';
      clientManager.setAuthUid(userId);

      final avatarsBucket = clientManager.storage.from('avatars');

      // Upload own avatar
      final avatarUrl = await avatarsBucket.uploadString(
        '$userId/profile.png',
        'avatar_image_bytes',
      );
      expect(avatarUrl, contains('avatars/$userId/profile.png'));

      // Download avatar
      final downloaded = await avatarsBucket.download('$userId/profile.png');
      expect(downloaded, isNotNull);

      // Switch to unauthenticated -> upload fails
      clientManager.setAuthUid(null);
      expect(
        () async => await avatarsBucket.uploadString('other.png', 'image_data'),
        throwsA(isA<PostgresSecurityException>()),
      );

      // Switch to different user -> deleting owner avatar fails
      clientManager.setAuthUid('usr_attacker');
      expect(
        () async => await avatarsBucket.delete('$userId/profile.png'),
        throwsA(isA<PostgresSecurityException>()),
      );
    });

    test('Realtime channel broadcasts database mutations', () async {
      final realtime = clientManager.channel('community_posts');
      final receivedEvents = <Map<String, dynamic>>[];

      final sub = realtime.stream.listen((event) {
        receivedEvents.add(event);
      });

      clientManager.setAuthUid('usr_live_01');
      await clientManager.from(SupabaseTableNames.communityPosts).insert({
        'id': 'post_live_1',
        'user_id': 'usr_live_01',
        'caption': 'Live stream test post',
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedEvents.isNotEmpty, isTrue);
      expect(receivedEvents.first['event'], equals('INSERT'));
      expect(receivedEvents.first['payload']['id'], equals('post_live_1'));

      await sub.cancel();
      realtime.close();
    });
  });

  group('Phase 4 & 10 — Repository Cloud Sync & Offline Queue Resilience', () {
    test(
      'WorkoutRepository syncs to Supabase when online and uses cache when offline',
      () async {
        final repo = SupabaseWorkoutRepository(clientManager: clientManager);
        final testWorkout = WorkoutHistory(
          workoutName: 'Upper Body Power',
          dateCompleted: DateTime.now(),
          durationSeconds: 2400,
          exercisesCompleted: 6,
          completionPercentage: 100.0,
          totalVolume: 4200.0,
          caloriesBurned: 350.0,
        );

        // 1. Online save
        clientManager.setAuthUid('usr_workout_hero');
        await repo.saveWorkoutSession(testWorkout);

        // Check remote cloud store
        final cloudRows = await clientManager
            .from(SupabaseTableNames.workoutSessions)
            .select();
        expect(cloudRows.isNotEmpty, isTrue);
        expect(cloudRows.first['workout_name'], equals('Upper Body Power'));

        // 2. Simulate Offline
        clientManager.setSimulateNetworkError(true);

        // Reading returns cached workouts without throwing
        final cachedList = await repo.getWorkoutHistory();
        expect(cachedList.isNotEmpty, isTrue);
        expect(cachedList.first.workoutName, equals('Upper Body Power'));

        clientManager.setSimulateNetworkError(false);
      },
    );
  });
}
