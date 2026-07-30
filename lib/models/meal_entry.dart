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

class MealEntry {
  final String id;
  final String name;
  final MealCategory category;
  final String timeLabel;
  final List<FoodItem> items;
  final bool isCompleted;

  const MealEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.timeLabel,
    required this.items,
    this.isCompleted = false,
  });

  double get totalCalories {
    return items.fold(0.0, (sum, item) => sum + item.calories);
  }

  double get totalProtein {
    return items.fold(0.0, (sum, item) => sum + item.proteinGrams);
  }

  double get totalCarbs {
    return items.fold(0.0, (sum, item) => sum + item.carbsGrams);
  }

  double get totalFat {
    return items.fold(0.0, (sum, item) => sum + item.fatGrams);
  }

  String get macrosSummary {
    return 'P: ${totalProtein.toStringAsFixed(0)}g · C: ${totalCarbs.toStringAsFixed(0)}g · F: ${totalFat.toStringAsFixed(0)}g';
  }

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List?;
    final itemList = rawItems != null
        ? rawItems.map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e))).toList()
        : <FoodItem>[];

    return MealEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Meal',
      category: MealCategory.fromJson(json['category'] as String? ?? 'snack'),
      timeLabel: json['timeLabel'] as String? ?? '12:00 PM',
      items: itemList,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.toJson(),
      'timeLabel': timeLabel,
      'items': items.map((e) => e.toJson()).toList(),
      'isCompleted': isCompleted,
    };
  }

  MealEntry copyWith({
    String? id,
    String? name,
    MealCategory? category,
    String? timeLabel,
    List<FoodItem>? items,
    bool? isCompleted,
  }) {
    return MealEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      timeLabel: timeLabel ?? this.timeLabel,
      items: items ?? List.from(this.items),
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
