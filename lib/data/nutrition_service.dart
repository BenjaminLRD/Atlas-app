import 'nutrition_repository.dart';

/// High-level service managing nutrition state and persistence.
class NutritionService {
  final NutritionRepository _repository;

  NutritionService([NutritionRepository? repository])
      : _repository = repository ?? LocalNutritionRepository();

  /// Get current protein consumed today
  double getProteinConsumed() {
    return _repository.getProteinConsumed();
  }

  /// Get daily target protein goal
  double getProteinGoal() {
    return _repository.getProteinGoal();
  }

  /// Persist updated protein consumed
  Future<void> saveProteinConsumed(double value) async {
    await _repository.saveProteinConsumed(value);
  }

  /// Persist updated target protein goal
  Future<void> saveProteinGoal(double value) async {
    await _repository.saveProteinGoal(value);
  }
}
