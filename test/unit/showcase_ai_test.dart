import 'dart:convert';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:atlas/services/ai/gemini_transport.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';
import 'package:atlas/services/machine/machine_scan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _proxy = 'https://proj.supabase.co/functions/v1/ai-proxy';
const _anon = 'public-anon-key-for-tests';

bool _showcase = true;

/// A proxy-backed config with Showcase Mode switched by [_showcase] and,
/// optionally, a signed-in user's token.
AIConfig _config({String? userToken}) => AIConfig(
  proxyUrl: _proxy,
  anonKey: _anon,
  accessTokenProvider: () => userToken,
  showcaseModeProvider: () => _showcase,
);

String _geminiText(String text) => jsonEncode({
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

class _Recorder {
  final List<http.Request> requests = [];
  late final MockClient client;
  _Recorder(String Function() answer, {int status = 200}) {
    client = MockClient((request) async {
      requests.add(request);
      return http.Response(answer(), status);
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _showcase = true;
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.setShowcaseModeEnabled(true);
  });

  tearDown(() async {
    await LocalStorage.setShowcaseModeEnabled(false);
  });

  group('AIConfig in Showcase Mode', () {
    test('is available with no account and no user token', () {
      final c = _config();
      expect(c.isShowcase, isTrue);
      expect(c.usesShowcaseProxy, isTrue);
      expect(c.isConfigured, isTrue);
      expect(c.unavailableReason, isNull);
    });

    test('outside Showcase a signed-out user is still told to sign in', () {
      _showcase = false;
      final c = _config();
      expect(c.isConfigured, isFalse);
      expect(c.unavailableReason, AIUnavailableReason.notSignedIn);
    });

    test('outside Showcase a signed-in user works as before', () {
      _showcase = false;
      final c = _config(userToken: 'user-token');
      expect(c.usesShowcaseProxy, isFalse);
      expect(c.isConfigured, isTrue);
    });

    test('a build with no backend says so, never "sign in"', () {
      final c = AIConfig(showcaseModeProvider: () => true);
      expect(c.isConfigured, isFalse);
      expect(c.unavailableReason, AIUnavailableReason.backendNotConfigured);
      final e = GeminiAIProvider.unavailableException(c);
      expect(e.message, isNot(contains('Sign in')));
    });

    test('fromEnvironment follows the real Showcase switch', () async {
      final c = AIConfig.fromEnvironment().copyWith(
        proxyUrl: _proxy,
        anonKey: _anon,
      );
      expect(c.isShowcase, isTrue);
      await LocalStorage.setShowcaseModeEnabled(false);
      expect(c.isShowcase, isFalse);
    });
  });

  group('Showcase requests', () {
    Future<http.Request> send(AIConfig config) async {
      final rec = _Recorder(() => _geminiText('ok'));
      await postGenerateContent(
        client: rec.client,
        config: config,
        feature: 'coach',
        body: {
          'contents': [
            {
              'parts': [
                {'text': 'hi'},
              ],
            },
          ],
        },
      );
      return rec.requests.single;
    }

    test('carry no user token and no user id, only the public key', () async {
      final req = await send(_config());
      expect(req.url.toString(), _proxy);
      expect(req.headers['Authorization'], 'Bearer $_anon');
      expect(req.headers[showcaseHeader], '1');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['showcase'], isTrue);
      expect(body['feature'], 'coach');
      expect(req.body, isNot(contains('user')));
    });

    test(
      'never carry a signed-in user\'s token, even on their device',
      () async {
        final req = await send(_config(userToken: 'real-user-token'));
        expect(
          req.headers['Authorization'],
          isNot(contains('real-user-token')),
        );
        expect(req.headers[showcaseHeader], '1');
      },
    );

    test('a signed-in user outside Showcase is sent as that user', () async {
      _showcase = false;
      final req = await send(_config(userToken: 'real-user-token'));
      expect(req.headers['Authorization'], 'Bearer real-user-token');
      expect(req.headers.containsKey(showcaseHeader), isFalse);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body.containsKey('showcase'), isFalse);
    });

    test(
      'a server that is not updated gives a clear message, not "sign in"',
      () async {
        final rec = _Recorder(
          () => jsonEncode({
            'error': {'code': 401, 'message': 'Sign in to use Atlas AI.'},
          }),
          status: 401,
        );
        final provider = GeminiAIProvider(
          config: _config(),
          httpClient: rec.client,
        );
        await expectLater(
          provider.generateResponse(
            message: 'hello',
            context: FitnessContext.initial(),
            history: const [],
          ),
          throwsA(
            isA<GeminiApiException>().having(
              (e) => e.message,
              'message',
              GeminiAIProvider.showcaseNotEnabledMessage,
            ),
          ),
        );
      },
    );

    test('the busy message from the server is shown as it is', () {
      expect(
        GeminiAIProvider.userMessageForHttpError(
          429,
          GeminiAIProvider.showcaseBusyMessage,
        ),
        GeminiAIProvider.showcaseBusyMessage,
      );
    });
  });

  group('Atlas AI chat in Showcase Mode', () {
    test(
      'a message is sent and the live reply is stored as an AI answer',
      () async {
        final rec = _Recorder(() => _geminiText('Eat protein and carbs.'));
        final service = CoachChatService(
          aiProvider: GeminiAIProvider(
            config: _config(),
            httpClient: rec.client,
          ),
        );
        final thread = await service.sendMessage(
          message: 'Plan my push day with sets and reps',
          context: FitnessContext.initial(),
        );
        expect(rec.requests, isNotEmpty, reason: 'the real backend is called');
        expect(thread.last.role, CoachRole.assistant);
        expect(thread.last.category, isNot(CoachReplySource.error));
        expect(thread.last.content, contains('protein'));
        expect(thread.last.content, isNot(contains('Sign in')));
      },
    );

    test('a failed request is an honest error with the real reason', () async {
      final rec = _Recorder(() => '{}', status: 500);
      final service = CoachChatService(
        aiProvider: GeminiAIProvider(config: _config(), httpClient: rec.client),
      );
      final thread = await service.sendMessage(
        message: 'Plan my push day with sets and reps',
        context: FitnessContext.initial(),
      );
      expect(thread.last.category, CoachReplySource.error);
      expect(thread.last.content, isNot(contains('Sign in')));
    });

    test('the conversation is stored apart from the real one', () async {
      // A real conversation exists first.
      await LocalStorage.setShowcaseModeEnabled(false);
      await LocalStorage.saveCoachMessages([
        CoachMessage(
          id: 'real1',
          role: CoachRole.user,
          content: 'my private question',
          timestamp: DateTime.now(),
        ),
      ]);

      // Showcase chat.
      await LocalStorage.setShowcaseModeEnabled(true);
      final rec = _Recorder(() => _geminiText('A demo answer.'));
      final service = CoachChatService(
        aiProvider: GeminiAIProvider(config: _config(), httpClient: rec.client),
      );
      await service.sendMessage(
        message: 'Plan my push day with sets and reps',
        context: FitnessContext.initial(),
      );
      expect(
        LocalStorage.getCoachMessages().map((m) => m.content),
        isNot(contains('my private question')),
        reason: 'showcase must not read the real conversation',
      );

      // Back to the real account: untouched, and no demo messages in it.
      await LocalStorage.setShowcaseModeEnabled(false);
      final real = LocalStorage.getCoachMessages();
      expect(real.map((m) => m.id), ['real1']);
      expect(
        real.any((m) => m.content.contains('push day')),
        isFalse,
        reason: 'a demo message must never reach a real history',
      );
    });

    test('ending Showcase forgets the demo conversation', () async {
      await LocalStorage.saveCoachMessages([
        CoachMessage(
          id: 'demo1',
          role: CoachRole.user,
          content: 'demo question',
          timestamp: DateTime.now(),
        ),
      ]);
      expect(LocalStorage.getCoachMessages(), hasLength(1));
      await LocalStorage.clearShowcaseCoachMessages();
      expect(LocalStorage.getCoachMessages(), isEmpty);
    });
  });

  group('Scanners in Showcase Mode', () {
    final photo = ChatAttachment(
      base64Data: 'ZHVtbXk=',
      mimeType: 'image/jpeg',
    );

    test('the food scanner analyses a photo with the live backend', () async {
      final rec = _Recorder(
        () => _geminiText(
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
        ),
      );
      final service = FoodAIVisionService(
        config: _config(),
        httpClient: rec.client,
      );
      final result = await service.analyzeMealImage(attachment: photo);
      expect(rec.requests.single.headers[showcaseHeader], '1');
      expect(result.foodName, 'Banana');
      // It is still an AI estimate, labelled as one.
      expect(result.isAiGenerated, isTrue);
    });

    test('the food scanner keeps unknown nutrients unknown', () async {
      final rec = _Recorder(
        () => _geminiText(
          jsonEncode({
            'foodName': 'Mystery snack',
            'confidence': 0.6,
            'servingSize': 50,
            'servingUnit': 'g',
            'calories': 200,
            'ingredients': ['snack'],
          }),
        ),
      );
      final service = FoodAIVisionService(
        config: _config(),
        httpClient: rec.client,
      );
      final result = await service.analyzeMealImage(attachment: photo);
      // Missing stays unknown: the 0 is only a placeholder behind the flag.
      expect(result.unknownNutrients, contains(FoodItem.proteinKey));
      expect(result.toFoodItem().unknownNutrients, contains(FoodItem.proteinKey));
    });

    test(
      'the machine scanner reaches the backend without an account',
      () async {
        final rec = _Recorder(
          () => _geminiText(
            jsonEncode({
              'is_gym_equipment': true,
              'machineName': 'Lat Pulldown',
              'confidence': 0.9,
            }),
          ),
        );
        final service = MachineScanService(
          config: _config(),
          httpClient: rec.client,
        );
        final result = await service.identify(photo);
        expect(rec.requests.single.headers[showcaseHeader], '1');
        expect(result, isNotNull);
      },
    );

    test(
      'the scanners name the real problem, not "sign in", with no backend',
      () async {
        final noBackend = AIConfig(showcaseModeProvider: () => true);
        await expectLater(
          FoodAIVisionService(
            config: noBackend,
          ).analyzeMealImage(attachment: photo),
          throwsA(
            isA<FoodVisionException>().having(
              (e) => e.message,
              'message',
              isNot(contains('Sign in')),
            ),
          ),
        );
        await expectLater(
          MachineScanService(config: noBackend).identify(photo),
          throwsA(
            isA<MachineScanException>().having(
              (e) => e.message,
              'message',
              isNot(contains('Sign in')),
            ),
          ),
        );
      },
    );

    test('outside Showcase the scanners still need a signed-in user', () async {
      _showcase = false;
      await expectLater(
        MachineScanService(config: _config()).identify(photo),
        throwsA(
          isA<MachineScanException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });

  group('Every AI entry point shares the Showcase path', () {
    test(
      'coach chat, food scan and machine scan all send a Showcase request',
      () async {
        final rec = _Recorder(
          () => _geminiText(
            jsonEncode({
              'foodName': 'Egg',
              'confidence': 0.9,
              'servingSize': 50,
              'servingUnit': 'g',
              'calories': 70,
              'is_gym_equipment': false,
            }),
          ),
        );
        final config = _config();
        final photo = ChatAttachment(
          base64Data: 'ZA==',
          mimeType: 'image/jpeg',
        );

        await GeminiAIProvider(
          config: config,
          httpClient: rec.client,
        ).generateResponse(
          message: 'hello',
          context: FitnessContext.initial(),
          history: const [],
        );
        await FoodAIVisionService(
          config: config,
          httpClient: rec.client,
        ).analyzeMealImage(attachment: photo);
        try {
          await MachineScanService(
            config: config,
            httpClient: rec.client,
          ).identify(photo);
        } catch (_) {
          // A "not equipment" answer may throw; the request is what matters.
        }

        expect(rec.requests, hasLength(3));
        for (final r in rec.requests) {
          expect(r.headers[showcaseHeader], '1');
          expect(r.headers['Authorization'], 'Bearer $_anon');
        }
      },
    );
  });
}
