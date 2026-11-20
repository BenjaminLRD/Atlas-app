import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/screens/exercise_detail_screen.dart';
import 'package:atlas/screens/weekly_workout_plan_screen.dart';
import 'package:atlas/screens/workout_overview_screen.dart';
import 'package:atlas/services/exercise/muscle_map.dart';
import 'package:atlas/widgets/exercise/muscle_body_painter.dart';
import 'package:atlas/widgets/exercise/muscle_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MuscleBodyPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byKey(const Key('muscle_body')),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as MuscleBodyPainter;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 400,
  double height = 1200,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

Map<String, dynamic> _plan(String id, String name, String muscle) => {
  'id': id,
  'name': name,
  'primaryTarget': muscle,
  'sets': [
    {'reps': 8, 'weight': 40.0, 'completed': false},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MuscleMapCard', () {
    final bench = MuscleMap.fromNames(['Chest', 'Triceps'], ['Front Deltoids']);
    final legExtension = MuscleMap.fromNames(['Quadriceps (Isolated)'], []);

    testWidgets('shows primary and secondary muscles with a legend', (
      tester,
    ) async {
      await _pump(tester, MuscleMapCard(activation: bench));
      expect(find.byKey(const Key('muscle_body')), findsOneWidget);
      final primary = find.byKey(const Key('muscle_primary_group'));
      final secondary = find.byKey(const Key('muscle_secondary_group'));
      expect(
        find.descendant(of: primary, matching: find.text('Chest')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: primary, matching: find.text('Triceps')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: secondary, matching: find.text('Front delts')),
        findsOneWidget,
      );
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
    });

    testWidgets('front and back can be switched when both show muscles', (
      tester,
    ) async {
      await _pump(tester, MuscleMapCard(activation: bench));
      expect(find.byKey(const Key('muscle_view_front')), findsOneWidget);
      expect(find.byKey(const Key('muscle_view_back')), findsOneWidget);
      expect(_painter(tester).view, MuscleView.front);

      await tester.tap(find.byKey(const Key('muscle_view_back')));
      await tester.pump();
      expect(_painter(tester).view, MuscleView.back);

      await tester.tap(find.byKey(const Key('muscle_view_front')));
      await tester.pump();
      expect(_painter(tester).view, MuscleView.front);
    });

    testWidgets('a single-view exercise has no switch at all', (tester) async {
      await _pump(tester, MuscleMapCard(activation: legExtension));
      expect(find.byKey(const Key('muscle_view_front')), findsNothing);
      expect(find.byKey(const Key('muscle_view_back')), findsNothing);
      expect(_painter(tester).view, MuscleView.front);
    });

    testWidgets('opens on the back for back work', (tester) async {
      final lats = MuscleMap.fromNames(['Lats'], []);
      await _pump(tester, MuscleMapCard(activation: lats));
      expect(_painter(tester).view, MuscleView.back);
      expect(find.byKey(const Key('muscle_view_front')), findsNothing);
    });

    testWidgets('switching exercise returns to that exercise\'s best side', (
      tester,
    ) async {
      Widget host(MuscleActivation a) => MuscleMapCard(activation: a);
      await _pump(tester, host(bench));
      await tester.tap(find.byKey(const Key('muscle_view_back')));
      await tester.pump();
      expect(_painter(tester).view, MuscleView.back);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(child: host(legExtension)),
          ),
        ),
      );
      await tester.pump();
      expect(_painter(tester).view, MuscleView.front);
      expect(find.byKey(const Key('muscle_view_back')), findsNothing);
    });

    testWidgets('full-body work says so instead of picking muscles', (
      tester,
    ) async {
      final general = MuscleMap.fromNames(['Full Body', 'Cardiovascular'], []);
      await _pump(tester, MuscleMapCard(activation: general));
      expect(find.byKey(const Key('muscle_general_note')), findsOneWidget);
      expect(find.byKey(const Key('muscle_primary_group')), findsNothing);
    });

    testWidgets('an unmappable exercise is flagged, not drawn', (tester) async {
      final unknown = MuscleMap.fromNames(['Flux Capacitor'], []);
      await _pump(tester, MuscleMapCard(activation: unknown));
      expect(find.byKey(const Key('muscle_map_incomplete')), findsOneWidget);
      expect(find.byKey(const Key('muscle_body')), findsNothing);
    });

    for (final w in [280.0, 320.0, 360.0, 430.0]) {
      testWidgets('fits a ${w.toInt()} px wide phone without overflow', (
        tester,
      ) async {
        await _pump(
          tester,
          Padding(
            padding: const EdgeInsets.all(16),
            child: MuscleMapCard(activation: bench),
          ),
          width: w,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('muscle_body')), findsOneWidget);
        final size = tester.getSize(find.byKey(const Key('muscle_body')));
        // Large enough to read the highlighted regions.
        expect(size.height, greaterThanOrEqualTo(240));
        expect(size.width, greaterThanOrEqualTo(100));
      });
    }

    testWidgets('works with no network: the figure is drawn, not downloaded', (
      tester,
    ) async {
      // The figure is vector code in the app. Nothing here loads an image or
      // a URL, so there is nothing that could fail offline.
      await _pump(tester, MuscleMapCard(activation: bench));
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('MuscleMapSheet', () {
    final workout = [
      _plan('bench_press', 'Barbell Bench Press', 'Chest'),
      _plan('lat_pulldown', 'Wide-Grip Lat Pulldown', 'Lats'),
    ];

    testWidgets('starts on the whole workout, then one exercise', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          height: 900,
          child: MuscleMapSheet(
            workoutName: 'Pull and Push',
            exercises: workout,
          ),
        ),
      );
      final primary = find.byKey(const Key('muscle_primary_group'));
      // Whole workout: chest from the bench AND lats from the pulldown.
      expect(
        find.descendant(of: primary, matching: find.text('Chest')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: primary, matching: find.text('Lats')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('muscle_select_1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('muscle_select_1')));
      await tester.pump();
      // Just the pulldown now.
      expect(
        find.descendant(of: primary, matching: find.text('Lats')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: primary, matching: find.text('Chest')),
        findsNothing,
      );

      await tester.ensureVisible(find.byKey(const Key('muscle_select_all')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('muscle_select_all')));
      await tester.pump();
      expect(
        find.descendant(of: primary, matching: find.text('Chest')),
        findsOneWidget,
      );
    });
  });

  group('Where it appears', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      AppDependencies.reset();
    });

    testWidgets('the workout start screen shows the combined map', (
      tester,
    ) async {
      final plan = DailyPlan(
        dayName: 'Monday',
        date: '16',
        title: 'Push Day',
        duration: '45 mins',
        muscleGroups: 'Chest',
        exercises: const [],
        structuredExercises: [
          _plan('bench_press', 'Barbell Bench Press', 'Chest'),
          _plan('lateral_raise', 'Dumbbell Lateral Raise', 'Side Deltoids'),
        ],
        isToday: true,
        focus: 'push',
        durationMinutes: 45,
      );
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: WorkoutOverviewScreen(
            planBuilder: () => [plan],
            activeSessionReader: () => null,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final primary = find.byKey(const Key('muscle_primary_group'));
      expect(find.byKey(const Key('muscle_map_card')), findsOneWidget);
      expect(
        find.descendant(of: primary, matching: find.text('Chest')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: primary, matching: find.text('Side delts')),
        findsOneWidget,
      );
      // The existing start action is untouched.
      expect(find.byKey(const Key('review_start')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('muscle_map_by_exercise')),
      );
      await tester.pump();
      final btn = find.byKey(const Key('muscle_map_by_exercise'));
      await tester.tap(btn);
      // The button animates before it acts, so give it a few frames.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(MuscleMapSheet), findsOneWidget);
    });

    testWidgets('the exercise screen shows that exercise\'s muscles', (
      tester,
    ) async {
      final squat = Exercise.getById('barbell_back_squat')!;
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ExerciseDetailScreen(
            exercise: squat,
            enableWorkoutStart: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final card = find.byKey(const Key('muscle_map_card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('muscle_primary_group')),
          matching: find.text('Quads'),
        ),
        findsOneWidget,
      );
    });
  });
}
