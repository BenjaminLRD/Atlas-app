import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/active_workout_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Workout Session Restore Logic Tests', () {
    test('restores session when saved workoutName matches current workout', () async {
      final session = ActiveWorkoutSession(
        workoutName: 'Leg Day',
        workoutId: 'leg_01',
        currentIndex: 1,
        seconds: 300,
        isPaused: false,
        completedSets: [
          [true, true, true, true],
          [true, false, false, false],
        ],
      );

      await LocalStorage.saveActiveSession(session);

      final retrieved = LocalStorage.getActiveSession();
      expect(retrieved, isNotNull);

      // Restore logic validation
      final matchesWorkout = retrieved!.workoutName == 'Leg Day';
      expect(matchesWorkout, isTrue);
      expect(retrieved.currentIndex, equals(1));
      expect(retrieved.seconds, equals(300));
    });

    test('rejects restoring session when saved workoutName differs from current workout', () async {
      final savedSession = ActiveWorkoutSession(
        workoutName: 'Chest Day',
        workoutId: 'chest_01',
        currentIndex: 2,
        seconds: 450,
        isPaused: true,
        completedSets: [
          [true, true],
        ],
      );

      await LocalStorage.saveActiveSession(savedSession);

      final retrieved = LocalStorage.getActiveSession();
      expect(retrieved, isNotNull);

      // When opening 'Leg Day', verify workout name comparison rejects 'Chest Day' session
      const targetWorkoutName = 'Leg Day';
      final matchesWorkout = retrieved!.workoutName == targetWorkoutName ||
          (retrieved.workoutName == 'Workout Session' && targetWorkoutName == 'Workout Session');

      expect(matchesWorkout, isFalse);
    });

    test('legacy saved session defaults to Workout Session and matches default target', () async {
      final legacyJson = {
        'currentIndex': 0,
        'seconds': 120,
        'isPaused': false,
        'completedSets': [],
      };

      await LocalStorage.saveActiveSession(legacyJson);

      final retrieved = LocalStorage.getActiveSession();
      expect(retrieved, isNotNull);
      expect(retrieved!.workoutName, equals('Workout Session'));

      // Legacy session matches default 'Workout Session'
      const defaultTargetName = 'Workout Session';
      final matchesDefault = retrieved.workoutName == defaultTargetName ||
          (retrieved.workoutName == 'Workout Session' && defaultTargetName == 'Workout Session');

      expect(matchesDefault, isTrue);
    });
  });
}
