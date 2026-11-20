import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/services/nutrition/nutrition_calculator.dart';

/// JSON as an older version saved it: no `nutritionBasis` key.
Map<String, dynamic> _legacy({
  String servingUnit = 'grams',
  bool isPackaged = false,
  bool isCustom = false,
  String? barcode,
  double calories = 120,
}) => {
  'id': 'f1',
  'name': 'Thing',
  'servingSize': '100g',
  'servingUnit': servingUnit,
  'calories': calories,
  'protein': 3.0,
  'carbohydrates': 20.0,
  'fats': 2.0,
  'isPackaged': isPackaged,
  'isCustom': isCustom,
  'barcode': ?barcode,
};

FoodItem _roundTrip(FoodItem f) =>
    FoodItem.fromJson(jsonDecode(jsonEncode(f.toJson())));

void main() {
  group('legacy JSON (no nutritionBasis key)', () {
    test('a built-in food in grams is per 100 g', () {
      expect(
        FoodItem.fromJson(_legacy()).nutritionBasis,
        NutritionBasis.per100g,
      );
      expect(
        FoodItem.fromJson(_legacy(servingUnit: 'g')).nutritionBasis,
        NutritionBasis.per100g,
      );
    });

    test('a built-in food in ml is per 100 ml', () {
      expect(
        FoodItem.fromJson(_legacy(servingUnit: 'ml')).nutritionBasis,
        NutritionBasis.per100ml,
      );
    });

    test('a scanned product labelled "grams" stays unknown, not grams', () {
      // Older versions labelled every scanned product "grams", drinks too.
      final f = FoodItem.fromJson(
        _legacy(isPackaged: true, barcode: '8901234567890'),
      );
      expect(f.nutritionBasis, NutritionBasis.unknown);
    });

    test('a custom food is unknown: its numbers are for the typed serving', () {
      final f = FoodItem.fromJson(_legacy(isCustom: true));
      expect(f.nutritionBasis, NutritionBasis.unknown);
    });

    test('per-piece and per-bowl foods are unknown', () {
      for (final unit in ['piece', 'bowl', 'serving', 'cup', '']) {
        expect(
          FoodItem.fromJson(_legacy(servingUnit: unit)).nutritionBasis,
          NutritionBasis.unknown,
          reason: unit,
        );
      }
    });

    test('old unknown-nutrient handling is untouched', () {
      // The old "all zeros" scanned product is still read as unknown
      // nutrition, and its basis is unknown too.
      final f = FoodItem.fromJson(
        _legacy(isPackaged: true, barcode: '1', calories: 0)
          ..['protein'] = 0
          ..['carbohydrates'] = 0
          ..['fats'] = 0,
      );
      expect(f.nutritionUnavailable, isTrue);
      expect(f.nutritionBasis, NutritionBasis.unknown);
    });

    test('an empty object still loads', () {
      final f = FoodItem.fromJson({});
      expect(f.name, 'Food Item');
      // No saved unit: nothing says grams, so it is unknown.
      expect(f.nutritionBasis, NutritionBasis.unknown);
    });
  });

  group('explicit basis', () {
    FoodItem food(NutritionBasis b, {String unit = 'grams'}) => FoodItem(
      id: 'x',
      name: 'X',
      servingUnit: unit,
      calories: 50,
      isPackaged: true,
      barcode: '1',
      nutritionBasis: b,
    );

    test('grams round-trips', () {
      final f = _roundTrip(food(NutritionBasis.per100g));
      expect(f.nutritionBasis, NutritionBasis.per100g);
    });

    test('millilitres round-trips and stays millilitres', () {
      final f = _roundTrip(food(NutritionBasis.per100ml, unit: 'grams'));
      expect(f.nutritionBasis, NutritionBasis.per100ml);
    });

    test('unknown round-trips and is not defaulted to grams', () {
      final f = _roundTrip(food(NutritionBasis.unknown));
      expect(f.nutritionBasis, NutritionBasis.unknown);

      // Even for a plain built-in "grams" food, an explicit unknown wins.
      const explicit = FoodItem(
        id: 'y',
        name: 'Y',
        servingUnit: 'grams',
        calories: 10,
        nutritionBasis: NutritionBasis.unknown,
      );
      expect(_roundTrip(explicit).nutritionBasis, NutritionBasis.unknown);
    });

    test('the key is always written', () {
      expect(
        food(NutritionBasis.per100ml).toJson()['nutritionBasis'],
        'per100ml',
      );
      expect(
        food(NutritionBasis.unknown).toJson()['nutritionBasis'],
        'unknown',
      );
    });

    test('a present but unrecognised value is unknown, never grams', () {
      for (final bad in ['grams', 'per_100g', 'PER100G', 5, true, '']) {
        final f = FoodItem.fromJson({..._legacy(), 'nutritionBasis': bad});
        expect(f.nutritionBasis, NutritionBasis.unknown, reason: '$bad');
      }
    });

    test('an explicit value wins over the legacy rule', () {
      final f = FoodItem.fromJson({
        ..._legacy(servingUnit: 'ml'),
        'nutritionBasis': 'per100g',
      });
      expect(f.nutritionBasis, NutritionBasis.per100g);
    });
  });

  group('copyWith', () {
    test('keeps the basis and can change it', () {
      final f = FoodItem.fromJson(_legacy(servingUnit: 'ml'));
      expect(f.copyWith(name: 'Other').nutritionBasis, NutritionBasis.per100ml);
      expect(
        f.copyWith(nutritionBasis: NutritionBasis.unknown).nutritionBasis,
        NutritionBasis.unknown,
      );
    });

    test('changing the unit label does not silently change the basis', () {
      final f = FoodItem.fromJson(_legacy(servingUnit: 'ml'));
      expect(f.copyWith(servingUnit: 'grams').nutritionBasis, f.nutritionBasis);
    });

    test('editing a value keeps unknown nutrients logic as before', () {
      const f = FoodItem(
        id: 'z',
        name: 'Z',
        calories: 0,
        isPackaged: true,
        barcode: '1',
        unknownNutrients: FoodItem.coreNutrients,
      );
      final edited = f.copyWith(calories: 90);
      expect(edited.isNutrientKnown(FoodItem.calorieKey), isTrue);
      expect(edited.nutritionBasis, NutritionBasis.unknown);
    });
  });

  test('scaling is unchanged by T1: the basis is data only', () {
    const grams = FoodItem(id: 'a', name: 'A', calories: 200);
    final ml = grams.copyWith(nutritionBasis: NutritionBasis.per100ml);
    expect(
      NutritionCalculator.calculate(ml, 50, 'ml').calories,
      NutritionCalculator.calculate(grams, 50, 'ml').calories,
    );
  });
}
