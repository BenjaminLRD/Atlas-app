import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/atlas_challenge.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/exercise_detail_screen.dart';
import 'package:atlas/screens/weekly_workout_plan_screen.dart';
import 'package:atlas/screens/workout_overview_screen.dart';
import 'package:atlas/services/challenges/atlas_challenge_service.dart';
import 'package:atlas/services/challenges/thirty_day_challenge.dart';
import 'package:atlas/widgets/workout/thirty_day_challenge_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _exercise(
  String id,
  String name,
  String muscle,
  int sets,
) => {
  'id': id,
  'name': name,
  'primaryTarget': muscle,
  'muscleGroup': muscle,
  'equipment': 'Barbell',
  'sets': [
    for (var i = 0; i < sets; i++)
      {'reps': 8, 'weight': 40.0, 'completed': false},
  ],
  'reps': 8,
  'weight': 40.0,
};

DailyPlan _today(
  List<Map<String, dynamic>> exercises, {
  String title = 'Leg Day',
}) => DailyPlan(
  dayName: 'Wednesday',
  date: '18',
  title: title,
  duration: '45 mins',
  muscleGroups: 'Quads & Glutes',
  exercises: const [],
  structuredExercises: exercises,
  isToday: true,
  focus: 'legs',
  durationMinutes: 45,
);

final _squat = _exercise('squat', 'Barbell Back Squat', 'Quads', 4);
final _lunge = _exercise('lunge', 'Walking Lunge', 'Glutes', 3);
final _press = _exercise('leg_press', 'Leg Press', 'Quads', 3);

final _now = DateTime(2026, 11, 12, 9);

