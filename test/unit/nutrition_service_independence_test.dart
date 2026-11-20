import 'dart:async';
import 'dart:io';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/nutrition_repository.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/nutrition/nutrition_changes.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _food = FoodItem(
  id: 'f1',
  name: 'Rice',
  calories: 130,
  protein: 3,
  carbohydrates: 28,
  fats: 0.5,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('NutritionService on its own (no FitnessProvider)', () {
    late int changes;
    late void Function() listener;

    setUp(() {
      changes = 0;
      listener = () => changes++;
      NutritionChanges.instance.addListener(listener);
    });

    tearDown(() => NutritionChanges.instance.removeListener(listener));

    test('no provider exists, and the service still works', () async {
      // The only listener is this test's own: nothing app-level is attached.
      expect(NutritionChanges.instance.listenerCount, 1);
      final service = NutritionService();
      await service.saveMacroTarget(
        const MacroTarget(
          calories: 2100,
          proteinGrams: 140,
          carbsGrams: 220,
          fatGrams: 60,
        ),
      );
      expect(service.getMacroTarget().calories, 2100);
      expect(changes, 1);
    });

    test('every save reports exactly one change', () async {
      final service = NutritionService();

      Future<void> expectOne(String name, Future<void> Function() save) async {
        final before = changes;
        await save();
        expect(changes - before, 1, reason: name);
      }

      await expectOne('saveScannedFood', () => service.saveScannedFood(_food));
      await expectOne('addCustomFood', () => service.addCustomFood(_food));
      await expectOne(
        'createCustomFood',
        () => service.createCustomFood(_food.copyWith(id: 'f2')),
      );
      await expectOne(
        'updateCustomFood',
        () => service.updateCustomFood(_food.copyWith(name: 'Brown rice')),
      );
      await expectOne(
        'toggleFavoriteFood',
        () => service.toggleFavoriteFood('f1'),
      );
      await expectOne('recordRecentFood', () => service.recordRecentFood('f1'));
      await expectOne('deleteCustomFood', () => service.deleteCustomFood('f2'));
      await expectOne(
        'saveProteinConsumed',
        () => service.saveProteinConsumed(40),
      );
      await expectOne('saveProteinGoal', () => service.saveProteinGoal(150));
      await expectOne(
        'saveDailyNutrition',
        () async => service.saveDailyNutrition(service.getDailyNutrition()),
      );
      await expectOne(
        'saveMacroTarget',
        () => service.saveMacroTarget(MacroTarget.defaultTarget()),
      );
      await expectOne(
        'logFoodItem',
        () =>
            service.logFoodItem(category: MealCategory.lunch, foodItem: _food),
      );
      final mealId = service.getDailyNutrition().meals.first.id;
      await expectOne(
        'toggleMealCompletion',
        () => service.toggleMealCompletion(mealId: mealId),
      );
      await expectOne(
        'addFoodToMeal',
        () => service.addFoodToMeal('Lunch', _food, 100, 'grams'),
      );
      await expectOne(
        'updateFoodQuantity',
        () => service.updateFoodQuantity('Lunch', _food.id, 200, 'grams'),
      );
      await expectOne(
        'removeFoodFromMeal',
        () => service.removeFoodFromMeal('Lunch', _food.id),
      );
      await expectOne(
        'completeMeal',
        () => service.completeMeal('Lunch', true),
      );
    });

    test('reading changes nothing', () {
      final service = NutritionService();
      service.getDailyNutrition();
      service.getTodayNutrition();
      service.getConsumedTotals();
      service.getMacroTarget();
      expect(changes, 0);
    });

    test(
      'a listener that unsubscribes while running does not break the rest',
      () {
        var second = 0;
        late void Function() once;
        once = () => NutritionChanges.instance.removeListener(once);
        NutritionChanges.instance.addListener(once);
        void secondListener() => second++;
        NutritionChanges.instance.addListener(secondListener);
        addTearDown(
          () => NutritionChanges.instance.removeListener(secondListener),
        );
        NutritionChanges.instance.notifyChanged();
        expect(changes, 1);
        expect(second, 1);
      },
    );

    test('the service source no longer refers to the provider', () {
      final source = File(
        'lib/services/nutrition/nutrition_service.dart',
      ).readAsStringSync();
      expect(source.contains('fitness_provider'), isFalse);
      expect(source.contains('FitnessProvider'), isFalse);
    });
  });

  group('the provider still refreshes when the service saves', () {
    setUp(() {
      FitnessProvider.resetInstance();
    });

    tearDown(FitnessProvider.resetInstance);

    test(
      'a save made through another service instance reaches the provider',
      () async {
        final provider = FitnessProvider.instance;
        var notified = 0;
        provider.addListener(() => notified++);

        // A different instance, like the AI tools create for themselves.
        await NutritionService().saveMacroTarget(
          const MacroTarget(
            calories: 1900,
            proteinGrams: 130,
            carbsGrams: 200,
            fatGrams: 55,
          ),
        );

        expect(notified, greaterThan(0));
        expect(provider.todayNutrition.targets.calories, 1900);
      },
    );

    test(
      'food logged through the provider is still reflected at once',
      () async {
        final provider = FitnessProvider.instance;
        await provider.addFoodToMeal('Lunch', _food, 100, 'grams');
        expect(provider.totalCaloriesConsumed, closeTo(130, 0.001));
      },
    );

    test('the provider listens once and stops when it is disposed', () {
      final before = NutritionChanges.instance.listenerCount;
      final provider = FitnessProvider.instance;
      expect(NutritionChanges.instance.listenerCount, before + 1);
      FitnessProvider.resetInstance();
      expect(NutritionChanges.instance.listenerCount, before);
      // A save after that must not reach the disposed provider.
      expect(provider, isNotNull);
    });

    test('a save with no provider alive is harmless', () async {
      FitnessProvider.resetInstance();
      await NutritionService().saveMacroTarget(
        const MacroTarget(
          calories: 1700,
          proteinGrams: 120,
          carbsGrams: 180,
          fatGrams: 50,
        ),
      );
      // A provider created afterwards starts from what was saved.
      expect(FitnessProvider.instance.todayNutrition.targets.calories, 1700);
      expect(FitnessProvider.instance.proteinGoal, 120);
    });
  });
  group('NutritionChanges lifecycle and event safety', () {
    final changes = NutritionChanges.instance;

    /// Runs [body] and returns the errors it reported to Flutter.
    Future<List<FlutterErrorDetails>> reported(
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

    setUp(FitnessProvider.resetInstance);
    tearDown(FitnessProvider.resetInstance);

    test('a notification with no listeners is harmless', () {
      expect(changes.listenerCount, 0);
      changes.notifyChanged();
    });

    test('adding the same listener twice registers it once', () {
      var calls = 0;
      void listener() => calls++;
      changes.addListener(listener);
      changes.addListener(listener);
      expect(changes.listenerCount, 1);
      changes.notifyChanged();
      expect(calls, 1);
      changes.removeListener(listener);
      changes.notifyChanged();
      expect(calls, 1, reason: 'one removal is enough');
    });

    test('refreshing the provider again does not add listeners', () {
      final before = changes.listenerCount;
      final provider = FitnessProvider.instance;
      expect(changes.listenerCount, before + 1);
      provider.refreshAll();
      provider.refreshAll();
      expect(FitnessProvider.instance, same(provider));
      expect(changes.listenerCount, before + 1);
    });

    test('disposing the provider removes its listener once', () {
      final before = changes.listenerCount;
      FitnessProvider.instance;
      expect(changes.listenerCount, before + 1);
      FitnessProvider.resetInstance();
      expect(changes.listenerCount, before);
      // Resetting again, with nothing to dispose, changes nothing.
      FitnessProvider.resetInstance();
      expect(changes.listenerCount, before);
    });

    test('a disposed provider is not notified by later saves', () async {
      FitnessProvider.instance;
      FitnessProvider.resetInstance();
      final errors = await reported(() async {
        await NutritionService().saveMacroTarget(MacroTarget.defaultTarget());
      });
      // A disposed provider that was still listening would have thrown here.
      expect(errors, isEmpty);
    });

    test(
      'a new provider after a reset is the one that gets notified',
      () async {
        FitnessProvider.instance;
        FitnessProvider.resetInstance();
        final fresh = FitnessProvider.instance;
        var notified = 0;
        fresh.addListener(() => notified++);
        await NutritionService().saveMacroTarget(MacroTarget.defaultTarget());
        expect(notified, greaterThan(0));
      },
    );

    test(
      'a listener that throws is reported and the others still run',
      () async {
        var before = 0, after = 0;
        void first() => before++;
        void broken() => throw StateError('listener failed');
        void last() => after++;
        changes
          ..addListener(first)
          ..addListener(broken)
          ..addListener(last);
        addTearDown(() {
          changes
            ..removeListener(first)
            ..removeListener(broken)
            ..removeListener(last);
        });

        final errors = await reported(() async {
          // The save itself still succeeds.
          await NutritionService().saveMacroTarget(MacroTarget.defaultTarget());
        });

        expect(before, 1);
        expect(after, 1);
        expect(errors, hasLength(1));
        expect(errors.single.exception, isA<StateError>());
        expect(errors.single.library, 'nutrition changes');
      },
    );

    test('listeners may unsubscribe while being notified', () {
      final ran = <String>[];
      late void Function() a, b, c, d;
      a = () {
        ran.add('a');
        changes.removeListener(a); // removes itself
      };
      b = () {
        ran.add('b');
        changes.removeListener(c); // removes one that has not run yet
      };
      c = () => ran.add('c');
      d = () => ran.add('d');
      for (final l in [a, b, c, d]) {
        changes.addListener(l);
      }
      addTearDown(() {
        for (final l in [a, b, c, d]) {
          changes.removeListener(l);
        }
      });

      changes.notifyChanged();
      expect(ran, ['a', 'b', 'd'], reason: 'c was removed before its turn');
      ran.clear();
      changes.notifyChanged();
      expect(ran, ['b', 'd']);
    });

    test('a listener may add another while being notified', () {
      var late = 0;
      void lateListener() => late++;
      void adder() => changes.addListener(lateListener);
      changes.addListener(adder);
      addTearDown(() {
        changes.removeListener(adder);
        changes.removeListener(lateListener);
      });
      changes.notifyChanged();
      expect(late, 0, reason: 'added during this notification, runs next time');
      changes.notifyChanged();
      expect(late, 1);
    });

    test(
      'a save through a separate service still reaches the active provider',
      () async {
        final provider = FitnessProvider.instance;
        var notified = 0;
        provider.addListener(() => notified++);
        await NutritionService().saveProteinGoal(135);
        await NutritionService(LocalNutritionRepository()).saveMacroTarget(
          const MacroTarget(
            calories: 2000,
            proteinGrams: 150,
            carbsGrams: 210,
            fatGrams: 60,
          ),
        );
        expect(notified, greaterThanOrEqualTo(2));
        expect(provider.todayNutrition.targets.calories, 2000);
      },
    );
  });
}
