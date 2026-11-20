import 'dart:io';

import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/repositories/food_repository.dart';
import 'package:atlas/services/nutrition/barcode_food_service.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _remoteFood = FoodItem(
  id: 'off_5000112',
  name: 'Remote Granola',
  brand: 'Brand',
  calories: 410,
  protein: 9,
  carbohydrates: 62,
  fats: 14,
  barcode: '5000112',
);

/// A remote source that returns a fixed product (or nothing, or fails) and
/// counts how often it is asked.
class _FakeRemote implements RemoteFoodSource {
  _FakeRemote({this.product, this.error});

  final FoodItem? product;
  final Object? error;
  final List<String> asked = [];

  @override
  Future<FoodItem?> fetchRemoteByBarcode(String barcode) async {
    asked.add(barcode);
    if (error != null) throw error!;
    return product;
  }

  @override
  Future<FoodItem?> fetchRemoteById(String id) async => null;

  @override
  Future<List<FoodItem>> searchRemote(String query) async => [];
}

DefaultBarcodeFoodService _serviceWith(_FakeRemote remote) =>
    DefaultBarcodeFoodService(
      nutritionService: NutritionService(
        null,
        LocalFoodRepository(remoteSource: remote),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('DefaultBarcodeFoodService without FitnessProvider', () {
    test('is built and used with no provider in existence', () async {
      final remote = _FakeRemote(product: _remoteFood);
      final service = _serviceWith(remote);
      final food = await service.lookupBarcode('5000112');
      expect(food?.name, 'Remote Granola');
    });

    test('the source no longer refers to the provider', () {
      final source = File(
        'lib/services/nutrition/barcode_food_service.dart',
      ).readAsStringSync();
      expect(source.contains('fitness_provider'), isFalse);
      expect(source.contains('FitnessProvider'), isFalse);
    });

    test('by default it uses the shared NutritionService of the app', () async {
      // The same one the provider works through.
      final shared = AppDependencies.instance.nutritionService;
      await shared.saveScannedFood(_remoteFood);
      final food = await DefaultBarcodeFoodService().lookupBarcode('5000112');
      expect(food?.id, 'off_5000112');
      expect(FitnessProvider.instance.scannedFoods.map((f) => f.id), [
        'off_5000112',
      ]);
    });
  });

  group('lookup behaviour', () {
    test('an empty or blank barcode finds nothing and asks nobody', () async {
      final remote = _FakeRemote(product: _remoteFood);
      final service = _serviceWith(remote);
      expect(await service.lookupBarcode(''), isNull);
      expect(await service.lookupBarcode('   '), isNull);
      expect(remote.asked, isEmpty);
    });

    test('a product found online is returned and remembered', () async {
      final remote = _FakeRemote(product: _remoteFood);
      final service = _serviceWith(remote);

      final first = await service.lookupBarcode('  5000112  ');
      expect(first?.id, 'off_5000112');
      expect(remote.asked, ['5000112'], reason: 'the barcode is trimmed');

      // The second lookup is answered from what was saved, not online.
      final second = await service.lookupBarcode('5000112');
      expect(second?.id, 'off_5000112');
      expect(remote.asked, hasLength(1));
      expect(
        NutritionService().getScannedFoods().map((f) => f.id),
        contains('off_5000112'),
      );
    });

    test(
      'a custom food with that barcode is found without asking online',
      () async {
        final remote = _FakeRemote(product: _remoteFood);
        final nutrition = NutritionService(
          null,
          LocalFoodRepository(remoteSource: remote),
        );
        await nutrition.addCustomFood(
          const FoodItem(
            id: 'mine',
            name: 'My Bar',
            calories: 200,
            protein: 10,
            carbohydrates: 20,
            fats: 8,
            barcode: '9990001',
          ),
        );
        final food = await DefaultBarcodeFoodService(
          nutritionService: nutrition,
        ).lookupBarcode('9990001');
        expect(food?.name, 'My Bar');
        expect(remote.asked, isEmpty);
      },
    );

    test('an unknown product gives null and nothing is made up', () async {
      final remote = _FakeRemote();
      final service = _serviceWith(remote);
      expect(await service.lookupBarcode('0000000000000'), isNull);
      expect(remote.asked, ['0000000000000']);
      expect(NutritionService().getScannedFoods(), isEmpty);
    });

    test('an online failure is passed on to the caller, not hidden', () async {
      final service = _serviceWith(
        _FakeRemote(error: const SocketException('offline')),
      );
      await expectLater(
        service.lookupBarcode('123456'),
        throwsA(isA<SocketException>()),
      );
      expect(NutritionService().getScannedFoods(), isEmpty);
    });
  });
}
