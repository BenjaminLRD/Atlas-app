import 'dart:convert';

import 'consumed_food.dart';
import 'food_item.dart';
import 'meal_entry.dart';

/// How a food can be portioned in a meal prep. The unit follows what the
/// food's numbers are measured per: grams and millilitres are never mixed,
/// and a food whose basis is unknown cannot be given a calculated portion.
class PortionUnit {
  final String unit;
  final String label;
  final double step;
  final double defaultQuantity;
  final bool supported;

  const PortionUnit({
    required this.unit,
    required this.label,
    required this.step,
    required this.defaultQuantity,
    this.supported = true,
  });

  static PortionUnit forFood(FoodItem food) {
    switch (food.nutritionBasis) {
      case NutritionBasis.per100g:
        final sq = food.servingQuantity;
        final useServing =
            sq != null && sq > 0 && food.servingQuantityUnit == 'g';
        return PortionUnit(
          unit: 'grams',
          label: 'g',
          step: 10,
          defaultQuantity: useServing ? sq : 100,
        );
      case NutritionBasis.per100ml:
        final sq = food.servingQuantity;
        final useServing =
            sq != null && sq > 0 && food.servingQuantityUnit == 'ml';
        return PortionUnit(
          unit: 'ml',
          label: 'ml',
          step: 10,
          defaultQuantity: useServing ? sq : 100,
        );
      case NutritionBasis.perServing:
        return const PortionUnit(
          unit: 'serving',
          label: 'serving',
          step: 0.5,
          defaultQuantity: 1,
        );
      case NutritionBasis.perPackage:
        return const PortionUnit(
          unit: 'package',
          label: 'package',
          step: 0.5,
          defaultQuantity: 1,
        );
      case NutritionBasis.unknown:
        // A built-in or custom food's numbers are for the serving it lists
        // ("1 bowl", "50 g"), so a portion is a number of those servings.
        // Any other food with an unknown basis (an older scanned product)
        // cannot be portioned: nothing is assumed.
        final listed =
            food.isCustom ||
            (food.nutritionSource == NutritionSource.builtIn &&
                food.barcode == null);
        return PortionUnit(
          unit: 'serving',
          label: listed && food.servingSize.trim().isNotEmpty
              ? 'x ${food.servingSize.trim()}'
              : 'serving',
          step: 0.5,
          defaultQuantity: 1,
          supported: listed,
        );
    }
  }
}

/// One food in a meal prep: a snapshot of the food, how much of it, and where
/// in the plan it goes. The snapshot means later edits to the food list never
/// change a saved plan, and saving a plan never creates a food record.
class MealPrepItem {
  final String id;
  final FoodItem food;
  final double quantity;
  final String unit;
  final MealCategory meal;

  /// 0 for Day 1.
  final int day;

  const MealPrepItem({
    required this.id,
    required this.food,
    required this.quantity,
    required this.unit,
    required this.meal,
    this.day = 0,
  });

  ConsumedFood get consumed =>
      ConsumedFood(food: food, quantity: quantity, unit: unit);

  /// Whether this portion has a trustworthy value for [nutrient]. A food whose
  /// basis is unknown never does: its portion cannot be calculated.
  bool isKnown(String nutrient) =>
      PortionUnit.forFood(food).supported && food.isNutrientKnown(nutrient);

  double? valueOf(String nutrient) {
    if (!isKnown(nutrient)) return null;
    final c = consumed;
    return switch (nutrient) {
      FoodItem.calorieKey => c.calories,
      FoodItem.proteinKey => c.protein,
      FoodItem.carbohydrateKey => c.carbohydrates,
      FoodItem.fatKey => c.fats,
      _ => null,
    };
  }

  /// Where the food's numbers come from, in words.
  String get sourceLabel => switch (food.nutritionSource) {
    NutritionSource.builtIn => 'Typical values',
    NutritionSource.openFoodFacts => 'Open Food Facts',
    NutritionSource.aiEstimate => 'AI estimate',
    NutritionSource.userEntry => 'Entered by you',
    NutritionSource.unknown => 'Source not recorded',
  };

  /// True when the numbers are an estimate rather than a product record or the
  /// athlete's own entry.
  bool get isEstimate =>
      food.nutritionSource == NutritionSource.builtIn ||
      food.nutritionSource == NutritionSource.aiEstimate ||
      food.nutritionSource == NutritionSource.unknown;

  MealPrepItem copyWith({double? quantity, MealCategory? meal, int? day}) =>
      MealPrepItem(
        id: id,
        food: food,
        quantity: quantity ?? this.quantity,
        unit: unit,
        meal: meal ?? this.meal,
        day: day ?? this.day,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'food': food.toJson(),
    'q': quantity,
    'u': unit,
    'meal': meal.name,
    'day': day,
  };

