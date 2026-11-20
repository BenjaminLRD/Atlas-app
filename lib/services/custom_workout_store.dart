import '../data/local_storage.dart';
import '../models/custom_workout.dart';

/// The athlete's saved custom workouts, on this device.
///
/// Showcase Mode has its own list, so demo workouts never mix with the real
/// ones and nothing built there is saved to the real account's list.
class CustomWorkoutStore {
  CustomWorkoutStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  static const String realKey = 'custom_workouts_v1';
  static const String showcaseKey = 'showcase_custom_workouts_v1';

  String get _key =>
      LocalStorage.isShowcaseModeEnabled() ? showcaseKey : realKey;

  /// All saved workouts, newest first.
  List<CustomWorkout> all() {
    final list = CustomWorkout.decodeAll(LocalStorage.getString(_key));
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  CustomWorkout? byId(String id) {
    for (final w in all()) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// A fresh id; ids are never reused after a delete.
  int _lastIdStamp = 0;

  String newId() {
    // Strictly increasing, so two ids made in the same clock tick still differ.
    var stamp = _clock().microsecondsSinceEpoch;
    if (stamp <= _lastIdStamp) stamp = _lastIdStamp + 1;
    _lastIdStamp = stamp;
    return 'cw_$stamp';
  }

  CustomWorkout blank(String name) {
    final now = _clock();
    return CustomWorkout(
      id: newId(),
      name: name,
      exercises: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Saves by id: a new workout is added, an edited one replaces itself, so
  /// saving twice never makes two copies.
  Future<CustomWorkout> save(CustomWorkout workout) async {
    final saved = workout.copyWith(updatedAt: _clock());
    final list = all()..removeWhere((w) => w.id == saved.id);
    list.add(saved);
    await LocalStorage.setString(_key, CustomWorkout.encodeAll(list));
    return saved;
  }

  Future<void> delete(String id) async {
    final list = all()..removeWhere((w) => w.id == id);
    await LocalStorage.setString(_key, CustomWorkout.encodeAll(list));
  }

  /// A copy with its own id and "(copy)" in the name.
  Future<CustomWorkout> duplicate(String id) async {
    final original = byId(id);
    if (original == null) {
      throw StateError('Workout not found');
    }
    final now = _clock();
    var name = '${original.name} (copy)';
    if (name.length > CustomWorkout.maxNameLength) {
      name =
          '${original.name.substring(0, CustomWorkout.maxNameLength - 7)} (copy)';
    }
    final copy = CustomWorkout(
      id: newId(),
      name: name,
      exercises: original.exercises,
      createdAt: now,
      updatedAt: now,
    );
    return save(copy);
  }
}
