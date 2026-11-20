import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local/community_local_repository.dart';
import 'package:atlas/data/local/nutrition_local_repository.dart';
import 'package:atlas/data/local/profile_local_repository.dart';
import 'package:atlas/data/local/workout_local_repository.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/services/cloud/cloud_repositories.dart';
import 'package:atlas/services/cloud/cloud_session.dart';
import 'package:atlas/services/cloud/cloud_sync_queue.dart';

const _legacyKey = 'Atlas_sync_queue_operations';

WorkoutSession _session() => WorkoutSession(
  id: 'sess_1',
  workoutId: 'w1',
  workoutName: 'Push',
  startTime: DateTime(2026, 10, 17, 10),
  endTime: DateTime(2026, 10, 17, 11),
  exercises: const [],
  completedExercises: 0,
  totalVolume: 0,
  caloriesBurned: 100,
  duration: const Duration(hours: 1),
  personalRecords: const [],
  xpEarned: 50,
);

WorkoutHistory _history() => WorkoutHistory(
  workoutName: 'Push',
  dateCompleted: DateTime(2026, 10, 17, 11),
  durationSeconds: 3600,
  exercisesCompleted: 4,
  completionPercentage: 100,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? signedInUser;

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    signedInUser = null;
    CloudSession.debugUserIdOverride = () => signedInUser;
  });

  tearDown(() {
    CloudSession.debugUserIdOverride = null;
  });

  group('local repositories no longer feed the retired sync queue', () {
    test('workout: saves locally and writes no legacy entry', () async {
      final repo = WorkoutLocalRepository();
      await repo.saveWorkoutSession(_session());
      await repo.saveWorkoutCompletion(_history());

      expect(repo.getWorkoutSessions().any((s) => s.id == 'sess_1'), isTrue);
      expect(
        repo.getWorkoutHistory().any((h) => h.workoutName == 'Push'),
        isTrue,
      );
      expect((await prefs()).containsKey(_legacyKey), isFalse);
    });

    test('nutrition: saves locally and writes no legacy entry', () async {
      final repo = NutritionLocalRepository();
      final day = DailyNutrition.defaultForDate('2026-10-17');
      await repo.saveDailyNutrition(day);
      await repo.saveNutritionLog(
        NutritionLog(id: 'log_1', date: DateTime(2026, 10, 17)),
      );

      expect(repo.getDailyNutrition('2026-10-17').date, '2026-10-17');
      expect(repo.getNutritionLogHistory().any((l) => l.id == 'log_1'), isTrue);
      expect((await prefs()).containsKey(_legacyKey), isFalse);
    });

    test('profile: saves locally and writes no legacy entry', () async {
      final repo = ProfileLocalRepository();
      final profile = LocalStorage.getUserProfile();
      profile.name = 'Casey Tester';
      await repo.saveProfile(profile);

      expect(repo.getProfile().name, 'Casey Tester');
      expect((await prefs()).containsKey(_legacyKey), isFalse);
    });

    test('community: caches the post and writes no legacy entry', () async {
      final repo = CommunityLocalRepository();
      final post = ActivityPost(
        id: 'post_1',
        userId: 'u1',
        userName: 'Casey',
        type: ActivityPostType.workout,
        title: 'Push day',
        description: 'Done',
        metadata: const {},
        createdAt: DateTime(2026, 10, 17),
      );
      await repo.createPost(post);

      expect(repo.getCommunityFeed().any((p) => p.id == 'post_1'), isTrue);
      expect((await prefs()).containsKey(_legacyKey), isFalse);
    });
  });

  group('cloud repositories still queue exactly one cloud write', () {
    test('one pending write per save, none for the retired queue', () async {
      signedInUser = 'u1';
      // A writer that always fails keeps the writes pending to be counted.
      final queue = CloudSyncQueue(_BlockedWriter());

      final nutrition = CloudNutritionRepository(cloudQueue: queue);
      await nutrition.saveDailyNutrition(
        DailyNutrition.defaultForDate('2026-10-17'),
      );
      expect(await queue.pendingCount, 1);

      final profiles = CloudProfileRepository(cloudQueue: queue);
      await profiles.saveProfile(LocalStorage.getUserProfile());
      expect(await queue.pendingCount, 2);

      final workouts = CloudWorkoutRepository(cloudQueue: queue);
      await workouts.saveWorkoutSession(_session());
      expect(await queue.pendingCount, 3);
      await workouts.saveWorkoutCompletion(_history());
      expect(await queue.pendingCount, 4);

      // Local data is still saved, and the old key is still absent.
      expect(
        workouts.getWorkoutSessions().any((s) => s.id == 'sess_1'),
        isTrue,
      );
      expect((await prefs()).containsKey(_legacyKey), isFalse);
    });

    test('signed out: saved locally, nothing queued anywhere', () async {
      final queue = CloudSyncQueue(_BlockedWriter());
      final workouts = CloudWorkoutRepository(cloudQueue: queue);
      await workouts.saveWorkoutSession(_session());

      expect(
        workouts.getWorkoutSessions().any((s) => s.id == 'sess_1'),
        isTrue,
      );
      expect(await queue.pendingCount, 0);
      expect((await prefs()).containsKey(_legacyKey), isFalse);
    });
  });

  group('cleanup of the old queue key', () {
    test('init removes a leftover queue, with its profile copy', () async {
      SharedPreferences.setMockInitialValues({
        _legacyKey:
            '[{"id":"op_profile_x","entityType":"profile","operationType":"UPDATE",'
            '"payload":{"user_profile":{"email":"a@b.c"}}}]',
      });
      await LocalStorage.init();

      expect((await prefs()).containsKey(_legacyKey), isFalse);
      expect(LocalStorage.getSyncQueueOperations(), isEmpty);
    });

    test('running it repeatedly is safe', () async {
      await LocalStorage.clearSyncQueueOperations();
      await LocalStorage.clearSyncQueueOperations();
      await LocalStorage.init();
      await LocalStorage.init();
      expect((await prefs()).containsKey(_legacyKey), isFalse);
    });

    test('other stored data is untouched', () async {
      SharedPreferences.setMockInitialValues({
        _legacyKey: '[]',
        'user_step_goal': 7000,
      });
      await LocalStorage.init();

      expect((await prefs()).getInt('user_step_goal'), 7000);
      expect((await prefs()).containsKey(_legacyKey), isFalse);
    });
  });
}

/// A writer that always fails, so queued writes stay pending and can be
/// counted.
class _BlockedWriter implements CloudWriter {
  @override
  Future<void> apply(CloudWrite write) async {
    throw Exception('offline');
  }
}
