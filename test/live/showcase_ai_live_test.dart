// LIVE test of the real Flutter AI client against the deployed `ai-proxy`
// Showcase pathway. Opt in with:
//
//   $env:ATLAS_LIVE_SHOWCASE = '1'
//   flutter test --no-pub test/live/showcase_ai_live_test.dart
//
// It reads SUPABASE_URL and SUPABASE_ANON_KEY from .env (never printed) and
// makes a handful of tiny real Gemini requests through the proxy, using the
// same client classes the app uses (GeminiAIProvider, FoodAIVisionService,
// MachineScanService) in Showcase configuration. Skipped otherwise.
import 'dart:convert';
import 'dart:io';

import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';
import 'package:atlas/services/machine/machine_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _env() {
  final out = <String, String>{};
  for (final line in File('.env').readAsLinesSync()) {
    final m = RegExp(r'^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$').firstMatch(line);
    if (m != null) out[m.group(1)!] = m.group(2)!.replaceAll('"', '');
  }
  return out;
}

void main() {
  final live = Platform.environment['ATLAS_LIVE_SHOWCASE'] == '1';
  late AIConfig config;
  late ChatAttachment photo;

  setUpAll(() {
    if (!live) return;
    final env = _env();
    config = AIConfig(
      proxyUrl: '${env['SUPABASE_URL']!.replaceAll(RegExp(r'/+$'), '')}/functions/v1/ai-proxy',
      anonKey: env['SUPABASE_ANON_KEY']!,
      accessTokenProvider: () => null,
      showcaseModeProvider: () => true,
    );
    final bytes = File('assets/community/photos/sp_alex_2.jpg').readAsBytesSync();
    photo = ChatAttachment(base64Data: base64Encode(bytes), mimeType: 'image/jpeg');
  });

  final skip = live ? null : 'live test: set ATLAS_LIVE_SHOWCASE=1';

  test('coach answers for real and keeps context across turns', () async {
    final provider = GeminiAIProvider(config: config);
    final first = await provider.generateResponse(
      message: 'For this chat, call me Zed. Reply with one short sentence.',
      context: FitnessContext.initial(),
      history: const [],
    );
    expect(first.trim(), isNotEmpty);
    final history = [
      CoachMessage(
        id: '1',
        role: CoachRole.user,
        content: 'For this chat, call me Zed. Reply with one short sentence.',
        timestamp: DateTime.now(),
      ),
      CoachMessage(
        id: '2',
        role: CoachRole.assistant,
        content: first,
        timestamp: DateTime.now(),
      ),
    ];
    final second = await provider.generateResponse(
      message: 'What name did I ask you to call me? One word.',
      context: FitnessContext.initial(),
      history: history,
    );
    // ignore: avoid_print
    print('LIVE coach turn 2 reply: ${second.trim()}');
    expect(second.toLowerCase(), contains('zed'));
  }, skip: skip, timeout: const Timeout(Duration(seconds: 90)));

  test('coach with a photo goes through the Showcase pathway', () async {
    final provider = GeminiAIProvider(config: config);
    final reply = await provider.generateResponse(
      message: 'In five words or fewer, what is in this photo?',
      context: FitnessContext.initial(),
      history: const [],
      attachment: photo,
    );
    // ignore: avoid_print
    print('LIVE coach photo reply: ${reply.trim()}');
    expect(reply.trim(), isNotEmpty);
  }, skip: skip, timeout: const Timeout(Duration(seconds: 90)));

  test('AI food scanner returns a structured result or a clear error', () async {
    final service = FoodAIVisionService(config: config);
    try {
      final r = await service.analyzeMealImage(attachment: photo);
      // ignore: avoid_print
      print('LIVE food scan: foodName=${r.foodName} isAi=${r.isAiGenerated}');
      expect(r.isAiGenerated, isTrue);
    } on FoodVisionException catch (e) {
      // A photo with no food is a legitimate, clearly worded outcome.
      // ignore: avoid_print
      print('LIVE food scan message: ${e.message}');
      expect(e.message, isNotEmpty);
    }
  }, skip: skip, timeout: const Timeout(Duration(seconds: 90)));

  test('machine scanner goes through the Showcase pathway', () async {
    final service = MachineScanService(config: config);
    try {
      final r = await service.identify(photo);
      // ignore: avoid_print
      print('LIVE machine scan: ${r.machineName}');
    } on MachineScanException catch (e) {
      // ignore: avoid_print
      print('LIVE machine scan message: ${e.message}');
      expect(e.message, isNotEmpty);
    }
  }, skip: skip, timeout: const Timeout(Duration(seconds: 90)));

  test('a wrong key is an honest error, never a success', () async {
    final bad = AIConfig(
      proxyUrl: config.proxyUrl,
      anonKey: 'not-the-project-key',
      accessTokenProvider: () => null,
      showcaseModeProvider: () => true,
    );
    await expectLater(
      GeminiAIProvider(config: bad).generateResponse(
        message: 'hello',
        context: FitnessContext.initial(),
        history: const [],
      ),
      throwsA(isA<GeminiApiException>()),
    );
  }, skip: skip, timeout: const Timeout(Duration(seconds: 60)));

  test('an over-limit photo is refused with a clear message', () async {
    final huge = ChatAttachment(
      base64Data: base64Encode(List<int>.filled(1000000, 65)),
      mimeType: 'image/jpeg',
    );
    await expectLater(
      FoodAIVisionService(config: config).analyzeMealImage(attachment: huge),
      throwsA(isA<FoodVisionException>()),
    );
  }, skip: skip, timeout: const Timeout(Duration(seconds: 60)));
}
