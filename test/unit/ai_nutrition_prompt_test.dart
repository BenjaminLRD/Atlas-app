import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/weight_goal.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _prompt(FitnessContext context) =>
    const CoachPromptBuilder().buildPrompt(
      message: 'how much protein should I eat today',
      context: context,
    );

UserGoal _userGoal({
  String id = 'goal_1',
  double weight = 70,
  double calories = 2600,
  double protein = 165,
}) => UserGoal(
  id: id,
  goalType: FitnessGoalType.muscleGain,
  fitnessLevel: FitnessLevel.intermediate,
  activityLevel: ActivityLevel.moderate,
  age: 24,
  height: 175,
  currentWeight: weight,
  targetWeight: 75,
  targetCalories: calories,
  targetProtein: protein,
  targetCarbohydrates: 280,
  targetFats: 70,
  createdDate: DateTime(2026, 10, 1),
  updatedDate: DateTime(2026, 10, 1),
);

WeightGoal _weightGoal({double calories = 2800, double protein = 160}) =>
    WeightGoal(
      id: 'wg_1',
      userId: 'user_1',
      type: WeightGoalType.gain,
      currentWeight: 70.0,
      targetWeight: 75.0,
      targetWeeks: 12,
      dailyCalorieTarget: calories,
      proteinGrams: protein,
      carbsGrams: 350.0,
      fatGrams: 75.0,
      expectedWeeklyRateKg: 0.4,
      diet: DietPreference.nonVegetarian,
      mealsPerDay: MealFrequency.fourMeals,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  void expectNoInventedTargets(String prompt) {
    expect(prompt, contains('calorie target: not recorded'));
    expect(prompt, contains('Protein Target: not recorded'));
    expect(prompt, isNot(contains('/ 150g')));
    expect(prompt, isNot(contains('/ 2200')));
    expect(prompt, isNot(contains('Target reached')));
    expect(prompt, isNot(contains('protein needed')));
    expect(prompt, isNot(contains('kcal remaining')));
  }

  group('empty context', () {
    test('no targets, step goal or preferences are invented', () {
      final prompt = _prompt(FitnessContext.initial());
      expectNoInventedTargets(prompt);
      expect(prompt, contains('step goal: not recorded'));
      expect(prompt, isNot(contains('10000')));
      expect(
        prompt,
        contains('Learned Food Preferences: Favorite: [not recorded]'),
      );
      expect(
        prompt,
        contains('Learned Exercise Preferences: Favorite: [not recorded]'),
      );
      expect(prompt, contains('Recommendation Feedback History: not recorded'));
      for (final old in [
        'Calibrating',
        'Standard clean foods',
        'Compound movements',
      ]) {
        expect(prompt, isNot(contains(old)), reason: old);
      }
    });
  });

  group('default NutritionLog', () {
    test('its constructor goals (2200 kcal / 150 g) are not user targets', () {
      final context = FitnessContext.initial().copyWith(
        todayNutritionLog: NutritionLog(
          id: 'log',
          date: DateTime(2026, 10, 15),
        ),
      );
      expectNoInventedTargets(_prompt(context));
    });

    test('goals that differ from the model default count as configured', () {
      final context = FitnessContext.initial().copyWith(
        todayNutritionLog: NutritionLog(
          id: 'log',
          date: DateTime(2026, 10, 15),
          calorieGoal: 2800,
          proteinGoal: 180,
        ),
      );
      final prompt = _prompt(context);
      expect(
        prompt,
        contains("Today's Calories: 0 / 2800 kcal (2800 kcal remaining)"),
      );
      expect(
        prompt,
        contains('Protein Target: 0 / 180g (180g protein needed)'),
      );
    });

    test('goals equal to the default values are not trusted', () {
      final context = FitnessContext.initial().copyWith(
        todayNutritionLog: NutritionLog(
          id: 'log',
          date: DateTime(2026, 10, 15),
          calorieGoal: NutritionLog.defaultCalorieGoal,
          proteinGoal: NutritionLog.defaultProteinGoal,
        ),
      );
      expectNoInventedTargets(_prompt(context));
    });

    test('a log with meals but no configured goal still has no target', () {
      final log = NutritionLog(id: 'log', date: DateTime(2026, 10, 15));
      expect(log.calorieGoal, 2200.0); // the default the prompt must ignore
      final context = FitnessContext.initial().copyWith(todayNutritionLog: log);
      final prompt = _prompt(context);
      expect(prompt, contains('0 kcal eaten'));
      expectNoInventedTargets(prompt);
    });
  });

  group('average intake is not a target', () {
    test('averages never become the calorie or protein target', () {
      final context = FitnessContext.initial().copyWith(
        nutritionSummary: NutritionSummary.empty().copyWith(
          averageDailyCalories: 1800,
          averageProtein: 120,
        ),
      );
      final prompt = _prompt(context);
      expectNoInventedTargets(prompt);
      expect(prompt, isNot(contains('/ 1800')));
      expect(prompt, isNot(contains('/ 120g')));
    });
  });

  group('configured targets', () {
    test('a weight program supplies both targets with remaining amounts', () {
      final prompt = _prompt(
        FitnessContext.initial().copyWith(weightGoal: _weightGoal()),
      );
      expect(
        prompt,
        contains("Today's Calories: 0 / 2800 kcal (2800 kcal remaining)"),
      );
      expect(
        prompt,
        contains('Protein Target: 0 / 160g (160g protein needed)'),
      );
    });

    test('a saved goal from goal setup supplies targets', () {
      final prompt = _prompt(
        FitnessContext.initial().copyWith(userGoal: _userGoal()),
      );
      expect(
        prompt,
        contains("Today's Calories: 0 / 2600 kcal (2600 kcal remaining)"),
      );
      expect(
        prompt,
        contains('Protein Target: 0 / 165g (165g protein needed)'),
      );
    });

    test('the weight program wins over a saved goal', () {
      final prompt = _prompt(
        FitnessContext.initial().copyWith(
          weightGoal: _weightGoal(),
          userGoal: _userGoal(),
        ),
      );
      expect(prompt, contains('/ 2800 kcal'));
      expect(prompt, isNot(contains('/ 2600 kcal')));
    });

    test('UserGoal.initial placeholders are not treated as configured', () {
      final prompt = _prompt(
        FitnessContext.initial().copyWith(userGoal: UserGoal.initial()),
      );
      expectNoInventedTargets(prompt);
      expect(prompt, isNot(contains('/ 2000')));
      expect(prompt, isNot(contains('/ 120g')));
    });

    test('a configured step goal is shown', () {
      final prompt = _prompt(
        FitnessContext.initial().copyWith(stepGoal: 8000, todaySteps: 3000),
      );
      expect(prompt, contains('3000 / 8000 steps'));
      expect(prompt, isNot(contains('step goal: not recorded')));

      // With no step reading the goal is still shown, and steps are not zero.
      final noSteps = _prompt(FitnessContext.initial().copyWith(stepGoal: 8000));
      expect(noSteps, contains('step goal: 8000'));
      expect(noSteps, contains('not recorded (the step counter has no reading today)'));
      expect(noSteps, isNot(contains('0 / 8000 steps')));
    });
  });

  group('zero or missing targets', () {
    test('a zero target is not recorded, never "Target reached"', () {
      final prompt = _prompt(
        FitnessContext.initial().copyWith(
          weightGoal: _weightGoal(calories: 0, protein: 0),
        ),
      );
      expectNoInventedTargets(prompt);
    });

    test('a zero calorie target does not hide a valid protein target', () {
      final prompt = _prompt(
        FitnessContext.initial().copyWith(
          weightGoal: _weightGoal(calories: 0, protein: 160),
        ),
      );
      expect(prompt, contains('calorie target: not recorded'));
      expect(prompt, contains('Protein Target: 0 / 160g'));
    });

    test('configuredNutritionTargets reports null without provenance', () {
      final targets = CoachPromptBuilder.configuredNutritionTargets(
        FitnessContext.initial(),
      );
      expect(targets.calories, isNull);
      expect(targets.protein, isNull);
    });
  });
}
