import '../../models/food_item.dart';
import '../../models/meal_prep.dart';
import '../../models/recipe.dart';
import '../community/sample_world.dart';

/// The recipes Atlas ships.
///
/// * Atlas recipes: written by Atlas from its own food list (typical values,
///   so labelled as estimates). No user is credited and nothing is rated.
/// * Sample community recipes: demonstration content for Showcase Mode only.
///   They are credited to Atlas's sample athletes, marked SAMPLE in the app,
///   and never mixed with real community records.
///
/// Every photo is a bundled, openly licensed image (see
/// docs/SAMPLE_MEDIA_AUDIT.md) and each recipe has its own. Ingredient
/// quantities use each food's own portion unit; nutrition is always computed
/// from the ingredients, never typed in.
class RecipeCatalog {
  const RecipeCatalog._();

  static const String _photos = 'assets/community/photos/';

  static final DateTime _epoch = DateTime(2026, 11, 1);

  /// (food name, quantity, in the food's own portion unit)
  static RecipeIngredient? _ing(List<FoodItem> foods, String name, double qty) {
    for (final f in foods) {
      if (f.name == name) {
        final p = PortionUnit.forFood(f);
        if (!p.supported) return null;
        return RecipeIngredient(food: f, quantity: qty, unit: p.unit);
      }
    }
    return null;
  }

  static Recipe? _make(
    List<FoodItem> foods, {
    required String id,
    required String name,
    required String description,
    required RecipeOrigin origin,
    required Set<RecipeCategory> categories,
    required int prep,
    required int servings,
    required List<(String, double)> ingredients,
    required List<String> steps,
    required String image,
    required String credit,
    String? creatorKey,
    bool sample = false,
  }) {
    final list = <RecipeIngredient>[];
    for (final (n, q) in ingredients) {
      final i = _ing(foods, n, q);
      // A recipe is only offered when every ingredient resolves, so its
      // numbers are never silently incomplete.
      if (i == null) return null;
      list.add(i);
    }
    SampleAthlete? athlete;
    if (creatorKey != null) {
      for (final a in SampleWorld.athletes) {
        if (a.key == creatorKey) athlete = a;
      }
      if (athlete == null) return null;
    }
    return Recipe(
      id: id,
      name: name,
      description: description,
      origin: origin,
      creatorName: athlete?.name,
      creatorAvatar: athlete?.avatar,
      isSample: sample,
      categories: categories,
      prepMinutes: prep,
      servings: servings,
      ingredients: list,
      steps: steps,
      imageAsset: '$_photos$image',
      imageCredit: credit,
      createdAt: _epoch,
      updatedAt: _epoch,
    );
  }