ThirtyDayView _view({List<DateTime> done = const [], DateTime? now}) =>
    ThirtyDayChallenge.view(
      challenge: AtlasChallenge(
        id: 'c',
        title: '30-Day Fitness Challenge',
        metric: ChallengeMetric.workouts,
        target: 20,
        durationDays: 30,
        createdAt: DateTime(2026, 11, 1),
        status: AtlasChallengeStatus.active,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 12, 1),
      ),
      workoutDates: done,
      now: now ?? _now,
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  Size size = const Size(412, 2400),
  double textScale = 1.0,
  ThirtyDayView? Function()? challenge,
  bool Function(DailyPlan)? completed,
  List<DailyPlan> Function()? plans,
  bool useDefaults = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox()); // a fresh screen each time
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: WorkoutOverviewScreen(
        planBuilder:
            plans ??
            () => [
              _today([_squat, _lunge, _press]),
            ],
        activeSessionReader: () => null,
        challengeLoader: useDefaults ? null : (challenge ?? () => _view()),
        completedTodayChecker: completed,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
    AtlasChallengeService.resetInstance();
  });

  group('the challenge tracker', () {
    testWidgets('an accepted challenge shows title, day and thirty circles', (
      tester,
    ) async {
      await _pumpScreen(tester);
      expect(_text(tester, 'challenge_title'), '30-DAY FITNESS CHALLENGE');
      expect(_text(tester, 'challenge_day'), 'Day 12 of 30');
      var circles = 0;
      for (var d = 1; d <= 30; d++) {
        circles += find
            .byWidgetPredicate(
              (w) => w.key.toString().startsWith("[<'day_${d}_"),
            )
            .evaluate()
            .length;
      }
      expect(circles, 30);
    });

    testWidgets('completed, today, missed and remaining days look different', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        challenge: () => _view(
          done: [
            DateTime(2026, 11, 1),
            DateTime(2026, 11, 2),
            DateTime(2026, 11, 4),
          ],
        ),
      );
      expect(find.byKey(const Key('day_1_completed')), findsOneWidget);
      expect(find.byKey(const Key('day_2_completed')), findsOneWidget);
      expect(find.byKey(const Key('day_3_missed')), findsOneWidget);
      expect(find.byKey(const Key('day_4_completed')), findsOneWidget);
      expect(find.byKey(const Key('day_12_today')), findsOneWidget);
      expect(find.byKey(const Key('day_13_upcoming')), findsOneWidget);
      expect(find.byKey(const Key('day_30_upcoming')), findsOneWidget);
      // Completed days are emerald; remaining days are dark.
      Color fill(String key) =>
          (tester.widget<AnimatedContainer>(find.byKey(Key(key))).decoration!
                  as BoxDecoration)
              .color!;
      expect(fill('day_1_completed'), AppColors.primary);
      expect(fill('day_13_upcoming'), isNot(AppColors.primary));
      expect(fill('day_13_upcoming').computeLuminance(), lessThan(0.1));
    });

    testWidgets('progress is calculated from completed days', (tester) async {
      await _pumpScreen(
        tester,
        challenge: () =>
            _view(done: [for (var d = 1; d <= 9; d++) DateTime(2026, 11, d)]),
      );
      expect(_text(tester, 'challenge_done'), '9 workout days done');
      expect(_text(tester, 'challenge_percent'), '30%');
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('challenge_bar')),
      );
      expect(bar.value, closeTo(0.3, 0.001));
    });

    testWidgets('today fills only after a workout is completed', (
      tester,
    ) async {
      await _pumpScreen(tester);
      expect(find.byKey(const Key('day_12_today')), findsOneWidget);
      await _pumpScreen(
        tester,
        challenge: () => _view(done: [DateTime(2026, 11, 12, 8)]),
      );
      expect(find.byKey(const Key('day_12_completed')), findsOneWidget);
    });

    testWidgets('no accepted challenge shows an honest empty state', (
      tester,
    ) async {
      await _pumpScreen(tester, challenge: () => null);
      expect(find.byKey(const Key('challenge_empty')), findsOneWidget);
      expect(find.byKey(const Key('challenge_accept')), findsOneWidget);
      expect(find.byKey(const Key('challenge_dots')), findsNothing);
      expect(find.byKey(const Key('challenge_percent')), findsNothing);
      expect(find.textContaining('of 30'), findsNothing);
    });

    testWidgets('accepting creates one real challenge and shows day 1', (
      tester,
    ) async {
      await _pumpScreen(tester, useDefaults: true);
      expect(find.byKey(const Key('challenge_accept')), findsOneWidget);
      await tester.tap(find.byKey(const Key('challenge_accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(AtlasChallengeService.instance.active().length, 1);
      expect(find.byKey(const Key('challenge_accept')), findsNothing);
      expect(_text(tester, 'challenge_day'), 'Day 1 of 30');
      expect(_text(tester, 'challenge_done'), '0 workout days done');
      expect(_text(tester, 'challenge_percent'), '0%');
      expect(find.byKey(const Key('challenge_sample_badge')), findsNothing);
    });

    testWidgets('a challenge that is over says so', (tester) async {
      await _pumpScreen(
        tester,
        challenge: () => _view(now: DateTime(2026, 12, 20)),
      );
      expect(_text(tester, 'challenge_day'), contains('Challenge over'));
    });
  });

  group("today's workouts", () {
    testWidgets('sit under the challenge, in the order to do them', (
      tester,
    ) async {
      await _pumpScreen(tester);
      final challengeY = tester
          .getTopLeft(find.byKey(const Key('challenge_card')))
          .dy;
      final headingY = tester
          .getTopLeft(find.byKey(const Key('today_heading')))
          .dy;
      final t0 = tester.getTopLeft(find.byKey(const Key('exercise_tile_0'))).dy;
      final t1 = tester.getTopLeft(find.byKey(const Key('exercise_tile_1'))).dy;
      final t2 = tester.getTopLeft(find.byKey(const Key('exercise_tile_2'))).dy;
      expect(challengeY, lessThan(headingY));
      expect(headingY, lessThan(t0));
      expect(t0, lessThan(t1));
      expect(t1, lessThan(t2));
      for (var i = 0; i < 3; i++) {
        expect(
          find.descendant(
            of: find.byKey(Key('exercise_number_$i')),
            matching: find.text('${i + 1}'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Barbell Back Squat'), findsOneWidget);
      expect(find.byKey(const Key('review_start')), findsOneWidget);
    });

    testWidgets('a completed workout is marked completed', (tester) async {
      await _pumpScreen(tester, completed: (_) => true);
      expect(find.byKey(const Key('today_completed')), findsOneWidget);
      expect(find.text('Completed today'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(
          find.descendant(
            of: find.byKey(Key('exercise_number_$i')),
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Train again'), findsOneWidget);
    });

    testWidgets('an unfinished workout shows no completion', (tester) async {
      await _pumpScreen(tester);
      expect(find.byKey(const Key('today_completed')), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('Review & Start'), findsOneWidget);
    });

    testWidgets(
      'no workout assigned shows a useful empty state, not an invented one',
      (tester) async {
        await _pumpScreen(tester, plans: () => const []);
        expect(find.byKey(const Key('no_plan_card')), findsOneWidget);
        expect(find.byKey(const Key('open_weekly_plan')), findsWidgets);
        expect(find.byKey(const Key('exercise_tile_0')), findsNothing);
        // The challenge is still there above it.
        expect(find.byKey(const Key('challenge_card')), findsOneWidget);
      },
    );

    testWidgets('tapping a workout opens its existing detail screen', (
      tester,
    ) async {
      final known = Exercise.defaultRegistry().first;
      await _pumpScreen(
        tester,
        plans: () => [
          _today([_exercise(known.id, known.name, 'Chest', 3)]),
        ],
      );
      await tester.tap(find.byKey(const Key('exercise_tile_0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ExerciseDetailScreen), findsOneWidget);
    });
  });

  group('Showcase Mode', () {
    setUp(() async {
      await ShowcaseModeProvider.instance.enableShowcaseMode();
    });
    tearDown(() async {
      await ShowcaseModeProvider.instance.disableShowcaseMode();
    });

    testWidgets(
      'shows an already accepted, clearly labelled sample challenge',
      (tester) async {
        await _pumpScreen(tester, useDefaults: true);
        expect(find.byKey(const Key('challenge_accept')), findsNothing);
        expect(find.byKey(const Key('challenge_sample_badge')), findsOneWidget);
        expect(find.byKey(const Key('challenge_sample_note')), findsOneWidget);
        expect(_text(tester, 'challenge_day'), 'Day 12 of 30');
        expect(_text(tester, 'challenge_done'), '9 workout days done');
        expect(_text(tester, 'challenge_percent'), '30%');
        expect(find.byKey(const Key('day_1_completed')), findsOneWidget);
        expect(find.byKey(const Key('day_4_missed')), findsOneWidget);
        expect(find.byKey(const Key('day_12_today')), findsOneWidget);
        expect(find.byKey(const Key('day_20_upcoming')), findsOneWidget);
      },
    );

    testWidgets('reading it leaves the real challenge data untouched', (
      tester,
    ) async {
      await _pumpScreen(tester, useDefaults: true);
      expect(AtlasChallengeService.instance.all(), isEmpty);
      expect(LocalStorage.getString('atlas_challenges_self_v1'), isNull);
      expect(LocalStorage.getString('atlas_challenges_sample_v1'), isNull);
    });

    testWidgets('after Showcase ends a real athlete sees no challenge', (
      tester,
    ) async {
      await _pumpScreen(tester, useDefaults: true);
      expect(find.byKey(const Key('challenge_sample_badge')), findsOneWidget);
      await ShowcaseModeProvider.instance.disableShowcaseMode();
      await _pumpScreen(tester, useDefaults: true);
      expect(find.byKey(const Key('challenge_sample_badge')), findsNothing);
      expect(find.byKey(const Key('challenge_empty')), findsOneWidget);
    });

    testWidgets('the workout list is interactive', (tester) async {
      await _pumpScreen(tester, useDefaults: true);
      expect(find.byKey(const Key('exercise_tile_0')), findsOneWidget);
      expect(find.byKey(const Key('review_start')), findsOneWidget);
    });
  });

  group('responsive layout', () {
    final longName = _exercise(
      'x',
      'Single-Arm Dumbbell Incline Chest Supported Row With Slow Eccentric',
      'Back',
      3,
    );
    for (final size in const [
      Size(320, 2600),
      Size(360, 2600),
      Size(412, 2600),
    ]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets('fits ${size.width.toInt()} dp at text scale $scale', (
          tester,
        ) async {
          await _pumpScreen(
            tester,
            size: size,
            textScale: scale,
            plans: () => [
              _today([longName, _squat, _lunge]),
            ],
            challenge: () => _view(
              done: [for (var d = 1; d <= 9; d++) DateTime(2026, 11, d)],
            ),
          );
          final ex = tester.takeException();
          if (ex != null) {
            fail(ex is FlutterError ? ex.toStringDeep() : '$ex');
          }
          expect(find.byKey(const Key('day_30_upcoming')), findsOneWidget);
        });
      }
    }

    testWidgets('the circles never overflow the card at 320 dp', (
      tester,
    ) async {
      await _pumpScreen(tester, size: const Size(320, 2600));
      final card = tester.getRect(find.byKey(const Key('challenge_card')));
      for (var d = 1; d <= 30; d++) {
        final f = find.byWidgetPredicate(
          (w) => w.key.toString().startsWith("[<'day_${d}_"),
        );
        final r = tester.getRect(f);
        expect(r.right, lessThanOrEqualTo(card.right + 0.5), reason: 'day $d');
        expect(r.left, greaterThanOrEqualTo(card.left - 0.5), reason: 'day $d');
      }
    });
  });

  group('the card on its own', () {
    testWidgets('renders without a challenge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: ThirtyDayChallengeCard(view: null)),
        ),
      );
      expect(find.byKey(const Key('challenge_accept')), findsOneWidget);
    });
  });
}
