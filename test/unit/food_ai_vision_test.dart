import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_analysis_result.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FoodAIVisionService.resetInstance();
  });

  group('1. FoodAnalysisResult Domain Model Tests', () {
    test('Serializes to JSON and deserializes correctly', () {
      final now = DateTime.now();
      final result = FoodAnalysisResult(
        foodName: 'Grilled Chicken Salad',
        confidence: 0.94,
        servingSize: 320.0,
        servingUnit: 'g',
        calories: 420.0,
        protein: 40.0,
        carbohydrates: 15.0,
        fats: 18.0,
        ingredients: ['Chicken Breast', 'Lettuce', 'Olive Oil', 'Tomatoes'],
        isAiGenerated: true,
        timestamp: now,
        notes: 'High protein fresh salad',
      );

      final json = result.toJson();
      expect(json['foodName'], equals('Grilled Chicken Salad'));
      expect(json['confidence'], equals(0.94));
      expect(json['calories'], equals(420.0));
      expect(json['protein'], equals(40.0));
      expect(json['carbohydrates'], equals(15.0));
      expect(json['fats'], equals(18.0));
      expect(json['ingredients'], contains('Chicken Breast'));
      expect(json['isAiGenerated'], isTrue);

      final reconstructed = FoodAnalysisResult.fromJson(json);
      expect(reconstructed.foodName, equals(result.foodName));
      expect(reconstructed.confidence, equals(result.confidence));
      expect(reconstructed.confidenceScore, equals(result.confidence));
      expect(reconstructed.servingSize, equals(result.servingSize));
      expect(reconstructed.calories, equals(result.calories));
      expect(reconstructed.protein, equals(result.protein));
      expect(reconstructed.ingredients, equals(result.ingredients));
    });

    test(
      'FoodAnalysisResult.empty initializes zeroed failure/placeholder state',
      () {
        final empty = FoodAnalysisResult.empty();
        expect(empty.foodName, isEmpty);
        expect(empty.confidence, equals(0.0));
        expect(empty.confidenceScore, equals(0.0));
        expect(empty.calories, equals(0.0));
        expect(empty.protein, equals(0.0));
        expect(empty.carbohydrates, equals(0.0));
        expect(empty.fats, equals(0.0));
        expect(empty.detectedIngredients, isEmpty);
        expect(empty.isAiGenerated, isFalse);
      },
    );

    test(
      'scaledToPortion scales calories and macronutrients proportionally',
      () {
        final base = FoodAnalysisResult(
          foodName: 'Chicken Breast',
          confidence: 0.95,
          servingSize: 200.0,
          servingUnit: 'g',
          calories: 330.0,
          protein: 62.0,
          carbohydrates: 0.0,
          fats: 7.2,
          timestamp: DateTime.now(),
        );

        final scaled300g = base.scaledToPortion(300.0);
        expect(scaled300g.servingSize, equals(300.0));
        expect(scaled300g.calories, equals(495.0)); // 330 * 1.5
        expect(scaled300g.protein, equals(93.0)); // 62 * 1.5
        expect(scaled300g.carbohydrates, equals(0.0));
        expect(scaled300g.fats, equals(10.8)); // 7.2 * 1.5
      },
    );

    test('Confidence level categorization and requiresVerification checks', () {
      final highResult = FoodAnalysisResult(
        foodName: 'Oatmeal',
        confidence: 0.88,
        calories: 200,
        protein: 8,
        carbohydrates: 34,
        fats: 3,
        timestamp: DateTime.now(),
      );
      expect(highResult.confidenceLevel, equals('High'));
      expect(highResult.requiresVerification, isFalse);

      final medResult = highResult.copyWith(confidence: 0.65);
      expect(medResult.confidenceLevel, equals('Medium'));
      expect(medResult.requiresVerification, isFalse);

      final lowResult = highResult.copyWith(confidence: 0.42);
      expect(lowResult.confidenceLevel, equals('Low'));
      expect(lowResult.requiresVerification, isTrue);
    });

    test('toFoodItem converts analysis result into normalized FoodItem', () {
      final result = FoodAnalysisResult(
        foodName: 'Avocado Toast',
        confidence: 0.91,
        servingSize: 150.0,
        servingUnit: 'g',
        calories: 300.0,
        protein: 9.0,
        carbohydrates: 30.0,
        fats: 15.0,
        ingredients: ['Whole grain bread', 'Avocado', 'Chia seeds'],
        isAiGenerated: true,
        timestamp: DateTime.now(),
      );

      final foodItem = result.toFoodItem();
      expect(foodItem.name, equals('Avocado Toast'));
      expect(foodItem.isCustom, isTrue);
      expect(foodItem.category, equals('AI Scanned'));
      expect(foodItem.description, contains('Whole grain bread'));
      // 300 kcal per 150g -> 200 kcal per 100g
      expect(foodItem.calories, equals(200.0));
    });
  });

  group('2. Gemini Vision JSON Parsing & Macro Extraction Tests', () {
    test(
      'Parses clean Gemini Vision JSON response and creates FoodAnalysisResult',
      () {
        final service = FoodAIVisionService();
        const sampleResponse = '''
{
  "foodName": "Chicken rice bowl",
  "ingredients": ["chicken breast", "white rice", "vegetables"],
  "servingSize": 450,
  "servingUnit": "grams",
  "calories": 620,
  "protein": 48,
  "carbohydrates": 75,
  "fats": 12,
  "confidence": 0.82
}
''';

        final result = service.parseGeminiVisionResponse(sampleResponse);
        expect(result.foodName, equals('Chicken rice bowl'));
        expect(result.confidence, equals(0.82));
        expect(result.servingSize, equals(450.0));
        expect(result.calories, equals(620.0));
        expect(result.protein, equals(48.0));
        expect(result.carbohydrates, equals(75.0));
        expect(result.fats, equals(12.0));
        expect(result.ingredients, contains('chicken breast'));
        expect(result.ingredients, contains('white rice'));
        expect(result.isAiGenerated, isTrue);
      },
    );

    test('Strips markdown code fences (```json ... ```) gracefully', () {
      final service = FoodAIVisionService();
      const markdownWrapped = '''
```json
{
  "foodName": "Protein Pancakes",
  "ingredients": ["Oats", "Whey Protein", "Egg Whites", "Blueberries"],
  "confidence": 0.88,
  "servingSize": 250.0,
  "servingUnit": "g",
  "calories": 380.0,
  "protein": 35.0,
  "carbohydrates": 42.0,
  "fats": 6.0,
  "is_food": true
}
```
''';

      final result = service.parseGeminiVisionResponse(markdownWrapped);
      expect(result.foodName, equals('Protein Pancakes'));
      expect(result.calories, equals(380.0));
      expect(result.protein, equals(35.0));
      expect(result.confidence, equals(0.88));
    });
  });

  group('3. Vision Error Handling & Failure Case Tests', () {
    test(
      'Throws FoodVisionException with "No food detected" when is_food is false',
      () {
        final service = FoodAIVisionService();
        const nonFoodJson = '''
{
  "is_food": false,
  "confidence": 0.0,
  "notes": "No food detected in this image"
}
''';

        expect(
          () => service.parseGeminiVisionResponse(nonFoodJson),
          throwsA(
            isA<FoodVisionException>().having(
              (e) => e.message,
              'message',
              contains(
                'No food detected. Try another image with better lighting.',
              ),
            ),
          ),
        );
      },
    );

    test(
      'Throws FoodVisionException with "Unable to analyze this image" on malformed JSON',
      () {
        final service = FoodAIVisionService();
        const brokenText = 'This is an image of a gym weight dumbbell.';

        expect(
          () => service.parseGeminiVisionResponse(brokenText),
          throwsA(
            isA<FoodVisionException>().having(
              (e) => e.message,
              'message',
              contains('Unable to analyze this image.'),
            ),
          ),
        );
      },
    );

    test(
      'Throws FoodVisionException saying the build has no AI backend when there is no key and no proxy',
      () async {
        final dummyConfig = AIConfig(apiKey: '', model: 'gemini-2.5-flash');
        final service = FoodAIVisionService(config: dummyConfig);

        final dummyAttachment = ChatAttachment(
          base64Data: 'dummy_base64_data',
          mimeType: 'image/jpeg',
        );

        expect(
          () => service.analyzeMealImage(attachment: dummyAttachment),
          throwsA(
            isA<FoodVisionException>().having(
              (e) => e.message,
              'message',
              contains('Atlas AI is not set up in this build'),
            ),
          ),
        );
      },
    );
  });

  group('4. End-to-End Gemini Vision Pipeline & Mock Client Tests', () {
    test(
      'Executes HTTP call with multimodal inline_data and returns parsed result',
      () async {
        final mockClient = MockClient((request) async {
          expect(
            request.url.toString(),
            contains('generativelanguage.googleapis.com'),
          );
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['contents'], isNotEmpty);

          final sampleResponse = {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'foodName': 'Tofu Stir Fry with Jasmine Rice',
                        'ingredients': [
                          'Tofu',
                          'Bell Peppers',
                          'Jasmine Rice',
                          'Soy Sauce',
                        ],
                        'confidence': 0.91,
                        'servingSize': 350.0,
                        'servingUnit': 'g',
                        'calories': 450.0,
                        'protein': 25.0,
                        'carbohydrates': 65.0,
                        'fats': 10.0,
                        'is_food': true,
                      }),
                    },
                  ],
                },
              },
            ],
          };

          return http.Response(jsonEncode(sampleResponse), 200);
        });

        final config = AIConfig(
          apiKey: 'test_key_abc_123',
          model: 'gemini-2.5-flash',
        );
        final service = FoodAIVisionService(
          config: config,
          httpClient: mockClient,
        );

        final attachment = service.prepareImageBytes(
          bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
          mimeType: 'image/jpeg',
        );

        final result = await service.analyzeMealImage(attachment: attachment!);
        expect(result.foodName, equals('Tofu Stir Fry with Jasmine Rice'));
        expect(result.calories, equals(450.0));
        expect(result.protein, equals(25.0));
        expect(result.carbohydrates, equals(65.0));
        expect(result.fats, equals(10.0));
        expect(result.confidenceLevel, equals('High'));
      },
    );
  });

  group('5. FitnessProvider Nutrition Pipeline Logging Tests', () {
    test(
      'logFoodAnalysisResult updates daily calories, macros, and meal history',
      () async {
        final provider = FitnessProvider.instance;

        final analysis = FoodAnalysisResult(
          foodName: 'Greek Yogurt with Blueberries',
          confidence: 0.95,
          servingSize: 200.0,
          servingUnit: 'g',
          calories: 180.0,
          protein: 20.0,
          carbohydrates: 18.0,
          fats: 2.0,
          ingredients: ['Greek Yogurt', 'Blueberries', 'Honey'],
          isAiGenerated: true,
          timestamp: DateTime.now(),
        );

        final initialCalories = provider.todayNutritionLog.dailyCalories;
        final initialProtein = provider.todayNutritionLog.dailyProtein;

        await provider.logFoodAnalysisResult(analysis, mealId: 'Breakfast');

        final updatedCalories = provider.todayNutritionLog.dailyCalories;
        final updatedProtein = provider.todayNutritionLog.dailyProtein;

        expect(updatedCalories, equals(initialCalories + 180.0));
        expect(updatedProtein, equals(initialProtein + 20.0));
        expect(provider.todaysMeals.isNotEmpty, isTrue);

        final loggedItem = provider.todaysMeals
            .expand((m) => m.consumedFoods)
            .firstWhere((c) => c.food.name == 'Greek Yogurt with Blueberries');
        expect(loggedItem.food.name, equals('Greek Yogurt with Blueberries'));
        expect(loggedItem.quantity, equals(200.0));
      },
    );
  });

  group('6. Live Gemini API Food Vision Test', () {
    test(
      'Real Gemini API analyzes sample food image if GEMINI_API_KEY is configured',
      () async {
        HttpOverrides.global = null;
        final envKey = Platform.environment['GEMINI_API_KEY'] ?? '';
        if (envKey.isNotEmpty) {
          final config = AIConfig(apiKey: envKey, model: 'gemini-2.5-flash');
          final service = FoodAIVisionService(config: config);

          // 1x1 png sample
          final sampleImageBytes = base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
          );

          final attachment = service.prepareImageBytes(
            bytes: sampleImageBytes,
            mimeType: 'image/png',
          );

          try {
            final result = await service.analyzeMealImage(
              attachment: attachment!,
            );
            expect(result.foodName.isNotEmpty, isTrue);
          } on FoodVisionException catch (e) {
            // Expected when a 1x1 single pixel test image contains no food
            expect(
              e.message.contains('No food detected') ||
                  e.message.contains('Unable to analyze') ||
                  e.message.contains('AI analysis unavailable'),
              isTrue,
            );
          }
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
      skip: Platform.environment['RUN_LIVE_AI_TESTS'] == '1'
          ? null
          : 'Set RUN_LIVE_AI_TESTS=1 and GEMINI_API_KEY to call the real API',
    );
  });
}
