import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/unified_food_scanner_screen.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/ai/vision/ai_vision_service.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';

const _proxy = 'https://proj.supabase.co/functions/v1/ai-proxy';

AIConfig _signedIn() =>
    AIConfig(proxyUrl: _proxy, accessTokenProvider: () => 'user-token');

const _photo = ChatAttachment(base64Data: 'aGVsbG8=', mimeType: 'image/jpeg');

class _FakeVision extends AIVisionService {
  _FakeVision(this.result);

  ImagePickResult result;
  int calls = 0;

  @override
  Future<ImagePickResult> pickWithOutcome({
    required ImageSource source,
    double maxWidth = 1280,
    double maxHeight = 1280,
    int imageQuality = 85,
  }) async {
    calls++;
    return result;
  }
}

String _answer() => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {
            'text': jsonEncode({
              'is_food': true,
              'foodName': 'Chicken rice bowl',
              'ingredients': ['chicken', 'rice'],
              'servingSize': 450,
              'servingUnit': 'grams',
              'calories': 620,
              'protein': 48,
              'carbohydrates': 75,
              'fats': 12,
              'confidence': 0.82,
            }),
          },
        ],
      },
    },
  ],
});

String _proxyError(int code, String message) => jsonEncode({
  'error': {'code': code, 'message': message},
});

Future<_FakeVision> _open(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) handler,
  ImagePickResult? pick,
  AIConfig? config,
}) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  FoodAIVisionService.setInstance(
    FoodAIVisionService(
      config: config ?? _signedIn(),
      httpClient: MockClient(handler),
    ),
  );
  final vision = _FakeVision(pick ?? const ImagePickResult.picked(_photo));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UnifiedFoodScannerScreen(
                    initialMode: UnifiedScanMode.foodAi,
                    visionService: vision,
                    currentMealId: 'Lunch',
                    currentMealTitle: 'Lunch',
                  ),
                ),
              ),
              child: const Text('open scanner'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open scanner'));
  await tester.pumpAndSettle();
  return vision;
}

Future<void> _takePhoto(WidgetTester tester) async {
  await tester.tap(find.text('Take Photo'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  tearDown(FoodAIVisionService.resetInstance);

  group('a good analysis', () {
    testWidgets('shows the estimate for the whole portion', (tester) async {
      await _open(tester, handler: (_) async => http.Response(_answer(), 200));
      await _takePhoto(tester);

      expect(find.text('AI FOOD ESTIMATE'), findsOneWidget);
      expect(find.text('Chicken rice bowl'), findsOneWidget);
      expect(find.textContaining('Portion: ~450'), findsOneWidget);
      // The estimate for the 450 g portion, not the per-100 g figure (138).
      expect(find.text('~620 kcal'), findsOneWidget);
      expect(find.text('~48.0g'), findsOneWidget);
      expect(find.text('~75.0g'), findsOneWidget);
      expect(find.text('~12.0g'), findsOneWidget);
      expect(find.text('~138 kcal'), findsNothing);
    });

    testWidgets('editing the estimate keeps portion totals, and the log '
        'matches', (tester) async {
      await _open(tester, handler: (_) async => http.Response(_answer(), 200));
      await _takePhoto(tester);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      TextField field(String label) =>
          tester.widget<TextField>(find.widgetWithText(TextField, label));
      expect(field('Calories (kcal)').controller!.text, '620');

      // Half the portion: the totals follow.
      await tester.enterText(
        find.widgetWithText(TextField, 'Portion Size (g)'),
        '225',
      );
      await tester.pump();
      expect(field('Calories (kcal)').controller!.text, '310');

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('~310 kcal'), findsOneWidget);

      await tester.tap(find.textContaining('Add To'));
      await tester.pumpAndSettle();
      expect(
        FitnessProvider.instance.todayNutritionLog.dailyCalories,
        closeTo(310, 1),
      );
    });
  });

  group('taking or choosing the photo', () {
    testWidgets('closing the camera says no photo was selected', (
      tester,
    ) async {
      var requests = 0;
      final vision = await _open(
        tester,
        pick: const ImagePickResult.cancelled(),
        handler: (_) async {
          requests++;
          return http.Response(_answer(), 200);
        },
      );
      await _takePhoto(tester);

      expect(vision.calls, 1);
      expect(find.text('No photo was selected.'), findsOneWidget);
      expect(requests, 0);
      expect(find.text('AI FOOD ESTIMATE'), findsNothing);
    });

    testWidgets('a refused camera shows what to do', (tester) async {
      await _open(
        tester,
        pick: const ImagePickResult.failed(
          'Camera access is off. Allow it in Settings, or choose a photo from your gallery.',
        ),
        handler: (_) async => http.Response(_answer(), 200),
      );
      await _takePhoto(tester);

      expect(find.textContaining('Camera access is off'), findsOneWidget);
    });
  });

  group('analysis failures are distinct and visible', () {
    Future<void> expectMessage(
      WidgetTester tester,
      Future<http.Response> Function(http.Request) handler,
      String text, {
      AIConfig? config,
    }) async {
      await _open(tester, handler: handler, config: config);
      await _takePhoto(tester);
      expect(find.textContaining(text), findsOneWidget, reason: text);
      expect(find.text('AI FOOD ESTIMATE'), findsNothing);
    }

    testWidgets('the daily limit', (tester) {
      return expectMessage(
        tester,
        (_) async => http.Response(
          _proxyError(
            429,
            'Daily AI limit reached. Upgrade to Atlas Pro for more.',
          ),
          429,
        ),
        'Daily AI limit reached',
      );
    });

    testWidgets('an expired session', (tester) {
      return expectMessage(
        tester,
        (_) async => http.Response(
          _proxyError(401, 'Your session expired. Sign in again.'),
          401,
        ),
        'Your session expired',
      );
    });

    testWidgets('a server failure shows the status', (tester) {
      return expectMessage(
        tester,
        (_) async => http.Response('boom', 502),
        'server error 502',
      );
    });

    testWidgets('a timeout', (tester) {
      return expectMessage(
        tester,
        (_) async => throw TimeoutException('slow'),
        'took too long',
      );
    });

    testWidgets('an empty answer', (tester) {
      return expectMessage(
        tester,
        (_) async => http.Response('{}', 200),
        'returned no result',
      );
    });

    testWidgets('a blocked answer', (tester) {
      return expectMessage(
        tester,
        (_) async => http.Response(
          jsonEncode({
            'promptFeedback': {'blockReason': 'SAFETY'},
          }),
          200,
        ),
        'could not use this photo',
      );
    });

    testWidgets('a build without backend settings', (tester) {
      return expectMessage(
        tester,
        (_) async => http.Response(_answer(), 200),
        'not set up in this build',
        config: AIConfig(),
      );
    });

    testWidgets('a signed-out user', (tester) {
      return expectMessage(
        tester,
        (_) async => http.Response(_answer(), 200),
        'Sign in to use Atlas AI.',
        config: AIConfig(proxyUrl: _proxy, accessTokenProvider: () => null),
      );
    });

    testWidgets('a failure can be retried and then succeeds', (tester) async {
      var first = true;
      await _open(
        tester,
        handler: (_) async {
          if (first) {
            first = false;
            return http.Response('boom', 503);
          }
          return http.Response(_answer(), 200);
        },
      );

      await _takePhoto(tester);
      expect(find.textContaining('server error 503'), findsOneWidget);

      await _takePhoto(tester);
      expect(find.textContaining('server error'), findsNothing);
      expect(find.text('AI FOOD ESTIMATE'), findsOneWidget);
    });
  });
}
