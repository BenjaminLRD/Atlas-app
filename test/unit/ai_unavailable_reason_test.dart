import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:atlas/services/supabase/supabase_env.dart';
import 'package:atlas/widgets/coach/ai_chat_status_banner.dart';

const _proxy = 'https://proj.supabase.co/functions/v1/ai-proxy';

/// No Supabase settings were passed at build time: no proxy address.
AIConfig _noBackend() => AIConfig();

/// Backend known, nobody signed in.
AIConfig _signedOut() =>
    AIConfig(proxyUrl: _proxy, accessTokenProvider: () => null);

/// Backend known and a session exists.
AIConfig _signedIn() =>
    AIConfig(proxyUrl: _proxy, accessTokenProvider: () => 'user-token');

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('AIConfig tells a missing backend from a signed-out user', () {
    test('no proxy address: the build has no AI backend', () {
      final c = _noBackend();
      expect(c.isConfigured, isFalse);
      expect(c.unavailableReason, AIUnavailableReason.backendNotConfigured);
    });

    test('proxy address but no session: not signed in', () {
      final c = _signedOut();
      expect(c.isConfigured, isFalse);
      expect(c.unavailableReason, AIUnavailableReason.notSignedIn);
    });

    test('an empty token counts as signed out', () {
      final c = AIConfig(proxyUrl: _proxy, accessTokenProvider: () => '');
      expect(c.unavailableReason, AIUnavailableReason.notSignedIn);
    });

    test('proxy address and session: available', () {
      final c = _signedIn();
      expect(c.isConfigured, isTrue);
      expect(c.unavailableReason, isNull);
    });

    test('a developer key makes it available without a proxy', () {
      final c = AIConfig(apiKey: 'a-developer-key-123');
      expect(c.unavailableReason, isNull);
    });

    test('a too-short key does not count, so there is no backend', () {
      final c = AIConfig(apiKey: 'short');
      expect(c.unavailableReason, AIUnavailableReason.backendNotConfigured);
    });

    test('the build-time fallback Supabase values are not valid settings', () {
      // Without --dart-define-from-file=.env SupabaseEnv.dev() holds these
      // placeholders: Supabase is never initialized and no proxy is derived.
      expect(SupabaseEnv.dev().isValid, isFalse);
      expect(SupabaseEnv.dev().supabaseAnonKey, 'dev_anon_key');
    });
  });

  group('the provider reports the real reason and sends nothing', () {
    FitnessContext context() => FitnessContext.initial();

    Future<GeminiApiException> chatFails(AIConfig config) async {
      var requests = 0;
      final provider = GeminiAIProvider(
        config: config,
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      try {
        await provider.generateResponse(
          message: 'hello',
          context: context(),
          history: const [],
        );
      } on GeminiApiException catch (e) {
        expect(requests, 0, reason: 'no request may be made');
        return e;
      }
      fail('expected a GeminiApiException');
    }

    test('missing backend: says the build is not set up (503)', () async {
      final e = await chatFails(_noBackend());
      expect(e.message, GeminiAIProvider.backendNotConfiguredMessage);
      expect(e.statusCode, 503);
      expect(e.message, isNot(contains('Sign in')));
    });

    test('signed out: says to sign in (401)', () async {
      final e = await chatFails(_signedOut());
      expect(e.message, GeminiAIProvider.notSignedInMessage);
      expect(e.statusCode, 401);
    });

    test('the agent path reports the same reasons', () async {
      for (final entry in {
        _noBackend(): GeminiAIProvider.backendNotConfiguredMessage,
        _signedOut(): GeminiAIProvider.notSignedInMessage,
      }.entries) {
        final provider = GeminiAIProvider(config: entry.key);
        await expectLater(
          provider.generateAgentResponse(
            message: 'hi',
            context: context(),
            history: const [],
            tools: const [],
          ),
          throwsA(
            isA<GeminiApiException>().having(
              (e) => e.message,
              'message',
              entry.value,
            ),
          ),
        );
      }
    });

    test('provider and chat service expose the reason', () {
      expect(
        GeminiAIProvider(config: _noBackend()).unavailableReason,
        AIUnavailableReason.backendNotConfigured,
      );
      expect(
        CoachChatService(
          aiProvider: GeminiAIProvider(config: _signedOut()),
        ).unavailableReason,
        AIUnavailableReason.notSignedIn,
      );
      expect(
        CoachChatService(
          aiProvider: GeminiAIProvider(config: _signedIn()),
        ).unavailableReason,
        isNull,
      );
    });
  });

  group('chat shows a real error, never fallback text as an answer', () {
    Future<CoachMessage> reply(AIConfig config) async {
      final service = CoachChatService(
        aiProvider: GeminiAIProvider(
          config: config,
          httpClient: MockClient((_) async => http.Response('{}', 500)),
        ),
      );
      final thread = await service.sendMessage(
        message: 'Plan my push day with sets and reps',
        context: FitnessContext.initial(),
      );
      return thread.last;
    }

    test('missing backend: an error reply with the real reason', () async {
      final last = await reply(_noBackend());
      expect(last.role, CoachRole.assistant);
      expect(last.category, CoachReplySource.error);
      expect(last.content, GeminiAIProvider.backendNotConfiguredMessage);
    });

    test('signed out: an error reply asking to sign in', () async {
      final last = await reply(_signedOut());
      expect(last.category, CoachReplySource.error);
      expect(last.content, GeminiAIProvider.notSignedInMessage);
    });
  });

  group('the request path works when the build and session are fine', () {
    test(
      'signed in: the proxy gets the user token and the coach feature',
      () async {
        late http.Request seen;
        final provider = GeminiAIProvider(
          config: _signedIn(),
          httpClient: MockClient((request) async {
            seen = request;
            return http.Response(_geminiText('Do 4 sets of 8.'), 200);
          }),
        );

        final text = await provider.generateResponse(
          message: 'Plan my push day',
          context: FitnessContext.initial(),
          history: const [],
        );

        expect(text, 'Do 4 sets of 8.');
        expect(seen.url.toString(), _proxy);
        expect(seen.headers['Authorization'], 'Bearer user-token');
        expect((jsonDecode(seen.body) as Map)['feature'], 'coach');
        expect(
          seen.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-goog-api-key')),
        );
      },
    );

    test('server answers shown to the user are the proxy messages', () {
      expect(
        GeminiAIProvider.userMessageForHttpError(
          401,
          'Your session expired. Sign in again.',
        ),
        'Your session expired. Sign in again.',
      );
      expect(
        GeminiAIProvider.userMessageForHttpError(
          503,
          'Atlas AI is not configured on the server.',
        ),
        'Atlas AI is not configured on the server.',
      );
    });

    test('other server errors stay generic and never leak a body', () {
      expect(
        GeminiAIProvider.userMessageForHttpError(503, '<html>gateway</html>'),
        'Atlas AI is temporarily unavailable. Please try again in a moment.',
      );
      expect(
        GeminiAIProvider.userMessageForHttpError(500, 'secret detail'),
        isNot(contains('secret')),
      );
    });
  });

  group('status banner', () {
    Future<void> pump(WidgetTester tester, {required bool backendMissing}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AiChatStatusBanner(
                isSignedIn: false,
                backendMissing: backendMissing,
              ),
            ),
          ),
        );

    testWidgets('a missing backend does not tell the user to sign in', (
      tester,
    ) async {
      await pump(tester, backendMissing: true);
      expect(find.text(AiChatStatusBanner.backendMissingText), findsOneWidget);
      expect(find.text(AiChatStatusBanner.signedOutText), findsNothing);
    });

    testWidgets('otherwise signed out still says to sign in', (tester) async {
      await pump(tester, backendMissing: false);
      expect(find.text(AiChatStatusBanner.signedOutText), findsOneWidget);
    });
  });
}
