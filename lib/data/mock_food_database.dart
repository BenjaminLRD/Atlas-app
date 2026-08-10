import '../models/food_item.dart';

/// Mock Food Database providing realistic food items across Protein, Carbohydrates, and Fats.
class MockFoodDatabase {
  static final List<FoodItem> defaultFoods = [
    // PROTEIN
    const FoodItem(
      id: 'food_chicken_breast',
      name: 'Chicken Breast',
      category: 'Protein',
      servingSize: '100g',
      calories: 165.0,
      protein: 31.0,
      carbohydrates: 0.0,
      fats: 3.6,
      imageUrl: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=300&q=80',
      description: 'Lean boneless grilled chicken breast packed with high-quality protein.',
    ),
    const FoodItem(
      id: 'food_eggs',
      name: 'Whole Eggs',
      category: 'Protein',
      servingSize: '100g (2 large eggs)',
      calories: 155.0,
      protein: 13.0,
      carbohydrates: 1.1,
      fats: 11.0,
      imageUrl: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=300&q=80',
      description: 'Whole farm-fresh eggs providing complete amino acid profile.',
    ),
    const FoodItem(
      id: 'food_greek_yogurt',
      name: 'Greek Yogurt',
      category: 'Protein',
      servingSize: '100g',
      calories: 97.0,
      protein: 10.0,
      carbohydrates: 3.8,
      fats: 5.0,
      imageUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=300&q=80',
      description: 'Strained probiotic Greek yogurt rich in casein protein and calcium.',
    ),
    const FoodItem(
      id: 'food_paneer',
      name: 'Paneer (Cottage Cheese)',
      category: 'Protein',
      servingSize: '100g',
      calories: 265.0,
      protein: 18.3,
      carbohydrates: 1.2,
      fats: 20.8,
      imageUrl: 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?auto=format&fit=crop&w=300&q=80',
      description: 'Fresh Indian cottage cheese high in protein and essential fatty acids.',
    ),

    // CARBS
    const FoodItem(
      id: 'food_white_rice',
      name: 'Steamed Rice',
      category: 'Carbohydrates',
      servingSize: '100g (cooked)',
      calories: 130.0,
      protein: 2.7,
      carbohydrates: 28.0,
      fats: 0.3,
      imageUrl: 'https://images.unsplash.com/photo-1516684732162-798a0062be99?auto=format&fit=crop&w=300&q=80',
      description: 'Steamed white rice providing fast-digesting glucose for post-workout recovery.',
    ),
    const FoodItem(
      id: 'food_rolled_oats',
      name: 'Rolled Oats',
      category: 'Carbohydrates',
      servingSize: '100g (dry)',
      calories: 389.0,
      protein: 16.9,
      carbohydrates: 66.3,
      fats: 6.9,
      imageUrl: 'https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&w=300&q=80',
      description: 'Whole grain rolled oats rich in complex carbs and soluble beta-glucan fiber.',
    ),
    const FoodItem(
      id: 'food_sweet_potato',
      name: 'Sweet Potato',
      category: 'Carbohydrates',
      servingSize: '100g (boiled)',
      calories: 86.0,
      protein: 1.6,
      carbohydrates: 20.1,
      fats: 0.1,
      imageUrl: 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=300&q=80',
      description: 'Nutrient-dense sweet potato providing sustained energy and Vitamin A.',
    ),

    // FATS
    const FoodItem(
      id: 'food_peanut_butter',
      name: 'Peanut Butter',
      category: 'Fats',
      servingSize: '100g',
      calories: 588.0,
      protein: 25.0,
      carbohydrates: 20.0,
      fats: 50.0,
      imageUrl: 'https://images.unsplash.com/photo-1563227812-0ea4c22e6cc8?auto=format&fit=crop&w=300&q=80',
      description: 'Natural roasted peanut butter loaded with healthy monounsaturated fats.',
    ),
    const FoodItem(
      id: 'food_whole_almonds',
      name: 'Whole Almonds',
      category: 'Fats',
      servingSize: '100g',
      calories: 579.0,
      protein: 21.2,
      carbohydrates: 21.6,
      fats: 49.9,
      imageUrl: 'https://images.unsplash.com/photo-1508061253366-f7da158b6d46?auto=format&fit=crop&w=300&q=80',
      description: 'Raw California almonds packed with healthy fats, Vitamin E, and magnesium.',
    ),
  ];

  static List<FoodItem> getAllFoods() => List.unmodifiable(defaultFoods);

  static List<FoodItem> getFoodsByCategory(String category) {
    return defaultFoods
        .where((f) => f.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  static FoodItem? getFoodById(String id) {
    try {
      return defaultFoods.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<FoodItem> searchFoods(String query) {
    if (query.trim().isEmpty) return getAllFoods();
    final q = query.toLowerCase().trim();
    return defaultFoods.where((f) {
      return f.name.toLowerCase().contains(q) ||
          f.category.toLowerCase().contains(q) ||
          f.description.toLowerCase().contains(q);
    }).toList();
  }
}