  static MealPrepItem? tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final id = raw['id'];
      if (id is! String || raw['food'] is! Map) return null;
      final q = raw['q'];
      if (q is! num || q <= 0) return null;
      return MealPrepItem(
        id: id,
        food: FoodItem.fromJson(Map<String, dynamic>.from(raw['food'] as Map)),
        quantity: q.toDouble(),
        unit: raw['u'] is String ? raw['u'] as String : 'grams',
        meal: MealCategory.fromJson('${raw['meal']}'),
        day: raw['day'] is num ? (raw['day'] as num).toInt().clamp(0, 6) : 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// One nutrient across several items. [total] is the sum of the items that
/// have a value, or null when none does: unknown is never added as zero.
class NutrientTotal {
  final double? total;

  /// How many items had no value for this nutrient.
  final int missing;
  final int count;

  const NutrientTotal(this.total, this.missing, this.count);

  bool get known => total != null;

  /// Some items are counted, some are not.
  bool get partial => known && missing > 0;
}

/// The four core nutrients across a set of items.
class NutritionTotals {
  final NutrientTotal calories;
  final NutrientTotal protein;
  final NutrientTotal carbs;
  final NutrientTotal fat;
  final int itemCount;
  final bool hasEstimates;

  const NutritionTotals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.itemCount,
    required this.hasEstimates,
  });

  static NutrientTotal _sum(Iterable<MealPrepItem> items, String key) {
    double sum = 0;
    var known = 0;
    var missing = 0;
    for (final i in items) {
      final v = i.valueOf(key);
      if (v == null) {
        missing++;
      } else {
        known++;
        sum += v;
      }
    }
    return NutrientTotal(known == 0 ? null : sum, missing, known + missing);
  }

  factory NutritionTotals.of(Iterable<MealPrepItem> items) {
    final list = items.toList();
    return NutritionTotals(
      calories: _sum(list, FoodItem.calorieKey),
      protein: _sum(list, FoodItem.proteinKey),
      carbs: _sum(list, FoodItem.carbohydrateKey),
      fat: _sum(list, FoodItem.fatKey),
      itemCount: list.length,
      hasEstimates: list.any((i) => i.isEstimate),
    );
  }

  bool get isEmpty => itemCount == 0;
  bool get anyPartial =>
      calories.partial || protein.partial || carbs.partial || fat.partial;
}

/// A meal prep plan: foods organised by day and meal type, with totals.
class MealPrep {
  final String id;
  final String name;

  /// Number of days the plan covers, 1 to [maxDays].
  final int days;
  final List<MealPrepItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Item id to the date (yyyy-MM-dd) it was last logged to the food diary,
  /// so logging the same day twice never doubles the diary.
  final Map<String, String> loggedOn;

  const MealPrep({
    required this.id,
    required this.name,
    required this.days,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.loggedOn = const {},
  });

  static const int maxDays = 7;
  static const int maxNameLength = 40;
  static const int maxItems = 80;

  List<MealPrepItem> itemsFor(int day, [MealCategory? meal]) => [
    for (final i in items)
      if (i.day == day && (meal == null || i.meal == meal)) i,
  ];

  NutritionTotals totalsForDay(int day) => NutritionTotals.of(itemsFor(day));
  NutritionTotals totalsForMeal(int day, MealCategory meal) =>
      NutritionTotals.of(itemsFor(day, meal));
  NutritionTotals get totals => NutritionTotals.of(items);

  /// The highest day (0-based) that has a food in it, or -1.
  int get lastUsedDay => items.isEmpty
      ? -1
      : items.map((i) => i.day).reduce((a, b) => a > b ? a : b);

  MealPrep copyWith({
    String? name,
    int? days,
    List<MealPrepItem>? items,
    DateTime? updatedAt,
    Map<String, String>? loggedOn,
  }) => MealPrep(
    id: id,
    name: name ?? this.name,
    days: days ?? this.days,
    items: items ?? this.items,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    loggedOn: loggedOn ?? this.loggedOn,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'days': days,
    'items': [for (final i in items) i.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'loggedOn': loggedOn,
  };

  static MealPrep? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String) return null;
    final days = raw['days'] is num
        ? (raw['days'] as num).toInt().clamp(1, maxDays)
        : 1;
    final list = raw['items'];
    final now = DateTime.now();
    final logged = <String, String>{};
    if (raw['loggedOn'] is Map) {
      for (final e in (raw['loggedOn'] as Map).entries) {
        if (e.key is String && e.value is String) {
          logged[e.key as String] = e.value as String;
        }
      }
    }
    return MealPrep(
      id: id,
      name: name,
      days: days,
      items: [
        if (list is List)
          for (final e in list) ?MealPrepItem.tryParse(e),
      ],
      createdAt: DateTime.tryParse('${raw['createdAt']}') ?? now,
      updatedAt: DateTime.tryParse('${raw['updatedAt']}') ?? now,
      loggedOn: logged,
    );
  }

  static String encodeAll(List<MealPrep> all) =>
      jsonEncode([for (final p in all) p.toJson()]);

  static List<MealPrep> decodeAll(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [for (final e in list) ?tryParse(e)];
    } catch (_) {
      return [];
    }
  }
}