  /// Atlas's own recipes.
  static List<Recipe> atlas(List<FoodItem> foods) => [
    ?_make(
      foods,
      id: 'atlas_banana_oats',
      name: 'Banana oat bowl',
      description:
          'Oats cooked in milk with sliced banana. Quick, filling and easy to repeat.',
      origin: RecipeOrigin.atlas,
      categories: {RecipeCategory.breakfast},
      prep: 8,
      servings: 1,
      ingredients: [
        ('Rolled Oats (Dry)', 1),
        ('Ripe Banana', 1),
        ('Whole Milk', 200),
      ],
      steps: [
        'Pour the oats and the milk into a small pan.',
        'Cook on medium heat for 4 to 5 minutes, stirring, until thick.',
        'Slice the banana over the top and serve warm.',
      ],
      image: 'sp_david_4.jpg',
      credit:
          '"Healthy Breakfast (Unsplash)" by Federica Diliberto federyka, CC0, via Wikimedia Commons',
    ),
    ?_make(
      foods,
      id: 'atlas_dal_rice',
      name: 'Dal and rice plate',
      description:
          'Yellow dal over rice with a cucumber side. A simple, cheap and balanced plate.',
      origin: RecipeOrigin.atlas,
      categories: {RecipeCategory.lunch, RecipeCategory.dinner},
      prep: 30,
      servings: 1,
      ingredients: [
        ('Dal Tadka (Yellow Dal)', 1),
        ('White Basmati Rice (Cooked)', 1),
        ('Fresh Cucumber (Kheera)', 80),
      ],
      steps: [
        'Warm the dal through in a pan.',
        'Plate the cooked rice and spoon the dal over it.',
        'Slice the cucumber and serve it on the side.',
      ],
      image: 'sp_zothanpuii_5.jpg',
      credit:
          '"Rice with Lentils" by Mrsagar105, CC BY-SA 4.0, via Wikimedia Commons',
    ),
    ?_make(
      foods,
      id: 'atlas_chicken_prep_box',
      name: 'Chicken and veg prep box',
      description:
          'Chicken breast, broccoli, carrots and rice, portioned for the fridge.',
      origin: RecipeOrigin.atlas,
      categories: {RecipeCategory.lunch},
      prep: 35,
      servings: 4,
      ingredients: [
        ('Chicken Breast', 600),
        ('Steamed Broccoli', 400),
        ('Raw Carrots (Gajar)', 300),
        ('White Basmati Rice (Cooked)', 4),
      ],
      steps: [
        'Cook the chicken until there is no pink in the middle, then slice it.',
        'Steam the broccoli and carrots until just tender.',
        'Divide the rice, chicken and vegetables into four boxes.',
        'Cool, close and refrigerate. Eat within three days.',
      ],
      image: 'sp_jenny_1_poster.jpg',
      credit:
          '"Fresh mixed salad and fridge-ready prep" by Umabruka, CC BY-SA 4.0, via Wikimedia Commons',
    ),
    ?_make(
      foods,
      id: 'atlas_banana_shake',
      name: 'Whey banana shake',
      description: 'A fast post-workout shake with whey, milk and a banana.',
      origin: RecipeOrigin.atlas,
      categories: {RecipeCategory.snack},
      prep: 5,
      servings: 1,
      ingredients: [
        ('Whey Protein Powder', 1),
        ('Whole Milk', 300),
        ('Ripe Banana', 1),
      ],
      steps: [
        'Add the milk, the whey and the peeled banana to a blender.',
        'Blend for 30 seconds and drink straight away.',
      ],
      image: 'sp_jenny_5.jpg',
      credit: '"Protein shake" by Sandstein, CC BY 3.0, via Wikimedia Commons',
    ),
  ];

