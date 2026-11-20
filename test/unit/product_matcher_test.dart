import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/services/food/off_search_client.dart';
import 'package:atlas/services/food/product_matcher.dart';

/// A real Open Food Facts search answer for "mountain dew" in India
/// (data (c) Open Food Facts contributors, ODbL).
List<OffProduct> _fixture() {
  final json = jsonDecode(
    File('test/fixtures/off_search_mountain_dew_india.json').readAsStringSync(),
  );
  return [
    for (final hit in json['hits'] as List)
      ?OffProduct.fromSearchHit(Map<String, dynamic>.from(hit as Map)),
  ];
}

OffProduct _byCode(List<OffProduct> all, String code) =>
    all.firstWhere((p) => p.code == code);

const _dew750 = '8902080364053';

ProductCandidate _dew({
  String? brand = 'PepsiCo',
  String? variant,
  double? ml,
}) => ProductCandidate(
  name: 'Mountain Dew',
  brand: brand,
  variant: variant,
  sizeValue: ml,
  sizeUnit: ml == null ? null : 'ml',
);

void main() {
  late List<OffProduct> products;
  setUp(() => products = _fixture());

  group('reading a search hit', () {
    test('a brand list, null nutrients and a junk quantity are handled', () {
      expect(products, hasLength(11));

      final cola = _byCode(products, '8902080364565');
      expect(cola.brands, ['MEWATI 🔔']);
      expect(cola.sizeValue, 1250);
      expect(cola.sizeUnit, 'ml');
      expect(cola.food.calories, 49);
      expect(cola.food.nutritionBasis, NutritionBasis.per100ml);
      expect(cola.inIndia, isTrue);
    });

    test('nutrition the source lacks stays unknown, not zero', () {
      final p = _byCode(products, _dew750);
      expect(p.hasNutrition, isFalse);
      expect(p.food.nutritionUnavailable, isTrue);
      expect(p.food.unknownNutrients, FoodItem.coreNutrients);
    });

    test('a size written in the name is used when the quantity is junk', () {
      final p = _byCode(products, _dew750); // quantity "3", name "... 750 ml"
      expect(p.sizeValue, 750);
      expect(p.sizeUnit, 'ml');
      expect(p.sizeLabel, '750 ml');
    });

    test('a quantity without a unit gives no size', () {
      final p = _byCode(products, '8902080364596'); // quantity "1"
      expect(p.sizeValue, isNull);
    });

    test('genuine zeros are kept as known zeros', () {
      final p = _byCode(products, '8902080364022');
      expect(p.food.isNutrientKnown(FoodItem.proteinKey), isTrue);
      expect(p.food.protein, 0);
      expect(p.food.fats, 0);
      expect(p.food.carbohydrates, 12.3);
    });

    test('the record links back to Open Food Facts', () {
      final p = _byCode(products, '8902080364022');
      expect(p.url, 'https://world.openfoodfacts.org/product/8902080364022');
      expect(p.food.nutritionSource, NutritionSource.openFoodFacts);
      expect(p.food.sourceUrl, p.url);
    });

    test('a hit with no code is skipped', () {
      expect(OffProduct.fromSearchHit({'product_name': 'x'}), isNull);
    });
  });

  group('exact match', () {
    test('brand, name and a size that agrees, listed for India', () {
      final outcome = ProductMatcher.match(_dew(ml: 750), products);

      expect(outcome.exact?.code, _dew750);
    });

    test('exact does not need nutrition: it is an exact product match', () {
      final outcome = ProductMatcher.match(_dew(ml: 750), products);

      expect(outcome.exact!.hasNutrition, isFalse);
    });

    test('other sizes of the same product are offered as possible', () {
      final outcome = ProductMatcher.match(_dew(ml: 750), products);

      final codes = outcome.possible.map((p) => p.code);
      expect(codes, contains('8902080364022')); // 250 ml, with nutrition
      expect(codes, isNot(contains(_dew750)));
    });
  });

  group('never silently picked', () {
    test('with no size on the label, several sizes mean choose', () {
      final outcome = ProductMatcher.match(_dew(), products);

      expect(outcome.exact, isNull);
      final codes = outcome.possible.map((p) => p.code).toSet();
      expect(codes, containsAll(['8902080364022', '8902080364589', _dew750]));
    });

    test('a wrong package size is not an exact match', () {
      final outcome = ProductMatcher.match(_dew(ml: 600), products);

      expect(outcome.exact, isNull);
      // The sizes that do exist are shown so the user can pick.
      expect(outcome.possible.map((p) => p.code), contains(_dew750));
    });

    test('a different brand is not exact', () {
      final outcome = ProductMatcher.match(
        _dew(brand: 'Pepsi', ml: 1000),
        products,
      );
      // "Pepsi" the brand of 8902080364060 is not "PepsiCo", but it is the
      // candidate's own brand here, so this one is the only identity match.
      expect(outcome.exact?.code, '8902080364060');

      final other = ProductMatcher.match(
        _dew(brand: 'Coca-Cola', ml: 750),
        products,
      );
      expect(other.exact, isNull);
    });

    test('no brand on the candidate can never be exact', () {
      final outcome = ProductMatcher.match(
        _dew(brand: null, ml: 750),
        products,
      );
      expect(outcome.exact, isNull);
      expect(outcome.possible.map((p) => p.code), contains(_dew750));
    });

    test('a variant word that differs is not exact', () {
      final outcome = ProductMatcher.match(
        _dew(variant: 'Zero Sugar', ml: 750),
        products,
      );
      expect(outcome.exact, isNull);
    });

    test('a product not listed for India is never exact', () {
      final abroad = [
        for (final p in products)
          if (p.code == _dew750)
            OffProduct.forTest(
              code: p.code,
              food: p.food,
              brands: p.brands,
              countries: const ['en:united-states'],
              sizeValue: p.sizeValue,
              sizeUnit: p.sizeUnit,
            ),
      ];
      final outcome = ProductMatcher.match(_dew(ml: 750), abroad);

      expect(outcome.exact, isNull);
      expect(outcome.possible.single.code, _dew750);
    });

    test('two records that both fit are a choice, not an exact match', () {
      final twin = OffProduct.forTest(
        code: '1111111111111',
        food: _byCode(products, '8902080364022').food,
        brands: const ['PepsiCo'],
        countries: const ['en:india'],
        sizeValue: 750,
        sizeUnit: 'ml',
      );
      final outcome = ProductMatcher.match(_dew(ml: 750), [...products, twin]);

      expect(outcome.exact, isNull);
      expect(
        outcome.possible.map((p) => p.code),
        containsAll([_dew750, '1111111111111']),
      );
    });
  });

  group('unrelated products', () {
    test('similar words in another product are left out', () {
      final outcome = ProductMatcher.match(_dew(), products);

      final names = outcome.possible.map((p) => p.food.name);
      expect(names, isNot(contains('Yardley London Morning Dew')));
      expect(names, isNot(contains('Vadilal moth dew bean sprouts')));
    });

    test('nothing in the results is none', () {
      final outcome = ProductMatcher.match(
        const ProductCandidate(name: 'Amul Butter', brand: 'Amul'),
        products,
      );
      expect(outcome.exact, isNull);
      expect(outcome.possible, isEmpty);
    });

    test('an empty result list is none', () {
      final outcome = ProductMatcher.match(_dew(ml: 750), const []);
      expect(outcome.exact, isNull);
      expect(outcome.possible, isEmpty);
    });
  });

  group('ranking', () {
    test('same-brand records with nutrition come first', () {
      final outcome = ProductMatcher.match(_dew(), products);
      expect(outcome.possible.first.inIndia, isTrue);
      expect(outcome.possible.first.brands, contains('PepsiCo'));
      expect(outcome.possible.first.hasNutrition, isTrue);
    });

    test('the list is capped', () {
      expect(
        ProductMatcher.match(_dew(), products).possible.length,
        lessThanOrEqualTo(8),
      );
    });
  });
}
