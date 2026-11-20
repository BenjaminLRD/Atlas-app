import 'dart:convert';
import 'dart:io';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/coach_safety_rules.dart';
import 'package:atlas/services/ai/gemini_transport.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/ai/tools/health_tool.dart';
import 'package:atlas/services/ai/tools/nutrition_tool.dart';
import 'package:atlas/services/ai/tools/progress_tool.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';
import 'package:atlas/services/machine/machine_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Showcase branch of `supabase/functions/ai-proxy/index.ts` validates every
/// request. This test builds the requests the app really sends and checks they
/// fit that validation, with the limits read from the function's own source so
/// the two cannot drift apart unnoticed. (The server logic itself is run by
/// `node --test tool/ai_proxy_local_test/run.mjs`.)
String get _source => File(
  'supabase/functions/ai-proxy/index.ts',
).readAsStringSync().replaceAll('\r\n', '\n');

int _limit(String name) {
  final m = RegExp('const $name = (\\d+);').firstMatch(_source);
  if (m == null) fail('$name not found in ai-proxy/index.ts');
  return int.parse(m.group(1)!);
}

AIConfig _config() => AIConfig(
  proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
  anonKey: 'public-anon-key-for-tests',
  accessTokenProvider: () => null,
  showcaseModeProvider: () => true,
);

String _answer(String text) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': text},
        ],
      },
      'finishReason': 'STOP',
    },
  ],
});

/// Records the last proxy request body and replies with [text].
class _Capture {
  final List<Map<String, dynamic>> bodies = [];
  final List<int> sizes = [];
  late final MockClient client;
  _Capture(String text) {
    client = MockClient((r) async {
      sizes.add(utf8.encode(r.body).length);
      bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response(_answer(text), 200);
    });
  }
  Map<String, dynamic> get request =>
      bodies.last['request'] as Map<String, dynamic>;
}

