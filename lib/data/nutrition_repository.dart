import 'local_storage.dart';

/// Abstract interface for nutrition data operations.
abstract class NutritionRepository {
  double getProteinConsumed();
  double getProteinGoal();
  Future<void> saveProteinConsumed(double value);
  Future<void> saveProteinGoal(double value);
}

/// Default implementation of NutritionRepository backed by LocalStorage.
class LocalNutritionRepository implements NutritionRepository {
  @override
  double getProteinConsumed() {
    return LocalStorage.getProteinConsumed();
  }

  @override
  double getProteinGoal() {
    return LocalStorage.getProteinGoal();
  }

  @override
  Future<void> saveProteinConsumed(double value) async {
    await LocalStorage.saveProteinConsumed(value);
  }

  @override
  Future<void> saveProteinGoal(double value) async {
    await LocalStorage.saveProteinGoal(value);
  }
}
