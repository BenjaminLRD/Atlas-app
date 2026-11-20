import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:atlas/models/food_analysis_result.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';
import 'package:atlas/services/food/gtin.dart';
import 'package:atlas/services/food/off_search_client.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';
import 'package:atlas/services/food/product_lookup_service.dart';
import 'package:atlas/services/food/product_matcher.dart';

const _cola = FoodItem(
  id: 'scanned_5449000000996',
  name: 'Coca-Cola',
  brand: 'Coca-Cola',
  calories: 42,
  carbohydrates: 10.6,
  protein: 0,
  fats: 0,
  isPackaged: true,
  barcode: '5449000000996',
  nutritionBasis: NutritionBasis.per100ml,
  nutritionSource: NutritionSource.openFoodFacts,
  packageQuantity: 330,
  packageQuantityUnit: 'ml',
);

ProductLookupService _service({
  Future<FoodItem?> Function(String)? barcode,
  String searchBody = '{"hits":[]}',
  List<Uri>? seen,
}) => ProductLookupService(
  client: OffSearchClient(
    httpClient: MockClient((r) async {
      seen?.add(r.url);
      return http.Response(searchBody, 200);
    }),
    minInterval: Duration.zero,
  ),
  barcodeLookup: barcode,
);

FoodAIVisionService _vision() => FoodAIVisionService(
  config: AIConfig(
    proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
    accessTokenProvider: () => 'user-token',
  ),
  httpClient: MockClient((_) async => http.Response('{}', 200)),
);

void main() {
  group('Gtin.isValid (check digit)', () {
    test('real EAN-13, EAN-8 and UPC-A codes pass', () {
      for (final code in [
        '5449000000996',
        '4006381333931',
        '8902080364053',
        '96385074',
        '036000291452',
      ]) {
        expect(Gtin.isValid(code), isTrue, reason: code);
      }
    });

    test('one wrong digit fails', () {
      for (final code in [
        '5449000000997',
        '5449000000396',
        '4006381333932',
        '96385075',
        '036000291453',
      ]) {
        expect(Gtin.isValid(code), isFalse, reason: code);
      }
    });

    test('the wrong length or non-digits fail', () {
      for (final code in ['', '123', '54490000009961', 'abcdefghijklm']) {
        expect(Gtin.isValid(code), isFalse, reason: code);
      }
    });

    test('clean removes spaces and hyphens and keeps only a valid code', () {
      expect(Gtin.clean('5449 0000 0099 6'), '5449000000996');
      expect(Gtin.clean('5449-0000-0099-6'), '5449000000996');
      expect(Gtin.clean('5449 0000 0099 7'), isNull);
      expect(Gtin.clean(null), isNull);
      expect(Gtin.clean(5449000000996), isNull);
    });
  });

  group('a barcode the AI read from the photo', () {
    FoodAnalysisResult parse(Map<String, dynamic> extra) =>
        _vision().parseGeminiVisionResponse(
          jsonEncode({
            'is_food': true,
            'foodName': 'Cola',
            'brand': 'Coca-Cola',
            'isPackagedProduct': true,
            ...extra,
          }),
        );

    test('a valid code is kept, with spaces removed', () {
      expect(
        parse({'barcode': '5449 0000 0099 6'}).readBarcode,
        '5449000000996',
      );
    });

    test('a code with a wrong check digit is thrown away', () {
      expect(parse({'barcode': '5449000000997'}).readBarcode, isNull);
    });

    test('a missing or odd value is ignored', () {
      expect(parse({}).readBarcode, isNull);
      expect(parse({'barcode': null}).readBarcode, isNull);
      expect(parse({'barcode': 12345}).readBarcode, isNull);
    });

    test('the prompt asks for it and says not to guess', () async {
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
        await service.analyzeMealImage(
          attachment: const ChatAttachment(
            base64Data: 'aGVsbG8=',
            mimeType: 'image/jpeg',
          ),
        );
      } on FoodVisionException {
        // The empty answer is not the point here.
      }
      expect(prompt, contains('"barcode"'));
      expect(prompt.toLowerCase(), contains('only if'));
    });
  });

  group('looking up by barcode first', () {
    ProductCandidate candidate({String? name, String? brand}) =>
        ProductCandidate(
          name: name ?? 'Coca-Cola',
          brand: brand ?? 'Coca-Cola',
          barcode: '5449000000996',
        );

    test('a found barcode is an exact match with no text search', () async {
      final seen = <Uri>[];
      final asked = <String>[];
      final service = _service(
        seen: seen,
        barcode: (code) async {
          asked.add(code);
          return _cola;
        },
      );

      final result = await service.lookup(candidate());

      expect(asked, ['5449000000996']);
      expect(seen, isEmpty, reason: 'no search request');
      expect(result.status, LookupStatus.exact);
      expect(result.viaBarcode, isTrue);
      expect(result.exact!.code, '5449000000996');
      expect(result.exact!.sizeLabel, '330 ml');
      expect(result.exact!.food.nutritionBasis, NutritionBasis.per100ml);
    });

    test('a barcode that is not a valid code is never looked up', () async {
      final asked = <String>[];
      final service = _service(
        barcode: (code) async {
          asked.add(code);
          return _cola;
        },
      );

      await service.lookup(
        const ProductCandidate(
          name: 'Coca-Cola',
          brand: 'Coca-Cola',
          barcode: '5449000000997',
        ),
      );
      expect(asked, isEmpty);
    });

    test(
      'a product that does not look like the photo is only a suggestion',
      () async {
        // The code is valid but belongs to something else: a misread digit pair
        // can still pass the check digit.
        final service = _service(barcode: (code) async => _cola);

        final result = await service.lookup(
          candidate(name: 'Britannia Good Day Biscuits', brand: 'Britannia'),
        );

        expect(result.status, LookupStatus.choose);
        expect(result.exact, isNull);
        expect(result.candidates.single.code, '5449000000996');
      },
    );

    test(
      'a barcode the database does not have falls back to the search',
      () async {
        final seen = <Uri>[];
        final service = _service(
          seen: seen,
          barcode: (code) async => null,
          searchBody: '{"hits":[]}',
        );

        final result = await service.lookup(candidate());

        expect(seen, isNotEmpty);
        expect(result.status, LookupStatus.none);
      },
    );

    test('a barcode lookup that fails falls back to the search', () async {
      final seen = <Uri>[];
      final service = _service(
        seen: seen,
        barcode: (code) async => throw const OpenFoodFactsException(
          message: 'down',
          isNetworkError: true,
        ),
      );

      final result = await service.lookup(candidate());

      expect(seen, isNotEmpty);
      expect(result.status, isNot(LookupStatus.exact));
    });

    test('with no barcode the search is used as before', () async {
      final seen = <Uri>[];
      final service = _service(
        seen: seen,
        barcode: (code) async => fail('must not be called'),
      );

      await service.lookup(
        const ProductCandidate(name: 'Mountain Dew', brand: 'PepsiCo'),
      );

      expect(seen, isNotEmpty);
    });
  });
}
