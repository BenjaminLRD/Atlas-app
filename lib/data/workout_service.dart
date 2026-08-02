import '../models/active_workout_session.dart';
import '../models/workout_history.dart';
import '../providers/fitness_provider.dart';
import 'workout_repository.dart';

/// High-level service handling workout operations for UI screens.
class WorkoutService {
  final WorkoutRepository _repository;

  WorkoutService([WorkoutRepository? repository])
      : _repository = repository ?? LocalWorkoutRepository();

  /// Retrieve the currently active workout session if present
  ActiveWorkoutSession? getActiveSession() {
    return _repository.getActiveSession();
  }

  /// Persist active workout session state
  Future<void> saveActiveSession(dynamic session) async {
    await _repository.saveActiveSession(session);
  }

  /// Clear the active workout session state
  Future<void> clearActiveSession() async {
    await _repository.clearActiveSession();
  }

  /// Retrieve full workout completion history sorted newest first
  List<WorkoutHistory> getWorkoutHistory() {
    final history = _repository.getWorkoutHistory();
    history.sort((a, b) => b.dateCompleted.compareTo(a.dateCompleted));
    return history;
  }

  /// Record a completed workout entry in history
  Future<void> saveWorkoutCompletion(WorkoutHistory entry) async {
    await _repository.saveWorkoutCompletion(entry);
    FitnessProvider.instance.refreshWorkoutHistory();
  }

  /// Alias for saving workout completion to history
  Future<void> addHistory(WorkoutHistory entry) async {
    await saveWorkoutCompletion(entry);
  }
}
