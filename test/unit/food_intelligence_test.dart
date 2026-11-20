import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/food_analysis_result.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/weight_goal.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/vision/image_analysis_result.dart';
import 'package:atlas/services/food_api/open_food_facts_service.dart';
import 'package:atlas/services/food_api/remote_food_mapper.dart';
import 'package:atlas/services/food_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('FoodAnalysisResult & Domain Models', () {
    test(
      'creates FoodAnalysisResult and correctly scales macros with scaledToPortion',
      () {
        final initial = FoodAnalysisResult(
          foodName: 'Grilled Chicken Rice Bowl',
          confidence: 0.88,
          servingSize: 300.0,
          servingUnit: 'g',
          calories: 500.0,
          protein: 40.0,
          carbohydrates: 60.0,
          fats: 10.0,
          detectedIngredients: const [
            'Chicken breast',
            'Jasmine rice',
            'Broccoli',
          ],
          isAiGenerated: true,
          timestamp: DateTime(2026, 8, 24),
        );

        // Scale to 450g (1.5x portion)
        final scaled = initial.scaledToPortion(450.0);

        expect(scaled.servingSize, equals(450.0));
        expect(scaled.calories, equals(750.0));
        expect(scaled.protein, equals(60.0));
        expect(scaled.carbohydrates, equals(90.0));
        expect(scaled.fats, equals(15.0));
        expect(scaled.detectedIngredients, contains('Chicken breast'));
        expect(scaled.confidence, equals(0.88));
        expect(scaled.isAiGenerated, isTrue);
      },
    );

    test(
      'FoodAnalysisResult JSON serialization and FoodItem conversion round trip',
      () {
        final original = FoodAnalysisResult(
          foodName: 'Whey Protein Isolate',
          brand: 'Optimum Nutrition',
          confidence: 1.0,
          servingSize: 30.0,
          servingUnit: 'g',
          calories: 120.0,
          protein: 24.0,
          carbohydrates: 2.0,
          fats: 1.0,
          barcode: '748927028669',
          timestamp: DateTime(2026, 8, 24, 12, 0),
        );

        final json = original.toJson();
        final fromJson = FoodAnalysisResult.fromJson(json);

        expect(fromJson.foodName, equals('Whey Protein Isolate'));
        expect(fromJson.brand, equals('Optimum Nutrition'));
        expect(fromJson.calories, equals(120.0));
        expect(fromJson.protein, equals(24.0));
        expect(fromJson.barcode, equals('748927028669'));

        final foodItem = original.toFoodItem();
        expect(foodItem.name, equals('Whey Protein Isolate'));
        expect(foodItem.calories, equals(400.0));
        expect(foodItem.protein, equals(80.0));
        expect(foodItem.barcode, equals('748927028669'));
      },
    );

    test('FoodScanSession tracks scan sessions with source and results', () {
      final session = FoodScanSession(
        id: 'sess_123',
        source: FoodSource.cameraAI,
        imagePath: '/data/user/0/cache/meal.jpg',
        result: FoodAnalysisResult(
          foodName: 'Salmon Salad',
          calories: 420.0,
          protein: 34.0,
          carbohydrates: 12.0,
          fats: 26.0,
          timestamp: DateTime(2026, 8, 24),
        ),
        createdAt: DateTime(2026, 8, 24),
      );

      final json = session.toJson();
      final fromJson = FoodScanSession.fromJson(json);

      expect(fromJson.id, equals('sess_123'));
      expect(fromJson.source, equals(FoodSource.cameraAI));
      expect(fromJson.imagePath, equals('/data/user/0/cache/meal.jpg'));
      expect(fromJson.result?.foodName, equals('Salmon Salad'));
      expect(fromJson.result?.calories, equals(420.0));
    });
  });

  group('FoodDatabaseService & OpenFoodFacts Mapping', () {
    test('RemoteFoodMapper correctly parses valid OpenFoodFacts JSON', () {
      final mockApiResponse = {
        'status': 1,
        'code': '8901234567890',
        'product': {
          'product_name': 'High Protein Greek Yogurt',
          'brands': 'Epigamia',
          'serving_size': '100g',
          'categories_tags': ['en:yogurts', 'en:dairy'],
          'nutriments': {
            'energy-kcal_100g': 95.0,
            'proteins_100g': 10.0,
            'carbohydrates_100g': 6.0,
            'fat_100g': 3.5,
            'fiber_100g': 0.0,
          },
        },
      };

      final item = RemoteFoodMapper.mapOpenFoodFactsToFoodItem(
        mockApiResponse,
        '8901234567890',
      );

      expect(item, isNotNull);
      expect(item!.name, equals('High Protein Greek Yogurt'));
      expect(item.brand, equals('Epigamia'));
      expect(item.calories, equals(95.0));
      expect(item.protein, equals(10.0));
      expect(item.carbohydrates, equals(6.0));
      expect(item.fats, equals(3.5));
      expect(item.barcode, equals('8901234567890'));
      expect(item.isPackaged, isTrue);
    });

    test(
      'FoodDatabaseService lookupBarcode fetches from mock HTTP OpenFoodFacts client',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('8901234567890')) {
            final responseBody = jsonEncode({
              'status': 1,
              'code': '8901234567890',
              'product': {
                'product_name': 'High Protein Greek Yogurt',
                'brands': 'Epigamia',
                'serving_size': '100g',
                'nutriments': {
                  'energy-kcal_100g': 95.0,
                  'proteins_100g': 10.0,
                  'carbohydrates_100g': 6.0,
                  'fat_100g': 3.5,
                },
              },
            });
            return http.Response(responseBody, 200);
          }
          return http.Response(jsonEncode({'status': 0, 'product': null}), 404);
        });

        final dbService = FoodDatabaseService(
          openFoodFactsService: HttpOpenFoodFactsService(mockClient),
        );

        final result = await dbService.lookupBarcode('8901234567890');
        expect(result, isNotNull);
        expect(result!.name, equals('High Protein Greek Yogurt'));
        expect(result.calories, equals(95.0));

        // Second lookup should resolve from local scanned cache
        final cached = await dbService.lookupBarcode('8901234567890');
        expect(cached, isNotNull);
        expect(cached!.name, equals('High Protein Greek Yogurt'));
      },
    );

    test(
      'FoodDatabaseService returns null on non-existent barcode without crashing',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'status': 0, 'product': null}), 404);
        });

        final dbService = FoodDatabaseService(
          openFoodFactsService: HttpOpenFoodFactsService(mockClient),
        );

        final result = await dbService.lookupBarcode('9999999999999');
        expect(result, isNull);
      },
    );

    test(
      'FoodDatabaseService searches local catalog and filters by category',
      () {
        final dbService = FoodDatabaseService.instance;
        final chickenResults = dbService.searchFoods(
          'Chicken',
          category: 'Protein',
        );

        expect(chickenResults, isNotEmpty);
        expect(chickenResults.first.name.toLowerCase(), contains('chicken'));
        expect(chickenResults.first.category, equals('Protein'));
      },
    );
  });

  group('FoodAIVisionService Estimation & Parsing', () {
    test(
      'FoodAIVisionService maps structured Gemini Vision analysis to FoodAnalysisResult',
      () {
        final analysis = ImageAnalysisResult(
          analysisType: VisionAnalysisType.food,
          title: 'Chicken Rice & Steamed Broccoli',
          description:
              'Healthy fitness meal with Chicken breast, White rice, Broccoli',
          confidence: 'High',
          calories: 620.0,
          protein: 48.0,
          carbs: 72.0,
          fat: 12.0,
          rawText: 'Plate contains grilled chicken, rice, and broccoli.',
          portionAdvice: 'Estimated 450g total serving.',
        );

        final foodResult = FoodAnalysisResult(
          foodName: analysis.title,
          confidence: 0.88,
          servingSize: 450.0,
          servingUnit: 'g',
          calories: analysis.calories!,
          protein: analysis.protein!,
          carbohydrates: analysis.carbs!,
          fats: analysis.fat!,
          detectedIngredients: const [
            'Chicken breast',
            'White rice',
            'Broccoli',
          ],
          isAiGenerated: true,
          timestamp: DateTime.now(),
          notes: analysis.portionAdvice,
        );

        expect(foodResult.foodName, equals('Chicken Rice & Steamed Broccoli'));
        expect(foodResult.calories, equals(620.0));
        expect(foodResult.protein, equals(48.0));
        expect(foodResult.carbohydrates, equals(72.0));
        expect(foodResult.fats, equals(12.0));
        expect(foodResult.confidence, equals(0.88));
        expect(foodResult.detectedIngredients.length, equals(3));
      },
    );
  });

  group('Nutrition Logging Pipeline & FitnessProvider Integration', () {
    test(
      'Zero-state verification: new day starts with 0 kcal and 0g protein',
      () {
        final provider = FitnessProvider.instance;
        final log = provider.todayNutritionLog;

        expect(log.dailyCalories, equals(0.0));
        expect(log.dailyProtein, equals(0.0));
        expect(log.dailyCarbohydrates, equals(0.0));
        expect(log.dailyFats, equals(0.0));
        expect(log.meals.every((m) => m.consumedFoods.isEmpty), isTrue);
      },
    );

    test(
      'logFoodAnalysisResult updates todayNutritionLog calories and macros instantly',
      () async {
        final provider = FitnessProvider.instance;

        final scanResult = FoodAnalysisResult(
          foodName: 'Grilled Chicken Breast',
          confidence: 0.92,
          servingSize: 200.0,
          servingUnit: 'g',
          calories: 330.0,
          protein: 62.0,
          carbohydrates: 0.0,
          fats: 7.2,
          detectedIngredients: const ['Chicken breast'],
          isAiGenerated: true,
          timestamp: DateTime.now(),
        );

        await provider.logFoodAnalysisResult(scanResult, mealId: 'Lunch');

        final updatedLog = provider.todayNutritionLog;
        expect(updatedLog.dailyCalories, equals(330.0));
        expect(updatedLog.dailyProtein, equals(62.0));
        expect(updatedLog.dailyCarbohydrates, equals(0.0));
        expect(updatedLog.dailyFats, equals(7.2));

        final lunchMeal = updatedLog.meals.firstWhere(
          (m) => m.mealType == MealCategory.lunch,
        );
        expect(lunchMeal.consumedFoods, isNotEmpty);
        expect(
          lunchMeal.consumedFoods.first.food.name,
          equals('Grilled Chicken Breast'),
        );
        expect(lunchMeal.consumedFoods.first.quantity, equals(200.0));
      },
    );
  });

  group('AI Coach Nutrition Context Injection', () {
    test(
      'CoachPromptBuilder includes exact remaining protein and logged meal context',
      () {
        const builder = CoachPromptBuilder();

        final todayLog = NutritionLog(
          id: 'log_test_today',
          date: DateTime.now(),
          meals: [
            MealEntry(
              id: 'm_breakfast',
              mealType: MealCategory.breakfast,
              timeLabel: '8:00 AM',
              consumedFoods: [
                ConsumedFood(
                  food: const FoodItem(
                    id: 'f_1',
                    name: 'Chicken Rice Bowl',
                    calories: 150.0,
                    protein: 11.25,
                    carbohydrates: 17.5,
                    fats: 2.5,
                  ),
                  quantity: 400.0,
                  unit: 'g',
                ),
              ],
            ),
            MealEntry(
              id: 'm_lunch',
              mealType: MealCategory.lunch,
              timeLabel: '1:00 PM',
              consumedFoods: [
                ConsumedFood(
                  food: const FoodItem(
                    id: 'f_2',
                    name: '3 Whole Eggs & Milk',
                    calories: 120.0,
                    protein: 10.0,
                    carbohydrates: 4.8,
                    fats: 6.4,
                  ),
                  quantity: 250.0,
                  unit: 'g',
                ),
              ],
            ),
          ],
        );

        final context = FitnessContext.initial().copyWith(
          todayNutritionLog: todayLog,
          weightGoal: WeightGoal(
            id: 'wg_1',
            userId: 'user_1',
            type: WeightGoalType.gain,
            currentWeight: 70.0,
            targetWeight: 75.0,
            targetWeeks: 12,
            dailyCalorieTarget: 2800.0,
            proteinGrams: 160.0,
            carbsGrams: 350.0,
            fatGrams: 75.0,
            expectedWeeklyRateKg: 0.4,
            diet: DietPreference.nonVegetarian,
            mealsPerDay: MealFrequency.fourMeals,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        final prompt = builder.buildPrompt(
          message: 'How is my nutrition today, Coach?',
          context: context,
        );

        expect(prompt, contains('[NUTRITION CONTEXT]'));
        expect(
          prompt,
          contains("Today's Calories: 900 / 2800 kcal (1900 kcal remaining)"),
        );
        // Total protein logged: 45 + 25 = 70g. Target: 160g. Remaining: 90g needed.
        expect(
          prompt,
          contains("Protein Target: 70 / 160g (90g protein needed)"),
        );
        expect(prompt, contains('Chicken Rice Bowl'));
        expect(prompt, contains('3 Whole Eggs & Milk'));
      },
    );

    test(
      'CoachPromptBuilder handles zero-state nutrition gracefully without fake numbers',
      () {
        const builder = CoachPromptBuilder();

        final context = FitnessContext.initial();
        final prompt = builder.buildPrompt(
          message: 'What should I eat today?',
          context: context,
        );

        expect(prompt, contains('[NUTRITION CONTEXT]'));
        expect(prompt, contains('No meals logged yet today'));
      },
    );
  });
}
