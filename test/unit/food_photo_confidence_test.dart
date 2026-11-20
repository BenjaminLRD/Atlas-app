import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:atlas/models/food_analysis_result.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/food_scan_result.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';

const _photo = ChatAttachment(base64Data: 'aGVsbG8=', mimeType: 'image/jpeg');

FoodAIVisionService _service(Map<String, dynamic> estimate) =>
    FoodAIVisionService(
      config: AIConfig(
        proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
        accessTokenProvider: () => 'user-token',
      ),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': jsonEncode(estimate)},
                  ],
                },
              },
            ],
          }),
          200,
        ),
      ),
    );

/// What the model said for a can of Mountain Dew.
Map<String, dynamic> _mountainDew({Map<String, dynamic> override = const {}}) =>
    {
      'is_food': true,
      'foodName': 'Mountain Dew',
      'ingredients': ['carbonated water', 'high fructose corn syrup'],
      'servingSize': 450,
      'servingUnit': 'ml',
      'calories': 207,
      'protein': 0,
      'carbohydrates': 56,
      'fats': 0,
      'confidence': 0.95,
      ...override,
    };

FoodAnalysisResult _result({
  double confidence = 0.9,
  double size = 450,
  String unit = 'ml',
  double calories = 207,
  double protein = 0,
  double carbs = 56,
  double fats = 0,
}) => FoodAnalysisResult(
  foodName: 'Mountain Dew',
  confidence: confidence,
  servingSize: size,
  servingUnit: unit,
  calories: calories,
  protein: protein,
  carbohydrates: carbs,
  fats: fats,
  isAiGenerated: true,
  timestamp: DateTime(2026, 10, 22),
);

FoodScanResult _scan(FoodAnalysisResult a) => FoodScanResult(
  scanType: FoodScanType.aiVision,
  food: a.toFoodItem(customId: 'ai'),
  estimatedQuantity: a.servingSize,
  estimatedUnit: a.servingUnit,
  confidence: a.photoEstimateLevel,
  modelConfidence: a.confidence,
);

