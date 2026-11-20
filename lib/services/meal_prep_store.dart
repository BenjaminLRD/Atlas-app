import '../data/local_storage.dart';
import '../models/meal_prep.dart';
import 'nutrition/nutrition_service.dart';

/// The athlete's saved meal preps, on this device. Showcase Mode keeps its own
/// list, so demo plans never mix with real ones.
class MealPrepStore {
  MealPrepStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const String realKey = 'meal_preps_v1';
  static const String showcaseKey = 'showcase_meal_preps_v1';

  String get _key =>
      LocalStorage.isShowcaseModeEnabled() ? showcaseKey : realKey;

  List<MealPrep> all() {
    final list = MealPrep.decodeAll(LocalStorage.getString(_key));
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  MealPrep? byId(String id) {
    for (final p in all()) {
      if (p.id == id) return p;
    }
    return null;
  }

  int _lastIdStamp = 0;

  String newId() {
    // Strictly increasing, so two ids made in the same clock tick still differ.
    var stamp = _clock().microsecondsSinceEpoch;
    if (stamp <= _lastIdStamp) stamp = _lastIdStamp + 1;
    _lastIdStamp = stamp;
    return 'mp_$stamp';
  }

  MealPrep blank(String name) {
    final now = _clock();
    return MealPrep(
      id: newId(),
      name: name,
      days: 1,
      items: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Saves by id, so saving twice replaces rather than duplicates.
  Future<MealPrep> save(MealPrep prep) async {
    final saved = prep.copyWith(updatedAt: _clock());
    final list = all()..removeWhere((p) => p.id == saved.id);
    list.add(saved);
    await LocalStorage.setString(_key, MealPrep.encodeAll(list));
    return saved;
  }

  Future<void> delete(String id) async {
    final list = all()..removeWhere((p) => p.id == id);
    await LocalStorage.setString(_key, MealPrep.encodeAll(list));
  }

  /// A copy with new ids and an empty "logged" history.
  Future<MealPrep> duplicate(String id) async {
    final original = byId(id);
    if (original == null) throw StateError('Meal prep not found');
    final now = _clock();
    var name = '${original.name} (copy)';
    if (name.length > MealPrep.maxNameLength) {
      name = '${original.name.substring(0, MealPrep.maxNameLength - 7)} (copy)';
    }
    var n = 0;
    final copy = MealPrep(
      id: newId(),
      name: name,
      days: original.days,
      items: [
        for (final i in original.items)
          MealPrepItem(
            id: 'it_${now.microsecondsSinceEpoch}_${n++}',
            food: i.food,
            quantity: i.quantity,
            unit: i.unit,
            meal: i.meal,
            day: i.day,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    return save(copy);
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// How many of day [day]'s foods are still to be logged for [today].
  int pendingToday(MealPrep prep, int day, {DateTime? today}) {
    final key = _dateKey(today ?? _clock());
    return prep.itemsFor(day).where((i) => prep.loggedOn[i.id] != key).length;
  }

  /// Adds day [day]'s foods to today's food diary through the existing
  /// nutrition service. Foods already logged today from this plan are skipped,
  /// so pressing it twice never doubles the diary. Returns how many were
  /// added. A food whose portion cannot be calculated is not logged.
  Future<int> logDayToToday(
    MealPrep prep,
    int day,
    NutritionService nutrition, {
    DateTime? today,
  }) async {
    final key = _dateKey(today ?? _clock());
    final logged = Map<String, String>.from(prep.loggedOn);
    var added = 0;
    for (final item in prep.itemsFor(day)) {
      if (logged[item.id] == key) continue;
      if (!PortionUnit.forFood(item.food).supported) continue;
      await nutrition.addFoodToMeal(
        item.meal.name,
        item.food,
        item.quantity,
        item.unit,
      );
      logged[item.id] = key;
      added++;
    }
    if (added > 0) {
      await save(prep.copyWith(loggedOn: logged));
    }
    return added;
  }
}
