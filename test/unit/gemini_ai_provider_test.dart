import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/app_dependencies.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/fitness_context.dart';
import 'package:aizawl_gym/models/recovery_state.dart';
import 'package:aizawl_gym/models/user_goal.dart';
import 'package:aizawl_gym/services/ai/ai_config.dart';
import 'package:aizawl_gym/services/ai/coach_chat_service.dart';
import 'package:aizawl_gym/services/ai/coach_memory.dart';
import 'package:aizawl_gym/services/ai/coach_prompt_builder.dart';
import 'package:aizawl_gym/services/ai/gemini_ai_provider.dart';
import 'package:aizawl_gym/services/ai/mock_ai_provider.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    AppDependencies.useMock();
  });

  group('AIConfig Unit Tests', () {
    test('AIConfig initializes defaults and checks API key validity', () {
      const config = AIConfig(apiKey: '');
      expect(config.isValidKey, isFalse);

      const validConfig = AIConfig(apiKey: 'AIzaSyABC1234567890_ValidKeyTest');
      expect(validConfig.isValidKey, isTrue);
    });
  });

  group('CoachPromptBuilder Unit Tests', () {
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
        recoveryState: RecoveryState(
          id: 'rec_1',
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

  group('GeminiAIProvider Fallback Tests', () {
    test('GeminiAIProvider falls back to MockAIProvider when API key is missing', () async {
      const provider = GeminiAIProvider(
        config: AIConfig(apiKey: ''), // Invalid API key
        fallbackProvider: MockAIProvider(),
      );

      final context = FitnessContext.initial();
      final response = await provider.generateResponse(
        message: 'Hello Coach',
        context: context,
        history: const [],
      );

      expect(response, isNotEmpty);
      expect(response.contains('workout') || response.contains('coach') || response.contains('Aizawl') || response.contains('great'), isTrue);
    });
  });

  group('AppDependencies Provider Switching Tests', () {
    test('useGemini switches active AIProvider in AppDependencies', () {
      expect(AppDependencies.instance.aiProvider, isA<MockAIProvider>());

      AppDependencies.useGemini(
        config: const AIConfig(apiKey: 'AIzaSyTestKey_123456789'),
      );

      expect(AppDependencies.instance.aiProvider, isA<GeminiAIProvider>());

      AppDependencies.useMock();
      expect(AppDependencies.instance.aiProvider, isA<MockAIProvider>());
    });
  });

  group('CoachChatService Timeout & Integration Tests', () {
    test('CoachChatService sendMessage delegates to AIProvider and returns assistant response', () async {
      const chatService = CoachChatService(aiProvider: MockAIProvider());
      final context = FitnessContext.initial();

      final messages = await chatService.sendMessage(
        message: 'What is my protein target?',
        context: context,
      );

      expect(messages.length, greaterThanOrEqualTo(2));
      expect(messages.last.role.name, equals('assistant'));
      expect(messages.last.content, isNotEmpty);
    });
  });
}
