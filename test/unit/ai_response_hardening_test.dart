import 'dart:convert';

import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/ai_response_cache.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/widgets/coach/ai_chat_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request with a fixed status and body. No network.
class _FixedClient extends http.BaseClient {
  final int status;
  final String body;

  _FixedClient(this.status, this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );
  }
}

GeminiAIProvider _provider(int status, String body) => GeminiAIProvider(
  config: AIConfig(
    proxyUrl: 'https://abc.supabase.co/functions/v1/ai-proxy',
    accessTokenProvider: () => 'secret-user-jwt-123',
  ),
  httpClient: _FixedClient(status, body),
);

Future<String> _answer(GeminiAIProvider provider) => provider.generateResponse(
  message: 'Explain progressive overload in detail',
  context: FitnessContext.initial(),
  history: const [],
);

String _geminiBody(String text, {String? finishReason}) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': text},
        ],
      },
      'finishReason': ?finishReason,
    },
  ],
});

Matcher _geminiError(String message) => throwsA(
  isA<GeminiApiException>().having((e) => e.message, 'message', message),
);

/// A chat service whose send always fails in an unexpected way.
class _ExplodingChatService extends CoachChatService {
  @override
  Future<List<CoachMessage>> sendMessage({
    required String message,
    required FitnessContext context,
    List<CoachMessage>? currentMessages,
    ChatAttachment? attachment,
  }) async => throw StateError('disk full: secret-detail');

