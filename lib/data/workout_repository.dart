import '../models/active_workout_session.dart';
import '../models/workout_history.dart';
import 'local_storage.dart';

/// Abstract interface for workout persistence operations.
abstract class WorkoutRepository {
  ActiveWorkoutSession? getActiveSession();
  Future<void> saveActiveSession(ActiveWorkoutSession session);
  Future<void> clearActiveSession();
  List<WorkoutHistory> getWorkoutHistory();
  Future<void> saveWorkoutCompletion(WorkoutHistory entry);
}

/// Default local implementation of WorkoutRepository backed by LocalStorage.
class LocalWorkoutRepository implements WorkoutRepository {
  @override
  ActiveWorkoutSession? getActiveSession() {
    return LocalStorage.getActiveSession();
  }

  @override
  Future<void> saveActiveSession(ActiveWorkoutSession session) async {
    await LocalStorage.saveActiveSession(session);
  }

  @override
  Future<void> clearActiveSession() async {
    await LocalStorage.clearActiveSession();
  }

  @override
  List<WorkoutHistory> getWorkoutHistory() {
    return LocalStorage.getWorkoutHistory();
  }

  @override
  Future<void> saveWorkoutCompletion(WorkoutHistory entry) async {
    await LocalStorage.saveWorkoutCompletion(entry);
  }
}
