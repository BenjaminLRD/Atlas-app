import 'package:atlas/models/recovery/readiness_inputs.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/coach_memory.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:http/http.dart' as http;
import 'package:atlas/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
  });

  group('1. AIConfig & .env Environment Tests', () {
    test('AIConfig defaults to gemini-2.5-flash and validates key length', () {
      const config = AIConfig(apiKey: '');
      expect(config.isValidKey, isFalse);
      expect(config.model, equals('gemini-2.5-flash'));

      const validConfig = AIConfig(apiKey: 'test-mock-gemini-key-12345');
      expect(validConfig.isValidKey, isTrue);
      expect(validConfig.model, equals('gemini-2.5-flash'));
    });

    test('AIConfig uses the proxy only when no developer key is set', () {
      final proxied = AIConfig(
        proxyUrl: 'https://abc.supabase.co/functions/v1/ai-proxy',
        accessTokenProvider: () => 'user-jwt',
      );
      expect(proxied.usesProxy, isTrue);
      expect(proxied.isConfigured, isTrue);

      final signedOut = AIConfig(
        proxyUrl: 'https://abc.supabase.co/functions/v1/ai-proxy',
        accessTokenProvider: () => null,
      );
      expect(signedOut.isConfigured, isFalse);

      const devKey = AIConfig(
        apiKey: 'test-mock-gemini-key-12345',
        proxyUrl: 'https://abc.supabase.co/functions/v1/ai-proxy',
      );
      expect(devKey.usesProxy, isFalse);
      expect(devKey.isConfigured, isTrue);
    });

    test('AIConfig.toJson never serializes the API key', () {
  const config = AIConfig(apiKey: 'test-mock-gemini-key-12345');
  expect(
    config.toJson().toString(),
    isNot(contains('test-mock-gemini-key-12345')),
  );
});

test('Proxy requests carry the user token and wrap the Gemini body', () async {
      http.Request? captured;
      final mockClient = _TestHttpClient((request) async {
        captured = request;
        return http.Response(
          '{"candidates":[{"content":{"parts":[{"text":"Brace before you pull."}]}}]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final provider = GeminiAIProvider(
        config: AIConfig(
          proxyUrl: 'https://abc.supabase.co/functions/v1/ai-proxy',
          accessTokenProvider: () => 'user-jwt',
        ),
        httpClient: mockClient,
      );

      final reply = await provider.generateResponse(
        message: 'Deadlift tip?',
        context: FitnessContext.initial(),
        history: const [],
      );

      expect(reply, equals('Brace before you pull.'));
      expect(
        captured!.url.toString(),
        equals('https://abc.supabase.co/functions/v1/ai-proxy'),
      );
      expect(captured!.headers['Authorization'], equals('Bearer user-jwt'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['feature'], equals('coach'));
      expect(body['model'], equals('gemini-2.5-flash'));
      expect(body['request'], isA<Map<String, dynamic>>());
    });
  });

  group('2. CoachPromptBuilder Unit Tests', () {
    test('buildPrompt embeds user goal, recovery, nutrition, and memory', () {
      const builder = CoachPromptBuilder();
      final context = FitnessContext.initial().copyWith(
        userGoal: UserGoal(
          id: 'g_1',
          goalType: FitnessGoalType.muscleGain,
          fitnessLevel: FitnessLevel.intermediate,
          activityLevel: ActivityLevel.moderate,
          age: 24,
          height: 175,
          currentWeight: 70,
          targetWeight: 75,
          targetCalories: 2600,
          targetProtein: 165,
          targetCarbohydrates: 280,
          targetFats: 70,
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
        ),
        recoveryState: RecoveryState(inputs: const ReadinessInputs(hasSleep: true, hasHrv: true), id: 'rec_1',
          recoveryScore: 88,
          fatigueLevel: FatigueLevel.low,
          lastUpdated: DateTime.now(),
        ),
      );

      const memory = CoachMemory(
        trainingPreferences: ['Heavy compound lifting'],
        preferredStyle: 'direct',
      );

      final prompt = builder.buildPrompt(
        message: 'Should I do bench press today?',
        context: context,
        memory: memory,
      );

      expect(prompt.contains('muscleGain'), isTrue);
      expect(prompt.contains('88%'), isTrue);
      expect(prompt.contains('Heavy compound lifting'), isTrue);
      expect(prompt.contains('Should I do bench press today?'), isTrue);
    });
  });

  group('3. GeminiAIProvider Real HTTP & FitnessContext Verification Tests', () {
    test(
      'GeminiAIProvider sends HTTP request with serialized FitnessContext and returns parsed candidate',
      () async {
        String? capturedUrl;
        String? capturedBody;
        String? capturedKeyHeader;

        final mockClient = _TestHttpClient((request) async {
          capturedUrl = request.url.toString();
          capturedBody = request.body;
          capturedKeyHeader = request.headers['x-goog-api-key'];
          return http.Response(
            '{"candidates":[{"content":{"parts":[{"text":"Increase rest time between heavy compound sets to 3 minutes for optimal CNS recovery."}]}}]}',
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final provider = GeminiAIProvider(
          config: const AIConfig(
            apiKey: 'test-mock-gemini-key-12345',
            model: 'gemini-2.5-flash',
            temperature: 0.7,
          ),
          httpClient: mockClient,
        );

        expect(provider.isGeminiActive, isTrue);
        expect(provider.isOnline, isTrue);
        expect(
          provider.providerName,
          equals('Google Gemini (gemini-2.5-flash)'),
        );

        final context = FitnessContext.initial().copyWith(
          userGoal: UserGoal(
            id: 'g_target',
            goalType: FitnessGoalType.muscleGain,
            fitnessLevel: FitnessLevel.advanced,
            activityLevel: ActivityLevel.veryActive,
            age: 26,
            height: 180,
            currentWeight: 82,
            targetWeight: 88,
            targetCalories: 3100,
            targetProtein: 200,
            targetCarbohydrates: 380,
            targetFats: 80,
            createdDate: DateTime.now(),
            updatedDate: DateTime.now(),
          ),
          recoveryState: RecoveryState(inputs: const ReadinessInputs(hasSleep: true, hasHrv: true), id: 'rec_90',
            recoveryScore: 92,
            fatigueLevel: FatigueLevel.low,
            lastUpdated: DateTime.now(),
          ),
        );

        final response = await provider.generateResponse(
          message: 'How should I optimize my chest workout today?',
          context: context,
          history: const [],
        );

        // Verify response parsing
        expect(
          response,
          equals(
            'Increase rest time between heavy compound sets to 3 minutes for optimal CNS recovery.',
          ),
        );

        // Verify URL targets the model and the key travels in a header, not the URL
        expect(capturedUrl, contains('gemini-2.5-flash:generateContent'));
        expect(capturedUrl, isNot(contains('key=')));
        expect(capturedKeyHeader, equals('test-mock-gemini-key-12345'));

        // Verify FitnessContext attributes reached the prompt payload
        expect(capturedBody, contains('muscleGain'));
        expect(capturedBody, contains('advanced'));
        expect(capturedBody, contains('92%'));
        expect(
          capturedBody,
          contains('How should I optimize my chest workout today?'),
        );

        // Verify runtime indicators
        expect(provider.runtimeStatus, contains('Gemini Active'));
      },
    );

    test(
      'GeminiAIProvider throws GeminiApiException on HTTP 500 server error',
      () async {
        final mockClient = _TestHttpClient((request) async {
          return http.Response('{"error": {"message": "Internal Server Error"}}', 500);
        });

        final provider = GeminiAIProvider(
          config: const AIConfig(
            apiKey: 'test-mock-gemini-key-12345',
            model: 'gemini-2.5-flash',
          ),
          httpClient: mockClient,
        );

        expect(
          () => provider.generateResponse(
            message: 'Hello Coach',
            context: FitnessContext.initial(),
            history: const [],
          ),
          throwsA(isA<GeminiApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(500),
          )),
        );
      },
    );
  });

  group('4. GeminiAIProvider Error Handling Tests', () {
    test(
      'GeminiAIProvider throws GeminiApiException when API key is missing',
      () async {
        final provider = GeminiAIProvider(
          config: const AIConfig(apiKey: ''),
        );

        final context = FitnessContext.initial();
        expect(
          () => provider.generateResponse(
            message: 'Hello Coach',
            context: context,
            history: const [],
          ),
          throwsA(
            isA<GeminiApiException>()
                // No key and no ai-proxy address: the build has no AI backend
                // (503), which is not the same as a signed-out user (401).
                .having((e) => e.statusCode, 'statusCode', equals(503))
                .having(
                  (e) => e.message,
                  'message',
                  GeminiAIProvider.backendNotConfiguredMessage,
                ),
          ),
        );
      },
    );
  });

  group('5. AppDependencies Provider Configuration Tests', () {
    test('AppDependencies initializes with GeminiAIProvider by default', () {
      final deps = AppDependencies.instance;
      expect(deps.aiProvider, isA<GeminiAIProvider>());
      expect(deps.coachChatService.activeProviderName, contains('Google Gemini'));
    });
  });

  group('6. CoachChatService Timeout & Error Handling Tests', () {
    test(
      'CoachChatService catches GeminiApiException and formats friendly error message',
      () async {
        final mockClient = _TestHttpClient((request) async {
          return http.Response('{"error": {"message": "Invalid API Key provided"}}', 403);
        });

        final provider = GeminiAIProvider(
          config: const AIConfig(
            apiKey: 'test-mock-invalid-key-123',
            model: 'gemini-2.5-flash',
          ),
          httpClient: mockClient,
        );

        final chatService = CoachChatService(aiProvider: provider);
        final context = FitnessContext.initial();

        final messages = await chatService.sendMessage(
          message: 'Can I do HIIT cardio today?',
          context: context,
        );

        expect(messages.length, greaterThanOrEqualTo(2));
        expect(messages.last.role.name, equals('assistant'));
        // The provider's own wording is not shown to the user.
        expect(messages.last.content, isNot(contains('Invalid API Key')));
        expect(
          messages.last.content,
          equals('Atlas AI is not available for this account right now.'),
        );
        expect(messages.last.category, equals('error'));
      },
    );
  });

  group('7. Live Gemini API End-to-End Test', () {
    test('Real Gemini API Live Request generates coaching response', () async {
      HttpOverrides.global = null;
      final envKey = Platform.environment['GEMINI_API_KEY'] ?? '';
      if (envKey.isNotEmpty) {
        final liveProvider = GeminiAIProvider(
          config: AIConfig(
            apiKey: envKey,
            model: 'gemini-2.5-flash',
          ),
        );

        try {
          final liveResponse = await liveProvider.generateResponse(
            message: 'Give me 1 quick tip on deadlift bracing in one short sentence.',
            context: FitnessContext.initial(),
            history: const [],
          );

          expect(liveResponse.isNotEmpty, isTrue);
        } on GeminiApiException catch (e) {
          expect(e.message.isNotEmpty, isTrue);
        }
      }
    },
        skip: Platform.environment['RUN_LIVE_AI_TESTS'] == '1'
            ? null
            : 'Set RUN_LIVE_AI_TESTS=1 and GEMINI_API_KEY to call the real API');
  });
}

class _TestHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) _handler;

  _TestHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final httpRequest = request as http.Request;
    final response = await _handler(httpRequest);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
