import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/custom_workout.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/meal_prep.dart';
import 'package:atlas/services/custom_workout_store.dart';
import 'package:atlas/services/meal_prep_store.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodItem _food(
  String id, {
  double calories = 100,
  double protein = 10,
  double carbs = 20,
  double fat = 5,
  Set<String> unknown = const {},
  NutritionBasis basis = NutritionBasis.per100g,
  NutritionSource source = NutritionSource.openFoodFacts,
}) => FoodItem(
  id: id,
  name: 'Food $id',
  calories: calories,
  protein: protein,
  carbohydrates: carbs,
  fats: fat,
  unknownNutrients: unknown,
  nutritionBasis: basis,
  nutritionSource: source,
);

MealPrepItem _item(
  String id,
  FoodItem food, {
  double q = 100,
  String unit = 'grams',
  MealCategory meal = MealCategory.lunch,
  int day = 0,
}) => MealPrepItem(
  id: id,
  food: food,
  quantity: q,
  unit: unit,
  meal: meal,
  day: day,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('custom workout model', () {
    const squat = CustomExercise(
      exerciseId: 'squat',
      name: 'Squat',
      sets: 4,
      reps: 8,
    );
    const plank = CustomExercise(
      exerciseId: 'plank',
      name: 'Plank',
      sets: 3,
      reps: 1,
      durationSec: 45,
    );

    CustomWorkout wk(List<CustomExercise> e) => CustomWorkout(
      id: 'w',
      name: 'Legs',
      exercises: e,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('summary numbers add up and the time is only an estimate', () {
      final w = wk([squat, plank]);
      expect(w.totalSets, 7);
      // squat 4 x (8*3 + 75) + plank 3 x (45 + 75) = 396 + 360 = 756 s
      expect(w.estimatedMinutes, 13);
    });

    test('the session gets one entry per set and no invented load', () {
      final s = wk([squat, plank]).toSessionExercises();
      expect(s.length, 2);
      final sets = s.first['sets'] as List;
      expect(sets.length, 4);
      expect((sets.first as Map)['reps'], 8);
      expect((sets.first as Map)['weight'], 0.0);
      expect(((s.last['sets'] as List).first as Map)['durationSeconds'], 45);
    });

    test('values are kept within sensible limits', () {
      final e = squat.copyWith(sets: 99, reps: 0);
      expect(e.sets, CustomExercise.maxSets);
      expect(e.reps, 1);
      expect(plank.copyWith(durationSec: 1).durationSec, 5);
    });

    test('it survives saving and loading and ignores damaged entries', () {
      final json = CustomWorkout.encodeAll([
        wk([squat, plank]),
      ]);
      final back = CustomWorkout.decodeAll(json);
      expect(back.single.exercises.length, 2);
      expect(back.single.exercises.last.isTimed, isTrue);
      expect(CustomWorkout.decodeAll('not json'), isEmpty);
      expect(
        CustomWorkout.decodeAll(
          '[{"id":"a","name":"A","exercises":[{"id":"x"},{"bad":1}]}]',
        ).single.exercises,
        isEmpty,
      );
    });
  });

  group('custom workout store', () {
    test('saving twice replaces instead of duplicating', () async {
      final store = CustomWorkoutStore();
      final w = store
          .blank('Push')
          .copyWith(
            exercises: const [CustomExercise(exerciseId: 'a', name: 'A')],
          );
      final saved = await store.save(w);
      await store.save(saved.copyWith(name: 'Push day'));
      final all = store.all();
      expect(all.length, 1);
      expect(all.single.name, 'Push day');
    });

    test(
      'duplicate makes an independent copy; delete removes only one',
      () async {
        final store = CustomWorkoutStore();
        final a = await store.save(
          store
              .blank('Pull')
              .copyWith(
                exercises: const [CustomExercise(exerciseId: 'a', name: 'A')],
              ),
        );
        final copy = await store.duplicate(a.id);
        expect(copy.id, isNot(a.id));
        expect(copy.name, 'Pull (copy)');
        expect(store.all().length, 2);
        await store.delete(a.id);
        expect(store.all().single.id, copy.id);
      },
    );

    test('Showcase keeps its own list', () async {
      final store = CustomWorkoutStore();
      await store.save(store.blank('Real'));
      await LocalStorage.setShowcaseModeEnabled(true);
      addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
      expect(store.all(), isEmpty);
      await store.save(store.blank('Demo'));
      expect(store.all().single.name, 'Demo');
      expect(
        LocalStorage.getString(CustomWorkoutStore.realKey),
        contains('Real'),
      );
      await LocalStorage.setShowcaseModeEnabled(false);
      expect(store.all().single.name, 'Real');
    });
  });

  group('meal prep totals: unknown is not zero', () {
    test('known foods add up', () {
      final t = NutritionTotals.of([
        _item('1', _food('a')),
        _item('2', _food('b', calories: 50), q: 200),
      ]);
      expect(t.calories.total, 200); // 100 + 50*2
      expect(t.protein.total, 30);
      expect(t.calories.partial, isFalse);
    });

    test('a food without calories is left out and the total says so', () {
      final t = NutritionTotals.of([
        _item('1', _food('a')),
        _item('2', _food('b', unknown: {FoodItem.calorieKey})),
      ]);
      expect(t.calories.total, 100);
      expect(t.calories.missing, 1);
      expect(t.calories.partial, isTrue);
      expect(t.protein.partial, isFalse);
    });

    test('when nothing is known the total is unavailable, not 0', () {
      final t = NutritionTotals.of([
        _item('1', _food('a', unknown: {FoodItem.calorieKey})),
      ]);
      expect(t.calories.total, isNull);
      expect(t.calories.known, isFalse);
    });

    test('a genuine zero stays a zero', () {
      final t = NutritionTotals.of([_item('1', _food('water', calories: 0))]);
      expect(t.calories.total, 0);
      expect(t.calories.known, isTrue);
    });

    test('a food with an unknown basis never gets a calculated portion', () {
      final f = _food('x', basis: NutritionBasis.unknown);
      expect(PortionUnit.forFood(f).supported, isFalse);
      expect(
        _item('1', f, unit: 'serving').valueOf(FoodItem.calorieKey),
        isNull,
      );
    });

    test('estimates are flagged and sources are named', () {
      final typical = _item('1', _food('a', source: NutritionSource.builtIn));
      final off = _item('2', _food('b'));
      expect(typical.isEstimate, isTrue);
      expect(typical.sourceLabel, 'Typical values');
      expect(off.isEstimate, isFalse);
      expect(NutritionTotals.of([typical, off]).hasEstimates, isTrue);
      expect(NutritionTotals.of([off]).hasEstimates, isFalse);
    });
  });

  group('meal prep portions', () {
    test('grams, millilitres and servings are never mixed', () {
      expect(PortionUnit.forFood(_food('g')).unit, 'grams');
      expect(
        PortionUnit.forFood(_food('m', basis: NutritionBasis.per100ml)).unit,
        'ml',
      );
      expect(
        PortionUnit.forFood(_food('s', basis: NutritionBasis.perServing)).unit,
        'serving',
      );
    });
  });

  group('meal prep plan', () {
    test('items group by day and meal, with totals for each', () {
      final p = MealPrep(
        id: 'p',
        name: 'Week',
        days: 2,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        items: [
          _item('1', _food('a'), meal: MealCategory.breakfast),
          _item('2', _food('b', calories: 300), meal: MealCategory.dinner),
          _item('3', _food('c', calories: 50), day: 1),
        ],
      );
      expect(p.itemsFor(0).length, 2);
      expect(p.totalsForDay(0).calories.total, 400);
      expect(p.totalsForDay(1).calories.total, 50);
      expect(p.totalsForMeal(0, MealCategory.dinner).calories.total, 300);
      expect(p.totals.calories.total, 450);
      expect(p.lastUsedDay, 1);
    });

    test('it survives saving and loading', () {
      final p = MealPrep(
        id: 'p',
        name: 'Week',
        days: 3,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        items: [
          _item('1', _food('a', unknown: {FoodItem.fatKey})),
        ],
        loggedOn: const {'1': '2026-11-17'},
      );
      final back = MealPrep.decodeAll(MealPrep.encodeAll([p])).single;
      expect(back.days, 3);
      expect(back.loggedOn['1'], '2026-11-17');
      // The unknown fat value survives the round trip as unknown.
      expect(back.totals.fat.known, isFalse);
      expect(MealPrep.decodeAll('garbage'), isEmpty);
    });
  });

  group('meal prep store', () {
    MealPrep prepWith(
      MealPrepStore s,
      List<MealPrepItem> items, {
      int days = 1,
    }) => s.blank('Prep').copyWith(items: items, days: days);

    test('saving twice replaces; duplicate gets new item ids', () async {
      final store = MealPrepStore();
      final saved = await store.save(prepWith(store, [_item('1', _food('a'))]));
      await store.save(saved.copyWith(name: 'Renamed'));
      expect(store.all().length, 1);
      final copy = await store.duplicate(saved.id);
      expect(store.all().length, 2);
      expect(copy.items.single.id, isNot('1'));
      expect(copy.loggedOn, isEmpty);
    });

    test('Showcase keeps its own list', () async {
      final store = MealPrepStore();
      await store.save(prepWith(store, [_item('1', _food('a'))]));
      await LocalStorage.setShowcaseModeEnabled(true);
      addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
      expect(store.all(), isEmpty);
    });

    test('adding a day to the diary twice does not double it', () async {
      final nutrition = NutritionService();
      final foods = nutrition.getAvailableFoods().take(2).toList();
      final availableBefore = nutrition.getAvailableFoods().length;
      expect(foods.length, 2);
      final store = MealPrepStore();
      var prep = await store.save(
        prepWith(store, [
          _item('1', foods[0], meal: MealCategory.breakfast),
          _item('2', foods[1], meal: MealCategory.lunch),
        ]),
      );
      int diaryCount() => nutrition.getTodayNutrition().meals.fold<int>(
        0,
        (n, m) => n + m.consumedFoods.length,
      );
      final before = diaryCount();
      final today = DateTime(2026, 11, 17, 9);
      expect(store.pendingToday(prep, 0, today: today), 2);
      final first = await store.logDayToToday(prep, 0, nutrition, today: today);
      expect(first, 2);
      prep = store.byId(prep.id)!;
      expect(store.pendingToday(prep, 0, today: today), 0);
      final second = await store.logDayToToday(
        prep,
        0,
        nutrition,
        today: today,
      );
      expect(second, 0);
      expect(diaryCount(), before + 2);
      // Saving the plan itself created no food records.
      expect(nutrition.getAvailableFoods().length, availableBefore);
    });

    test('a food with no calculable portion is not logged', () async {
      final nutrition = NutritionService();
      final store = MealPrepStore();
      final prep = await store.save(
        prepWith(store, [
          _item(
            '1',
            _food('x', basis: NutritionBasis.unknown),
            unit: 'serving',
          ),
        ]),
      );
      final added = await store.logDayToToday(
        prep,
        0,
        nutrition,
        today: DateTime(2026, 11, 17),
      );
      expect(added, 0);
    });
  });
}
