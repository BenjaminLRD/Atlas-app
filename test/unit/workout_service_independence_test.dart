import 'dart:async';
import 'dart:io';

import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/workout_changes.dart';
import 'package:atlas/data/workout_repository.dart';
import 'package:atlas/data/workout_service.dart';
import 'package:atlas/models/active_workout_session.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutHistory _entry([String name = 'Push Day', DateTime? at]) =>
    WorkoutHistory(
      workoutName: name,
      dateCompleted: at ?? DateTime.now(),
      durationSeconds: 2400,
      exercisesCompleted: 4,
      completionPercentage: 100,
    );

WorkoutSession _session() => WorkoutSession(
  id: 'sess_ind',
  workoutId: 'w_ind',
  workoutName: 'Push Day',
  startTime: DateTime.now().subtract(const Duration(minutes: 30)),
  endTime: DateTime.now(),
  exercises: const [],
  completedExercises: 0,
  totalVolume: 0,
  caloriesBurned: 0,
  duration: const Duration(minutes: 30),
);

/// Runs [body] and returns the errors it reported to Flutter.
Future<List<FlutterErrorDetails>> _reported(
  FutureOr<void> Function() body,
) async {
  final previous = FlutterError.onError;
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('WorkoutService on its own (no FitnessProvider)', () {
    late int changes;
    late void Function() listener;

    setUp(() {
      changes = 0;
      listener = () => changes++;
      WorkoutChanges.instance.addListener(listener);
    });

    tearDown(() => WorkoutChanges.instance.removeListener(listener));

    test('works with no provider alive', () async {
      // The only listener is the one added here: nothing app-level is attached.
      expect(WorkoutChanges.instance.listenerCount, 1);
      final service = WorkoutService(LocalWorkoutRepository());
      await service.saveWorkoutCompletion(_entry());
      expect(service.getWorkoutHistory(), hasLength(1));
      expect(changes, 1);
    });

    test(
      'saving a completion, or adding history, reports one change each',
      () async {
        final service = WorkoutService();
        await service.saveWorkoutCompletion(_entry('A'));
        expect(changes, 1);
        await service.addHistory(
          _entry('B', DateTime.now().add(const Duration(seconds: 1))),
        );
        expect(changes, 2);
      },
    );

    test('reads and other saves report no change', () async {
      final service = WorkoutService();
      service.getActiveSession();
      service.getWorkoutSessions();
      service.getWorkoutHistory();
      await service.saveWorkoutSession(_session());
      await service.saveActiveSession(
        ActiveWorkoutSession(
          workoutName: 'Push Day',
          workoutId: 'w_ind',
          currentIndex: 0,
          seconds: 10,
          isPaused: false,
          completedSets: const [
            [true],
          ],
        ),
      );
      await service.clearActiveSession();
      expect(changes, 0);
    });

    test('a failed save reports no change', () async {
      final service = WorkoutService(_FailingRepository());
      await expectLater(
        service.saveWorkoutCompletion(_entry()),
        throwsA(isA<StateError>()),
      );
      expect(changes, 0);
    });

    test('saving still stores the workouts newest first', () async {
      final service = WorkoutService();
      await service.saveWorkoutCompletion(
        _entry('Older', DateTime(2026, 1, 1)),
      );
      await service.saveWorkoutCompletion(
        _entry('Newer', DateTime(2026, 1, 2)),
      );
      expect(service.getWorkoutHistory().map((e) => e.workoutName), [
        'Newer',
        'Older',
      ]);
    });

    test('the service source no longer refers to the provider', () {
      final source = File('lib/data/workout_service.dart').readAsStringSync();
      expect(source.contains('fitness_provider'), isFalse);
      expect(source.contains('FitnessProvider'), isFalse);
    });
  });

  group('the provider still refreshes when a workout is saved', () {
    setUp(FitnessProvider.resetInstance);
    tearDown(FitnessProvider.resetInstance);

    test(
      'a separately constructed service reaches the active provider',
      () async {
        final provider = FitnessProvider.instance;
        var notified = 0;
        provider.addListener(() => notified++);
        expect(provider.workoutHistory, isEmpty);

        await WorkoutService().saveWorkoutCompletion(_entry('From elsewhere'));

        expect(notified, greaterThan(0));
        expect(provider.workoutHistory.map((e) => e.workoutName), [
          'From elsewhere',
        ]);
      },
    );

    test('the AppDependencies service reaches it too', () async {
      final provider = FitnessProvider.instance;
      await AppDependencies.instance.workoutService.saveWorkoutCompletion(
        _entry('Via dependencies'),
      );
      expect(provider.workoutHistory.single.workoutName, 'Via dependencies');
    });

    test('the refresh has happened when the save returns', () async {
      final provider = FitnessProvider.instance;
      await WorkoutService().saveWorkoutCompletion(_entry('Sync'));
      // No extra pump or delay between the save and the new state.
      expect(provider.workoutHistory.single.workoutName, 'Sync');
    });

    test('the provider listens once and stops when disposed', () {
      final before = WorkoutChanges.instance.listenerCount;
      final provider = FitnessProvider.instance;
      expect(WorkoutChanges.instance.listenerCount, before + 1);
      provider.refreshAll();
      provider.refreshAll();
      expect(WorkoutChanges.instance.listenerCount, before + 1);
      FitnessProvider.resetInstance();
      expect(WorkoutChanges.instance.listenerCount, before);
    });

    test('a disposed provider is not notified by later saves', () async {
      FitnessProvider.instance;
      FitnessProvider.resetInstance();
      final errors = await _reported(() async {
        await WorkoutService().saveWorkoutCompletion(_entry('After dispose'));
      });
      // A disposed provider still listening would have thrown and been reported.
      expect(errors, isEmpty);
    });

    test('a failing listener is reported and does not fail the save', () async {
      var after = 0;
      void broken() => throw StateError('listener failed');
      void last() => after++;
      WorkoutChanges.instance
        ..addListener(broken)
        ..addListener(last);
      addTearDown(() {
        WorkoutChanges.instance
          ..removeListener(broken)
          ..removeListener(last);
      });

      final errors = await _reported(() async {
        await WorkoutService().saveWorkoutCompletion(_entry('Still saved'));
      });

      expect(after, 1);
      expect(errors, hasLength(1));
      expect(errors.single.library, 'workout changes');
      expect(WorkoutService().getWorkoutHistory(), hasLength(1));
    });
  });
}

/// A repository whose completion save fails.
class _FailingRepository extends LocalWorkoutRepository {
  @override
  Future<void> saveWorkoutCompletion(
    WorkoutHistory entry, {
    String userId = 'usr_local_01',
  }) async {
    throw StateError('disk full');
  }
}
