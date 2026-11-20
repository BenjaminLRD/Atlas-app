import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../data/local_storage.dart';
import '../../models/food_item.dart';
import '../../models/meal_entry.dart';
import '../../models/meal_prep.dart';
import '../../models/recipe.dart';
import '../meal_prep_store.dart';
import '../nutrition/nutrition_service.dart';
import 'recipe_catalog.dart';
import 'recipe_ratings.dart';

bool get _showcase => LocalStorage.isShowcaseModeEnabled();

/// The athlete's own meals, on this device. Showcase Mode keeps a separate
/// list, so demo meals never mix with real ones.
class CustomMealStore {
  CustomMealStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const String realKey = 'custom_meals_v1';
  static const String showcaseKey = 'showcase_custom_meals_v1';

  String get _key => _showcase ? showcaseKey : realKey;

  List<Recipe> all() {
    final list = Recipe.decodeAllCustom(LocalStorage.getString(_key));
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Recipe? byId(String id) {
    for (final r in all()) {
      if (r.id == id) return r;
    }
    return null;
  }

  Recipe blank(String name) {
    final now = _clock();
    return Recipe(
      id: 'cm_${now.microsecondsSinceEpoch}',
      name: name,
      origin: RecipeOrigin.custom,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Saves by id, so saving again replaces rather than duplicates.
  Future<Recipe> save(Recipe meal) async {
    final saved = meal.copyWith(updatedAt: _clock());
    final list = all()..removeWhere((r) => r.id == saved.id);
    list.add(saved);
    await LocalStorage.setString(_key, Recipe.encodeAll(list));
    return saved;
  }

  Future<void> delete(String id) async {
    final list = all()..removeWhere((r) => r.id == id);
    await LocalStorage.setString(_key, Recipe.encodeAll(list));
  }

  Future<Recipe> duplicate(String id) async {
    final original = byId(id);
    if (original == null) throw StateError('Meal not found');
    final now = _clock();
    var name = '${original.name} (copy)';
    if (name.length > Recipe.maxNameLength) {
      name = '${original.name.substring(0, Recipe.maxNameLength - 7)} (copy)';
    }
    return save(
      Recipe(
        id: 'cm_${now.microsecondsSinceEpoch}',
        name: name,
        description: original.description,
        origin: RecipeOrigin.custom,
        categories: original.categories,
        prepMinutes: original.prepMinutes,
        servings: original.servings,
        ingredients: original.ingredients,
        steps: original.steps,
        imageFile: original.imageFile,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

/// Recipes the athlete bookmarked (a list of ids), kept apart in Showcase.
class SavedRecipesStore {
  static const String realKey = 'saved_recipes_v1';
  static const String showcaseKey = 'showcase_saved_recipes_v1';

  String get _key => _showcase ? showcaseKey : realKey;

  Set<String> ids() {
    final raw = LocalStorage.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final v = jsonDecode(raw);
      return v is List
          ? {
              for (final e in v)
                if (e is String) e,
            }
          : {};
    } catch (_) {
      return {};
    }
  }

  bool isSaved(String id) => ids().contains(id);

  /// Flips the bookmark and returns the new state.
  Future<bool> toggle(String id) async {
    final s = ids();
    final now = !s.remove(id);
    if (now) s.add(id);
    await LocalStorage.setString(_key, jsonEncode(s.toList()));
    return now;
  }
}

/// Copies a photo the athlete picked into the app's own storage, so clearing
/// the cache does not remove it. Each call makes a new file; it never deletes
/// another meal's photo. On any failure the original path is returned.
class MealPhotoStore {
  const MealPhotoStore._();

  static Future<String> persist(String pickedPath, {Directory? baseDir}) async {
    if (kIsWeb) return pickedPath;
    try {
      final source = File(pickedPath);
      if (!await source.exists()) return pickedPath;
      final root = baseDir ?? source.parent.parent;
      final dir = Directory('${root.path}${Platform.pathSeparator}atlas_meals');
      if (!await dir.exists()) await dir.create(recursive: true);
      final ext = pickedPath.contains('.')
          ? pickedPath.substring(pickedPath.lastIndexOf('.'))
          : '.jpg';
      final target = File(
        '${dir.path}${Platform.pathSeparator}meal_'
        '${DateTime.now().microsecondsSinceEpoch}$ext',
      );
      await source.copy(target.path);
      return target.path;
    } catch (_) {
      return pickedPath;
    }
  }
}

/// What happened when a meal was added to the food diary.
class MealLogResult {
  final int added;
  final int skipped;

  /// The same meal, slot and day was already logged and nothing was added.
  final bool alreadyLogged;

  const MealLogResult({
    this.added = 0,
    this.skipped = 0,
    this.alreadyLogged = false,
  });
}

/// Adds a recipe or custom meal to today's food diary through the existing
/// nutrition service, one entry per ingredient scaled to the servings eaten.
/// The entries are independent copies: editing or removing one in the diary
/// never changes the saved recipe.
class MealLogger {
  MealLogger({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const String storageKey = 'recipe_log_ledger_v1';

  /// Logs in progress, so a double tap cannot add twice.
  static final Set<String> _inFlight = {};

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String keyFor(Recipe r, MealCategory slot) =>
      '${r.id}|${_day(_clock())}|${slot.name}';

  Map<String, dynamic> _ledger() {
    final raw = LocalStorage.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : {};
    } catch (_) {
      return {};
    }
  }

  bool wasLoggedToday(Recipe r, MealCategory slot) =>
      _ledger().containsKey(keyFor(r, slot));

  /// Adds [servings] of [recipe] to [slot] today. Without [force], a meal
  /// already logged in that slot today is not added again.
  Future<MealLogResult> log(
    Recipe recipe,
    double servings,
    MealCategory slot,
    NutritionService nutrition, {
    bool force = false,
  }) async {
    if (servings <= 0 || servings > 50) {
      throw ArgumentError.value(servings, 'servings');
    }
    final key = keyFor(recipe, slot);
    if (_inFlight.contains(key)) {
      return const MealLogResult(alreadyLogged: true);
    }
    if (!force && _ledger().containsKey(key)) {
      return const MealLogResult(alreadyLogged: true);
    }
    _inFlight.add(key);
    try {
      final factor = servings / recipe.servings;
      var added = 0;
      var skipped = 0;
      for (final ing in recipe.ingredients) {
        if (!ing.portion.supported) {
          skipped++;
          continue;
        }
        await nutrition.addFoodToMeal(
          slot.name,
          ing.food,
          ing.quantity * factor,
          ing.unit,
        );
        added++;
      }
      if (added > 0) {
        final l = _ledger();
        l[key] = {'servings': servings, 'at': _clock().toIso8601String()};
        await LocalStorage.setString(storageKey, jsonEncode(l));
      }
      return MealLogResult(added: added, skipped: skipped);
    } finally {
      _inFlight.remove(key);
    }
  }
}

/// Adds a recipe to a meal plan (a [MealPrep]) as separate portions.
class RecipePlanner {
  RecipePlanner({MealPrepStore? store}) : _store = store ?? MealPrepStore();

  final MealPrepStore _store;

  /// Adds [servings] of [recipe] to [plan] (or a new plan named [newName]) on
  /// [day], in [slot]. Returns the saved plan.
  Future<MealPrep> add(
    Recipe recipe,
    double servings, {
    MealPrep? plan,
    String? newName,
    required int day,
    required MealCategory slot,
  }) async {
    final base = plan ?? _store.blank((newName ?? recipe.name).trim());
    final factor = servings / recipe.servings;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var n = 0;
    final items = [...base.items];
    for (final ing in recipe.ingredients) {
      if (!ing.portion.supported) continue;
      items.add(
        ing.toItem(
          id: 'it_${stamp}_${n++}',
          factor: factor,
          meal: slot,
          day: day,
        ),
      );
    }
    return _store.save(
      base.copyWith(
        items: items,
        days: day + 1 > base.days ? day + 1 : base.days,
      ),
    );
  }
}

/// Which recipes and which ratings service the current mode uses.
class RecipeHub {
  RecipeHub({List<FoodItem>? foods, RecipeRatingRepository? ratings})
    // ignore: prefer_initializing_formals
    : _foods = foods,
      // ignore: prefer_initializing_formals
      _ratings = ratings;

  final List<FoodItem>? _foods;
  final RecipeRatingRepository? _ratings;

  List<FoodItem> get foods => _foods ?? const [];

  /// Atlas's own recipes (every mode).
  List<Recipe> atlas() => RecipeCatalog.atlas(foods);

  /// Community recipes. Only Showcase Mode has any, and they are samples;
  /// real community recipes need a backend that is not switched on yet.
  List<Recipe> community() =>
      _showcase ? RecipeCatalog.sampleCommunity(foods) : const [];

  bool get communityAvailable => _showcase;

  List<Recipe> mine() => CustomMealStore().all();

  RecipeRatingRepository get ratings =>
      _ratings ??
      (_showcase
          ? SampleRatingRepository()
          : const UnavailableRatingRepository());

  List<Recipe> everything() => [...mine(), ...atlas(), ...community()];
}
