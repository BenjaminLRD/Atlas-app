import 'dart:io';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/mock_food_database.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/meal_prep.dart';
import 'package:atlas/models/recipe.dart';
import 'package:atlas/services/community/sample_world.dart';
import 'package:atlas/services/food_validation_service.dart';
import 'package:atlas/services/meal_prep_store.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:atlas/services/recipes/recipe_catalog.dart';
import 'package:atlas/services/recipes/recipe_ratings.dart';
import 'package:atlas/services/recipes/recipe_stores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

FoodItem _custom({
  String id = 'custom_1',
  double kcal = 300,
  Set<String> unknown = const {},
  double? fiber,
}) => FoodItem(
  id: id,
  name: 'My wrap',
  servingSize: '150 grams',
  servingUnit: 'grams',
  calories: kcal,
  protein: 20,
  carbohydrates: 30,
  fats: 8,
  fiber: fiber,
  unknownNutrients: unknown,
  isCustom: true,
  nutritionSource: NutritionSource.userEntry,
);

Recipe _meal(
  List<RecipeIngredient> ing, {
  int servings = 1,
  String id = 'cm_t',
}) => Recipe(
  id: id,
  name: 'Test meal',
  origin: RecipeOrigin.custom,
  servings: servings,
  ingredients: ing,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final foods = MockFoodDatabase.defaultFoods;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('recipe catalogue', () {
    test('Atlas recipes resolve every ingredient and have their own photo', () {
      final list = RecipeCatalog.atlas(foods);
      expect(list.length, 4);
      final images = list.map((r) => r.imageAsset).toSet();
      expect(images.length, list.length);
      for (final r in list) {
        expect(File(r.imageAsset!).existsSync(), isTrue, reason: r.imageAsset);
        expect(r.imageCredit, isNotEmpty);
        expect(r.creatorName, isNull, reason: 'no user is credited');
        expect(r.isSample, isFalse);
        final n = r.perServing;
        expect(n.calories, isNotNull);
        expect(n.protein, isNotNull);
        expect(n.partial, isFalse);
        expect(r.steps, isNotEmpty);
      }
    });

    test('nutrition is computed from the ingredients, not typed in', () {
      final shake = RecipeCatalog.atlas(
        foods,
      ).firstWhere((r) => r.id == 'atlas_banana_shake');
      final whey = foods.firstWhere((f) => f.name == 'Whey Protein Powder');
      final milk = foods.firstWhere((f) => f.name == 'Whole Milk');
      final banana = foods.firstWhere((f) => f.name == 'Ripe Banana');
      // whey 1 serving + 300 ml milk (per 100 ml) + 1 banana (per piece)
      final expected = whey.calories + milk.calories * 3 + banana.calories;
      expect(shake.perServing.calories, closeTo(expected, 0.01));
    });

    test('per serving divides the whole recipe by its servings', () {
      final box = RecipeCatalog.atlas(
        foods,
      ).firstWhere((r) => r.id == 'atlas_chicken_prep_box');
      expect(box.servings, 4);
      expect(
        box.perServing.calories! * 4,
        closeTo(box.totals.calories.total!, 0.01),
      );
    });

    test('community recipes exist only in Showcase Mode, as samples', () async {
      final hub = RecipeHub(foods: foods);
      expect(hub.community(), isEmpty);
      expect(hub.communityAvailable, isFalse);
      await LocalStorage.setShowcaseModeEnabled(true);
      addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
      final list = hub.community();
      expect(list.length, greaterThanOrEqualTo(5));
      final names = SampleWorld.athletes.map((a) => a.name).toSet();
      for (final r in list) {
        expect(r.isSample, isTrue);
        expect(names.contains(r.creatorName), isTrue);
        expect(File(r.imageAsset!).existsSync(), isTrue);
      }
      expect({for (final r in list) r.imageAsset}.length, list.length);
    });
  });

  group('ratings', () {
    RecipeRating r(int s) => RecipeRating(
      recipeId: 'x',
      raterId: 'u$s',
      raterName: 'U',
      stars: s,
      updatedAt: DateTime(2026),
    );

    test('no ratings is not a zero rating', () {
      final none = RatingSummary.of(const []);
      expect(none.average, isNull);
      expect(none.hasRatings, isFalse);
      expect(none.label, 'No ratings yet');
    });

    test('the average and the count come from the submitted ratings', () {
      final s = RatingSummary.of([r(5), r(4), r(3)]);
      expect(s.average, 4.0);
      expect(s.count, 3);
      expect(s.label, '4.0 (3)');
    });

    test('real mode has no ratings and refuses to take one', () async {
      const repo = UnavailableRatingRepository();
      expect(repo.available, isFalse);
      expect(repo.summaryFor('a').count, 0);
      expect(
        () => repo.submit(recipeId: 'a', stars: 5),
        throwsA(isA<RatingException>()),
      );
    });

    test('one rating per person: rating again updates, never adds', () async {
      final repo = SampleRatingRepository();
      const id = 'sample_recipe_tuna_box';
      final before = repo.summaryFor(id);
      await repo.submit(recipeId: id, stars: 5, review: 'Great');
      final once = repo.summaryFor(id);
      expect(once.count, before.count + 1);
      for (var i = 0; i < 5; i++) {
        await repo.submit(recipeId: id, stars: 5);
      }
      expect(repo.summaryFor(id).count, before.count + 1);
      await repo.submit(recipeId: id, stars: 1);
      final updated = repo.summaryFor(id);
      expect(updated.count, before.count + 1);
      expect(updated.average, lessThan(once.average!));
      expect(repo.mine(id)!.stars, 1);
    });

    test('invalid stars and over-long reviews are refused', () async {
      final repo = SampleRatingRepository();
      for (final bad in [0, 6, -1]) {
        expect(
          () => repo.submit(recipeId: 'a', stars: bad),
          throwsA(isA<RatingException>()),
        );
      }
      expect(
        () => repo.submit(recipeId: 'a', stars: 3, review: 'x' * 601),
        throwsA(isA<RatingException>()),
      );
      expect(repo.mine('a'), isNull);
    });

    test('a recipe cannot be rated by its own creator', () {
      expect(
        () => SampleRatingRepository().submit(
          recipeId: 'a',
          stars: 5,
          creatorId: SampleRatingRepository.selfId,
        ),
        throwsA(isA<RatingException>()),
      );
    });

    test('Showcase ratings use their own key and touch nothing real', () async {
      final repo = SampleRatingRepository();
      await repo.submit(recipeId: 'sample_recipe_dal_bhat', stars: 4);
      expect(
        LocalStorage.getString(SampleRatingRepository.storageKey),
        isNotNull,
      );
      final keys = SharedPreferences.getInstance();
      final prefs = await keys;
      expect(
        prefs.getKeys().where(
          (k) => !k.contains('showcase') && k.contains('rating'),
        ),
        isEmpty,
      );
    });

    test('sample reviews come from sample athletes and are flagged', () {
      final list = SampleRatingRepository().ratingsFor(
        'sample_recipe_chicken_broccoli_rice',
      );
      expect(list, isNotEmpty);
      expect(list.every((x) => x.isSample), isTrue);
    });
  });

  group('custom meals and manual foods', () {
    test('a custom food is portioned per its entered serving', () {
      final f = _custom();
      final p = PortionUnit.forFood(f);
      expect(p.supported, isTrue);
      expect(p.unit, 'serving');
      final item = MealPrepItem(
        id: 'i',
        food: f,
        quantity: 2,
        unit: 'serving',
        meal: MealCategory.lunch,
      );
      expect(item.valueOf(FoodItem.calorieKey), 600);
      expect(item.sourceLabel, 'Entered by you');
      expect(item.isEstimate, isFalse);
    });

    test('blank optional nutrients stay unknown, not zero', () {
      final f = _custom(unknown: {FoodItem.proteinKey});
      final item = MealPrepItem(
        id: 'i',
        food: f,
        quantity: 1,
        unit: 'serving',
        meal: MealCategory.lunch,
      );
      expect(item.valueOf(FoodItem.proteinKey), isNull);
      expect(item.valueOf(FoodItem.calorieKey), 300);
      expect(f.fiber, isNull);
    });

    test('a confirmed zero stays a zero', () {
      final f = FoodItem(
        id: 'z',
        name: 'Black coffee',
        servingSize: '250 ml',
        servingUnit: 'ml',
        calories: 0,
        protein: 0,
        carbohydrates: 0,
        fats: 0,
        isCustom: true,
        nutritionSource: NutritionSource.userEntry,
      );
      final r = _meal([
        RecipeIngredient(food: f, quantity: 1, unit: 'serving'),
      ]);
      expect(r.perServing.calories, 0);
      expect(r.perServing.protein, 0);
    });

    test('per-serving totals divide by servings and keep unknown unknown', () {
      final a = RecipeIngredient(food: _custom(), quantity: 2, unit: 'serving');
      final b = RecipeIngredient(
        food: _custom(id: 'c2', unknown: {FoodItem.calorieKey}),
        quantity: 1,
        unit: 'serving',
      );
      final r = _meal([a, b], servings: 2);
      expect(r.perServing.calories, 300); // 600 known / 2
      expect(r.perServing.partial, isTrue);
      final onlyUnknown = _meal([b]);
      expect(onlyUnknown.perServing.calories, isNull);
    });

    test('scaling a serving changes the totals proportionally', () {
      final one = _meal([
        RecipeIngredient(food: _custom(), quantity: 1, unit: 'serving'),
      ]);
      final three = _meal([
        RecipeIngredient(food: _custom(), quantity: 3, unit: 'serving'),
      ]);
      expect(three.perServing.calories, one.perServing.calories! * 3);
    });

    test('invalid manual foods are refused', () {
      expect(
        FoodValidationService.validateCustomFood(_custom(kcal: -5)).isValid,
        isFalse,
      );
      expect(
        FoodValidationService.validateCustomFood(_custom(fiber: -1)).isValid,
        isFalse,
      );
      expect(
        FoodValidationService.validateCustomFood(_custom()).isValid,
        isTrue,
      );
    });

    test('store: save replaces, duplicate copies, delete removes', () async {
      final store = CustomMealStore();
      var m = store
          .blank('Bowl')
          .copyWith(
            ingredients: [
              RecipeIngredient(food: _custom(), quantity: 1, unit: 'serving'),
            ],
            servings: 2,
          );
      m = await store.save(m);
      await store.save(m.copyWith(name: 'Big bowl'));
      expect(store.all().length, 1);
      final copy = await store.duplicate(m.id);
      expect(copy.name, 'Big bowl (copy)');
      expect(copy.id, isNot(m.id));
      expect(store.all().length, 2);
      await store.delete(m.id);
      expect(store.all().single.id, copy.id);
      // The saved form round-trips with its unknown values intact.
      final back = store.all().single;
      expect(back.ingredients.single.food.isCustom, isTrue);
      expect(back.perServing.calories, 150);
    });

    test(
      'Showcase keeps its own meals, saved list and nothing leaks',
      () async {
        final store = CustomMealStore();
        await store.save(store.blank('Real meal'));
        await SavedRecipesStore().toggle('atlas_banana_oats');
        await LocalStorage.setShowcaseModeEnabled(true);
        addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
        expect(store.all(), isEmpty);
        expect(SavedRecipesStore().ids(), isEmpty);
        await store.save(store.blank('Demo meal'));
        expect(
          LocalStorage.getString(CustomMealStore.realKey),
          contains('Real meal'),
        );
        expect(
          LocalStorage.getString(CustomMealStore.realKey),
          isNot(contains('Demo meal')),
        );
      },
    );

    test('saved recipes toggle on and off', () async {
      final s = SavedRecipesStore();
      expect(await s.toggle('a'), isTrue);
      expect(s.isSaved('a'), isTrue);
      expect(await s.toggle('a'), isFalse);
      expect(s.isSaved('a'), isFalse);
    });
  });

  group('logging to the food diary', () {
    late NutritionService nutrition;
    late Recipe recipe;
    final day = DateTime(2026, 11, 17, 9);

    int diary() => nutrition.getTodayNutrition().meals.fold<int>(
      0,
      (n, m) => n + m.consumedFoods.length,
    );

    setUp(() {
      nutrition = NutritionService();
      recipe = RecipeCatalog.atlas(
        foods,
      ).firstWhere((r) => r.id == 'atlas_banana_shake');
    });

    test(
      'adds one entry per ingredient and a second tap adds nothing',
      () async {
        final logger = MealLogger(clock: () => day);
        final before = diary();
        final first = await logger.log(
          recipe,
          1,
          MealCategory.snack,
          nutrition,
        );
        expect(first.added, recipe.ingredients.length);
        expect(diary(), before + recipe.ingredients.length);
        final again = await logger.log(
          recipe,
          1,
          MealCategory.snack,
          nutrition,
        );
        expect(again.alreadyLogged, isTrue);
        expect(diary(), before + recipe.ingredients.length);
        final forced = await logger.log(
          recipe,
          1,
          MealCategory.snack,
          nutrition,
          force: true,
        );
        expect(forced.added, recipe.ingredients.length);
        expect(diary(), before + 2 * recipe.ingredients.length);
      },
    );

    test('two taps at the same instant add the meal once', () async {
      final logger = MealLogger(clock: () => day);
      final before = diary();
      final results = await Future.wait([
        logger.log(recipe, 1, MealCategory.lunch, nutrition),
        logger.log(recipe, 1, MealCategory.lunch, nutrition),
      ]);
      expect(results.where((r) => r.added > 0).length, 1);
      expect(diary(), before + recipe.ingredients.length);
    });

    test(
      'servings scale the logged amounts and the saved recipe is unchanged',
      () async {
        final logger = MealLogger(clock: () => day);
        final milk = recipe.ingredients.firstWhere(
          (i) => i.food.name == 'Whole Milk',
        );
        expect(milk.quantity, 300);
        await logger.log(recipe, 2, MealCategory.snack, nutrition);
        final logged = nutrition
            .getTodayNutrition()
            .meals
            .expand((m) => m.consumedFoods)
            .where((c) => c.food.name == 'Whole Milk')
            .toList();
        expect(logged.any((c) => c.quantity == 600), isTrue);
        // Removing it from the diary does not touch the recipe.
        for (final m in nutrition.getTodayNutrition().meals) {
          if (m.consumedFoods.any((c) => c.food.name == 'Whole Milk')) {
            await nutrition.removeFoodFromMeal(m.id, milk.food.id);
          }
        }
        expect(
          recipe.ingredients
              .firstWhere((i) => i.food.name == 'Whole Milk')
              .quantity,
          300,
        );
        expect(recipe.perServing.calories, isNotNull);
      },
    );

    test('invalid servings are refused', () async {
      final logger = MealLogger(clock: () => day);
      expect(
        () => logger.log(recipe, 0, MealCategory.lunch, nutrition),
        throwsArgumentError,
      );
    });

    test('adding to a plan keeps scaled portions and grows the days', () async {
      final store = MealPrepStore();
      final planner = RecipePlanner(store: store);
      final plan = await planner.add(
        recipe,
        2,
        newName: 'Week',
        day: 2,
        slot: MealCategory.snack,
      );
      expect(plan.days, 3);
      expect(plan.itemsFor(2).length, recipe.ingredients.length);
      final milk = plan
          .itemsFor(2)
          .firstWhere((i) => i.food.name == 'Whole Milk');
      expect(milk.quantity, 600);
      final more = await planner.add(
        recipe,
        1,
        plan: plan,
        day: 0,
        slot: MealCategory.breakfast,
      );
      expect(store.all().length, 1);
      expect(more.items.length, recipe.ingredients.length * 2);
      expect({for (final i in more.items) i.id}.length, more.items.length);
    });
  });
}
