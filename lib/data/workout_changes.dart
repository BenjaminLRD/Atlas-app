import '../services/change_signal.dart';

/// Tells whoever shows workout history that a completed workout was saved.
///
/// `WorkoutService` calls `notifyChanged` after it saves a workout completion,
/// and the app-level state (`FitnessProvider`) listens and reloads the
/// history. One app-wide signal, because more than one `WorkoutService`
/// instance exists (the provider's own and the one in `AppDependencies`) and a
/// save through any of them has always refreshed the history. The listener
/// rules are those of [ChangeSignal].
class WorkoutChanges extends ChangeSignal {
  WorkoutChanges._() : super('workout changes');

  static final WorkoutChanges instance = WorkoutChanges._();
}
