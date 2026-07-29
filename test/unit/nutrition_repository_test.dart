import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/data/nutrition_repository.dart';
import 'package:aizawl_gym/data/nutrition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('NutritionRepository & NutritionService Tests', () {
    test('NutritionService reads default protein consumed and goal', () {
      final repo = LocalNutritionRepository();
      final service = NutritionService(repo);

      expect(service.getProteinConsumed(), equals(0.0));
      expect(service.getProteinGoal(), equals(140.0));
    });

    test('NutritionService saves and updates protein consumed round trip', () async {
      final service = NutritionService();

      await service.saveProteinConsumed(75.0);
      expect(service.getProteinConsumed(), equals(75.0));

      await service.saveProteinGoal(160.0);
      expect(service.getProteinGoal(), equals(160.0));
    });
  });
}
