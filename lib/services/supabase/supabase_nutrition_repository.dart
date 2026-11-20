import '../../data/local_storage.dart';
import '../../models/daily_nutrition.dart';
import '../../models/food_item.dart';
import '../../models/meal_entry.dart';
import 'database_models.dart';
import 'supabase_client.dart';

/// Cloud-first, local-fallback repository for daily nutrition logs, meals, and foods.
class SupabaseNutritionRepository {
  final SupabaseClientManager _clientManager;

  SupabaseNutritionRepository({SupabaseClientManager? clientManager})
    : _clientManager = clientManager ?? SupabaseClientManager.instance;

  /// Retrieves today's nutrition log: tries Supabase first, falls back to LocalStorage cache.
  Future<DailyNutrition> getTodayNutrition({String? userId}) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';

      final rows = await _clientManager
          .from(SupabaseTableNames.nutritionLogs)
          .select('user_id', uid);

      final matching = rows.where((r) => r['log_date'] == dateStr || r['date'] == dateStr);
      if (matching.isNotEmpty) {
        final row = matching.first;
        final rawMeals = (row['meals'] as List?) ?? [];
        final meals = rawMeals
            .map((m) => MealEntry.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList();

        final nutrition = DailyNutrition(
          date: dateStr,
          targets: LocalStorage.getDailyNutrition(dateStr).targets,
          meals: meals,
          waterLiters: (row['water_liters'] as num?)?.toDouble() ?? 2.0,
        );
        await LocalStorage.saveDailyNutrition(nutrition);
        return nutrition;
      }
    } catch (_) {
      // Offline fallback
    }
    return LocalStorage.getDailyNutrition(dateStr);
  }

  /// Saves daily nutrition: saves locally first, then attempts cloud sync
  /// of both the aggregate nutrition_logs record and individual meal_entries.
  Future<void> saveDailyNutrition(
    DailyNutrition nutrition, {
    String? userId,
  }) async {
    // 1. Local Cache
    await LocalStorage.saveDailyNutrition(nutrition);

    // 2. Cloud Sync
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final payload = SupabaseModelMappers.dailyNutritionToTable(
        nutrition,
        userId: uid,
      );
      await _clientManager
          .from(SupabaseTableNames.nutritionLogs)
          .upsert(payload, onConflictColumn: 'id');

      final logId = payload['id'] as String;

      // Sync normalized meal entries
      for (final meal in nutrition.meals) {
        for (final consumed in meal.consumedFoods) {
          final mealPayload = SupabaseModelMappers.mealEntryToTable(
            nutritionLogId: logId,
            food: consumed,
            mealCategory: meal.mealType.name,
            loggedAt: meal.date,
          );
          await _clientManager
              .from(SupabaseTableNames.mealEntries)
              .insert(mealPayload);
        }
      }
    } catch (_) {
      // Offline resilience
    }
  }

  /// Saves a custom food item to Supabase `foods` catalog.
  Future<void> saveCustomFood(FoodItem food, {String? creatorId}) async {
    try {
      final uid = creatorId ?? _clientManager.authenticatedUid;
      final payload = SupabaseModelMappers.foodItemToTable(food, creatorId: uid);
      await _clientManager
          .from(SupabaseTableNames.foods)
          .upsert(payload, onConflictColumn: 'id');
    } catch (_) {
      // Fallback
    }
  }

  /// Fetches foods catalog from Supabase
  Future<List<FoodItem>> getFoodsCatalog() async {
    try {
      final rows = await _clientManager
          .from(SupabaseTableNames.foods)
          .select('source', 'system');
      if (rows.isNotEmpty) {
        return rows.map((r) => SupabaseModelMappers.tableToFoodItem(r)).toList();
      }
    } catch (_) {
      // Fallback
    }
    return <FoodItem>[];
  }
}
