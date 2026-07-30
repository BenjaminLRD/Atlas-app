class MacroTarget {
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  const MacroTarget({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
  });

  factory MacroTarget.defaultTarget() {
    return const MacroTarget(
      calories: 2500.0,
      proteinGrams: 160.0,
      carbsGrams: 350.0,
      fatGrams: 75.0,
    );
  }

  factory MacroTarget.fromJson(Map<String, dynamic> json) {
    return MacroTarget(
      calories: (json['calories'] as num?)?.toDouble() ?? 2500.0,
      proteinGrams: (json['proteinGrams'] as num?)?.toDouble() ?? 160.0,
      carbsGrams: (json['carbsGrams'] as num?)?.toDouble() ?? 350.0,
      fatGrams: (json['fatGrams'] as num?)?.toDouble() ?? 75.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
    };
  }

  MacroTarget copyWith({
    double? calories,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
  }) {
    return MacroTarget(
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
    );
  }
}
