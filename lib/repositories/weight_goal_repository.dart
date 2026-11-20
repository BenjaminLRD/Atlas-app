import '../data/local_storage.dart';
import '../models/weight_goal.dart';

/// Abstract contract for persisting and retrieving user [WeightGoal] profiles
abstract class WeightGoalRepository {
  /// Retrieves the active [WeightGoal], or null if unconfigured
  WeightGoal? getWeightGoal();

  /// Persists a new or updated [WeightGoal]
  Future<void> saveWeightGoal(WeightGoal goal);

  /// Clears stored weight goal
  Future<void> clearWeightGoal();
}

/// LocalStorage implementation of [WeightGoalRepository]
class LocalWeightGoalRepository implements WeightGoalRepository {
  const LocalWeightGoalRepository();

  @override
  WeightGoal? getWeightGoal() {
    return LocalStorage.getWeightGoal();
  }

  @override
  Future<void> saveWeightGoal(WeightGoal goal) async {
    await LocalStorage.saveWeightGoal(goal);
  }

  @override
  Future<void> clearWeightGoal() async {
    await LocalStorage.clearWeightGoal();
  }
}
