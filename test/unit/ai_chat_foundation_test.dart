import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/coach_message.dart';
import 'package:aizawl_gym/models/fitness_context.dart';
import 'package:aizawl_gym/models/nutrition_progress.dart';
import 'package:aizawl_gym/models/nutrition_summary.dart';
import 'package:aizawl_gym/models/progress_summary.dart';
import 'package:aizawl_gym/models/user_goal.dart';
import 'package:aizawl_gym/models/user_progress.dart';
import 'package:aizawl_gym/repositories/coach_conversation_repository.dart';
import 'package:aizawl_gym/services/ai/mock_ai_provider.dart';
import 'package:aizawl_gym/services/ai/coach_chat_service.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('CoachMessage Advanced Serialization Tests', () {
    test('supports system role, category, and contextSnapshot', () {
      final now = DateTime(2026, 8, 8, 2, 0);
      final msg = CoachMessage(
        id: 'msg_sys_1',
        role: CoachRole.system,
        content: 'System notice',
        timestamp: now,
        category: 'NUTRITION',
        contextSnapshot: const {'proteinTarget': 140},
      );

      final json = msg.toJson();
      expect(json['role'], equals('system'));
      expect(json['category'], equals('NUTRITION'));
      expect(json['contextSnapshot'], equals({'proteinTarget': 140}));

      final restored = CoachMessage.fromJson(json);
      expect(restored.role, equals(CoachRole.system));
      expect(restored.category, equals('NUTRITION'));
      expect(restored.contextSnapshot, equals({'proteinTarget': 140}));
    });
  });

  group('MockAIProvider Context-Aware Response Tests', () {
    const provider = MockAIProvider();

    test('generates nutrition response with protein target and hit rate', () async {
      final ctx = FitnessContext.initial().copyWith(
        userGoal: UserGoal.initial().copyWith(targetProtein: 160),
        nutritionSummary: NutritionSummary.empty().copyWith(
          proteinGoalHitPercentage: 85.0,
        ),
        nutritionProgress: NutritionProgress.initial().copyWith(
          currentNutritionStreak: 5,
        ),
      );

      final response = await provider.generateResponse(
        message: 'How is my protein intake looking?',
        context: ctx,
        history: const [],
      );

      expect(response, contains('160g'));
      expect(response, contains('85%'));
      expect(response, contains('5-day nutrition streak'));
    });

    test('generates training response with total volume and workout streak', () async {
      final ctx = FitnessContext.initial().copyWith(
        progressSummary: ProgressSummary.zero().copyWith(
          totalWorkouts: 12,
          totalVolume: 45000.0,
          currentStreak: 4,
        ),
      );

      final response = await provider.generateResponse(
        message: 'Should I take a rest day?',
        context: ctx,
        history: const [],
      );

      expect(response, contains('4-day workout streak'));
      expect(response, contains('45000 kg total volume'));
      expect(response, contains('active recovery day'));
    });

    test('generates rank and XP response', () async {
      final ctx = FitnessContext.initial().copyWith(
        userProgress: const UserProgress(
          totalXP: 750,
          completedWorkouts: 10,
          rankedUnlocked: true,
          currentRank: 'Bronze',
          currentDivision: 'III',
          workoutStreak: 3,
          longestStreak: 5,
          lastWorkoutDate: null,
          totalWorkoutMinutes: 300,
          totalVolumeLifted: 12000.0,
          achievements: [],
        ),
      );

      final response = await provider.generateResponse(
        message: 'What is my current rank?',
        context: ctx,
        history: const [],
      );

      expect(response, contains('750 total XP'));
      expect(response, contains('Bronze'));
    });
  });

  group('CoachChatService & Repository Tests', () {
    test('sends user message and persists assistant response', () async {
      const repo = LocalCoachConversationRepository();
      await repo.clearConversation();

      const service = CoachChatService(repository: repo);
      final ctx = FitnessContext.initial();

      final messages = await service.sendMessage(
        message: 'How do I hit my protein goal?',
        context: ctx,
      );

      expect(messages.length, equals(2));
      expect(messages.first.role, equals(CoachRole.user));
      expect(messages.first.content, equals('How do I hit my protein goal?'));
      expect(messages.last.role, equals(CoachRole.assistant));

      final persisted = repo.getMessages();
      expect(persisted.length, equals(2));

      await repo.clearConversation();
      expect(repo.getMessages(), isEmpty);
    });
  });

  group('FitnessProvider Coach Integration Tests', () {
    test('sendCoachMessage updates provider state and clears conversation', () async {
      final provider = FitnessProvider.instance;
      await provider.clearCoachConversation();

      expect(provider.coachMessages, isEmpty);

      final future = provider.sendCoachMessage('What rank am I?');
      expect(provider.isCoachReplying, isTrue);

      await future;
      expect(provider.isCoachReplying, isFalse);
      expect(provider.coachMessages.length, equals(2));
      expect(provider.coachMessages.first.content, equals('What rank am I?'));

      await provider.clearCoachConversation();
      expect(provider.coachMessages, isEmpty);
    });
  });
}
