import 'consumed_food.dart';
import 'food_item.dart';

enum MealCategory {
  breakfast,
  lunch,
  dinner,
  snack;

  String toJson() => name;

  static MealCategory fromJson(String value) {
    return MealCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MealCategory.snack,
    );
  }
}

/// Alias for MealCategory matching required spec
typedef MealType = MealCategory;

/// Model representing a logged meal containing a list of consumed food items.
class MealEntry {
  final String id;
  final DateTime date;
  final MealCategory mealType;
  final List<ConsumedFood> consumedFoods;
  final bool completed;
  final String _customName;
  final String timeLabel;

  MealEntry({
    required this.id,
    DateTime? date,
    MealCategory? mealType,
    MealCategory? category,
    List<ConsumedFood>? consumedFoods,
    List<FoodItem>? items,
    List<FoodItem>? foods,
    bool? completed,
    bool? isCompleted,
    String name = '',
    this.timeLabel = '12:00 PM',
  })  : date = date ?? DateTime.now(),
        mealType = mealType ?? category ?? MealCategory.snack,
        consumedFoods = consumedFoods ??
            ((items ?? foods)
                    ?.map((f) => ConsumedFood(food: f, quantity: 100.0, unit: 'grams'))
                    .toList() ??
                const []),
        completed = completed ?? isCompleted ?? false,
        _customName = name;

  MealCategory get category => mealType;
  bool get isCompleted => completed;

  String get name {
    if (_customName.isNotEmpty) return _customName;
    switch (mealType) {
      case MealCategory.breakfast:
        return 'Breakfast';
      case MealCategory.lunch:
        return 'Lunch';
      case MealCategory.dinner:
        return 'Dinner';
      case MealCategory.snack:
        return 'Snack';
    }
  }

  /// List of raw FoodItems for backwards compatibility
  List<FoodItem> get foods => consumedFoods.map((cf) => cf.food).toList();
  List<FoodItem> get items => foods;

  double get totalCalories {
    return consumedFoods.fold(0.0, (sum, item) => sum + item.calories);
  }

  double get totalProtein {
    return consumedFoods.fold(0.0, (sum, item) => sum + item.protein);
  }

  double get totalCarbohydrates {
    return consumedFoods.fold(0.0, (sum, item) => sum + item.carbohydrates);
  }

  double get totalCarbs => totalCarbohydrates;

  double get totalFats {
    return consumedFoods.fold(0.0, (sum, item) => sum + item.fats);
  }

  double get totalFat => totalFats;

  String get macrosSummary {
    return 'P: ${totalProtein.toStringAsFixed(0)}g · C: ${totalCarbohydrates.toStringAsFixed(0)}g · F: ${totalFats.toStringAsFixed(0)}g';
  }

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    final rawConsumed = json['consumedFoods'] as List?;
    List<ConsumedFood> consumedList = [];

    if (rawConsumed != null) {
      consumedList = rawConsumed
          .map((e) => ConsumedFood.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      final rawItems = json['items'] as List?;
      if (rawItems != null) {
        consumedList = rawItems
            .map((e) => ConsumedFood(
                  food: FoodItem.fromJson(Map<String, dynamic>.from(e)),
                  quantity: 100.0,
                  unit: 'grams',
                ))
            .toList();
      }
    }

    return MealEntry(
      id: json['id'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      mealType: MealCategory.fromJson(
          json['mealType'] as String? ?? json['category'] as String? ?? 'snack'),
      consumedFoods: consumedList,
      completed: json['completed'] as bool? ?? json['isCompleted'] as bool? ?? false,
      name: json['name'] as String? ?? '',
      timeLabel: json['timeLabel'] as String? ?? '12:00 PM',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'mealType': mealType.toJson(),
      'category': mealType.toJson(),
      'consumedFoods': consumedFoods.map((e) => e.toJson()).toList(),
      'items': items.map((e) => e.toJson()).toList(),
      'completed': completed,
      'isCompleted': isCompleted,
      'name': name,
      'timeLabel': timeLabel,
      'totalCalories': totalCalories,
      'totalProtein': totalProtein,
      'totalCarbohydrates': totalCarbohydrates,
      'totalFats': totalFats,
    };
  }

  MealEntry copyWith({
    String? id,
    DateTime? date,
    MealCategory? mealType,
    MealCategory? category,
    List<ConsumedFood>? consumedFoods,
    List<FoodItem>? items,
    List<FoodItem>? foods,
    bool? completed,
    bool? isCompleted,
    String? name,
    String? timeLabel,
  }) {
    return MealEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? category ?? this.mealType,
      consumedFoods: consumedFoods ??
          ((items ?? foods)
              ?.map((f) => ConsumedFood(food: f, quantity: 100.0, unit: 'grams'))
              .toList() ??
          List.from(this.consumedFoods)),
      completed: completed ?? isCompleted ?? this.completed,
      name: name ?? _customName,
      timeLabel: timeLabel ?? this.timeLabel,
    );
  }
}


