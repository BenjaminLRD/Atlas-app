import '../change_signal.dart';

/// Tells whoever shows nutrition data that it just changed.
///
/// `NutritionService` calls `notifyChanged` after it saves something, and the
/// app-level state (`FitnessProvider`) listens and reloads.
///
/// This is one app-wide signal rather than a callback handed to each service
/// on purpose: several `NutritionService` instances exist (the provider's own,
/// the one in `AppDependencies`, the ones the AI tools build), and a save made
/// through any of them has always refreshed the app state. The listener rules
/// are those of [ChangeSignal].
class NutritionChanges extends ChangeSignal {
  NutritionChanges._() : super('nutrition changes');

  static final NutritionChanges instance = NutritionChanges._();
}