  @override
  List<CoachMessage> getMessages() => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
    AIResponseCache.instance.clear();
    AIResponseCache.instance.preloadDomainKnowledge();
  });

  group('truncated and blocked answers', () {
    test('a STOP answer, or one with no reason, is complete', () async {
      expect(
        await _answer(
          _provider(200, _geminiBody('Full answer.', finishReason: 'STOP')),
        ),
        'Full answer.',
      );
      expect(
        await _answer(_provider(200, _geminiBody('Also fine.'))),
        'Also fine.',
      );
    });

    test('MAX_TOKENS is not shown as an answer, even with partial text', () {
      expect(
        _answer(
          _provider(
            200,
            _geminiBody(
              'Progressive overload is the',
              finishReason: 'MAX_TOKENS',
            ),
          ),
        ),
        _geminiError(GeminiAIProvider.truncatedMessage),
      );
    });

    test('safety and other blocked reasons give a friendly refusal', () {
      for (final reason in [
        'SAFETY',
        'RECITATION',
        'BLOCKLIST',
        'PROHIBITED_CONTENT',
      ]) {
        expect(
          _answer(_provider(200, _geminiBody('partial', finishReason: reason))),
          _geminiError(GeminiAIProvider.blockedMessage),
          reason: reason,
        );
      }
    });

    test('a blocked prompt (no candidates) gives the refusal message', () {
      final body = jsonEncode({
        'promptFeedback': {'blockReason': 'SAFETY'},
      });
      expect(
        _answer(_provider(200, body)),
        _geminiError(GeminiAIProvider.blockedMessage),
      );
    });

    test('unknown finish reasons and empty candidates are not answers', () {
      expect(
        _answer(
          _provider(
            200,
            _geminiBody('x', finishReason: 'MALFORMED_FUNCTION_CALL'),
          ),
        ),
        _geminiError(GeminiAIProvider.incompleteMessage),
      );
      expect(
        _answer(_provider(200, jsonEncode({'candidates': []}))),
        _geminiError(GeminiAIProvider.emptyResponseMessage),
      );
    });

    test(
      'the chat stores a truncated reply as an error, not as AI text',
      () async {
        final service = CoachChatService(
          aiProvider: _provider(
            200,
            _geminiBody(
              'Progressive overload is the',
              finishReason: 'MAX_TOKENS',
            ),
          ),
        );
        final messages = await service.sendMessage(
          message: 'Explain progressive overload in detail',
          context: FitnessContext.initial(),
          currentMessages: const [],
        );
        final reply = messages.last;
        expect(reply.category, CoachReplySource.error);
        expect(reply.content, GeminiAIProvider.truncatedMessage);
        expect(reply.content, isNot(contains('Progressive overload is the')));
        // And it is not cached for the next ask.
        expect(
          AIResponseCache.instance.get(
            'explain progressive overload in detail',
          ),
          isNull,
        );
      },
    );
  });

  group('sanitized HTTP errors', () {
    test('proxy sign-in and quota messages are kept', () {
      for (final entry in {
        401: 'Your session expired. Sign in again.',
        429: 'Daily AI limit reached. Upgrade to Atlas Pro for more.',
      }.entries) {
        final body = jsonEncode({
          'error': {'code': entry.key, 'message': entry.value},
        });
        expect(_answer(_provider(entry.key, body)), _geminiError(entry.value));
      }
    });

    test('provider error bodies are replaced by short messages', () {
      const secretBody =
          '{"error":{"code":400,"message":"API key not valid. key=AIzaSyFAKE Bearer secret-user-jwt-123"}}';
      expect(
        _answer(_provider(400, secretBody)),
        _geminiError(GeminiAIProvider.userMessageForHttpError(400, '')),
      );
      // An upstream (not proxy) 429 is not passed through either.
      final upstream429 = jsonEncode({
        'error': {
          'code': 429,
          'message': 'Resource has been exhausted (e.g. check quota).',
        },
      });
      expect(
        _answer(_provider(429, upstream429)),
        _geminiError(
          'Atlas AI is busy right now. Please try again in a minute.',
        ),
      );
    });

    test('HTML and platform errors never reach the user', () async {
      const html =
          '<html><body><h1>502 Bad Gateway</h1>token=secret-user-jwt-123</body></html>';
      for (final status in [500, 502, 503, 504]) {
        try {
          await _answer(_provider(status, html));
          fail('expected an exception');
        } on GeminiApiException catch (e) {
          expect(e.message, contains('temporarily unavailable'));
          for (final leaked in [
            '<html',
            '502',
            'Bad Gateway',
            'secret-user-jwt-123',
            'AIza',
          ]) {
            expect(
              e.message,
              isNot(contains(leaked)),
              reason: '$status $leaked',
            );
          }
          expect(e.details, isNull);
        }
      }
    });

    test('an unreadable 200 body is a friendly error', () {
      expect(
        _answer(_provider(200, '<html>maintenance</html>')),
        _geminiError(GeminiAIProvider.unreadableResponseMessage),
      );
    });

    test('status-specific messages are short and safe', () {
      expect(
        GeminiAIProvider.userMessageForHttpError(413, 'x'),
        contains('too large'),
      );
      expect(
        GeminiAIProvider.userMessageForHttpError(403, 'x'),
        contains('not available'),
      );
      expect(
        GeminiAIProvider.userMessageForHttpError(401, 'garbage'),
        contains('sign in'),
      );
      for (final status in [400, 401, 403, 413, 429, 500, 503]) {
        final message = GeminiAIProvider.userMessageForHttpError(
          status,
          '<b>raw</b> AIzaKEY',
        );
        expect(message.length, lessThan(120));
        expect(message, isNot(contains('raw')));
        expect(message, isNot(contains('AIza')));
      }
    });
  });

  group('unexpected failures are visible', () {
    test(
      'sendCoachMessage shows an error reply instead of failing silently',
      () async {
        final provider = FitnessProvider(
          coachChatService: _ExplodingChatService(),
        );
        await provider.sendCoachMessage('Explain progressive overload');

        final messages = provider.coachMessages;
        expect(
          messages.where((m) => m.role == CoachRole.user).last.content,
          'Explain progressive overload',
        );
        final reply = messages.last;
        expect(reply.role, CoachRole.assistant);
        expect(reply.category, CoachReplySource.error);
        expect(reply.id, startsWith('msg_error_'));
        expect(
          reply.content,
          'Something went wrong sending that message. Please try again.',
        );
        // The exception text is not shown to the user.
        expect(reply.content, isNot(contains('disk full')));
        expect(reply.content, isNot(contains('secret-detail')));
        expect(provider.isCoachReplying, isFalse);
      },
    );
  });

  group('status banner', () {
    Future<void> pump(WidgetTester tester, bool signedIn) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AiChatStatusBanner(isSignedIn: signedIn)),
      ),
    );

    testWidgets('signed in: neutral text, no claims about learning or data', (
      tester,
    ) async {
      await pump(tester, true);
      expect(find.text('Atlas AI'), findsOneWidget);
      expect(find.byKey(const Key('ai_status_text')), findsOneWidget);
      expect(find.text(AiChatStatusBanner.signedInText), findsOneWidget);
      for (final claim in [
        'learning',
        'data sources',
        'Continuously',
        'Analyzing',
        'online',
      ]) {
        expect(
          find.textContaining(claim, findRichText: true),
          findsNothing,
          reason: claim,
        );
      }
    });

    testWidgets('signed out: says sign-in is needed', (tester) async {
      await pump(tester, false);
      expect(find.text(AiChatStatusBanner.signedOutText), findsOneWidget);
      expect(find.text(AiChatStatusBanner.signedInText), findsNothing);
    });
  });
}
