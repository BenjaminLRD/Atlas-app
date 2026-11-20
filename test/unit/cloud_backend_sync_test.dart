import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/cloud/cloud_repositories.dart';
import 'package:atlas/services/cloud/cloud_session.dart';
import 'package:atlas/services/cloud/cloud_sync_coordinator.dart';
import 'package:atlas/services/cloud/cloud_sync_queue.dart';

class _RecordingWriter implements CloudWriter {
  final List<CloudWrite> applied = [];
  int failuresLeft = 0;

  @override
  Future<void> apply(CloudWrite write) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw Exception('network down');
    }
    applied.add(write);
  }
}

class _FakeReader implements CloudReader {
  final Map<String, List<Map<String, dynamic>>> rows;
  _FakeReader(this.rows);

  @override
  Future<List<Map<String, dynamic>>> fetch(
    String table, {
    required String userColumn,
    required String userId,
    String? orderBy,
    int? limit,
  }) async => rows[table] ?? const [];
}

WorkoutHistory _history(DateTime when, String name) => WorkoutHistory(
  workoutName: name,
  dateCompleted: when,
  durationSeconds: 1800,
  exercisesCompleted: 4,
  completionPercentage: 100,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? signedInUser;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    signedInUser = null;
    CloudSession.debugUserIdOverride = () => signedInUser;
  });

  tearDown(() {
    CloudSession.debugUserIdOverride = null;
  });

  group('CloudSyncQueue', () {
    test(
      'holds writes while signed out and pushes them after sign-in',
      () async {
        final writer = _RecordingWriter();
        final queue = CloudSyncQueue(writer);

        await queue.enqueue(
          const CloudWrite.upsert('t', {
            'user_id': 'u1',
            'id': 'a',
          }, keyColumns: 'user_id,id'),
        );
        expect(await queue.flush(), isFalse);
        expect(writer.applied, isEmpty);
        expect(await queue.pendingCount, 1);

        signedInUser = 'u1';
        expect(await queue.flush(), isTrue);
        expect(writer.applied.single.row['id'], 'a');
        expect(await queue.pendingCount, 0);
      },
    );

    test('a newer write to the same record replaces the pending one', () async {
      final writer = _RecordingWriter();
      final queue = CloudSyncQueue(writer);

      await queue.enqueue(
        const CloudWrite.upsert('t', {
          'user_id': 'u1',
          'id': 'a',
          'v': 1,
        }, keyColumns: 'user_id,id'),
      );
      await queue.enqueue(
        const CloudWrite.upsert('t', {
          'user_id': 'u1',
          'id': 'a',
          'v': 2,
        }, keyColumns: 'user_id,id'),
      );
      signedInUser = 'u1';
      await queue.flush();

      expect(writer.applied, hasLength(1));
      expect(writer.applied.single.row['v'], 2);
    });

    test('keeps failed writes, in order, and retries them later', () async {
      signedInUser = 'u1';
      final writer = _RecordingWriter()..failuresLeft = 1;
      final queue = CloudSyncQueue(writer);
      await queue.flush();

      await queue.enqueue(
        const CloudWrite.upsert('t', {
          'user_id': 'u1',
          'id': 'a',
        }, keyColumns: 'user_id,id'),
      );
      await queue.flush();
      await queue.enqueue(
        const CloudWrite.upsert('t', {
          'user_id': 'u1',
          'id': 'b',
        }, keyColumns: 'user_id,id'),
      );
      await queue.flush();

      expect(writer.applied.map((w) => w.row['id']), ['a', 'b']);
      expect(await queue.pendingCount, 0);
    });

    test('pending writes survive an app restart', () async {
      await CloudSyncQueue(_RecordingWriter()).enqueue(
        const CloudWrite.upsert('t', {
          'user_id': 'u1',
          'id': 'a',
        }, keyColumns: 'user_id,id'),
      );

      final writer = _RecordingWriter();
      final restarted = CloudSyncQueue(writer);
      expect(await restarted.pendingCount, 1);
      signedInUser = 'u1';
      await restarted.flush();
      expect(writer.applied, hasLength(1));
    });
  });

  group('Cloud repositories', () {
    test('nutrition saves queue the whole day only when signed in', () async {
      final writer = _RecordingWriter();
      final queue = CloudSyncQueue(writer);
      final repo = CloudNutritionRepository(cloudQueue: queue);

      await repo.saveDailyNutrition(
        DailyNutrition.defaultForDate('2026-10-07'),
      );
      expect(await queue.pendingCount, 0);

      signedInUser = 'u1';
      await repo.saveDailyNutrition(
        DailyNutrition.defaultForDate('2026-10-07'),
      );
      await queue.flush();

      final write = writer.applied.single;
      expect(write.table, CloudTables.nutritionDays);
      expect(write.row['user_id'], 'u1');
      expect(write.row['log_date'], '2026-10-07');
      expect(LocalStorage.getDailyNutrition('2026-10-07').date, '2026-10-07');
    });

    test(
      'workout completions are saved locally and queued with a stable id',
      () async {
        signedInUser = 'u1';
        final writer = _RecordingWriter();
        final queue = CloudSyncQueue(writer);
        final repo = CloudWorkoutRepository(cloudQueue: queue);
        final entry = _history(DateTime.utc(2026, 10, 7, 9), 'Push Day');

        await repo.saveWorkoutCompletion(entry);
        await queue.flush();

        expect(LocalStorage.getWorkoutHistory().single.workoutName, 'Push Day');
        expect(writer.applied.single.table, CloudTables.workoutHistory);
        expect(writer.applied.single.row['id'], CloudTables.historyId(entry));
      },
    );
  });

  group('CloudSyncCoordinator', () {
    test('pull adds workouts this device is missing', () async {
      signedInUser = 'u1';
      final remote = _history(DateTime.utc(2026, 10, 1, 8), 'Leg Day');
      final coordinator = CloudSyncCoordinator(
        queue: CloudSyncQueue(_RecordingWriter()),
        reader: _FakeReader({
          CloudTables.workoutHistory: [
            {'id': CloudTables.historyId(remote), 'data': remote.toJson()},
          ],
        }),
      );

      expect(await coordinator.pullIntoLocal('u1'), isTrue);
      expect(LocalStorage.getWorkoutHistory().single.workoutName, 'Leg Day');
    });

    test(
      'pull never overwrites a nutrition day with unsynced local edits',
      () async {
        final queue = CloudSyncQueue(_RecordingWriter());
        final local = DailyNutrition.defaultForDate('2026-10-07');
        await LocalStorage.saveDailyNutrition(local);
        await queue.enqueue(
          CloudWrite.upsert(CloudTables.nutritionDays, {
            'user_id': 'u1',
            'log_date': '2026-10-07',
            'data': local.toJson(),
          }, keyColumns: 'user_id,log_date'),
        );

        final remote = DailyNutrition.defaultForDate('2026-10-07').toJson()
          ..['waterLiters'] = 3.5;
        final coordinator = CloudSyncCoordinator(
          queue: queue,
          reader: _FakeReader({
            CloudTables.nutritionDays: [
              {'log_date': '2026-10-07', 'data': remote},
            ],
          }),
        );

        expect(await coordinator.pullIntoLocal('u1'), isFalse);
      },
    );

    test(
      'a different account signing in clears the previous account data',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sb-project-auth-token', 'session');
        await LocalStorage.saveWorkoutCompletion(
          _history(DateTime.utc(2026, 9, 30), 'Account A workout'),
        );
        final coordinator = CloudSyncCoordinator(
          queue: CloudSyncQueue(_RecordingWriter()),
          reader: _FakeReader({}),
        );

        expect(await coordinator.claimLocalData('user-a'), isFalse);
        expect(LocalStorage.getWorkoutHistory(), hasLength(1));

        expect(await coordinator.claimLocalData('user-b'), isTrue);
        expect(LocalStorage.getWorkoutHistory(), isEmpty);
        expect(prefs.getString('sb-project-auth-token'), 'session');
      },
    );
  });
}
