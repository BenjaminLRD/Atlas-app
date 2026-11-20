import 'dart:convert';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/storage/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutHistory _entry(String name, DateTime date) => WorkoutHistory(
  workoutName: name,
  dateCompleted: date,
  durationSeconds: 1800,
  exercisesCompleted: 5,
  completionPercentage: 100,
);

Future<void> _initWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await LocalStorage.init();
}

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

Future<List<String>> _backupsOf(String key) async {
  final prefs = await _prefs();
  return [
    for (final k in prefs.getKeys())
      if (k.startsWith('$key.corrupt.')) prefs.getString(k)!,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final day1 = DateTime(2026, 1, 1);
  final day2 = DateTime(2026, 1, 2);

  group('workout history recovery', () {
    test('valid history still loads normally, newest first', () async {
      await _initWith({});
      await LocalStorage.saveWorkoutHistory([
        _entry('Push', day1),
        _entry('Pull', day2),
      ]);

      final loaded = LocalStorage.getWorkoutHistory();
      expect(loaded.map((e) => e.workoutName), ['Pull', 'Push']);
      expect(await _backupsOf('workout_history'), isEmpty);
    });

    test(
      'genuinely empty storage returns an empty list and no backup',
      () async {
        await _initWith({});
        expect(LocalStorage.getWorkoutHistory(), isEmpty);
        expect(LocalStorage.getWorkoutHistory(userId: 'abc'), isEmpty);
        await LocalStorage.saveWorkoutHistory([]);
        expect(await _backupsOf('workout_history'), isEmpty);
      },
    );

    test('one malformed record does not hide the valid ones', () async {
      final raw = jsonEncode([
        _entry('Push', day1).toJson(),
        'not a record',
        _entry('Pull', day2).toJson(),
      ]);
      await _initWith({'workout_history': raw});

      final loaded = LocalStorage.getWorkoutHistory();
      expect(loaded.map((e) => e.workoutName), ['Pull', 'Push']);
      // Reading alone changes nothing.
      expect((await _prefs()).getString('workout_history'), raw);
    });

    test('the original raw value is preserved before it is replaced', () async {
      final raw = jsonEncode([_entry('Push', day1).toJson(), 42]);
      await _initWith({'workout_history': raw});

      await LocalStorage.saveWorkoutCompletion(_entry('Legs', day2));

      expect(await _backupsOf('workout_history'), [raw]);
      final loaded = LocalStorage.getWorkoutHistory();
      expect(loaded.map((e) => e.workoutName), ['Legs', 'Push']);
    });

    test(
      'saving recovered history again does not erase or duplicate the backup',
      () async {
        final raw = jsonEncode([_entry('Push', day1).toJson(), 42]);
        await _initWith({'workout_history': raw});

        await LocalStorage.saveWorkoutCompletion(_entry('Legs', day2));
        await LocalStorage.saveWorkoutCompletion(
          _entry('Arms', DateTime(2026, 1, 3)),
        );

        expect(await _backupsOf('workout_history'), [raw]);
        expect(LocalStorage.getWorkoutHistory(), hasLength(3));
      },
    );

    test('a malformed top level is preserved, not invented over', () async {
      const raw = '{"not":"a list"}';
      await _initWith({'workout_history': raw});

      expect(LocalStorage.getWorkoutHistory(), isEmpty);
      expect((await _prefs()).getString('workout_history'), raw);

      await LocalStorage.saveWorkoutCompletion(_entry('Push', day1));
      expect(await _backupsOf('workout_history'), [raw]);
    });

    test('truncated JSON is preserved before the next save', () async {
      const raw = '[{"workoutName":"Push","dateCompl';
      await _initWith({'workout_history': raw});

      expect(LocalStorage.getWorkoutHistory(), isEmpty);
      await LocalStorage.saveWorkoutCompletion(_entry('Push', day1));
      expect(await _backupsOf('workout_history'), [raw]);
    });

    test('distinct corrupt values written back to back are all kept', () async {
      await _initWith({});
      final prefs = await _prefs();
      final raws = [for (var i = 0; i < 25; i++) '{"corrupt": $i']; // truncated
      for (final raw in raws) {
        await prefs.setString('workout_history', raw);
        await LocalStorage.saveWorkoutHistory([]);
      }
      expect(await _backupsOf('workout_history'), unorderedEquals(raws));
    });

    test('per-user history uses its own key and backup', () async {
      final raw = jsonEncode([_entry('Push', day1).toJson(), 'bad']);
      await _initWith({'workout_history_u1': raw});

      expect(LocalStorage.getWorkoutHistory(userId: 'u1'), hasLength(1));
      await LocalStorage.saveWorkoutCompletion(
        _entry('Pull', day2),
        userId: 'u1',
      );
      expect(await _backupsOf('workout_history_u1'), [raw]);
      expect(await _backupsOf('workout_history'), isEmpty);
    });
  });

  group('user progress recovery', () {
    test('valid progress round-trips with no backup', () async {
      await _initWith({});
      await LocalStorage.saveUserProgress(UserProgress.initial());
      expect(
        LocalStorage.getUserProgress().toJson(),
        UserProgress.initial().toJson(),
      );
      expect(await _backupsOf('user_progress'), isEmpty);
    });

    test('unreadable progress is preserved before it is overwritten', () async {
      const raw = '{"xp": broken';
      await _initWith({'user_progress': raw});

      // Reading falls back to the initial state without touching storage.
      expect(
        LocalStorage.getUserProgress().toJson(),
        UserProgress.initial().toJson(),
      );
      expect((await _prefs()).getString('user_progress'), raw);

      await LocalStorage.saveUserProgress(UserProgress.initial());
      expect(await _backupsOf('user_progress'), [raw]);
    });
  });

  group('user profile recovery', () {
    test(
      'an unreadable stored profile is kept before the default replaces it',
      () async {
        const raw = '{"name": "Broken';
        final secure = SecureStorageService.inMemory();
        SharedPreferences.setMockInitialValues({'user_profile': raw});
        // The legacy prefs profile is migrated into secure storage first.
        await LocalStorage.init(secureStorage: secure);

        // The app still starts with a usable (default) profile...
        expect(LocalStorage.getUserProfile().name, isNotNull);
        // ...and the unreadable original is still available.
        expect(await secure.readSecureData('user_profile.corrupt.secure'), raw);

        // A second launch does not replace the preserved original.
        await LocalStorage.init(secureStorage: secure);
        expect(await secure.readSecureData('user_profile.corrupt.secure'), raw);
      },
    );

    test('a valid stored profile is not backed up', () async {
      await _initWith({});
      final profile = LocalStorage.getUserProfile();
      await LocalStorage.saveUserProfile(profile);
      await LocalStorage.init();
      expect(await _backupsOf('user_profile'), isEmpty);
    });
  });
}
