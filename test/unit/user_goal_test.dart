import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/user_goal.dart';
import 'package:aizawl_gym/repositories/goal_repository.dart';
import 'package:aizawl_gym/services/goal_calculation_service.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('UserGoal Model Tests', () {
    test('initial UserGoal creates default goal instance', () {
      final goal = UserGoal.initial();

      expect(goal.id, equals('default_goal'));
      expect(goal.goalType, equals(FitnessGoalType.muscleGain));
      expect(goal.fitnessLevel, equals(FitnessLevel.intermediate));
      expect(goal.activityLevel, equals(ActivityLevel.moderate));
      expect(goal.age, equals(25));
      expect(goal.height, equals(175.0));
      expect(goal.currentWeight, equals(70.0));
      expect(goal.targetWeight, equals(75.0));
      expect(goal.targetCalories, equals(2500.0));
    });

    test('toJson and fromJson round trip symmetrically', () {
      final now = DateTime(2026, 8, 7, 10, 0);
      final goal = UserGoal(
        id: 'goal_123',
        goalType: FitnessGoalType.fatLoss,
        fitnessLevel: FitnessLevel.advanced,
        activityLevel: ActivityLevel.active,
        age: 30,
        height: 180.0,
        currentWeight: 85.0,
        targetWeight: 78.0,
        targetCalories: 2100.0,
        targetProtein: 187.0,
        targetCarbohydrates: 200.0,
        targetFats: 58.0,
        createdDate: now,
        updatedDate: now,
      );

      final json = goal.toJson();
      final restored = UserGoal.fromJson(json);

      expect(restored.id, equals('goal_123'));
      expect(restored.goalType, equals(FitnessGoalType.fatLoss));
      expect(restored.fitnessLevel, equals(FitnessLevel.advanced));
      expect(restored.activityLevel, equals(ActivityLevel.active));
      expect(restored.age, equals(30));
      expect(restored.height, equals(180.0));
      expect(restored.currentWeight, equals(85.0));
      expect(restored.targetWeight, equals(78.0));
      expect(restored.targetCalories, equals(2100.0));
      expect(restored.targetProtein, equals(187.0));
    });

    test('copyWith updates specified fields correctly', () {
      final goal = UserGoal.initial();
      final updated = goal.copyWith(
        goalType: FitnessGoalType.strength,
        currentWeight: 80.0,
        targetWeight: 88.0,
      );

      expect(updated.goalType, equals(FitnessGoalType.strength));
      expect(updated.currentWeight, equals(80.0));
      expect(updated.targetWeight, equals(88.0));
      expect(updated.fitnessLevel, equals(goal.fitnessLevel));
    });
  });

  group('GoalCalculationService BMR & TDEE Calculation Tests', () {
    const service = GoalCalculationService();

    test('calculateBMR uses Mifflin-St Jeor formula correctly', () {
      // BMR = 10*70 + 6.25*175 - 5*25 + 5 = 700 + 1093.75 - 125 + 5 = 1673.75
      final bmr = service.calculateBMR(weight: 70.0, height: 175.0, age: 25);
      expect(bmr, equals(1673.75));
    });

    test('getActivityMultiplier returns exact TDEE multipliers', () {
      expect(GoalCalculationService.getActivityMultiplier(ActivityLevel.sedentary), equals(1.2));
      expect(GoalCalculationService.getActivityMultiplier(ActivityLevel.light), equals(1.375));
      expect(GoalCalculationService.getActivityMultiplier(ActivityLevel.moderate), equals(1.55));
      expect(GoalCalculationService.getActivityMultiplier(ActivityLevel.active), equals(1.725));
      expect(GoalCalculationService.getActivityMultiplier(ActivityLevel.veryActive), equals(1.9));
    });

    test('calculateTDEE applies activity multiplier correctly', () {
      // 1673.75 * 1.55 = 2594.3125
      final tdee = service.calculateTDEE(bmr: 1673.75, activityLevel: ActivityLevel.moderate);
      expect(tdee, closeTo(2594.31, 0.01));
    });

    test('calculateTargets allocates calories and macros for muscleGain', () {
      final targets = service.calculateTargets(
        age: 25,
        height: 175.0,
        weight: 70.0,
        activityLevel: ActivityLevel.moderate,
        goalType: FitnessGoalType.muscleGain,
      );

      // TDEE ~2594.31 + 400 surplus = ~2994.31 kcal
      expect(targets.targetCalories, closeTo(2994.31, 0.01));
      // Protein: 2.0g * 70kg = 140g
      expect(targets.targetProtein, equals(140.0));
      // Fat: 25% of 2994.31 / 9 = ~83.17g
      expect(targets.targetFats, closeTo(83.17, 0.01));
    });

    test('calculateTargets allocates calories and macros for fatLoss', () {
      final targets = service.calculateTargets(
        age: 25,
        height: 175.0,
        weight: 70.0,
        activityLevel: ActivityLevel.moderate,
        goalType: FitnessGoalType.fatLoss,
      );

      // TDEE ~2594.31 - 400 deficit = ~2194.31 kcal
      expect(targets.targetCalories, closeTo(2194.31, 0.01));
      // Protein: 2.2g * 70kg = 154g
      expect(targets.targetProtein, equals(154.0));
    });

    test('generateUserGoal constructs UserGoal instance with auto-calculated targets', () {
      final goal = service.generateUserGoal(
        id: 'user_goal_1',
        goalType: FitnessGoalType.strength,
        fitnessLevel: FitnessLevel.advanced,
        activityLevel: ActivityLevel.active,
        age: 28,
        height: 182.0,
        currentWeight: 82.0,
        targetWeight: 86.0,
      );

      expect(goal.id, equals('user_goal_1'));
      expect(goal.goalType, equals(FitnessGoalType.strength));
      expect(goal.targetCalories, greaterThan(2000.0));
      expect(goal.targetProtein, greaterThan(150.0));
    });
  });

  group('GoalRepository & LocalStorage Persistence Tests', () {
    test('LocalGoalRepository saves, retrieves, and clears UserGoal', () async {
      const repo = LocalGoalRepository();

      expect(repo.getGoal(), isNull);

      final goal = UserGoal.initial().copyWith(id: 'saved_goal_1', currentWeight: 72.0);
      await repo.saveGoal(goal);

      final fetched = repo.getGoal();
      expect(fetched, isNotNull);
      expect(fetched!.id, equals('saved_goal_1'));
      expect(fetched.currentWeight, equals(72.0));

      await repo.clearGoal();
      expect(repo.getGoal(), isNull);
    });
  });

  group('FitnessProvider Goal Integration Tests', () {
    test('saveGoal, updateGoal, and clearGoal update currentGoal and notify listeners', () async {
      final provider = FitnessProvider.instance;
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      expect(provider.currentGoal, isNull);

      final goal = UserGoal.initial();
      await provider.saveGoal(goal);

      expect(provider.currentGoal, isNotNull);
      expect(provider.currentGoal!.id, equals('default_goal'));
      expect(notifyCount, equals(1));

      final updatedGoal = goal.copyWith(targetWeight: 78.0);
      await provider.updateGoal(updatedGoal);

      expect(provider.currentGoal!.targetWeight, equals(78.0));
      expect(notifyCount, equals(2));

      await provider.clearGoal();

      expect(provider.currentGoal, isNull);
      expect(notifyCount, equals(3));
    });
  });
}
