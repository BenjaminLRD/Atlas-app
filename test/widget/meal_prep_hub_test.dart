import 'dart:io';

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/recipe.dart';
import 'package:atlas/screens/custom_meal_editor_screen.dart';
import 'package:atlas/screens/meal_prep_hub_screen.dart';
import 'package:atlas/services/meal_prep_store.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:atlas/services/recipes/recipe_stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  double width = 390,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1400),
          textScaler: TextScaler.linear(scale),
        ),
        child: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Brings a (possibly not yet built) item on a lazy list into view.
Future<void> _reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    final sc = find.byType(Scrollable).first;
    // Items above the viewport are not built: go back to the top first.
    await tester.drag(sc, const Offset(0, 6000));
    await tester.pump();
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 300, scrollable: sc);
    }
  }
  await tester.ensureVisible(f);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await _reveal(tester, f);
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // Sheets and routes finish sliding in.
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NutritionService nutrition;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    nutrition = NutritionService();
  });

  Future<void> openHub(WidgetTester tester, {double w = 390, double s = 1}) =>
      _pump(
        tester,
        MealPrepHubScreen(nutrition: nutrition),
        width: w,
        scale: s,
      );

  int diary() => nutrition.getTodayNutrition().meals.fold<int>(
    0,
    (n, m) => n + m.consumedFoods.length,
  );

  group('discovery', () {
    testWidgets(
      'shows Atlas recipes with photos, nutrition and no fake ratings',
      (tester) async {
        await openHub(tester);
        expect(find.text('Atlas recipes'), findsOneWidget);
        expect(find.byKey(const Key('card_atlas_banana_oats')), findsOneWidget);
        expect(find.text('Banana oat bowl'), findsOneWidget);
        expect(find.byType(Image), findsWidgets);
        expect(find.textContaining('kcal'), findsWidgets);
        // Nothing is rated: "no ratings" rather than a zero.
        final t = tester.widget<Text>(
          find.byKey(const Key('rating_atlas_banana_oats')),
        );
        expect(t.data, 'No ratings yet');
        expect(find.text('SAMPLE'), findsNothing);
      },
    );

    testWidgets('real community recipes are not faked', (tester) async {
      await openHub(tester);
      await _reveal(tester, find.byKey(const Key('community_unavailable')));
      expect(find.byKey(const Key('community_unavailable')), findsOneWidget);
      expect(find.textContaining('Sample'), findsNothing);
    });

    testWidgets('search narrows by name or ingredient', (tester) async {
      await openHub(tester);
      await tester.enterText(find.byKey(const Key('recipe_search')), 'chicken');
      await tester.pump();
      expect(
        find.byKey(const Key('card_atlas_chicken_prep_box')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('card_atlas_banana_oats')), findsNothing);
      await tester.enterText(find.byKey(const Key('recipe_search')), 'zzzz');
      await tester.pump();
      expect(find.byKey(const Key('no_results')), findsOneWidget);
    });

    testWidgets('category and high-protein filters work', (tester) async {
      await openHub(tester);
      await _tap(tester, find.byKey(const Key('filter_breakfast')));
      expect(find.byKey(const Key('card_atlas_banana_oats')), findsOneWidget);
      expect(
        find.byKey(const Key('card_atlas_chicken_prep_box')),
        findsNothing,
      );
      await _tap(tester, find.byKey(const Key('filter_highProtein')));
      expect(
        find.byKey(const Key('card_atlas_chicken_prep_box')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('card_atlas_banana_oats')), findsNothing);
    });

    testWidgets('sorting changes the order and the label', (tester) async {
      await openHub(tester);
      await _tap(tester, find.byKey(const Key('filter_snack')));
      await _tap(tester, find.byKey(const Key('filter_all')));
      await _tap(tester, find.byKey(const Key('sort_menu')));
      await tester.tap(find.text('Quickest').last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<Text>(find.byKey(const Key('sort_label'))).data,
        'Sort: Quickest',
      );
      final first = tester
          .getTopLeft(find.byKey(const Key('card_atlas_banana_shake')))
          .dy;
      final other = tester
          .getTopLeft(find.byKey(const Key('card_atlas_dal_rice')))
          .dy;
      expect(first, lessThan(other)); // 5 min before 30 min
    });

    testWidgets('saving a recipe keeps it under Saved', (tester) async {
      await openHub(tester);
      await _tap(tester, find.byKey(const Key('save_atlas_banana_oats')));
      expect(SavedRecipesStore().isSaved('atlas_banana_oats'), isTrue);
      await _tap(tester, find.byKey(const Key('filter_saved')));
      expect(find.byKey(const Key('card_atlas_banana_oats')), findsOneWidget);
      expect(find.byKey(const Key('card_atlas_dal_rice')), findsNothing);
    });

    for (final w in const [320.0, 360.0]) {
      testWidgets(
        'no overflow at ${w.toInt()}dp, text x1.5 (real and Showcase)',
        (tester) async {
          await openHub(tester, w: w, s: 1.5);
          expect(tester.takeException(), isNull);
          await LocalStorage.setShowcaseModeEnabled(true);
          addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
          await openHub(tester, w: w, s: 1.5);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Showcase community recipes', () {
    setUp(() async => LocalStorage.setShowcaseModeEnabled(true));
    tearDown(() async => LocalStorage.setShowcaseModeEnabled(false));

    testWidgets('are populated, credited and clearly marked as samples', (
      tester,
    ) async {
      await openHub(tester);
      await _reveal(
        tester,
        find.byKey(const Key('card_sample_recipe_tuna_box')),
      );
      expect(find.text('Tuna sweetcorn box'), findsOneWidget);
      expect(
        find.byKey(const Key('sample_badge_sample_recipe_tuna_box')),
        findsOneWidget,
      );
      expect(find.text('Daniel Kim'), findsWidgets);
      await _reveal(
        tester,
        find.byKey(const Key('rating_sample_recipe_tuna_box')),
      );
      final label = tester
          .widget<Text>(find.byKey(const Key('rating_sample_recipe_tuna_box')))
          .data!;
      expect(label, matches(RegExp(r'^\d\.\d \(\d+\)$')));
      // Atlas recipes in Showcase are still unrated.
      await _reveal(tester, find.byKey(const Key('rating_atlas_dal_rice')));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('rating_atlas_dal_rice')))
            .data,
        'No ratings yet',
      );
    });

    testWidgets('rating one updates once and never touches real ratings', (
      tester,
    ) async {
      await openHub(tester);
      await _tap(tester, find.byKey(const Key('card_sample_recipe_dal_bhat')));
      expect(find.byKey(const Key('creator_name')), findsOneWidget);
      expect(find.byKey(const Key('detail_sample_badge')), findsOneWidget);
      final before = tester
          .widget<Text>(find.byKey(const Key('detail_rating')))
          .data!;
      expect(before, contains('2 ratings'));

      Future<void> rate(int stars, String review) async {
        await _tap(tester, find.byKey(const Key('rate_button')));
        await tester.tap(find.byKey(Key('star_$stars')));
        await tester.pump();
        await tester.enterText(find.byKey(const Key('review_field')), review);
        await tester.tap(find.byKey(const Key('submit_rating')));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 1));
      }

      await rate(5, 'Lovely');
      expect(
        tester.widget<Text>(find.byKey(const Key('detail_rating'))).data,
        contains('3 ratings'),
      );
      await rate(2, 'Changed my mind');
      final after = tester
          .widget<Text>(find.byKey(const Key('detail_rating')))
          .data!;
      expect(after, contains('3 ratings')); // updated, not added
      expect(find.text('Changed my mind'), findsOneWidget);
      expect(find.text('Lovely'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where(
          (k) => k.contains('rating') && !k.contains('showcase'),
        ),
        isEmpty,
      );
    });

    testWidgets('logging is off so demo meals never touch the real diary', (
      tester,
    ) async {
      await openHub(tester);
      final before = diary();
      await _tap(tester, find.byKey(const Key('card_atlas_banana_shake')));
      await _tap(tester, find.byKey(const Key('log_to_diary')));
      expect(find.textContaining('Showcase'), findsOneWidget);
      expect(diary(), before);
    });
  });

  group('recipe details', () {
    testWidgets('show ingredients, steps, nutrition, source and credit; '
        'servings scale the amounts', (tester) async {
      await openHub(tester);
      await _tap(tester, find.byKey(const Key('card_atlas_banana_shake')));
      expect(
        tester.widget<Text>(find.byKey(const Key('recipe_title'))).data,
        'Whey banana shake',
      );
      expect(find.text('By Atlas'), findsOneWidget);
      expect(find.byKey(const Key('nutrition_card')), findsOneWidget);
      expect(find.textContaining('300 ml Whole Milk'), findsOneWidget);
      expect(find.textContaining('Add the milk'), findsOneWidget);
      expect(find.byKey(const Key('nutrition_source')), findsOneWidget);
      await _reveal(tester, find.byKey(const Key('image_credit')));
      expect(find.byKey(const Key('image_credit')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('servings_plus')));
      expect(find.textContaining('600 ml Whole Milk'), findsOneWidget);
      expect(find.byKey(const Key('detail_rating')), findsOneWidget);
    });

    testWidgets('real mode explains that ratings are not available', (
      tester,
    ) async {
      await openHub(tester);
      await _tap(tester, find.byKey(const Key('card_atlas_banana_shake')));
      await _reveal(tester, find.byKey(const Key('ratings_unavailable')));
      expect(find.byKey(const Key('ratings_unavailable')), findsOneWidget);
      await _tap(tester, find.byKey(const Key('rate_button')));
      expect(find.byKey(const Key('submit_rating')), findsNothing);
    });

    testWidgets('log to diary: slot, servings, once, and not twice', (
      tester,
    ) async {
      await openHub(tester);
      await _tap(tester, find.byKey(const Key('card_atlas_banana_shake')));
      final before = diary();
      await _tap(tester, find.byKey(const Key('log_to_diary')));
      expect(find.byKey(const Key('sheet_nutrition')), findsOneWidget);
      await tester.tap(find.byKey(const Key('slot_snack')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet_plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet_confirm')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(diary(), before + 3);
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).clearSnackBars();
      await tester.pump(const Duration(seconds: 1));

      await _tap(tester, find.byKey(const Key('log_to_diary')));
      await tester.tap(find.byKey(const Key('slot_snack')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sheet_confirm')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(diary(), before + 3);
      expect(find.textContaining('already in'), findsOneWidget);
    });

    testWidgets('add to plan creates a plan with the scaled foods', (
      tester,
    ) async {
      await openHub(tester);
      await _tap(tester, find.byKey(const Key('card_atlas_dal_rice')));
      await _tap(tester, find.byKey(const Key('add_to_plan')));
      await tester.tap(find.byKey(const Key('plan_confirm')));
      await tester.pump(const Duration(milliseconds: 600));
      final plans = MealPrepStore().all();
      expect(plans.length, 1);
      expect(plans.single.items.length, 3);
    });
  });

  group('custom meals', () {
    Directory? photoDir;

    Future<void> openEditor(
      WidgetTester tester, {
      Future<String?> Function()? photo,
    }) => _pump(
      tester,
      CustomMealEditorScreen(
        nutrition: nutrition,
        pickPhoto: photo,
        photoBaseDir: photoDir,
      ),
    );

    Future<void> addFood(WidgetTester tester, String name) async {
      final food = nutrition.getAvailableFoods().firstWhere(
        (f) => f.name == name,
      );
      await tester.tap(find.byKey(Key('pick_food_${food.id}')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('food_picker_add')));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('validation names what is missing without a dialog', (
      tester,
    ) async {
      await openEditor(tester);
      await _tap(tester, find.byKey(const Key('save_meal')));
      expect(find.text('Give your meal a name.'), findsOneWidget);
      expect(find.text('Add at least one ingredient to save.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(CustomMealStore().all(), isEmpty);
    });

    testWidgets('build a meal: pick foods, adjust portions, see the numbers, '
        'save', (tester) async {
      await openEditor(tester);
      await tester.enterText(
        find.byKey(const Key('meal_name')),
        'Chicken rice',
      );
      await _tap(tester, find.byKey(const Key('add_ingredient_empty')));
      await tester.enterText(
        find.byKey(const Key('food_search')),
        'Chicken Breast',
      );
      await tester.pump();
      await addFood(tester, 'Chicken Breast');
      final line = tester
          .widget<Text>(find.byKey(const Key('meal_per_serving')))
          .data!;
      expect(line, contains('165 kcal')); // 100 g, the default
      await _tap(tester, find.byKey(const Key('ing_plus_0')));
      expect(
        tester.widget<Text>(find.byKey(const Key('meal_per_serving'))).data,
        contains('182 kcal'),
      ); // 110 g
      await _tap(tester, find.byKey(const Key('servings_plus')));
      await _tap(tester, find.byKey(const Key('save_meal')));
      final saved = CustomMealStore().all().single;
      expect(saved.name, 'Chicken rice');
      expect(saved.servings, 2);
      expect(saved.perServing.calories, closeTo(165 * 1.1 / 2, 0.5));
    });

    testWidgets('a missing food can be added by hand and then used', (
      tester,
    ) async {
      await openEditor(tester);
      await tester.enterText(find.byKey(const Key('meal_name')), 'Wrap');
      await _tap(tester, find.byKey(const Key('add_ingredient_empty')));
      await tester.tap(find.byKey(const Key('add_custom_food')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('custom_food_basis_note')), findsOneWidget);
      Future<void> fill(String label, String v) async {
        final f = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(f);
        await tester.enterText(f, v);
      }

      await fill('Food Name *', 'Homemade wrap');
      await fill('Serving Size *', '150');
      await fill('Calories (kcal) *', '320');
      await fill('Protein (g) *', '20');
      await fill('Carbs (g) *', '30');
      await fill('Fat (g) *', '9');
      final save = find.text('SAVE FOOD');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(
        find.byKey(const Key('food_search')),
        'Homemade wrap',
      );
      await tester.pump();
      final id = nutrition
          .getAvailableFoods()
          .firstWhere((f) => f.name == 'Homemade wrap')
          .id;
      await tester.tap(find.byKey(Key('pick_food_$id')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('food_picker_add')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.textContaining('Entered by you', skipOffstage: false),
        findsWidgets,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('meal_per_serving'))).data,
        contains('320 kcal'),
      );
    });

    testWidgets('a photo is kept with the meal', (tester) async {
      final dir = Directory.systemTemp.createTempSync('atlas_meal_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/pic.jpg')..writeAsBytesSync([1, 2, 3]);
      photoDir = Directory('${dir.path}/app')..createSync();
      await openEditor(tester, photo: () async => file.path);
      await tester.enterText(find.byKey(const Key('meal_name')), 'Photo meal');
      await tester.tap(find.byKey(const Key('meal_photo')));
      // The copy into the app's storage is real file work: each step needs
      // the real event loop, so alternate real time and pumps.
      for (var k = 0; k < 12; k++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(photoDir!.listSync(recursive: true), isNotEmpty);
      expect(find.text('Change photo'), findsOneWidget);
    });

    testWidgets('hub: create, edit, duplicate and delete with undo', (
      tester,
    ) async {
      final store = CustomMealStore();
      final food = nutrition.getAvailableFoods().firstWhere(
        (f) => f.name == 'Chicken Breast',
      );
      var m = store
          .blank('Lunch box')
          .copyWith(
            ingredients: [
              RecipeIngredient(food: food, quantity: 150, unit: 'grams'),
            ],
          );
      m = await store.save(m);
      await openHub(tester);
      expect(find.text('Lunch box'), findsOneWidget);
      await _tap(tester, find.byKey(Key('dup_${m.id}')));
      expect(store.all().length, 2);
      expect(find.text('Lunch box (copy)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await _tap(tester, find.byKey(Key('del_${m.id}')));
      expect(store.all().length, 1);
      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.all().length, 2);
    });

    testWidgets('a custom meal can be logged and does not disturb the scanners'
        ' lookup', (tester) async {
      final store = CustomMealStore();
      final food = nutrition.getAvailableFoods().firstWhere(
        (f) => f.name == 'Chicken Breast',
      );
      final m = await store.save(
        store
            .blank('Plain chicken')
            .copyWith(
              ingredients: [
                RecipeIngredient(food: food, quantity: 200, unit: 'grams'),
              ],
            ),
      );
      final scannedBefore = nutrition.getScannedFoods().length;
      await openHub(tester);
      final before = diary();
      await _tap(tester, find.byKey(Key('card_${m.id}')));
      await _tap(tester, find.byKey(const Key('log_to_diary')));
      await tester.tap(find.byKey(const Key('sheet_confirm')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(diary(), before + 1);
      expect(nutrition.getScannedFoods().length, scannedBefore);
    });
  });
}