List<CoachMessage> _longHistory() => [
  for (var i = 0; i < 12; i++)
    CoachMessage(
      id: 'm$i',
      role: i.isEven ? CoachRole.user : CoachRole.assistant,
      content: 'x' * 900, // longer than the app's own 600 character cap
      timestamp: DateTime(2026, 11, 17, 9, i),
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setShowcaseModeEnabled(true);
  });
  tearDown(() => LocalStorage.setShowcaseModeEnabled(false));

  final photo = ChatAttachment(
    base64Data: base64Encode(List<int>.filled(60000, 7)),
    mimeType: 'image/jpeg',
  );

  void checkFits(
    Map<String, dynamic> request,
    int bytes, {
    required bool hasImage,
  }) {
    final turns = request['contents'] as List;
    expect(turns.length, lessThanOrEqualTo(_limit('SHOWCASE_MAX_TURNS')));
    expect(bytes, lessThanOrEqualTo(_limit('SHOWCASE_MAX_BODY_BYTES')));
    if (!hasImage) {
      expect(bytes, lessThanOrEqualTo(_limit('SHOWCASE_MAX_TEXT_BODY_BYTES')));
    }
    var text = 0;
    var images = 0;
    for (final t in turns) {
      final parts = (t as Map)['parts'] as List;
      expect(
        parts.length,
        lessThanOrEqualTo(_limit('SHOWCASE_MAX_PARTS_PER_TURN')),
      );
      for (final p in parts.cast<Map>()) {
        if (p.containsKey('text')) {
          final n = (p['text'] as String).length;
          expect(n, lessThanOrEqualTo(_limit('SHOWCASE_MAX_PART_CHARS')));
          text += n;
        } else {
          images++;
          final d = (p['inline_data'] as Map)['data'] as String;
          expect(
            d.length,
            lessThanOrEqualTo(_limit('SHOWCASE_MAX_IMAGE_BASE64_CHARS')),
          );
        }
      }
    }
    expect(text, lessThanOrEqualTo(_limit('SHOWCASE_MAX_TEXT_CHARS')));
    expect(images, lessThanOrEqualTo(1));
    // Only fields the server accepts.
    expect(
      request.keys.toSet().difference({
        'contents',
        'generationConfig',
        'systemInstruction',
        'tools',
        'safetySettings',
      }),
      isEmpty,
    );
    for (final t in turns) {
      expect((t as Map)['role'] ?? 'user', anyOf('user', 'model'));
    }
    expect((turns.last as Map)['role'] ?? 'user', 'user');
    expect((turns.first as Map)['role'] ?? 'user', 'user');
  }

  test('the server limits are the ones the review set', () {
    expect(_limit('SHOWCASE_MAX_TEXT_BODY_BYTES'), 65536);
    expect(_limit('SHOWCASE_MAX_OUTPUT_TOKENS'), AIConfig.maxOutputTokens);
    expect(_limit('SHOWCASE_THINKING_BUDGET'), AIConfig.thinkingBudget);
  });

  test('the server holds a verbatim copy of the app chat rules', () {
    expect(_source, contains(CoachSafetyRules.systemInstruction.trim()));
  });

  test('a long chat message fits the server limits', () async {
    final cap = _Capture('Hello');
    final provider = GeminiAIProvider(
      config: _config(),
      httpClient: cap.client,
    );
    await provider.generateResponse(
      message: 'Make me a push day',
      context: FitnessContext.initial(),
      history: _longHistory(),
    );
    checkFits(cap.request, cap.sizes.last, hasImage: false);
    // The rules sent are the ones the server holds, plus the app's earlier-turns note.
    final si =
        ((cap.request['systemInstruction'] as Map)['parts'] as List).first
            as Map;
    expect(
      (si['text'] as String).trim(),
      startsWith(CoachSafetyRules.systemInstruction.trim()),
    );
  });

  test('a chat message with a photo fits the server limits', () async {
    final cap = _Capture('Looks like a squat rack.');
    final provider = GeminiAIProvider(
      config: _config(),
      httpClient: cap.client,
    );
    await provider.generateResponse(
      message: 'What machine is this?',
      context: FitnessContext.initial(),
      history: _longHistory(),
      attachment: photo,
    );
    checkFits(cap.request, cap.sizes.last, hasImage: true);
  });

  test('the tool-calling chat request fits the server limits', () async {
    final cap = _Capture('Plain answer');
    final provider = GeminiAIProvider(
      config: _config(),
      httpClient: cap.client,
    );
    final result = await provider.generateAgentResponse(
      message: 'Log my breakfast',
      context: FitnessContext.initial(),
      history: _longHistory(),
      tools: [WorkoutTool(), NutritionTool(), HealthTool(), ProgressTool()],
    );
    // The server drops `tools`; the answer must still come back as text.
    expect(result.responseText, 'Plain answer');
    checkFits(cap.request, cap.sizes.last, hasImage: false);
    // Real size, so a growth in the tool schemas is noticed.
    expect(
      cap.sizes.last,
      lessThan(_limit('SHOWCASE_MAX_TEXT_BODY_BYTES')),
      reason: 'agent request is ${cap.sizes.last} bytes',
    );
  });

  test(
    'the food scan and machine scan requests fit the server limits',
    () async {
      final food = _Capture(
        jsonEncode({
          'foodName': 'Banana',
          'confidence': 0.9,
          'servingSize': 118,
          'servingUnit': 'g',
          'calories': 105,
          'protein': 1.3,
          'carbohydrates': 27,
          'fats': 0.4,
          'ingredients': ['Banana'],
        }),
      );
      await FoodAIVisionService(
        config: _config(),
        httpClient: food.client,
      ).analyzeMealImage(attachment: photo);
      checkFits(food.request, food.sizes.last, hasImage: true);

      final machine = _Capture(jsonEncode({'is_gym_equipment': false}));
      try {
        await MachineScanService(
          config: _config(),
          httpClient: machine.client,
        ).identify(photo);
      } catch (_) {
        // The reply content does not matter here, only the request.
      }
      expect(machine.bodies, isNotEmpty);
      checkFits(machine.request, machine.sizes.last, hasImage: true);
    },
  );

  test('the client ceiling equals the server ceiling', () {
    expect(showcaseMaxRequestBytes, _limit('SHOWCASE_MAX_BODY_BYTES'));
  });

  test('an over-ceiling photo is refused at once, without an upload', () async {
    var calls = 0;
    final client = MockClient((r) async {
      calls++;
      return http.Response(_answer('should not be reached'), 200);
    });
    final huge = ChatAttachment(
      base64Data: base64Encode(List<int>.filled(1000000, 65)),
      mimeType: 'image/jpeg',
    );
    await expectLater(
      FoodAIVisionService(
        config: _config(),
        httpClient: client,
      ).analyzeMealImage(attachment: huge),
      throwsA(isA<FoodVisionException>()),
    );
    expect(calls, 0);
  });
}
