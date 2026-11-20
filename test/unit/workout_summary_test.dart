import 'package:atlas/models/personal_record.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/services/exercise/muscle_map.dart';
import 'package:atlas/services/progressive_overload_service.dart';
import 'package:atlas/services/workout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  List<WorkoutSessionExercise>? exercises,
  Duration duration = const Duration(minutes: 45),
}) {
  final start = DateTime(2026, 11, 16, 16, 30);
  return WorkoutSession(
    id: 's1',
    workoutId: 'w1',
    workoutName: 'Push Day',
    startTime: start,
    endTime: start.add(duration),
    completedExercises: 0,
    totalVolume: 0,
    caloriesBurned: 0,
    duration: duration,
    exercises:
        exercises ??
        [
          const WorkoutSessionExercise(
            id: 'bench_press',
            name: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            isCompleted: true,
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 100,
                reps: 5,
                completed: true,
                durationSeconds: 30,
              ),
              WorkoutSessionSet(
                setNumber: 2,
                weight: 100,
                reps: 5,
                completed: true,
                durationSeconds: 40,
              ),
            ],
          ),
          const WorkoutSessionExercise(
            id: 'lateral_raise',
            name: 'Dumbbell Lateral Raise',
            muscleGroup: 'Side Deltoids',
            sets: [
              WorkoutSessionSet(
                setNumber: 1,
                weight: 10,
                reps: 12,
                completed: true,
              ),
              WorkoutSessionSet(
                setNumber: 2,
                weight: 10,
                reps: 12,
                completed: false,
              ),
            ],
          ),
        ],
  );
}

WorkoutSessionExercise _one(String id, double weight, bool done) =>
    WorkoutSessionExercise(
      id: id,
      name: id,
      isCompleted: done,
      sets: [
        WorkoutSessionSet(
          setNumber: 1,
          weight: weight,
          reps: 10,
          completed: done,
        ),
      ],
    );

void main() {
  group('WorkoutSummaryBuilder', () {
    test('counts, duration, volume and averages come from the session', () {
      final s = WorkoutSummaryBuilder.build(session: _session());
      expect(s.workoutName, 'Push Day');
      expect(s.duration, const Duration(minutes: 45));
      expect(s.startTime, DateTime(2026, 11, 16, 16, 30));
      expect(s.endTime, DateTime(2026, 11, 16, 17, 15));
      expect(s.completedAt, DateTime(2026, 11, 16, 17, 15));
      expect(s.exercisesTotal, 2);
      expect(s.exercisesCompleted, 1);
      expect(s.setsTotal, 4);
      expect(s.setsCompleted, 3);
      // Only finished sets count: 2 x (100 x 5) + 10 x 12.
      expect(s.totalVolumeKg, 1120);
      // Only the two timed sets count towards the average.
      expect(s.averageSetSeconds, 35);
    });

    test('muscles come from the exercises that were actually worked', () {
      final s = WorkoutSummaryBuilder.build(session: _session());
      expect(s.muscles.primary, contains(MuscleRegion.chest));
      expect(s.muscles.primary, contains(MuscleRegion.sideDelts));
      final skipped = WorkoutSummaryBuilder.build(
        session: _session(exercises: [_one('lat_pulldown', 40, false)]),
      );
      expect(skipped.muscles.isComplete, isFalse);
    });

    test('bodyweight work has no volume rather than 0 kg', () {
      final s = WorkoutSummaryBuilder.build(
        session: _session(exercises: [_one('push_ups', 0, true)]),
      );
      expect(s.totalVolumeKg, isNull);
      expect(s.setsCompleted, 1);
      expect(s.averageSetSeconds, isNull, reason: 'no set was timed');
    });

    test('a genuine zero stays zero', () {
      final s = WorkoutSummaryBuilder.build(
        session: _session(exercises: [_one('bench_press', 50, false)]),
      );
      expect(s.setsCompleted, 0);
      expect(s.exercisesCompleted, 0);
      expect(s.totalVolumeKg, isNull);
    });

    test('no PR, streak, XP or calories unless they were supplied', () {
      final s = WorkoutSummaryBuilder.build(session: _session());
      expect(s.personalRecords, isEmpty);
      expect(s.streakDays, isNull);
      expect(s.xpEarned, isNull);
      expect(s.caloriesEstimate, isNull);
    });

    test('a real PR is carried through with its numbers', () {
      final s = WorkoutSummaryBuilder.build(
        session: _session(),
        personalRecords: const [
          PersonalRecordResult(
            displayText: 'Barbell Bench Press: Weight PR 145.5 kg',
            record: PersonalRecord(
              id: 'pr1',
              exerciseName: 'Barbell Bench Press',
              recordType: 'Heaviest Lift',
              value: 145.5,
              previousValue: 140,
              improvementPercentage: 3.9,
            ),
          ),
        ],
        xpEarned: 120,
        caloriesEstimate: 310,
      );
      expect(s.personalRecords, hasLength(1));
      expect(s.personalRecords.single.valueText, '145.5 kg');
      expect(s.personalRecords.single.improvementPercent, 3.9);
      expect(s.xpEarned, 120);
      expect(s.caloriesEstimate, 310);
    });
  });

  group('streakFor', () {
    WorkoutHistory entry(DateTime at) => WorkoutHistory(
      workoutName: 'Push Day',
      dateCompleted: at,
      durationSeconds: 2700,
      exercisesCompleted: 3,
      completionPercentage: 100,
    );

    test('is null when the saved history does not contain the workout', () {
      final saved = entry(DateTime.now());
      expect(WorkoutSummaryBuilder.streakFor(const [], saved), isNull);
      expect(
        WorkoutSummaryBuilder.streakFor([
          entry(DateTime.now().subtract(const Duration(days: 1))),
        ], saved),
        isNull,
      );
    });

    test('counts consecutive days from the saved history', () {
      final now = DateTime.now();
      final saved = entry(now);
      final history = [
        saved,
        entry(now.subtract(const Duration(days: 1))),
        entry(now.subtract(const Duration(days: 2))),
        entry(now.subtract(const Duration(days: 5))),
      ];
      expect(WorkoutSummaryBuilder.streakFor(history, saved), 3);
    });

    test('a first workout is a one day streak, real but small', () {
      final saved = entry(DateTime.now());
      expect(WorkoutSummaryBuilder.streakFor([saved], saved), 1);
    });
  });
}
