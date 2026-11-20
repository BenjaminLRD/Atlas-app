import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/active_workout_session.dart';
import 'package:atlas/screens/weekly_workout_plan_screen.dart';
import 'package:atlas/screens/workout_overview_screen.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _exercise(
  String id,
  String name,
  String muscle,
  int sets,
) {
  return {
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
    'aiReasoning': ['Fits your available equipment'],
  };
}

DailyPlan _plan({
  required String day,
  required String title,
  bool isToday = false,
  bool rest = false,
  List<Map<String, dynamic>>? exercises,
}) {
  return DailyPlan(
    dayName: day,
    date: '13',
    title: title,
    duration: '45 mins',
    muscleGroups: 'Quads & Glutes',
    exercises: const [],
    structuredExercises: exercises ?? const [],
    isToday: isToday,
    focus: 'legs',
    durationMinutes: 45,
    isRestDay: rest,
  );
}

final _squat = _exercise('squat', 'Barbell Back Squat', 'Quads', 4);
final _lunge = _exercise('lunge', 'Walking Lunge', 'Glutes', 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
  });

  Future<void> pumpOverview(
    WidgetTester tester, {
    required List<DailyPlan> plans,
    ActiveWorkoutSession? active,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: WorkoutOverviewScreen(
          planBuilder: () => plans,
          activeSessionReader: () => active,
        ),
      ),
    );
    await tester.pump();
  }

  // AppButton plays a press animation (three frames) before onPressed runs.
  Future<void> tapButton(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  group('today\'s workout', () {
    testWidgets('shows title, focus, exercises with sets x reps and muscle', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        plans: [
          _plan(day: 'MONDAY', title: 'Lower Body', exercises: [_lunge]),
          _plan(
            day: 'TUESDAY',
            title: 'Leg Day Technical',
            isToday: true,
            exercises: [_squat, _lunge],
          ),
        ],
      );

      expect(find.text('Leg Day Technical'), findsOneWidget);
      expect(find.text('Lower Body'), findsNothing); // not today
      expect(find.textContaining('Quads & Glutes'), findsOneWidget);
      expect(find.text('2 exercises'), findsOneWidget);
      expect(find.text('7 sets'), findsOneWidget);
      expect(find.textContaining('4 sets × 8 reps · Quads'), findsOneWidget);
      expect(find.textContaining('3 sets × 8 reps · Glutes'), findsOneWidget);
      // Existing reasoning is shown, nothing invented.
      expect(find.text('Fits your available equipment'), findsNWidgets(2));
      // Transparent duration estimate: 7 sets x 130 s + 5 min -> ~20 min.
      expect(find.text('~20 min'), findsOneWidget);
      expect(find.textContaining('40 s per set'), findsOneWidget);
      expect(find.text('Review & Start'), findsOneWidget);
    });

    test('duration estimate rounds to 5 minutes and handles missing sets', () {
      expect(WorkoutDurationEstimate.minutes([_squat, _lunge]), 20);
      expect(
        WorkoutDurationEstimate.totalSets([
          {'name': 'x'},
        ]),
        3,
      );
    });
  });

  group('rest day and missing plan', () {
    testWidgets('rest day shows a rest overview and the weekly plan link', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        plans: [
          _plan(
            day: 'THURSDAY',
            title: 'Rest & Core Stability',
            isToday: true,
            rest: true,
            exercises: [_lunge],
          ),
        ],
      );
      expect(find.byKey(const Key('rest_day_card')), findsOneWidget);
      expect(find.text('Review & Start'), findsNothing);
      expect(find.text('View weekly plan'), findsOneWidget);
    });

    testWidgets('no plan shows an empty state, never a forced workout', (
      tester,
    ) async {
      await pumpOverview(tester, plans: const []);
      expect(find.byKey(const Key('no_plan_card')), findsOneWidget);
      expect(find.textContaining('Leg Day'), findsNothing);
      expect(find.text('Review & Start'), findsNothing);
      expect(find.text('Open weekly plan'), findsOneWidget);
    });

    testWidgets('a workout day without exercises counts as no usable plan', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        plans: [_plan(day: 'MONDAY', title: 'Empty', isToday: true)],
      );
      expect(find.byKey(const Key('no_plan_card')), findsOneWidget);
    });

    testWidgets('the weekly plan can be opened from the empty state', (
      tester,
    ) async {
      await pumpOverview(tester, plans: const []);
      await tapButton(tester, find.byKey(const Key('open_weekly_plan')));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyWorkoutPlanScreen), findsOneWidget);
    });
  });

  group('starting the session', () {
    testWidgets('hands the exact list, name and id to the session screen', (
      tester,
    ) async {
      final exercises = [_squat, _lunge];
      await pumpOverview(
        tester,
        plans: [
          _plan(
            day: 'TUESDAY',
            title: 'Leg Day Technical',
            isToday: true,
            exercises: exercises,
          ),
        ],
      );

      await tapButton(tester, find.byKey(const Key('review_start')));
      await tester.pumpAndSettle();
      // The review sheet comes first; nothing has started yet.
      expect(find.text('Ready to start?'), findsOneWidget);
      expect(find.byType(WorkoutSessionScreen), findsNothing);

      await tapButton(tester, find.text('Start workout'));
      await tester.pump(const Duration(milliseconds: 600));

      final session = tester.widget<WorkoutSessionScreen>(
        find.byType(WorkoutSessionScreen),
      );
      expect(session.workoutName, 'Leg Day Technical');
      expect(session.workoutId, 'weekly_plan_tuesday');
      expect(identical(session.initialExercises, exercises), isTrue);
      expect(session.initialExercises!.map((e) => e['name']), [
        'Barbell Back Squat',
        'Walking Lunge',
      ]);
    });

    testWidgets('"Keep reviewing" does not start anything', (tester) async {
      await pumpOverview(
        tester,
        plans: [
          _plan(
            day: 'TUESDAY',
            title: 'Leg Day Technical',
            isToday: true,
            exercises: [_squat],
          ),
        ],
      );
      await tapButton(tester, find.byKey(const Key('review_start')));
      await tester.pumpAndSettle();
      await tapButton(tester, find.text('Keep reviewing'));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutSessionScreen), findsNothing);
    });
  });

  group('active session', () {
    ActiveWorkoutSession active({
      String name = 'Leg Day Technical',
      String id = 'weekly_plan_tuesday',
    }) => ActiveWorkoutSession(
      workoutName: name,
      workoutId: id,
      currentIndex: 0,
      seconds: 600,
      isPaused: true,
      completedSets: const [
        [true, true, false, false],
        [false, false, false],
      ],
      exercisesData: [_squat, _lunge],
    );

    final plans = [
      _plan(
        day: 'TUESDAY',
        title: 'Leg Day Technical',
        isToday: true,
        exercises: [_squat, _lunge],
      ),
    ];

    testWidgets('a matching session prioritizes Resume', (tester) async {
      await pumpOverview(tester, plans: plans, active: active());
      expect(find.byKey(const Key('resume_card')), findsOneWidget);
      expect(find.textContaining('2 of 7 sets done'), findsOneWidget);
      expect(find.textContaining('10 min elapsed'), findsOneWidget);
      expect(find.byKey(const Key('resume_differs')), findsNothing);
      expect(find.text('Review & Start'), findsNothing);
    });

    testWidgets('Resume reopens the saved session with its saved exercises', (
      tester,
    ) async {
      final saved = active();
      await pumpOverview(tester, plans: plans, active: saved);
      await tapButton(tester, find.byKey(const Key('resume_button')));
      await tester.pump(const Duration(milliseconds: 600));

      final session = tester.widget<WorkoutSessionScreen>(
        find.byType(WorkoutSessionScreen),
      );
      expect(session.workoutName, 'Leg Day Technical');
      expect(session.workoutId, 'weekly_plan_tuesday');
      expect(identical(session.initialExercises, saved.exercisesData), isTrue);
    });

    testWidgets('a different session is explained and today stays reachable', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        plans: plans,
        active: active(name: 'Upper Body Flow', id: 'weekly_plan_wednesday'),
      );
      expect(find.text('Resume workout'), findsOneWidget);
      expect(find.byKey(const Key('resume_differs')), findsOneWidget);
      expect(find.textContaining('Upper Body Flow'), findsWidgets);
      // Today's plan is hidden until asked for.
      expect(find.byKey(const Key('overview_title')), findsNothing);

      await tapButton(tester, find.byKey(const Key('view_today_plan')));
      await tester.pump();
      expect(find.byKey(const Key('overview_title')), findsOneWidget);

      await tapButton(tester, find.byKey(const Key('review_start')));
      await tester.pumpAndSettle();
      // Starting today's workout would replace the unfinished one.
      expect(find.byKey(const Key('replace_warning')), findsOneWidget);
    });
  });

  group('weekly plan builder', () {
    test('produces seven days with exactly one today and two rest days', () {
      final plans = buildWeeklyPlans(now: DateTime(2026, 10, 13)); // Tuesday
      expect(plans.length, 7);
      expect(plans.where((p) => p.isToday).length, 1);
      expect(plans.firstWhere((p) => p.isToday).dayName, 'TUESDAY');
      expect(plans.where((p) => p.isRestDay).map((p) => p.dayName), [
        'THURSDAY',
        'SUNDAY',
      ]);
      final monday = plans.first;
      expect(monday.structuredExercises, isNotEmpty);
      expect(monday.durationMinutes, 45);
    });
  });
}