void main() {
  group('confidence of an AI photo estimate', () {
    test('is never "High", however confident the model says it is', () {
      for (final c in [1.0, 0.99, 0.95, 0.82, 0.8, 0.7, 0.5]) {
        final level = _result(confidence: c).photoEstimateLevel;
        expect(level, FoodAnalysisResult.photoLevelUnverified, reason: '$c');
        expect(level, isNot('High'));
        expect(level, isNot('Medium'));
      }
    });

    test('a low model confidence is flagged low', () {
      for (final c in [0.49, 0.3, 0.0]) {
        expect(
          _result(confidence: c).photoEstimateLevel,
          FoodAnalysisResult.photoLevelLow,
          reason: '$c',
        );
      }
    });

    test(
      'a successful answer with a recognised name stays unverified',
      () async {
        final r = await _service(
          _mountainDew(),
        ).analyzeMealImage(attachment: _photo);

        expect(r.foodName, 'Mountain Dew');
        expect(
          r.confidence,
          0.95,
          reason: 'the model\'s number is kept as said',
        );
        expect(r.photoEstimateLevel, 'Unverified');
      },
    );

    test('a missing confidence is not read as confident', () async {
      final estimate = _mountainDew()..remove('confidence');
      final r = await _service(estimate).analyzeMealImage(attachment: _photo);
      expect(r.confidence, 0.5);
      expect(r.photoEstimateLevel, 'Unverified');
    });

    test('verified package data keeps its own meaning', () {
      const food = FoodItem(
        id: 'scanned_1',
        name: 'Soda',
        calories: 46,
        protein: 0,
        carbohydrates: 12.4,
        fats: 0,
        isPackaged: true,
        barcode: '1',
      );
      final r = FoodAnalysisResult.fromFoodItem(food);
      expect(r.confidenceLevel, 'High');
      expect(r.isAiGenerated, isFalse);
    });

    test('the scan keeps the model number and shows the cautious label', () {
      final scan = _scan(_result(confidence: 0.9));
      expect(scan.confidence, 'Unverified');
      expect(scan.modelConfidence, 0.9);
      expect(scan.isAiEstimate, isTrue);

      final low = _scan(_result(confidence: 0.2));
      expect(low.confidence, 'Low');
    });
  });

  group('beverage portions', () {
    test('the Mountain Dew estimate: 450 ml, 207 kcal, 56 g carbs', () async {
      final r = await _service(
        _mountainDew(),
      ).analyzeMealImage(attachment: _photo);

      expect(r.servingSize, 450);
      expect(r.servingUnit, 'ml');
      expect(r.calories, 207);
      expect(r.carbohydrates, 56);
      expect(r.protein, 0);
      expect(r.fats, 0);

      // Stored per 100 ml, shown and logged for the whole portion.
      final food = r.toFoodItem();
      expect(food.calories, closeTo(46, 0.01));
      expect(food.carbohydrates, closeTo(12.44, 0.01));
      final scan = _scan(r);
      expect(scan.estimatedCalories, closeTo(207, 0.01));
      expect(scan.estimatedCarbs, closeTo(56, 0.01));
    });

    test('spellings of millilitres all become ml with the same size', () {
      for (final unit in [
        'ml',
        'mL',
        'ML',
        'milliliters',
        'Milliliter',
        'millilitres',
        'cc',
        ' ml ',
      ]) {
        final n = FoodAIVisionService.normalizeServing(450, unit);
        expect(n.unit, 'ml', reason: unit);
        expect(n.size, 450, reason: unit);
      }
    });

    test('spellings of grams all become g', () {
      for (final unit in ['g', 'G', 'gr', 'gram', 'Grams', 'grams']) {
        final n = FoodAIVisionService.normalizeServing(120, unit);
        expect(n.unit, 'g', reason: unit);
        expect(n.size, 120);
      }
    });

    test('litres, kilograms and ounces are converted', () {
      final l = FoodAIVisionService.normalizeServing(1.5, 'litres');
      expect((l.size, l.unit), (1500.0, 'ml'));
      final capL = FoodAIVisionService.normalizeServing(0.5, 'L');
      expect((capL.size, capL.unit), (500.0, 'ml'));
      final kg = FoodAIVisionService.normalizeServing(0.25, 'kg');
      expect((kg.size, kg.unit), (250.0, 'g'));
      final flOz = FoodAIVisionService.normalizeServing(12, 'fl oz');
      expect(flOz.unit, 'ml');
      expect(flOz.size, closeTo(354.88, 0.01));
      final dotted = FoodAIVisionService.normalizeServing(12, 'fl. oz.');
      expect(dotted.unit, 'ml');
      final oz = FoodAIVisionService.normalizeServing(4, 'oz');
      expect(oz.unit, 'g');
      expect(oz.size, closeTo(113.4, 0.01));
    });

    test('other units are kept as they are, never guessed into a weight', () {
      for (final unit in ['cup', 'slice', 'piece', 'bottle', 'can']) {
        final n = FoodAIVisionService.normalizeServing(2, unit);
        expect(n.unit, unit);
        expect(n.size, 2);
      }
      expect(FoodAIVisionService.normalizeServing(2, '').unit, 'g');
    });

    test(
      'a beverage reported in millilitres or litres gives the same totals',
      () async {
        final ml = await _service(
          _mountainDew(override: {'servingUnit': 'milliliters'}),
        ).analyzeMealImage(attachment: _photo);
        final litres = await _service(
          _mountainDew(override: {'servingSize': 0.45, 'servingUnit': 'L'}),
        ).analyzeMealImage(attachment: _photo);

        expect(ml.servingUnit, 'ml');
        expect(litres.servingUnit, 'ml');
        expect(litres.servingSize, closeTo(450, 0.001));
        expect(_scan(ml).estimatedCalories, closeTo(207, 0.01));
        expect(_scan(litres).estimatedCalories, closeTo(207, 0.01));
      },
    );

    test(
      'the prompt asks for ml for drinks and totals for the whole portion',
      () async {
        late String prompt;
        final service = FoodAIVisionService(
          config: AIConfig(
            proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
            accessTokenProvider: () => 'user-token',
          ),
          httpClient: MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final parts =
                (body['request']['contents'] as List).single['parts'] as List;
            prompt = parts.first['text'] as String;
            return http.Response('{}', 200);
          }),
        );
        try {
          await service.analyzeMealImage(attachment: _photo);
        } on FoodVisionException {
          // The empty answer is not the point here.
        }
        expect(prompt, contains('in ml for drinks'));
        expect(prompt, contains('for that whole portion'));
      },
    );

    test('a half portion halves every total', () {
      final scan = _scan(_result()).copyWith(estimatedQuantity: 225);
      expect(scan.estimatedCalories, closeTo(103.5, 0.01));
      expect(scan.estimatedCarbs, closeTo(28, 0.01));
    });
  });

  group('nutrition results that do not add up', () {
    test('the Mountain Dew numbers add up', () {
      expect(_scan(_result()).caloriesMatchMacros, isTrue);
    });

    test('calories far from the macros are flagged', () {
      expect(
        _scan(_result(calories: 500, carbs: 10)).caloriesMatchMacros,
        isFalse,
      );
      expect(
        _scan(_result(calories: 200, carbs: 0)).caloriesMatchMacros,
        isFalse,
      );
    });

    test('tiny calorie counts are not judged', () {
      expect(
        _scan(_result(calories: 5, carbs: 0.5)).caloriesMatchMacros,
        isTrue,
      );
      expect(_scan(_result(calories: 0, carbs: 0)).caloriesMatchMacros, isTrue);
    });

    test('the check follows the edited values', () {
      final scan = _scan(_result());
      final edited = scan.copyWith(food: scan.food.copyWith(calories: 300));
      expect(edited.caloriesMatchMacros, isFalse);
    });
  });

  group('parsing the estimate', () {
    Future<Object> failure(Map<String, dynamic> estimate) async {
      try {
        await _service(estimate).analyzeMealImage(attachment: _photo);
      } on FoodVisionException catch (e) {
        return e.message;
      }
      fail('expected a FoodVisionException');
    }

    test('negative numbers are an invalid answer, not zeros', () async {
      for (final key in ['calories', 'protein', 'carbohydrates', 'fats']) {
        final message = await failure(_mountainDew(override: {key: -5}));
        expect(message, contains('complete nutrition estimate'), reason: key);
      }
    });

    test('a portion of zero or less is invalid', () async {
      expect(
        await failure(_mountainDew(override: {'servingSize': 0})),
        contains('complete nutrition estimate'),
      );
      expect(
        await failure(_mountainDew(override: {'servingSize': -450})),
        contains('complete nutrition estimate'),
      );
    });

    test('text numbers and a missing unit still parse', () async {
      final estimate = _mountainDew(
        override: {
          'servingSize': '450',
          'calories': '207',
          'carbohydrates': '56',
        },
      )..remove('servingUnit');
      final r = await _service(estimate).analyzeMealImage(attachment: _photo);
      expect(r.servingUnit, 'g');
      expect(r.calories, 207);
    });

    test('a model that says it is not food gives no estimate', () async {
      expect(
        await failure({'is_food': false, 'confidence': 0.0}),
        contains('No food detected'),
      );
    });
  });
}
