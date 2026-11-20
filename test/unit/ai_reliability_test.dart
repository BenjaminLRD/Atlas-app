import 'dart:convert';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/ai_guardrail_service.dart';
import 'package:atlas/services/ai/ai_provider.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Records requests and answers with a fixed Gemini reply. No network.
class _FakeClient extends http.BaseClient {
  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          '{"candidates":[{"content":{"parts":[{"text":"A real answer."}]}}]}',
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _ThrowingProvider implements AIProvider {
  @override
  String get providerName => 'throwing';
  @override
  bool get isOnline => true;
  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  }) async => throw const GeminiApiException(message: 'Boom');
}

class _AnsweringProvider implements AIProvider {
  @override
  String get providerName => 'answering';
  @override
  bool get isOnline => true;
  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  }) async => 'Here is a real answer about your question.';
}

CoachMessage _msg(String id, CoachRole role, String text, {String? category}) =>
    CoachMessage(
      id: id,
      role: role,
      content: text,
      timestamp: DateTime(2026, 10, 15),
      category: category,
    );

UserProfile _profile({
  String name = '',
  String dob = '',
  String height = '',
  String weight = '',
}) => UserProfile.defaultProfile().copyWith(
  name: name,
  dob: dob,
  height: height,
  weight: weight,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('routing: the six audited messages and substring false positives', () {
    final guardrail = AIGuardrailService.instance;

    test('personal, conversational and wellness questions go to the model', () {
      for (final message in [
        'what took you so long to respond',
        "what's my age",
        'how old am I',
        'what is my name',
        'what is my bmi',
        'can you speak hindi',
      ]) {
        expect(guardrail.isFitnessRelated(message), isTrue, reason: message);
        final decision = AIRequestRouter.instance.route(
          message: message,
          context: FitnessContext.initial(),
        );
        expect(decision.needsLLM, isTrue, reason: message);
        expect(decision.isDirectAnswer, isFalse, reason: message);
      }
    });

    test('"rep" in report and "set" in settings are not keyword hits', () {
      // Both used to be classified by substring; neither is off-topic.
      expect(guardrail.isFitnessRelated('did you get my report'), isTrue);
      expect(guardrail.isFitnessRelated('open settings'), isTrue);
      // And an off-topic word inside another word is not a hit either.
      expect(guardrail.isFitnessRelated('my sqlite note on pythons'), isTrue);
    });

    test('clearly unrelated requests still get the local redirect', () {
      for (final message in [
        'Write python code to sort a list',
        'Who is the president?',
        'Give me crypto stock market advice',
        'Write a poem about space',
        'What is the latest movie in cinema?',
      ]) {
        expect(guardrail.isFitnessRelated(message), isFalse, reason: message);
        final decision = AIRequestRouter.instance.route(
          message: message,
          context: FitnessContext.initial(),
        );
        expect(decision.isDirectAnswer, isTrue, reason: message);
        expect(decision.directResponse, AIGuardrailService.offTopicResponse);
      }
    });

    test('distinct questions never share one canned answer', () {
      final answers = {
        for (final m in ['what took you so long', "what's my age"])
          AIRequestRouter.instance
              .route(message: m, context: FitnessContext.initial())
              .directResponse,
      };
      expect(answers, {null});
    });
  });

  group('prompt: truthful personal context', () {
    test('missing profile values are marked not recorded', () {
      final block = CoachPromptBuilder.userProfileBlock(_profile());
      expect(block, contains('- Name: not recorded'));
      expect(block, contains('- Age: not recorded'));
      expect(block, contains('- Height: not recorded'));
      expect(block, contains('- Weight: not recorded'));
      // UserProfile.age falls back to 25; that must never be sent.
      expect(block, isNot(contains('25')));
    });

    test('present values are included, age computed from date of birth', () {
      final block = CoachPromptBuilder.userProfileBlock(
        _profile(name: 'Lal', dob: '1998-05-14', height: '178', weight: '77.5'),
        now: DateTime(2026, 10, 15),
      );
      expect(block, contains('- Name: Lal'));
      expect(block, contains('- Age: 28'));
      expect(block, contains('- Height: 178 cm'));
      expect(block, contains('- Weight: 77.5 kg'));
    });

    test(
      'before the birthday the age is one lower; bad dates are unrecorded',
      () {
        expect(
          CoachPromptBuilder.userProfileBlock(
            _profile(dob: '1998-12-31'),
            now: DateTime(2026, 10, 15),
          ),
          contains('- Age: 27'),
        );
        for (final dob in ['not-a-date', '2030-01-01', '1800-01-01']) {
          expect(
            CoachPromptBuilder.userProfileBlock(_profile(dob: dob)),
            contains('- Age: not recorded'),
            reason: dob,
          );
        }
      },
    );

    test('the prompt carries the profile block and the honesty rule', () {
      final prompt = const CoachPromptBuilder().buildPrompt(
        message: "what's my age",
        context: FitnessContext.initial(),
      );
      expect(prompt, contains('[USER PROFILE]'));
      expect(prompt, contains('NEVER invent personal facts'));
    });
  });

  group('prompt: no fabricated defaults', () {
    test('an empty context contains none of the old invented figures', () {
      final prompt = const CoachPromptBuilder().buildPrompt(
        message: 'How am I doing?',
        context: FitnessContext.initial(),
      );
      for (final invented in [
        'Squat 1RM: 130',
        'Bench Press: 100kg',
        'Deadlift: 160',
        'Average form: 82%',
        'Knee collapse',
        'scored 82/100',
        'ROM: 88%',
        'Symmetry: 94%',
        'Tempo: 78%',
        'build_muscle',
      ]) {
        expect(prompt, isNot(contains(invented)), reason: invented);
      }
      expect(prompt, contains('No form analysis has been recorded yet.'));
      expect(prompt, contains('No athlete profile data recorded yet'));
      expect(prompt, contains('Nutrition Adherence Model: not enough logged'));
      expect(prompt, contains('Workout Recommendation Model: not enough'));
    });

    test('recovery values that were not recorded are not substituted', () {
      final prompt = const CoachPromptBuilder().buildPrompt(
        message: 'How is my recovery?',
        context: FitnessContext.initial(),
      );
      expect(prompt, contains('Recovery: not recorded'));
      expect(prompt, contains('Resting HR: not recorded'));
      expect(prompt, isNot(contains('HRV: 62')));
      expect(prompt, isNot(contains('Resting HR: 58')));
      expect(prompt, contains('Recent Training Volume: not recorded'));
    });
  });

  group('conversation history', () {
    test('keeps order and roles and does not repeat the current message', () {
      final contents = GeminiAIProvider.buildHistoryContents([
        _msg('1', CoachRole.user, 'What is creatine?'),
        _msg('2', CoachRole.assistant, 'A supplement.', category: 'ai'),
        _msg('3', CoachRole.user, 'Is it safe?'), // the message being sent
      ], currentMessage: 'Is it safe?');
      expect(contents.map((c) => c['role']), ['user', 'model']);
      expect(contents.first['parts'][0]['text'], 'What is creatine?');
      expect(contents.last['parts'][0]['text'], 'A supplement.');
    });

    test('is bounded in count and length', () {
      final history = [
        for (var i = 0; i < 30; i++)
          _msg(
            'm$i',
            i.isEven ? CoachRole.user : CoachRole.assistant,
            'turn $i ${'x' * 2000}',
            category: i.isEven ? null : 'ai',
          ),
      ];
      final contents = GeminiAIProvider.buildHistoryContents(
        history,
        currentMessage: 'now',
      );
      expect(
        contents.length,
        lessThanOrEqualTo(GeminiAIProvider.maxHistoryMessages),
      );
      for (final c in contents) {
        final text = c['parts'][0]['text'] as String;
        expect(
          text.length,
          lessThanOrEqualTo(GeminiAIProvider.maxHistoryChars + 1),
        );
      }
      expect(contents.first['role'], 'user');
    });

    test('local redirects and errors are not sent back as model turns', () {
      final contents = GeminiAIProvider.buildHistoryContents([
        _msg('1', CoachRole.user, 'write python'),
        _msg(
          '2',
          CoachRole.assistant,
          AIGuardrailService.offTopicResponse,
          category: CoachReplySource.local,
        ),
        _msg('3', CoachRole.user, 'ok then, creatine?'),
        _msg(
          'msg_error_1',
          CoachRole.assistant,
          'Atlas AI took too long to respond. Please try again.',
          category: CoachReplySource.error,
        ),
      ], currentMessage: 'again');
      // Two user turns remain and are merged so roles still alternate.
      expect(contents, hasLength(1));
      expect(contents.single['role'], 'user');
      expect(contents.single['parts'][0]['text'], contains('write python'));
      expect(contents.single['parts'][0]['text'], contains('creatine'));
      expect(
        contents.single['parts'][0]['text'],
        isNot(contains('I am your fitness coach')),
      );
    });

    test('the request sent to ai-proxy includes the earlier turns', () async {
      final client = _FakeClient();
      final provider = GeminiAIProvider(
        config: AIConfig(
          proxyUrl: 'https://abc.supabase.co/functions/v1/ai-proxy',
          accessTokenProvider: () => 'user-jwt',
        ),
        httpClient: client,
      );
      final reply = await provider.generateResponse(
        message: 'And how much per day?',
        context: FitnessContext.initial(),
        history: [
          _msg('1', CoachRole.user, 'What is creatine?'),
          _msg('2', CoachRole.assistant, 'A supplement.', category: 'ai'),
          _msg('3', CoachRole.user, 'And how much per day?'),
        ],
      );
      expect(reply, 'A real answer.');
      final body = jsonDecode(client.requests.single.body) as Map;
      final contents = (body['request'] as Map)['contents'] as List;
      expect(contents.map((c) => (c as Map)['role']), [
        'user',
        'model',
        'user',
      ]);
      final last = (contents.last as Map)['parts'][0]['text'] as String;
      expect(last, contains('And how much per day?'));
      // The latest user message appears once, in the final turn.
      final all = jsonEncode(contents);
      expect('And how much per day?'.allMatches(all).length, 1);
    });
  });

  group('reply source marking', () {
    CoachChatService service(AIProvider provider) =>
        CoachChatService(aiProvider: provider);

    test('a model answer is marked ai', () async {
      final result = await service(_AnsweringProvider()).sendMessage(
        message: 'how old am I',
        context: FitnessContext.initial(),
        currentMessages: const [],
      );
      expect(result.last.role, CoachRole.assistant);
      expect(result.last.category, CoachReplySource.ai);
    });

    test('a local redirect is marked local, not ai', () async {
      final result = await service(_AnsweringProvider()).sendMessage(
        message: 'Write python code to sort a list',
        context: FitnessContext.initial(),
        currentMessages: const [],
      );
      expect(result.last.content, AIGuardrailService.offTopicResponse);
      expect(result.last.category, CoachReplySource.local);
    });

    test('a failure is marked error and cannot look like an answer', () async {
      final result = await service(_ThrowingProvider()).sendMessage(
        message: 'tell me about my sleep habits',
        context: FitnessContext.initial(),
        currentMessages: const [],
      );
      expect(result.last.category, CoachReplySource.error);
      expect(result.last.category, isNot(CoachReplySource.ai));
      expect(result.last.id, startsWith('msg_error_'));
    });
  });
}
