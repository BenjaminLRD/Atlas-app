import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/services/ai/ai_guardrail_service.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/goal_validation_service.dart';
import '../mocks/mock_ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AIGuardrailService.resetInstance();
    GoalValidationService.resetInstance();
  });

  group('1. Fitness Domain Classification & Allowed Topics Tests', () {
    final guardrail = AIGuardrailService.instance;

    test('Allows core fitness, workout, and nutrition queries', () {
      expect(
        guardrail.isFitnessRelated('How much protein for hypertrophy?'),
        isTrue,
      );
      expect(
        guardrail.isFitnessRelated('Create push pull legs split'),
        isTrue,
      );
      expect(
        guardrail.isFitnessRelated('Improve squat form'),
        isTrue,
      );
      expect(
        guardrail.isFitnessRelated('What are the best chest exercises for mass?'),
        isTrue,
      );
      expect(
        guardrail.isFitnessRelated('How should I structure my deload week?'),
        isTrue,
      );
      expect(
        guardrail.isFitnessRelated('Should I take creatine before or after workouts?'),
        isTrue,
      );
      expect(
        guardrail.isFitnessRelated('How to optimize sleep and HRV recovery?'),
        isTrue,
      );
    });

    test('Allows polite coaching greetings and introduction queries', () {
      expect(guardrail.isFitnessRelated('hi'), isTrue);
      expect(guardrail.isFitnessRelated('hello coach'), isTrue);
      expect(guardrail.isFitnessRelated('good morning'), isTrue);
      expect(guardrail.isFitnessRelated('what can you do?'), isTrue);
      expect(guardrail.isFitnessRelated('thank you for the workout plan'), isTrue);
    });

    test('Blocks off-topic requests (coding, politics, homework, storytelling)', () {
      expect(guardrail.isFitnessRelated('Write Python code'), isFalse);
      expect(guardrail.isFitnessRelated('Write JavaScript function to sort array'), isFalse);
      expect(guardrail.isFitnessRelated('Explain politics'), isFalse);
      expect(guardrail.isFitnessRelated('Who is the president?'), isFalse);
      expect(guardrail.isFitnessRelated('Write a story'), isFalse);
      expect(guardrail.isFitnessRelated('Write a poem about space'), isFalse);
      expect(guardrail.isFitnessRelated('Help me solve my algebra homework'), isFalse);
      expect(guardrail.isFitnessRelated('What is the latest movie in cinema?'), isFalse);
      expect(guardrail.isFitnessRelated('Give me crypto stock market advice'), isFalse);
    });
  });

  group('2. Unsafe Goal Detection & Realistic Timeline Tests', () {
    final guardrail = AIGuardrailService.instance;
    final validator = GoalValidationService.instance;

    test('Detects extreme and dangerous weight loss goals', () {
      expect(guardrail.containsUnsafeGoal('Lose 30kg in 5 days'), isTrue);
      expect(guardrail.containsUnsafeGoal('Lose 20kg in 2 weeks'), isTrue);
      expect(guardrail.containsUnsafeGoal('Drop 15kg in 1 week'), isTrue);

      final result = validator.validateGoalQuery('Lose 20kg in 2 weeks');
      expect(result.isSafe, isFalse);
      expect(result.issue, contains('Extreme'));
      expect(result.recommendation, contains('0.5kg to 1.0kg'));
      expect(result.safeRatePerWeek, equals(0.75));
    });

    test('Detects physiologically impossible muscle gain timelines', () {
      expect(guardrail.containsUnsafeGoal('Gain 20kg muscle in one month'), isTrue);
      expect(guardrail.containsUnsafeGoal('Gain 15kg muscle in 1 month'), isTrue);
      expect(guardrail.containsUnsafeGoal('Pack on 10kg pure muscle in 2 weeks'), isTrue);

      final result = validator.validateGoalQuery('Gain 15kg muscle in 1 month');
      expect(result.isSafe, isFalse);
      expect(result.issue, contains('muscle gain'));
      expect(result.recommendation, contains('0.5kg to 1.5kg'));
    });

    test('Detects dangerously low calorie intake targets', () {
      expect(guardrail.containsUnsafeGoal('I want to eat 500 calories a day'), isTrue);
      expect(guardrail.containsUnsafeGoal('Plan a 600 calorie diet for me'), isTrue);

      final result = validator.validateGoalQuery('I want to eat 500 calories a day');
      expect(result.isSafe, isFalse);
      expect(result.issue, contains('caloric intake'));
      expect(result.recommendation, contains('1,000'));
    });

    test('Allows safe, realistic fitness goals', () {
      expect(guardrail.containsUnsafeGoal('I want to lose 5kg in 2 months'), isFalse);
      expect(guardrail.containsUnsafeGoal('Can I gain 1kg of muscle this month?'), isFalse);
      expect(guardrail.containsUnsafeGoal('Set a daily calorie target of 2200 kcal'), isFalse);
    });
  });

  group('3. User Metric & Biometric Validation Tests', () {
    final guardrail = AIGuardrailService.instance;
    final validator = GoalValidationService.instance;

    test('Rejects invalid human height measurements', () {
      final invalidHeightProfile = UserProfile.defaultProfile()
        ..height = '20' // 20cm is physiologically invalid for an adult athlete
        ..weight = '70'
        ..age = 25;

      expect(guardrail.validateUserMetrics(invalidHeightProfile), isFalse);

      final direct = validator.validateMetrics(age: 25, heightCm: 20.0, weightKg: 70.0);
      expect(direct.isSafe, isFalse);
      expect(direct.issue, contains('Invalid height'));
      expect(direct.recommendation, contains('between 90 cm and 250 cm'));
    });

    test('Rejects invalid body weight measurements', () {
      final invalidWeightProfile = UserProfile.defaultProfile()
        ..height = '175'
        ..weight = '500' // 500kg
        ..age = 25;

      expect(guardrail.validateUserMetrics(invalidWeightProfile), isFalse);

      final direct = validator.validateMetrics(age: 25, heightCm: 175.0, weightKg: 500.0);
      expect(direct.isSafe, isFalse);
      expect(direct.issue, contains('Invalid body weight'));
      expect(direct.recommendation, contains('between 25 kg and 350 kg'));
    });

    test('Rejects invalid user age', () {
      final invalidAgeProfile = UserProfile.defaultProfile()
        ..height = '175'
        ..weight = '70'
        ..age = 2; // 2 years old

      expect(guardrail.validateUserMetrics(invalidAgeProfile), isFalse);

      final direct = validator.validateMetrics(age: 2, heightCm: 175.0, weightKg: 70.0);
      expect(direct.isSafe, isFalse);
      expect(direct.issue, contains('Invalid age'));
      expect(direct.recommendation, contains('between 10 and 110 years'));
    });

    test('Validates realistic user profile metrics successfully', () {
      final validProfile = UserProfile.defaultProfile()
        ..height = '180'
        ..weight = '78'
        ..age = 28;

      expect(guardrail.validateUserMetrics(validProfile), isTrue);

      final direct = validator.validateMetrics(age: 28, heightCm: 180.0, weightKg: 78.0);
      expect(direct.isSafe, isTrue);
    });
  });

  group('4. CoachChatService End-to-End Safety Pipeline Tests', () {
    test('Intercepts off-topic query and returns polite redirect without hitting AI provider', () async {
      final chatService = CoachChatService(aiProvider: const MockAIProvider());
      final context = FitnessContext.initial();

      final messages = await chatService.sendMessage(
        message: 'Write Python code for web scraping',
        context: context,
      );

      expect(messages.length, greaterThanOrEqualTo(2));
      final last = messages.last;
      expect(last.role.name, equals('assistant'));
      expect(last.content, contains('I am your fitness coach'));
      expect(last.content, contains('workouts, nutrition, recovery'));
    });

    test('Intercepts extreme unsafe goal and provides safe coaching guidance', () async {
      final chatService = CoachChatService(aiProvider: const MockAIProvider());
      final context = FitnessContext.initial();

      final messages = await chatService.sendMessage(
        message: 'I need to lose 30kg in 5 days for an event',
        context: context,
      );

      expect(messages.length, greaterThanOrEqualTo(2));
      final last = messages.last;
      expect(last.role.name, equals('assistant'));
      expect(last.content, contains('0.5kg to 1.0kg'));
      expect(last.content, contains('moderate'));
    });

    test('Sanitizes clinical diagnosis queries and adds Medical Safety Advisory', () {
      final guardrail = AIGuardrailService.instance;
      const rawAiResponse = 'Based on your symptoms, your anterior deltoid might be strained.';
      final sanitized = guardrail.sanitizeAIResponse(
        rawAiResponse,
        'Can you diagnose my torn chest pain?',
      );

      expect(sanitized, contains('Safety Advisory'));
      expect(sanitized, contains('athletic and nutrition coaching, not clinical or medical diagnoses'));
      expect(sanitized, contains('qualified physician'));
    });
  });
}
