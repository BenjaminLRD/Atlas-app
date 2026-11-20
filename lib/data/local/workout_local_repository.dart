import '../../models/active_workout_session.dart';
import '../../models/workout_history.dart';
import '../../models/workout_session.dart';
import '../local_storage.dart';
import '../workout_repository.dart';

/// Production offline-first local repository for workout sessions and tracking history.
/// Saves instantly to local storage. Cloud upload is done by
/// `CloudWorkoutRepository`, which extends this class.
class WorkoutLocalRepository implements WorkoutRepository {
  @override
  ActiveWorkoutSession? getActiveSession() {
    return LocalStorage.getActiveSession();
  }

  @override
  Future<void> saveActiveSession(dynamic session) async {
    await LocalStorage.saveActiveSession(session);
  }

  @override
  Future<void> clearActiveSession() async {
    await LocalStorage.clearActiveSession();
  }

  @override
  List<WorkoutSession> getWorkoutSessions({String? userId}) {
    return LocalStorage.getWorkoutSessions(userId: userId);
  }

  @override
  Future<void> saveWorkoutSession(
    WorkoutSession session, {
    String userId = 'usr_local_01',
  }) async {
    await LocalStorage.saveWorkoutSession(session, userId: userId);
  }

  @override
  List<WorkoutHistory> getWorkoutHistory({String? userId}) {
    return LocalStorage.getWorkoutHistory(userId: userId);
  }

  @override
  Future<void> saveWorkoutCompletion(
    WorkoutHistory entry, {
    String userId = 'usr_local_01',
  }) async {
    await LocalStorage.saveWorkoutCompletion(entry, userId: userId);
  }
}
