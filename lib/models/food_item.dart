class FoodItem {
  final String id;
  final String name;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String servingSize;

  const FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.servingSize = '1 serving',
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Food Item',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      proteinGrams: (json['proteinGrams'] as num?)?.toDouble() ?? 0.0,
      carbsGrams: (json['carbsGrams'] as num?)?.toDouble() ?? 0.0,
      fatGrams: (json['fatGrams'] as num?)?.toDouble() ?? 0.0,
      servingSize: json['servingSize'] as String? ?? '1 serving',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'servingSize': servingSize,
    };
  }

  FoodItem copyWith({
    String? id,
    String? name,
    double? calories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    String? servingSize,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      servingSize: servingSize ?? this.servingSize,
    );
  }
}
