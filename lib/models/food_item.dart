/// Model representing a food item with macronutrient details.
class FoodItem {
  final String id;
  final String name;
  final String category;
  final String servingSize;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final String imageUrl;
  final String description;

  const FoodItem({
    required this.id,
    required this.name,
    this.category = 'General',
    this.servingSize = '100g',
    required this.calories,
    double? protein,
    double? proteinGrams,
    double? carbohydrates,
    double? carbsGrams,
    double? fats,
    double? fatGrams,
    this.imageUrl = '',
    this.description = '',
  })  : protein = protein ?? proteinGrams ?? 0.0,
        carbohydrates = carbohydrates ?? carbsGrams ?? 0.0,
        fats = fats ?? fatGrams ?? 0.0;

  // Backwards compatibility getters for existing code
  double get proteinGrams => protein;
  double get carbsGrams => carbohydrates;
  double get fatGrams => fats;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Food Item',
      category: json['category'] as String? ?? 'General',
      servingSize: json['servingSize'] as String? ?? '100g',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ??
          (json['proteinGrams'] as num?)?.toDouble() ??
          0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ??
          (json['carbsGrams'] as num?)?.toDouble() ??
          0.0,
      fats: (json['fats'] as num?)?.toDouble() ??
          (json['fatGrams'] as num?)?.toDouble() ??
          0.0,
      imageUrl: json['imageUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'servingSize': servingSize,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fats': fats,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'imageUrl': imageUrl,
      'description': description,
    };
  }

  FoodItem copyWith({
    String? id,
    String? name,
    String? category,
    String? servingSize,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fats,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    String? imageUrl,
    String? description,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      servingSize: servingSize ?? this.servingSize,
      calories: calories ?? this.calories,
      protein: protein ?? proteinGrams ?? this.protein,
      carbohydrates: carbohydrates ?? carbsGrams ?? this.carbohydrates,
      fats: fats ?? fatGrams ?? this.fats,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
    );
  }
}
