import 'dart:convert';

import 'food_item.dart';
import 'meal_entry.dart';
import 'meal_prep.dart';

/// Where a recipe comes from.
enum RecipeOrigin {
  /// Written by Atlas from its own food list. No user is credited.
  atlas,

  /// Shared by another Atlas user. Real ones need the community backend; in
  /// Showcase Mode these are clearly marked sample recipes.
  community,

  /// Built by the athlete and kept on this device.
  custom,
}

/// Browse categories. "High protein" is worked out from the recipe's numbers,
/// not stored.
enum RecipeCategory {
  breakfast,
  lunch,
  dinner,
  snack;

  String get label => switch (this) {
    RecipeCategory.breakfast => 'Breakfast',
    RecipeCategory.lunch => 'Lunch',
    RecipeCategory.dinner => 'Dinner',
    RecipeCategory.snack => 'Snacks',
  };

  MealCategory get slot => switch (this) {
    RecipeCategory.breakfast => MealCategory.breakfast,
    RecipeCategory.lunch => MealCategory.lunch,
    RecipeCategory.dinner => MealCategory.dinner,
    RecipeCategory.snack => MealCategory.snack,
  };
}

/// One ingredient: a snapshot of the food and how much of it the recipe uses
/// in total (for all of the recipe's servings).
class RecipeIngredient {
  final FoodItem food;
  final double quantity;
  final String unit;

  const RecipeIngredient({
    required this.food,
    required this.quantity,
    required this.unit,
  });

  PortionUnit get portion => PortionUnit.forFood(food);

  /// The ingredient as a portion, optionally scaled (for example by
  /// servings eaten / servings in the recipe).
  MealPrepItem toItem({
    String id = 'ing',
    double factor = 1,
    MealCategory meal = MealCategory.lunch,
    int day = 0,
  }) => MealPrepItem(
    id: id,
    food: food,
    quantity: quantity * factor,
    unit: unit,
    meal: meal,
    day: day,
  );

  /// "150 g Chicken Breast" or "1.5 x 1 bowl Dal Tadka".
  String text({double factor = 1}) {
    final q = quantity * factor;
    final n = q == q.roundToDouble()
        ? q.round().toString()
        : q.toStringAsFixed(1);
    final p = portion;
    return '$n ${p.label} ${food.name}';
  }

  Map<String, dynamic> toJson() => {
    'food': food.toJson(),
    'q': quantity,
    'u': unit,
  };

