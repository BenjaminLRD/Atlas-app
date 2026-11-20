import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/custom_workout.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/meal_prep.dart';
import 'package:atlas/screens/custom_workout_editor_screen.dart';
import 'package:atlas/screens/custom_workouts_screen.dart';
import 'package:atlas/screens/meal_prep_editor_screen.dart';
import 'package:atlas/screens/meal_preps_screen.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:atlas/services/custom_workout_store.dart';
import 'package:atlas/services/meal_prep_store.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  double width = 390,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(scale),
        ),
        child: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('custom workouts', () {
    final exercises = Exercise.defaultRegistry();
    final a = exercises[0];
    final b = exercises[1];

    Future<void> openEditor(WidgetTester tester) async {
      await _pump(tester, const CustomWorkoutsScreen());
      expect(find.byKey(const Key('workouts_empty')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('new_workout_empty')));
      expect(find.text('New workout'), findsOneWidget);
    }

    Future<void> addTwo(WidgetTester tester) async {
      await _tap(tester, find.byKey(const Key('add_exercise_empty')));
      await tester.enterText(
        find.byKey(const Key('exercise_search')),
        a.name.split(' ').first,
      );
      await tester.pump();
      expect(find.byKey(Key('pick_${a.id}')), findsOneWidget);
      await tester.tap(find.byKey(Key('pick_${a.id}')));
      await tester.pump();
      // Clear the search and pick a second one.
      await tester.enterText(find.byKey(const Key('exercise_search')), '');
      await tester.pump();
      await tester.tap(find.byKey(Key('pick_${b.id}')));
      await tester.pump();
      expect(find.text('Add 2 exercises'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('picker_add')));
    }

    testWidgets('an empty list explains itself and leads to the editor', (
      tester,
    ) async {
      await openEditor(tester);
      expect(find.byKey(const Key('exercises_empty')), findsOneWidget);
      expect(find.text('Add exercises'), findsOneWidget);
    });

    testWidgets('search finds exercises, steppers edit sets and reps, the '
        'summary updates, and saving lists the workout', (tester) async {
      await openEditor(tester);
      await addTwo(tester);
      expect(find.text(a.name), findsWidgets);
      expect(
        tester.widget<Text>(find.byKey(const Key('workout_summary'))).data,
        contains('2 exercises'),
      );

      await _tap(tester, find.byKey(const Key('sets_0_plus')));
      expect(
        tester.widget<Text>(find.byKey(const Key('sets_0_value'))).data,
        '4',
      );
      if (a.durationSeconds == null) {
        await _tap(tester, find.byKey(const Key('reps_0_plus')));
        expect(
          tester.widget<Text>(find.byKey(const Key('reps_0_value'))).data,
          '11',
        );
      }
      expect(
        tester.widget<Text>(find.byKey(const Key('workout_summary'))).data,
        contains('estimate'),
      );

      await _tap(tester, find.byKey(const Key('save_workout')));
      expect(find.text('My workouts'), findsOneWidget);
      expect(find.text('My workout'), findsWidgets);
      expect(CustomWorkoutStore().all().single.exercises.length, 2);
    });

    testWidgets('validation names what is missing, without a dialog', (
      tester,
    ) async {
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('workout_name')), '');
      await tester.pump();
      await _tap(tester, find.byKey(const Key('save_workout')));
      expect(find.text('Give your workout a name.'), findsOneWidget);
      expect(find.text('Add at least one exercise to save.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(CustomWorkoutStore().all(), isEmpty);
    });

    testWidgets('removing and reordering exercises works', (tester) async {
      await openEditor(tester);
      await addTwo(tester);
      final firstBefore = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d == a.name || d == b.name)
          .first;
      await tester.drag(
        find.byKey(const Key('drag_exercise_0')),
        const Offset(0, 160),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final firstAfter = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d == a.name || d == b.name)
          .first;
      expect(firstAfter, isNot(firstBefore));

      await _tap(tester, find.byKey(const Key('remove_exercise_0')));
      expect(
        tester.widget<Text>(find.byKey(const Key('workout_summary'))).data,
        contains('1 exercise '),
      );
    });

    testWidgets('leaving with unsaved changes asks; a clean editor does not', (
      tester,
    ) async {
      await openEditor(tester);
      // Nothing changed yet: back leaves without a dialog.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const Key('workouts_empty')), findsOneWidget);

      await _tap(tester, find.byKey(const Key('new_workout_empty')));
      await tester.enterText(find.byKey(const Key('workout_name')), 'Changed');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('keep_editing')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('New workout'), findsOneWidget);
    });

    testWidgets('duplicate and delete with undo', (tester) async {
      final store = CustomWorkoutStore();
      final w = await store.save(
        store
            .blank('Legs')
            .copyWith(
              exercises: [CustomExercise(exerciseId: a.id, name: a.name)],
            ),
      );
      await _pump(tester, CustomWorkoutsScreen(store: store));
      expect(find.byKey(Key('workout_${w.id}')), findsOneWidget);
      expect(find.byKey(Key('start_${w.id}')), findsOneWidget);

      await _tap(tester, find.byKey(Key('menu_${w.id}')));
      await tester.tap(find.text('Duplicate'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.all().length, 2);
      expect(find.text('Legs (copy)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await _tap(tester, find.byKey(Key('menu_${w.id}')));
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 1));
      expect(store.all().length, 1);
      expect(find.text('Undo'), findsOneWidget);
      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.all().length, 2);
    });

    testWidgets('Start opens the workout session with the saved exercises', (
      tester,
    ) async {
      final store = CustomWorkoutStore();
      final w = await store.save(
        store
            .blank('Legs')
            .copyWith(
              exercises: [
                CustomExercise(
                  exerciseId: a.id,
                  name: a.name,
                  sets: 2,
                  durationSec: a.durationSeconds,
                ),
              ],
            ),
      );
      await _pump(tester, CustomWorkoutsScreen(store: store));
      await _tap(tester, find.byKey(Key('start_${w.id}')));
      expect(find.byType(WorkoutSessionScreen), findsOneWidget);
      final screen = tester.widget<WorkoutSessionScreen>(
        find.byType(WorkoutSessionScreen),
      );
      expect(screen.workoutName, 'Legs');
      expect(screen.initialExercises!.single['name'], a.name);
      expect((screen.initialExercises!.single['sets'] as List).length, 2);
      await tester.pumpWidget(const SizedBox());
    });

    for (final w in const [320.0, 360.0]) {
      testWidgets('editor has no overflow at ${w.toInt()}dp, text x1.5', (
        tester,
      ) async {
        final store = CustomWorkoutStore();
        final saved = await store.save(
          store
              .blank('A very long workout name that keeps going')
              .copyWith(
                exercises: [
                  for (final e in exercises.take(3))
                    CustomExercise(
                      exerciseId: e.id,
                      name: e.name,
                      muscleGroup: e.muscleGroup,
                      durationSec: e.durationSeconds,
                    ),
                ],
              ),
        );
        await _pump(
          tester,
          CustomWorkoutEditorScreen(existing: saved, store: store),
          width: w,
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
        await _pump(
          tester,
          CustomWorkoutsScreen(store: store),
          width: w,
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('meal preps', () {
    late NutritionService nutrition;

    setUp(() => nutrition = NutritionService());

    Future<void> openEditor(WidgetTester tester) async {
      await _pump(tester, MealPrepsScreen(nutrition: nutrition));
      expect(find.byKey(const Key('preps_empty')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('new_prep_empty')));
      expect(find.text('New meal prep'), findsOneWidget);
    }

    Future<void> addFood(WidgetTester tester, String meal) async {
      await _tap(tester, find.byKey(Key('add_food_$meal')));
      final food = nutrition.getAvailableFoods().first;
      await tester.tap(find.byKey(Key('pick_food_${food.id}')));
      await tester.pump();
      await _tap(tester, find.byKey(const Key('food_picker_add')));
    }

    testWidgets('empty state, then a day is built with totals and a portion '
        'stepper', (tester) async {
      await openEditor(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('totals_text'))).data,
        'Add foods to see the total',
      );
      await addFood(tester, 'breakfast');
      final food = nutrition.getAvailableFoods().first;
      final unit = PortionUnit.forFood(food);
      final item = find.byWidgetPredicate(
        (w) => w.key is Key && '${w.key}'.contains('qty_it_'),
      );
      expect(item, findsOneWidget);
      final before = tester.widget<Text>(item).data!;
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w.key is Key && '${w.key}'.contains('qty_plus_'),
        ),
      );
      await tester.pump();
      expect(tester.widget<Text>(item).data, isNot(before));
      expect(unit.label, isNotEmpty);
      expect(
        tester.widget<Text>(find.byKey(const Key('totals_text'))).data,
        contains('kcal'),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('prep_summary'))).data,
        contains('1 food'),
      );
    });

    testWidgets('validation, then save lists the plan', (tester) async {
      await openEditor(tester);
      await _tap(tester, find.byKey(const Key('save_prep')));
      expect(find.byKey(const Key('prep_empty_error')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await addFood(tester, 'lunch');
      await _tap(tester, find.byKey(const Key('save_prep')));
      expect(find.text('Meal preps'), findsOneWidget);
      expect(find.text('Meal prep'), findsWidgets);
      expect(MealPrepStore().all().single.items.length, 1);
    });

    testWidgets(
      'days: totals per day, and a day with foods cannot be dropped',
      (tester) async {
        await openEditor(tester);
        await _tap(tester, find.byKey(const Key('days_plus')));
        expect(find.byKey(const Key('day_chip_1')), findsOneWidget);
        await _tap(tester, find.byKey(const Key('day_chip_1')));
        await addFood(tester, 'dinner');
        await _tap(tester, find.byKey(const Key('days_minus')));
        expect(find.textContaining('has foods'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('days_value'))).data,
          '2',
        );
        await _tap(tester, find.byKey(const Key('day_chip_0')));
        expect(
          tester.widget<Text>(find.byKey(const Key('totals_text'))).data,
          'Add foods to see the total',
        );
      },
    );

    testWidgets('adding to the diary works once and is not repeated', (
      tester,
    ) async {
      final store = MealPrepStore();
      final food = nutrition.getAvailableFoods().first;
      final unit = PortionUnit.forFood(food);
      final prep = await store.save(
        store
            .blank('Diary test')
            .copyWith(
              items: [
                MealPrepItem(
                  id: 'it_1',
                  food: food,
                  quantity: unit.defaultQuantity,
                  unit: unit.unit,
                  meal: MealCategory.lunch,
                  day: 0,
                ),
              ],
            ),
      );
      int diary() => nutrition.getTodayNutrition().meals.fold<int>(
        0,
        (n, m) => n + m.consumedFoods.length,
      );
      final before = diary();
      await _pump(tester, MealPrepsScreen(store: store, nutrition: nutrition));
      await _tap(tester, find.byKey(Key('log_${prep.id}')));
      expect(diary(), before + 1);
      await tester.pump(const Duration(seconds: 5));
      await _tap(tester, find.byKey(Key('log_${prep.id}')));
      expect(diary(), before + 1);
      expect(find.textContaining('already in'), findsOneWidget);
    });

    testWidgets('Showcase never touches the diary', (tester) async {
      await LocalStorage.setShowcaseModeEnabled(true);
      addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
      final store = MealPrepStore();
      final food = nutrition.getAvailableFoods().first;
      final unit = PortionUnit.forFood(food);
      final prep = await store.save(
        store
            .blank('Demo')
            .copyWith(
              items: [
                MealPrepItem(
                  id: 'it_1',
                  food: food,
                  quantity: unit.defaultQuantity,
                  unit: unit.unit,
                  meal: MealCategory.lunch,
                ),
              ],
            ),
      );
      int diary() => nutrition.getTodayNutrition().meals.fold<int>(
        0,
        (n, m) => n + m.consumedFoods.length,
      );
      final before = diary();
      await _pump(tester, MealPrepsScreen(store: store, nutrition: nutrition));
      await _tap(tester, find.byKey(Key('log_${prep.id}')));
      expect(diary(), before);
      expect(find.textContaining('Showcase'), findsOneWidget);
    });

    for (final w in const [320.0, 360.0]) {
      testWidgets('no overflow at ${w.toInt()}dp, text x1.5', (tester) async {
        final store = MealPrepStore();
        final foods = nutrition.getAvailableFoods().take(4).toList();
        final prep = await store.save(
          store
              .blank('A long meal prep name that keeps going and going')
              .copyWith(
                days: 2,
                items: [
                  for (var i = 0; i < foods.length; i++)
                    MealPrepItem(
                      id: 'it_$i',
                      food: foods[i],
                      quantity: PortionUnit.forFood(foods[i]).defaultQuantity,
                      unit: PortionUnit.forFood(foods[i]).unit,
                      meal: MealCategory.values[i % 4],
                    ),
                ],
              ),
        );
        await _pump(
          tester,
          MealPrepEditorScreen(
            existing: prep,
            store: store,
            nutrition: nutrition,
          ),
          width: w,
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
        await _pump(
          tester,
          MealPrepsScreen(store: store, nutrition: nutrition),
          width: w,
          scale: 1.5,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
