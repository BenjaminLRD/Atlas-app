import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_record.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/services/ranked/rank_ladder.dart';
import 'package:atlas/services/ranked/ranked_catalog.dart';
import 'package:atlas/services/ranked/ranked_evaluator.dart';
import 'package:atlas/services/ranked/ranked_progress_store.dart';

RankedCatalog _catalog() => RankedCatalog.fromJson(
  jsonDecode(File(rankedCatalogAsset).readAsStringSync())
      as Map<String, dynamic>,
);

WorkoutHistory _workout(
  String exercise,
  double weight,
  int reps, {
  DateTime? when,
}) => WorkoutHistory(
  workoutName: exercise,
  dateCompleted: when ?? DateTime.now(),
  durationSeconds: 3600,
  exercisesCompleted: 1,
  completionPercentage: 100,
  sessionExercises: [
    WorkoutSessionExercise(
      id: exercise,
      name: exercise,
      sets: [
        WorkoutSessionSet(
          setNumber: 1,
          weight: weight,
          reps: reps,
          completed: true,
        ),
      ],
    ),
  ],
);

CardioSession _run(double km, int seconds) => CardioSession(
  id: 'run_$km',
  exerciseId: 'running',
  exerciseName: 'Outdoor Run',
  category: 'cardio',
  durationSeconds: seconds,
  distanceKm: km,
  caloriesBurned: 300,
  startTime: DateTime.now(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = _catalog();
  final evaluator = RankedEvaluator(catalog);

  test('catalog defines 4 stats with 5 levels each (20 points)', () {
    expect(catalog.stats.map((s) => s.id), [
      'strength',
      'endurance',
      'cardio',
      'consistency',
    ]);
    expect(catalog.maxPoints, 20);
    for (final m in catalog.milestones) {
      expect(m.male, hasLength(5), reason: m.id);
      expect(m.female, hasLength(5), reason: m.id);
    }
  });

  test('estimated one-rep max uses sets of 1 to 5 reps only', () {
    expect(RankedEvaluator.estimatedOneRepMax(100, 1), 100);
    expect(RankedEvaluator.estimatedOneRepMax(100, 5), closeTo(116.67, 0.01));
    expect(RankedEvaluator.estimatedOneRepMax(100, 8), isNull);
    expect(RankedEvaluator.estimatedOneRepMax(0, 3), isNull);
  });

  test('a balanced athlete lands in Platinum II', () {
    final history = [
      _workout('Barbell Bench Press', 85, 5), // 1.24× BW → level 3
      _workout('Barbell Back Squat', 120, 3), // 1.65× → level 3
      _workout('Conventional Deadlift', 160, 1), // 2.0× → level 3
      _workout('Overhead Press', 50, 5), // 0.73× → level 3
      _workout('Push-ups', 0, 52), // 52 reps → level 3
      for (var i = 0; i < 5; i++) _workout('Accessories', 20, 10),
    ];
    final result = evaluator.evaluate(
      history: history,
      sessions: const [],
      cardio: [_run(5.2, 26 * 60)], // 25:00 per 5 km → level 3
      bodyweight: 80,
      gender: 'Male',
    );

    expect(result.statLevels['strength'], 3);
    expect(result.statLevels['endurance'], 3);
    expect(result.statLevels['cardio'], 3);
    // 10 workouts + 1 run in 28 days → level 2 (8+)
    expect(result.statLevels['consistency'], 2);
    expect(result.points, 11);
    expect(result.rank.title, 'Platinum II');
  });

  test('strength needs the level on two lifts', () {
    final result = evaluator.evaluate(
      history: [
        _workout('Bench Press', 130, 1), // 1.63× → level 5
        _workout('Back Squat', 70, 1), // 0.88× → level 1
      ],
      sessions: const [],
      cardio: const [],
      bodyweight: 80,
      gender: 'Male',
    );
    expect(result.milestones['bench_press']!.level, 5);
    expect(result.statLevels['strength'], 1);
  });

  test('female standards apply when the profile says so', () {
    final male = evaluator.evaluate(
      history: [_workout('Bench Press', 40, 1), _workout('Squat', 60, 1)],
      sessions: const [],
      cardio: const [],
      bodyweight: 60,
      gender: 'Male',
    );
    final female = evaluator.evaluate(
      history: [_workout('Bench Press', 40, 1), _workout('Squat', 60, 1)],
      sessions: const [],
      cardio: const [],
      bodyweight: 60,
      gender: 'Female',
    );
    expect(male.milestones['bench_press']!.level, 1); // 0.67×
    expect(female.milestones['bench_press']!.level, 3);
  });

  test('variations and short runs do not count', () {
    final result = evaluator.evaluate(
      history: [
        _workout('Romanian Deadlift', 200, 1),
        _workout('Goblet Squat', 200, 1),
        _workout('Knee Push-ups', 0, 80),
      ],
      sessions: const [],
      cardio: [_run(3, 12 * 60)],
      bodyweight: 80,
      gender: 'Male',
    );
    expect(result.milestones['deadlift']!.best, isNull);
    expect(result.milestones['squat']!.best, isNull);
    expect(result.milestones['push_ups']!.best, isNull);
    expect(result.milestones['run_5k']!.best, isNull);
  });

  test('without body weight, strength is not judged', () {
    final result = evaluator.evaluate(
      history: [_workout('Bench Press', 100, 1)],
      sessions: const [],
      cardio: const [],
      bodyweight: null,
      gender: 'Male',
    );
    expect(result.hasBodyweight, isFalse);
    expect(result.statLevels['strength'], 0);
  });

  test('old workouts do not count toward consistency', () {
    final old = DateTime.now().subtract(const Duration(days: 40));
    final result = evaluator.evaluate(
      history: [for (var i = 0; i < 20; i++) _workout('Row', 50, 8, when: old)],
      sessions: const [],
      cardio: const [],
      bodyweight: 80,
      gender: 'Male',
    );
    expect(result.statLevels['consistency'], 0);
  });

  test('top strength and push-up levels need video; cardio never does', () {
    final bench = catalog.milestones.firstWhere((m) => m.id == 'bench_press');
    final run = catalog.milestones.firstWhere((m) => m.id == 'run_5k');
    expect(catalog.needsVideo(bench, 3), isFalse);
    expect(catalog.needsVideo(bench, 4), isTrue);
    expect(catalog.needsVideo(run, 5), isFalse);
  });

  test('the cached snapshot drives the rank shown everywhere', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    expect(RankedProgressStore.position.isRanked, isFalse);

    await RankedProgressStore.save(
      const RankedSnapshot(
        points: 13,
        verified: true,
        claims: [
          RankedClaim(
            milestoneId: 'bench_press',
            level: 4,
            status: 'needs_video',
          ),
        ],
      ),
    );
    expect(RankedProgressStore.position.title, 'Diamond III');
    expect(
      RankedProgressStore.current.claimFor('bench_press', 4)!.needsVideo,
      isTrue,
    );
    expect(RankLadder.fromPoints(13).next!.title, 'Diamond II');
  });
}
