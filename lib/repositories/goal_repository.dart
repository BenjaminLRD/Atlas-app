import '../data/local_storage.dart';
import '../models/user_goal.dart';

/// Abstract interface for user goal repository operations.
abstract class GoalRepository {
  /// Retrieve current active UserGoal, or null if no goal is configured
  UserGoal? getGoal();

  /// Persist or update user fitness goal
  Future<void> saveGoal(UserGoal goal);

  /// Clear stored user goal
  Future<void> clearGoal();
}

/// Default implementation of GoalRepository backed by LocalStorage.
class LocalGoalRepository implements GoalRepository {
  const LocalGoalRepository();

  @override
  UserGoal? getGoal() {
    return LocalStorage.getGoal();
  }

  @override
  Future<void> saveGoal(UserGoal goal) async {
    await LocalStorage.saveGoal(goal);
  }

  @override
  Future<void> clearGoal() async {
    await LocalStorage.clearGoal();
  }
}