  /// Sample community recipes for Showcase Mode only.
  static List<Recipe> sampleCommunity(List<FoodItem> foods) => [
    ?_make(
      foods,
      id: 'sample_recipe_tuna_box',
      name: 'Tuna sweetcorn box',
      description: 'Tuna, sweetcorn and crunchy veg. No cooking, packs well.',
      origin: RecipeOrigin.community,
      categories: {RecipeCategory.lunch, RecipeCategory.snack},
      prep: 10,
      servings: 1,
      ingredients: [
        ('Canned Tuna (in water)', 120),
        ('Sweet Corn Kernels', 60),
        ('Raw Carrots (Gajar)', 50),
        ('Fresh Cucumber (Kheera)', 60),
      ],
      steps: [
        'Drain the tuna.',
        'Chop the carrot and cucumber.',
        'Mix everything in a box and chill.',
      ],
      image: 'sp_daniel_4.jpg',
      credit:
          '"Tuna Salad with sweet corn" by Adesolive, CC0, via Wikimedia Commons',
      creatorKey: 'daniel',
      sample: true,
    ),
    ?_make(
      foods,
      id: 'sample_recipe_tofu_curry',
      name: 'Tofu and veg curry with rice',
      description: 'A student-budget dinner: tofu and vegetables over rice.',
      origin: RecipeOrigin.community,
      categories: {RecipeCategory.dinner},
      prep: 25,
      servings: 2,
      ingredients: [
        ('Tofu (Soy Curd)', 300),
        ('Yellow Onion', 80),
        ('Raw Spinach (Palak)', 100),
        ('White Basmati Rice (Cooked)', 2),
      ],
      steps: [
        'Fry the onion until soft, then add the cubed tofu and brown it.',
        'Add the spinach and a splash of water, and cook until wilted.',
        'Serve over the rice.',
      ],
      image: 'sp_liam_4.jpg',
      credit:
          '"Stir fried Vegetable Tofu broken with rice for dinner" by Pradeepraajkumar1981, CC BY-SA 4.0, via Wikimedia Commons',
      creatorKey: 'liam',
      sample: true,
    ),
    ?_make(
      foods,
      id: 'sample_recipe_chicken_broccoli_rice',
      name: 'Chicken, broccoli and rice',
      description: 'Match-day fuel: lean chicken, broccoli and plenty of rice.',
      origin: RecipeOrigin.community,
      categories: {RecipeCategory.lunch, RecipeCategory.dinner},
      prep: 25,
      servings: 1,
      ingredients: [
        ('Chicken Breast', 180),
        ('Steamed Broccoli', 120),
        ('White Basmati Rice (Cooked)', 1.5),
      ],
      steps: [
        'Cook the chicken in a pan until golden and cooked through.',
        'Steam the broccoli for 4 minutes.',
        'Serve with the rice.',
      ],
      image: 'sp_hminga_6_poster.jpg',
      credit:
          '"Cooking Chicken and Rice" by Alabama Extension, CC0, via Wikimedia Commons',
      creatorKey: 'hminga',
      sample: true,
    ),
    ?_make(
      foods,
      id: 'sample_recipe_tofu_spinach',
      name: 'Tofu and spinach stir-fry',
      description: 'Fried tofu with greens. Ready in 15 minutes.',
      origin: RecipeOrigin.community,
      categories: {RecipeCategory.lunch},
      prep: 15,
      servings: 1,
      ingredients: [
        ('Tofu (Soy Curd)', 200),
        ('Raw Spinach (Palak)', 150),
        ('Yellow Onion', 30),
      ],
      steps: [
        'Fry the tofu until golden.',
        'Add the onion, then the spinach.',
        'Cook for 2 minutes and serve.',
      ],
      image: 'sp_maya_4.jpg',
      credit:
          '"Stir-fry spinach with tofu" by NeoBatfreak, CC BY-SA 4.0, via Wikimedia Commons',
      creatorKey: 'maya',
      sample: true,
    ),
    ?_make(
      foods,
      id: 'sample_recipe_dal_bhat',
      name: 'Dal bhat plate',
      description:
          'Dal and rice with a carrot side, the way I eat on a heavy training day.',
      origin: RecipeOrigin.community,
      categories: {RecipeCategory.dinner},
      prep: 30,
      servings: 1,
      ingredients: [
        ('Dal Tadka (Yellow Dal)', 1.5),
        ('White Basmati Rice (Cooked)', 1.5),
        ('Raw Carrots (Gajar)', 80),
      ],
      steps: [
        'Heat the dal.',
        'Plate the rice.',
        'Add the dal and the sliced carrot.',
      ],
      image: 'sp_coach_zuala_6.jpg',
      credit:
          '"Nepali dal-bhat-tarkari" by Subhashish Panigrahi, CC BY-SA 4.0, via Wikimedia Commons',
      creatorKey: 'coach_zuala',
      sample: true,
    ),
    ?_make(
      foods,
      id: 'sample_recipe_milk_fruit',
      name: 'Milk and banana bowl',
      description: 'A light lunch for the park: cold milk and a banana.',
      origin: RecipeOrigin.community,
      categories: {RecipeCategory.snack, RecipeCategory.breakfast},
      prep: 3,
      servings: 1,
      ingredients: [('Whole Milk', 250), ('Ripe Banana', 1)],
      steps: ['Slice the banana into a bowl.', 'Pour over cold milk.'],
      image: 'sp_marcus_6.jpg',
      credit:
          '"Healthy Breakfast 1 (Unsplash)" by Carissa Gan carissagan, CC0, via Wikimedia Commons',
      creatorKey: 'marcus',
      sample: true,
    ),
  ];
}
