import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/data/workout_repository.dart';
import 'package:aizawl_gym/data/workout_service.dart';
import 'package:aizawl_gym/models/active_workout_session.dart';
import 'package:aizawl_gym/models/workout_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('WorkoutRepository & WorkoutService Tests', () {
    test('WorkoutService routes active session operations through WorkoutRepository', () async {
      final repo = LocalWorkoutRepository();
      final service = WorkoutService(repo);

      final session = ActiveWorkoutSession(
        workoutName: 'Chest Day',
        currentIndex: 1,
        seconds: 150,
        isPaused: false,
        completedSets: [
          [true, true],
        ],
      );

      await service.saveActiveSession(session);

      final retrieved = service.getActiveSession();
      expect(retrieved, isNotNull);
      expect(retrieved!.workoutName, equals('Chest Day'));
      expect(retrieved.seconds, equals(150));

      await service.clearActiveSession();
      expect(service.getActiveSession(), isNull);
    });

    test('WorkoutService saves and sorts workout completion history', () async {
      final service = WorkoutService();

      final earlier = WorkoutHistory(
        workoutName: 'Morning Cardio',
        dateCompleted: DateTime.now().subtract(const Duration(hours: 5)),
        durationSeconds: 1800,
        exercisesCompleted: 3,
        completionPercentage: 1.0,
      );

      final later = WorkoutHistory(
        workoutName: 'Evening Leg Session',
        dateCompleted: DateTime.now(),
        durationSeconds: 2400,
        exercisesCompleted: 4,
        completionPercentage: 1.0,
      );

      await service.saveWorkoutCompletion(earlier);
      await service.saveWorkoutCompletion(later);

      final history = service.getWorkoutHistory();
      expect(history.length, equals(2));
      // Verify sorted newest first
      expect(history.first.workoutName, equals('Evening Leg Session'));
      expect(history.last.workoutName, equals('Morning Cardio'));
    });
  });
}