  static RecipeIngredient? tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final q = raw['q'];
      if (raw['food'] is! Map || q is! num || q <= 0) return null;
      return RecipeIngredient(
        food: FoodItem.fromJson(Map<String, dynamic>.from(raw['food'] as Map)),
        quantity: q.toDouble(),
        unit: raw['u'] is String ? raw['u'] as String : 'serving',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Nutrition for one serving. A null value is unknown, never zero.
class RecipeNutrition {
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  /// Some ingredients have no value for at least one nutrient and are not
  /// counted in it.
  final bool partial;

  /// The numbers include typical or estimated values.
  final bool estimates;

  const RecipeNutrition({
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.partial = false,
    this.estimates = false,
  });
}

/// A recipe or a custom meal.
class Recipe {
  final String id;
  final String name;
  final String description;
  final RecipeOrigin origin;

  /// Shown for community recipes; null for Atlas and custom ones.
  final String? creatorName;
  final String? creatorAvatar;

  /// True for demonstration recipes in Showcase Mode.
  final bool isSample;
  final Set<RecipeCategory> categories;
  final int prepMinutes;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;

  /// A bundled photo, or null.
  final String? imageAsset;

  /// A photo the athlete added, a path on the phone, or null.
  final String? imageFile;

  /// Attribution for [imageAsset].
  final String? imageCredit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Recipe({
    required this.id,
    required this.name,
    this.description = '',
    required this.origin,
    this.creatorName,
    this.creatorAvatar,
    this.isSample = false,
    this.categories = const {},
    this.prepMinutes = 15,
    this.servings = 1,
    this.ingredients = const [],
    this.steps = const [],
    this.imageAsset,
    this.imageFile,
    this.imageCredit,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int maxServings = 20;
  static const int maxIngredients = 40;
  static const int maxNameLength = 60;

  NutritionTotals get totals => NutritionTotals.of([
    for (var i = 0; i < ingredients.length; i++)
      ingredients[i].toItem(id: 'i$i'),
  ]);

  /// Per serving: the sum of the known ingredient values divided by the
  /// servings. Unknown stays unknown.
  RecipeNutrition get perServing {
    final t = totals;
    double? per(NutrientTotal n) =>
        n.total == null ? null : n.total! / servings;
    return RecipeNutrition(
      calories: per(t.calories),
      protein: per(t.protein),
      carbs: per(t.carbs),
      fat: per(t.fat),
      partial: t.anyPartial,
      estimates: t.hasEstimates,
    );
  }

  /// 25 g of protein or more per serving, when protein is known.
  bool get isHighProtein => (perServing.protein ?? 0) >= 25;

  bool get hasPhoto => imageAsset != null || imageFile != null;

  Recipe copyWith({
    String? name,
    String? description,
    Set<RecipeCategory>? categories,
    int? prepMinutes,
    int? servings,
    List<RecipeIngredient>? ingredients,
    List<String>? steps,
    String? imageFile,
    bool clearImage = false,
    DateTime? updatedAt,
  }) => Recipe(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    origin: origin,
    creatorName: creatorName,
    creatorAvatar: creatorAvatar,
    isSample: isSample,
    categories: categories ?? this.categories,
    prepMinutes: prepMinutes ?? this.prepMinutes,
    servings: servings ?? this.servings,
    ingredients: ingredients ?? this.ingredients,
    steps: steps ?? this.steps,
    imageAsset: imageAsset,
    imageFile: clearImage ? null : (imageFile ?? this.imageFile),
    imageCredit: imageCredit,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'categories': [for (final c in categories) c.name],
    'prep': prepMinutes,
    'servings': servings,
    'ingredients': [for (final i in ingredients) i.toJson()],
    'steps': steps,
    if (imageFile != null) 'imageFile': imageFile,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// A custom meal from its saved form.
  static Recipe? tryParseCustom(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String) return null;
    final now = DateTime.now();
    final cats = <RecipeCategory>{};
    if (raw['categories'] is List) {
      for (final c in raw['categories'] as List) {
        for (final v in RecipeCategory.values) {
          if (v.name == c) cats.add(v);
        }
      }
    }
    return Recipe(
      id: id,
      name: name,
      description: raw['description'] is String
          ? raw['description'] as String
          : '',
      origin: RecipeOrigin.custom,
      categories: cats,
      prepMinutes: raw['prep'] is num
          ? (raw['prep'] as num).toInt().clamp(0, 1440)
          : 15,
      servings: raw['servings'] is num
          ? (raw['servings'] as num).toInt().clamp(1, maxServings)
          : 1,
      ingredients: [
        if (raw['ingredients'] is List)
          for (final e in raw['ingredients'] as List)
            ?RecipeIngredient.tryParse(e),
      ],
      steps: [
        if (raw['steps'] is List)
          for (final s in raw['steps'] as List)
            if (s is String && s.trim().isNotEmpty) s,
      ],
      imageFile: raw['imageFile'] is String ? raw['imageFile'] as String : null,
      createdAt: DateTime.tryParse('${raw['createdAt']}') ?? now,
      updatedAt: DateTime.tryParse('${raw['updatedAt']}') ?? now,
    );
  }

  static String encodeAll(List<Recipe> all) =>
      jsonEncode([for (final r in all) r.toJson()]);

  static List<Recipe> decodeAllCustom(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [for (final e in list) ?tryParseCustom(e)];
    } catch (_) {
      return [];
    }
  }
}
