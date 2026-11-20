import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:atlas/models/food_analysis_result.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/food_scan_result.dart';
import 'package:atlas/models/nutrient_status.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';

const _photo = ChatAttachment(base64Data: 'aGVsbG8=', mimeType: 'image/jpeg');

FoodAIVisionService _service({MockClient? client}) => FoodAIVisionService(
  config: AIConfig(
    proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
    accessTokenProvider: () => 'user-token',
  ),
  httpClient: client ?? MockClient((_) async => http.Response('{}', 200)),
);

FoodAnalysisResult _parse(Map<String, dynamic> estimate) =>
    _service().parseGeminiVisionResponse(jsonEncode(estimate));

/// What the model said for the Mountain Dew bottle in the bug report.
Map<String, dynamic> _bottle({
  Map<String, dynamic> override = const {},
  List<String> remove = const [],
}) {
  final m = <String, dynamic>{
    'is_food': true,
    'foodName': 'Mountain Dew',
    'brand': 'PepsiCo',
    'isPackagedProduct': true,
    'servingSize': 600,
    'servingUnit': 'ml',
    'calories': 287,
    'protein': 0,
    'carbohydrates': 78,
    'fats': 0,
    'confidence': 0.9,
    ...override,
  };
  for (final k in remove) {
    m.remove(k);
  }
  return m;
}

/// A plate of home food: nothing packaged about it.
Map<String, dynamic> _plate({
  Map<String, dynamic> override = const {},
  List<String> remove = const [],
}) {
  final m = <String, dynamic>{
    'is_food': true,
    'foodName': 'Rice and dal',
    'servingSize': 350,
    'servingUnit': 'g',
    'calories': 480,
    'protein': 14,
    'carbohydrates': 80,
    'fats': 9,
    'confidence': 0.7,
    ...override,
  };
  for (final k in remove) {
    m.remove(k);
  }
  return m;
}

