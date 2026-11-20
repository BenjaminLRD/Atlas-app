import 'dart:async';
import 'dart:convert';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/ai_provider.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// No network and no Gemini quota: every request goes to a fake.
class _FakeClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  final List<http.Request> requests = [];

  _FakeClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    requests.add(req);
    final response = await handler(req);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

/// Never answers, like a Gemini call that takes too long.
class _HangingProvider implements AIProvider {
  @override
  String get providerName => 'Hanging fake';

  @override
  bool get isOnline => true;

  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  }) => Completer<String>().future;
}

const _proxyUrl = 'https://abc.supabase.co/functions/v1/ai-proxy';

GeminiAIProvider _proxiedProvider(http.Client client) => GeminiAIProvider(
  config: AIConfig(proxyUrl: _proxyUrl, accessTokenProvider: () => 'user-jwt'),
  httpClient: client,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('loading status text', () {
    const router = AIRequestRouter.instance;

    test('is intent-aware and names only the topic', () {
      final workout = router.classifyIntent('Can you build me a push workout?');
      final nutrition = router.classifyIntent('What should I eat for protein?');
      final recovery = router.classifyIntent('How is my recovery and sleep?');
      expect(workout, AIRequestIntent.workoutRequest);
      expect(nutrition, AIRequestIntent.nutritionQuestion);
      expect(recovery, AIRequestIntent.recoveryQuestion);

      expect(
        AIRequestRouter.loadingStatusFor(workout),
        'Atlas AI is thinking about your workout question…',
      );
      expect(
        AIRequestRouter.loadingStatusFor(nutrition),
        'Atlas AI is thinking about your nutrition question…',
      );
      expect(
        AIRequestRouter.loadingStatusFor(recovery),
        'Atlas AI is thinking about your recovery question…',
      );
    });

    test('general questions get neutral text, not a workout message', () {
      final intent = router.classifyIntent('What is progressive overload?');
      expect(intent, AIRequestIntent.generalFitnessQuestion);
      final text = AIRequestRouter.loadingStatusFor(intent);
      expect(text, 'Atlas AI is thinking…');
      expect(text.toLowerCase(), isNot(contains('workout')));
    });

    test('a photo says so, and no text claims work being done', () {
      expect(
        AIRequestRouter.loadingStatusFor(
          AIRequestIntent.workoutRequest,
          hasAttachment: true,
        ),
        'Atlas AI is looking at your photo…',
      );
      for (final intent in AIRequestIntent.values) {
        final text = AIRequestRouter.loadingStatusFor(intent).toLowerCase();
        expect(text, isNot(contains('building')));
        expect(text, isNot(contains('analyzing')));
        expect(text, isNot(contains('checking')));
        expect(text, isNot(contains('learning')));
      }
    });
  });

  group('generation request', () {
    test('goes to ai-proxy with bounded generation settings', () async {
      final client = _FakeClient(
        (request) async => http.Response(
          '{"candidates":[{"content":{"parts":[{"text":"Hi."}]}}]}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final reply = await _proxiedProvider(client).generateResponse(
        message: 'Deadlift tip?',
        context: FitnessContext.initial(),
        history: const [],
      );

      expect(reply, 'Hi.');
      expect(client.requests, hasLength(1));
      final request = client.requests.single;
      // Through the proxy, never to Google directly, and no key header.
      expect(request.url.toString(), _proxyUrl);
      expect(request.url.host, isNot(contains('googleapis')));
      expect(request.headers['Authorization'], 'Bearer user-jwt');
      expect(request.headers.containsKey('x-goog-api-key'), isFalse);

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'gemini-2.5-flash');
      expect(body['feature'], 'coach');
      final gemini = body['request'] as Map<String, dynamic>;
      expect(gemini['contents'], isNotEmpty);
      final config = gemini['generationConfig'] as Map<String, dynamic>;
      expect(config['temperature'], 0.7);
      expect(config['maxOutputTokens'], AIConfig.maxOutputTokens);
      expect(
        (config['thinkingConfig'] as Map)['thinkingBudget'],
        AIConfig.thinkingBudget,
      );
    });

    test('the limits are within what gemini-2.5-flash accepts', () {
      // thinkingBudget: 0..24576 (or -1 for dynamic); the answer needs room
      // below maxOutputTokens, which also counts thinking tokens.
      expect(AIConfig.thinkingBudget, inInclusiveRange(0, 24576));
      expect(AIConfig.maxOutputTokens, greaterThan(AIConfig.thinkingBudget));
      expect(
        AIConfig.maxOutputTokens - AIConfig.thinkingBudget,
        greaterThanOrEqualTo(1024),
      );
    });
  });

  group('timeout', () {
    test('uses one 45 second limit', () {
      expect(AIConfig.requestTimeout, const Duration(seconds: 45));
      expect(
        AIConfig.timeoutMessage,
        'Atlas AI took too long to respond. Please try again.',
      );
    });

    testWidgets('the proxy request waits past 15 s and fails at 45 s', (
      tester,
    ) async {
      final provider = _proxiedProvider(
        _FakeClient((request) => Completer<http.Response>().future),
      );
      Object? error;
      var done = false;
      provider
          .generateResponse(
            message: 'Deadlift tip?',
            context: FitnessContext.initial(),
            history: const [],
          )
          .then((_) => done = true)
          .catchError((Object e) {
            error = e;
            done = true;
            return true;
          });

      await tester.pump(const Duration(seconds: 15));
      expect(done, isFalse, reason: 'the old 15 s limit must be gone');
      await tester.pump(const Duration(seconds: 29));
      expect(done, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(done, isTrue);
      expect(error, isA<GeminiApiException>());
      expect((error! as GeminiApiException).message, AIConfig.timeoutMessage);
    });

    testWidgets('the chat shows the timeout message after 45 s, not 15 s', (
      tester,
    ) async {
      final service = CoachChatService(aiProvider: _HangingProvider());
      List<CoachMessage>? result;
      service
          .sendMessage(
            message: 'Is creatine safe?',
            context: FitnessContext.initial(),
            currentMessages: const [],
          )
          .then((messages) => result = messages);

      await tester.pump(const Duration(seconds: 16));
      expect(result, isNull, reason: 'still waiting at 16 s');
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(result, isNotNull);
      final last = result!.last.content;
      expect(last, contains('took too long to respond'));
      expect(last, isNot(contains('Gemini')));
      expect(last, isNot(contains('15 seconds')));
    });
  });
}
