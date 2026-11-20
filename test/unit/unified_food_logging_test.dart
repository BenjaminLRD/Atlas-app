import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/food_scan_result.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/diet_plan_screen.dart';
import 'package:atlas/screens/unified_food_scanner_screen.dart';
import 'package:atlas/services/barcode/barcode_scanner_service.dart';
import 'package:atlas/services/nutrition/barcode_food_service.dart';
import 'package:atlas/widgets/nutrition/food_search_sheet.dart';
import 'package:atlas/widgets/nutrition/scanned_food_result_card.dart';

class MockBarcodeFoodService implements BarcodeFoodService {
  final Map<String, FoodItem> database = {
    '8901234567890': const FoodItem(
      id: 'scanned_8901234567890',
      name: 'Oats & Honey Granola Bar',
      brand: 'Nature Valley',
      calories: 190.0,
      protein: 4.0,
      carbohydrates: 29.0,
      fats: 7.0,
      isPackaged: true,
      barcode: '8901234567890',
    ),
  };

  @override
  Future<FoodItem?> lookupBarcode(String barcode) async {
    return database[barcode];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Unified Food Logging & Scanner Pipeline Tests', () {
    test(
      '1. BarcodeFoodService returns product when barcode matches',
      () async {
        final service = MockBarcodeFoodService();
        final item = await service.lookupBarcode('8901234567890');
        expect(item, isNotNull);
        expect(item!.name, 'Oats & Honey Granola Bar');
        expect(item.calories, 190.0);
      },
    );

    test(
      '2. BarcodeFoodService returns null for unknown barcode without inventing data',
      () async {
        final service = MockBarcodeFoodService();
        final item = await service.lookupBarcode('0000000000000');
        expect(item, isNull);
      },
    );

    test('3. FoodScanResult correctly computes macros and totals', () {
      const food = FoodItem(
        id: 'scan_food_1',
        name: 'Grilled Chicken Salad',
        calories: 120.0,
        protein: 13.0,
        carbohydrates: 4.0,
        fats: 3.0,
      );

      final scanResult = FoodScanResult(
        scanType: FoodScanType.aiVision,
        food: food,
        estimatedQuantity: 300.0,
        estimatedUnit: 'g',
        confidence: 'High',
        notes: '1 medium bowl (300g)',
      );

      expect(scanResult.food.name, 'Grilled Chicken Salad');
      // 120 * (300/100) = 360
      expect(scanResult.estimatedCalories, 360.0);
      // 13 * 3 = 39
      expect(scanResult.estimatedProtein, 39.0);
      expect(scanResult.confidence, 'High');
      expect(scanResult.isAiEstimate, isTrue);

      final json = scanResult.toJson();
      final fromJson = FoodScanResult.fromJson(json);
      expect(fromJson.food.name, 'Grilled Chicken Salad');
      expect(fromJson.estimatedCalories, 360.0);
    });

    test(
      '4. FitnessProvider.addFoodToMeal updates todayNutritionLog and macro state',
      () async {
        final provider = FitnessProvider.instance;
        final initialCalories = provider.todayNutritionLog.dailyCalories;

        const testFood = FoodItem(
          id: 'test_egg_white',
          name: 'Boiled Egg Whites',
          calories: 52.0,
          protein: 11.0,
          carbohydrates: 0.7,
          fats: 0.2,
        );

        await provider.addFoodToMeal('Breakfast', testFood, 2.0, 'pieces');

        final updatedLog = provider.todayNutritionLog;
        expect(
          updatedLog.dailyCalories,
          greaterThanOrEqualTo(initialCalories + 100),
        );
        expect(updatedLog.dailyProtein, greaterThanOrEqualTo(20));
      },
    );

    testWidgets(
      '5. UnifiedFoodScannerScreen renders AI Photo mode by default',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: UnifiedFoodScannerScreen(
              initialMode: UnifiedScanMode.foodAi,
              currentMealId: 'Breakfast',
              currentMealTitle: 'Breakfast',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Scan your meal or barcode'), findsOneWidget);
        expect(find.text('Take Photo'), findsOneWidget);
        expect(find.text('From Gallery'), findsOneWidget);
      },
    );

    testWidgets(
      '6. UnifiedFoodScannerScreen switches to Barcode mode and renders viewfinder UI',
      (tester) async {
        final mockScanner = DefaultBarcodeScannerService();
        mockScanner.setCameraPermissionState(true);

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedFoodScannerScreen(
              initialMode: UnifiedScanMode.barcode,
              barcodeScannerService: mockScanner,
              barcodeFoodService: MockBarcodeFoodService(),
              currentMealId: 'Lunch',
              currentMealTitle: 'Lunch',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Point camera at Barcode / QR'), findsOneWidget);
        expect(find.text('OR ENTER BARCODE / QR MANUALLY'), findsOneWidget);
        expect(find.text('Lookup'), findsOneWidget);
      },
    );

    testWidgets(
      '7. UnifiedFoodScannerScreen handles denied camera permission in Barcode mode',
      (tester) async {
        final mockScanner = DefaultBarcodeScannerService();
        mockScanner.setCameraPermissionState(false);

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedFoodScannerScreen(
              initialMode: UnifiedScanMode.barcode,
              barcodeScannerService: mockScanner,
              currentMealId: 'Dinner',
              currentMealTitle: 'Dinner',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Camera Permission Denied'), findsOneWidget);
        expect(find.text('Request Permission'), findsOneWidget);
      },
    );

    testWidgets(
      '8. FoodSearchSheet renders Add Food Hub with Meal selector and Quick Actions',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: FoodSearchSheet(
                mealId: 'Breakfast',
                mealTitle: 'Breakfast',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ADD FOOD'), findsOneWidget);
        expect(find.text('Meal:'), findsOneWidget);
        expect(find.text('Scan Food'), findsOneWidget);
        expect(find.text('Scan Barcode'), findsOneWidget);
        expect(find.text('Manual Entry'), findsOneWidget);
      },
    );

    testWidgets(
      '9. DietPlanScreen renders without FloatingActionButton and has [ + ADD FOOD ] button',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: DietPlanScreen()));
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('ADD FOOD'), findsWidgets);
        expect(find.text('NUTRITION DASHBOARD'), findsOneWidget);
      },
    );

    testWidgets(
      '10. ScannedFoodResultCard allows logging food directly to meals',
      (tester) async {
        const food = FoodItem(
          id: 'scanned_snack_1',
          name: 'Roasted Almonds',
          calories: 160.0,
          protein: 6.0,
          carbohydrates: 6.0,
          fats: 14.0,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ScannedFoodResultCard(
                food: food,
                currentMealId: 'Snacks',
                currentMealTitle: 'Snacks',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Roasted Almonds'), findsOneWidget);
        expect(find.text('Snacks'), findsOneWidget);

        await tester.tap(find.text('Snacks'));
        await tester.pumpAndSettle();

        final todaysMeals = FitnessProvider.instance.todaysMeals;
        final snacks = todaysMeals.firstWhere(
          (m) => m.name.toLowerCase().contains('snack'),
        );
        expect(
          snacks.consumedFoods.any((cf) => cf.food.name == 'Roasted Almonds'),
          isTrue,
        );
      },
    );

    testWidgets(
      '11. Nutrition Dashboard renders across responsive screen widths without overflow',
      (tester) async {
        final widths = [320.0, 360.0, 390.0, 412.0];

        for (final width in widths) {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(const MaterialApp(home: DietPlanScreen()));
          await tester.pumpAndSettle();

          expect(find.text('NUTRITION DASHBOARD'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      '12. Manual barcode lookup of valid barcode displays product result card',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockService = MockBarcodeFoodService();

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedFoodScannerScreen(
              initialMode: UnifiedScanMode.barcode,
              barcodeFoodService: mockService,
              currentMealId: 'Lunch',
              currentMealTitle: 'Lunch',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter valid barcode
        await tester.ensureVisible(find.text('Lookup'));
        await tester.enterText(find.byType(TextField).last, '8901234567890');
        await tester.tap(find.text('Lookup'));
        await tester.pumpAndSettle();

        expect(find.text('Oats & Honey Granola Bar'), findsOneWidget);
        expect(find.text('Nature Valley'), findsOneWidget);
        expect(find.text('190 kcal'), findsOneWidget);
      },
    );

    testWidgets(
      '13. Manual barcode lookup of unknown barcode displays Product Not Found and fallbacks',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockService = MockBarcodeFoodService();

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedFoodScannerScreen(
              initialMode: UnifiedScanMode.barcode,
              barcodeFoodService: mockService,
              currentMealId: 'Dinner',
              currentMealTitle: 'Dinner',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter unknown barcode
        await tester.ensureVisible(find.text('Lookup'));
        await tester.enterText(find.byType(TextField).last, '9999999999999');
        await tester.tap(find.text('Lookup'));
        await tester.pumpAndSettle();

        expect(find.text('Product Not Found'), findsOneWidget);
        expect(find.text('Barcode: 9999999999999'), findsOneWidget);
        expect(find.text('Enter Manually'), findsOneWidget);
        expect(find.text('Search Food'), findsOneWidget);
      },
    );

    testWidgets(
      '14. Unsupported QR code displays clear guidance and scan again action',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockService = MockBarcodeFoodService();

        await tester.pumpWidget(
          MaterialApp(
            home: UnifiedFoodScannerScreen(
              initialMode: UnifiedScanMode.barcode,
              barcodeFoodService: mockService,
              currentMealId: 'Breakfast',
              currentMealTitle: 'Breakfast',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter generic non-food URL
        await tester.ensureVisible(find.text('Lookup'));
        await tester.enterText(
          find.byType(TextField).last,
          'https://example.com/wifi-login',
        );
        await tester.tap(find.text('Lookup'));
        await tester.pumpAndSettle();

        expect(find.text('QR Code Unsupported'), findsOneWidget);
        expect(
          find.text(
            "QR code detected, but it doesn't contain a supported food/product identifier.",
          ),
          findsOneWidget,
        );
        expect(find.text('Scan Again'), findsOneWidget);
      },
    );
  });
}