void main() {
  group('a zero from the model is not a measured zero', () {
    test('zero protein and fat from a photo are unknown, not 0.0 g', () {
      final r = _parse(_bottle());

      expect(r.unknownNutrients, {FoodItem.proteinKey, FoodItem.fatKey});
      expect(r.carbohydrates, 78);
      expect(r.calories, 287);
    });

    test('they reach the food item as unknown', () {
      final food = _parse(_bottle()).toFoodItem();

      expect(food.isNutrientKnown(FoodItem.proteinKey), isFalse);
      expect(food.isNutrientKnown(FoodItem.fatKey), isFalse);
      expect(food.isNutrientKnown(FoodItem.carbohydrateKey), isTrue);
      expect(food.isNutrientKnown(FoodItem.calorieKey), isTrue);
    });

    test('a missing macro is unknown too, never zero', () {
      for (final (key, nutrient) in [
        ('protein', FoodItem.proteinKey),
        ('carbohydrates', FoodItem.carbohydrateKey),
        ('fats', FoodItem.fatKey),
        ('calories', FoodItem.calorieKey),
      ]) {
        final r = _parse(_plate(remove: [key]));
        expect(r.unknownNutrients, {nutrient}, reason: key);
      }
    });

    test('a null from the model is unknown', () {
      final r = _parse(_plate(override: {'protein': null}));
      expect(r.unknownNutrients, {FoodItem.proteinKey});
    });

    group('a zero counts only when the model confirms it', () {
      Map<String, dynamic> zeros(String name, {Object? confirmed}) => {
        'foodName': name,
        'calories': 0,
        'protein': 0,
        'carbohydrates': 0,
        'fats': 0,
        'confirmedZero': ?confirmed,
      };

      test('four bare zeros are unknown for any food, water included', () {
        // Home food: nothing usable, so it is rejected as incomplete.
        for (final name in ['Water', 'Rice', 'Diet Cola']) {
          expect(
            () => _parse(_plate(override: zeros(name))),
            throwsA(isA<FoodVisionException>()),
            reason: name,
          );
        }
        // A packaged product keeps its identity, with every value unknown.
        final r = _parse(
          _bottle(override: zeros('Mineral Water')..['brand'] = 'Brand'),
        );
        expect(r.unknownNutrients, FoodItem.coreNutrients);
      });

      test('the same answer gives the same result whatever the name is', () {
        Set<String> unknownFor(String name) => _parse(
          _bottle(
            override: zeros(name, confirmed: ['calories'])
              ..['brand'] = 'Brand',
          ),
        ).unknownNutrients;
        expect(unknownFor('Water'), unknownFor('Fanta'));
        expect(unknownFor('Water'), isNot(contains(FoodItem.calorieKey)));
      });

      test('all four confirmed is a zero-calorie food, still an estimate', () {
        final r = _parse(
          _plate(
            override: zeros(
              'Water',
              confirmed: ['calories', 'protein', 'carbohydrates', 'fats'],
            ),
          ),
        );
        expect(r.unknownNutrients, isEmpty);
        expect(r.calories, 0);
        final food = r.toFoodItem();
        expect(food.statusOf(FoodItem.calorieKey), NutrientStatus.estimate);
      });

      test('a legitimate zero in a food that is not water is kept', () {
        // Black coffee: energy and protein are small, fat and carbs are none.
        final r = _parse(
          _plate(
            override: {
              'foodName': 'Black coffee',
              'servingSize': 240,
              'servingUnit': 'ml',
              'calories': 2,
              'protein': 0.3,
              'carbohydrates': 0,
              'fats': 0,
              'confirmedZero': ['carbs', 'fat'],
            },
          ),
        );
        expect(r.unknownNutrients, isEmpty);
        expect(r.carbohydrates, 0);
        expect(r.fats, 0);
      });

      test('only the named nutrients are zeros, the rest stay unknown', () {
        final r = _parse(
          _plate(
            override: {
              'calories': 120,
              'protein': 0,
              'carbohydrates': 0,
              'fats': 5,
              'confirmedZero': ['protein'],
            },
          ),
        );
        expect(r.unknownNutrients, {FoodItem.carbohydrateKey});
      });

      test('zero calories next to a macro that is not zero is not trusted', () {
        final r = _parse(
          _plate(
            override: {
              'calories': 0,
              'protein': 5,
              'carbohydrates': 10,
              'fats': 2,
              'confirmedZero': ['calories'],
            },
          ),
        );
        expect(r.unknownNutrients, {FoodItem.calorieKey});
      });

      test('a confirmation that is not a list is ignored', () {
        final r = _parse(
          _plate(
            override: {
              'calories': 0,
              'protein': 4,
              'carbohydrates': 9,
              'fats': 1,
              'confirmedZero': 'calories',
            },
          ),
        );
        expect(r.unknownNutrients, {FoodItem.calorieKey});
      });

      test('a number is never turned into zero by being confirmed', () {
        final r = _parse(_plate(override: {'confirmedZero': ['protein']}));
        expect(r.protein, isNot(0));
        expect(r.unknownNutrients, isEmpty);
      });
    });

    test('a saved result with a missing number reads it as unknown', () {
      final r = FoodAnalysisResult.fromJson({
        'foodName': 'Soup',
        'servingSize': 300,
        'servingUnit': 'g',
        'calories': 150,
        'protein': 6,
        // carbohydrates and fats were never saved
      });
      expect(r.unknownNutrients, {
        FoodItem.carbohydrateKey,
        FoodItem.fatKey,
      });
      expect(r.calories, 150);
    });

    test('saved numbers, including a saved zero, stay values', () {
      final r = FoodAnalysisResult.fromJson({
        'foodName': 'Soup',
        'calories': 150,
        'protein': 0,
        'carbohydrates': 12,
        'fats': 5,
      });
      expect(r.unknownNutrients, isEmpty);
    });

    test('numbers that are present and non-zero are known', () {
      final r = _parse(_plate());
      expect(r.unknownNutrients, isEmpty);
    });

    test('negative numbers are still an invalid answer', () {
      for (final key in ['calories', 'protein', 'carbohydrates', 'fats']) {
        expect(
          () => _parse(_plate(override: {key: -5})),
          throwsA(isA<FoodVisionException>()),
          reason: key,
        );
      }
    });

    test('unknown nutrients survive scaling and copying', () {
      final r = _parse(_bottle());
      expect(r.copyWith(foodName: 'x').unknownNutrients, r.unknownNutrients);
      expect(r.scaledToPortion(300).unknownNutrients, r.unknownNutrients);
    });
  });

  group('an answer with no nutrition at all', () {
    test('is an error for home food: there is nothing to show', () {
      expect(
        () => _parse(
          _plate(remove: ['calories', 'protein', 'carbohydrates', 'fats']),
        ),
        throwsA(
          isA<FoodVisionException>().having(
            (e) => e.message,
            'message',
            contains('complete nutrition estimate'),
          ),
        ),
      );
    });

    test('is fine for a packaged product: it identifies the product', () {
      final r = _parse(
        _bottle(
          remove: [
            'calories',
            'protein',
            'carbohydrates',
            'fats',
            'servingSize',
            'servingUnit',
          ],
        ),
      );

      expect(r.isPackagedProduct, isTrue);
      expect(r.brand, 'PepsiCo');
      expect(r.unknownNutrients, FoodItem.coreNutrients);
      expect(r.servingSize, 0, reason: 'no portion is invented');
    });
  });

  group('the portion', () {
    test('home food still needs a portion', () {
      for (final bad in [
        _plate(remove: ['servingSize']),
        _plate(override: {'servingSize': 0}),
      ]) {
        expect(() => _parse(bad), throwsA(isA<FoodVisionException>()));
      }
    });

    test('a packaged product may come without one', () {
      final r = _parse(_bottle(remove: ['servingSize']));
      expect(r.servingSize, 0);
    });

    test('a packaged product with a guess keeps the guess as a guess', () {
      final r = _parse(_bottle());
      expect(r.isPackagedProduct, isTrue);
      expect(r.servingSize, 600);
    });
  });

  group('what the model read on the label', () {
    test('brand, variant and a printed pack size are kept', () {
      final r = _parse(
        _bottle(
          override: {
            'variant': 'Zero Sugar',
            'packageSize': 750,
            'packageUnit': 'ml',
          },
        ),
      );

      expect(r.brand, 'PepsiCo');
      expect(r.variant, 'Zero Sugar');
      expect(r.labelPackageSize, 750);
      expect(r.labelPackageUnit, 'ml');
    });

    test('litres are converted to ml', () {
      final r = _parse(
        _bottle(override: {'packageSize': 0.75, 'packageUnit': 'L'}),
      );
      expect(r.labelPackageSize, 750);
      expect(r.labelPackageUnit, 'ml');
    });

    test('a pack size that is not a number is ignored', () {
      final r = _parse(_bottle(override: {'packageSize': 'big'}));
      expect(r.labelPackageSize, isNull);
    });

    test('empty text fields are null', () {
      final r = _parse(_bottle(override: {'brand': '  ', 'variant': ''}));
      expect(r.brand, isNull);
      expect(r.variant, isNull);
    });

    test('a brand alone marks it packaged', () {
      final r = _parse(
        _bottle(remove: ['isPackagedProduct'], override: {'brand': 'Amul'}),
      );
      expect(r.isPackagedProduct, isTrue);
    });

    test('home food is not packaged', () {
      expect(_parse(_plate()).isPackagedProduct, isFalse);
    });

    test('an old-style answer without these fields still parses', () {
      final r = _parse(_plate());
      expect(r.brand, isNull);
      expect(r.variant, isNull);
      expect(r.labelPackageSize, isNull);
    });
  });

  group('the AI food item', () {
    test('is marked as an AI estimate with a per-100 basis', () {
      final ml = _parse(_bottle()).toFoodItem();
      expect(ml.nutritionSource, NutritionSource.aiEstimate);
      expect(ml.nutritionBasis, NutritionBasis.per100ml);

      final g = _parse(_plate()).toFoodItem();
      expect(g.nutritionBasis, NutritionBasis.per100g);
      expect(g.nutritionSource, NutritionSource.aiEstimate);
    });

    test('a portion in cups has values for one cup', () {
      final r = _parse(
        _plate(override: {'servingUnit': 'cup', 'servingSize': 2}),
      );
      final food = r.toFoodItem();
      expect(food.nutritionBasis, NutritionBasis.perServing);
      // 480 kcal for 2 cups is 240 per cup, never read as per 100 g.
      expect(food.calories, 240);
    });
  });

  group('the prompt', () {
    test('asks for brand and label details and forbids guessing', () async {
      late String prompt;
      final service = _service(
        client: MockClient((request) async {
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

      expect(prompt, contains('brand'));
      expect(prompt, contains('isPackagedProduct'));
      expect(prompt, contains('packageSize'));
      expect(prompt, contains('null'));
      expect(prompt.toLowerCase(), contains('never use 0'));
      expect(prompt.toLowerCase(), contains('do not estimate'));
    });
  });

  group('the scan result', () {
    FoodScanResult scan(FoodAnalysisResult r, {bool confirmed = false}) =>
        FoodScanResult(
          scanType: FoodScanType.aiVision,
          food: r.toFoodItem(),
          estimatedQuantity: r.servingSize,
          estimatedUnit: r.servingUnit,
          portionConfirmed: confirmed,
        );

    test('knows which values are unknown', () {
      final s = scan(_parse(_bottle()));
      expect(s.isKnown(FoodItem.calorieKey), isTrue);
      expect(s.isKnown(FoodItem.proteinKey), isFalse);
      expect(s.isKnown(FoodItem.fatKey), isFalse);
    });

    test('the calorie cross-check is skipped when a macro is unknown', () {
      // 287 kcal against 78 g carbs alone looks "wrong" only because protein
      // and fat are unknown, not because the numbers disagree.
      expect(scan(_parse(_bottle())).caloriesMatchMacros, isTrue);
    });

    test('the cross-check still runs on complete numbers', () {
      final s = scan(_parse(_plate(override: {'calories': 900})));
      expect(s.caloriesMatchMacros, isFalse);
    });

    test('a portion is known only when it is above zero', () {
      expect(scan(_parse(_bottle())).portionKnown, isTrue);
      expect(
        scan(_parse(_bottle(remove: ['servingSize']))).portionKnown,
        isFalse,
      );
    });

    test('the portion is unconfirmed by default only when asked', () {
      expect(scan(_parse(_bottle())).portionConfirmed, isFalse);
      expect(
        FoodScanResult(
          scanType: FoodScanType.barcodeOrQr,
          food: _parse(_bottle()).toFoodItem(),
        ).portionConfirmed,
        isTrue,
      );
    });
  });

  group('FoodItem source', () {
    test('is saved and loaded', () {
      const food = FoodItem(
        id: 'x',
        name: 'X',
        calories: 49,
        nutritionSource: NutritionSource.openFoodFacts,
        sourceUrl: 'https://world.openfoodfacts.org/product/1',
      );
      final back = FoodItem.fromJson(food.toJson());
      expect(back.nutritionSource, NutritionSource.openFoodFacts);
      expect(back.sourceUrl, 'https://world.openfoodfacts.org/product/1');
    });

    test('a food saved before has an unknown source, not a claimed one', () {
      final old = FoodItem.fromJson({
        'id': 'x',
        'name': 'X',
        'calories': 10,
        'isPackaged': true,
        'barcode': '1',
      });
      expect(old.nutritionSource, NutritionSource.unknown);
      expect(old.sourceUrl, isNull);
    });

    test('an unrecognised saved source is unknown', () {
      final f = FoodItem.fromJson({
        'id': 'x',
        'name': 'X',
        'nutritionSource': 'verified',
      });
      expect(f.nutritionSource, NutritionSource.unknown);
    });

    test('copyWith keeps and changes it', () {
      const food = FoodItem(
        id: 'x',
        name: 'X',
        calories: 1,
        nutritionSource: NutritionSource.openFoodFacts,
      );
      expect(
        food.copyWith(name: 'Y').nutritionSource,
        NutritionSource.openFoodFacts,
      );
      expect(
        food
            .copyWith(nutritionSource: NutritionSource.userEntry)
            .nutritionSource,
        NutritionSource.userEntry,
      );
    });
  });
}
