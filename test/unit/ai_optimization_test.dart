import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_model_provider.dart';
import 'package:atlas/services/ai/ai_privacy_filter.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/ai_response_cache.dart';
import 'package:atlas/services/ai/evaluation/ai_response_evaluator.dart';
import 'package:atlas/services/ai/analytics/ai_usage_tracker.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import '../mocks/mock_ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await FitnessMemory.instance.initialize();
    AIResponseCache.instance.clear();
    AIResponseCache.instance.preloadDomainKnowledge();
    AIUsageTracker.instance.reset();

    final profile = UserProfile(
      name: 'John Doe',
      email: 'john.doe@example.com',
      phone: '+1 555-123-4567',
      dob: '1995-04-12',
      gender: 'Male',
      height: '178',
      weight: '75.0',
      fitnessGoal: 'Muscle Gain',
      workoutExperience: 'intermediate',
      preferredDays: ['Monday', 'Wednesday', 'Friday'],
      dietPreference: 'High Protein',
      massUnit: 'kg',
      lengthUnit: 'cm',
      subscription: 'Free',
      privacy: 'Public',
      notificationsEnabled: true,
      profilePic: '',
    );

    final goal = UserGoal(
      id: 'goal_opt_01',
      goalType: FitnessGoalType.muscleGain,
      fitnessLevel: FitnessLevel.intermediate,
      activityLevel: ActivityLevel.moderate,
      age: 25,
      height: 178.0,
      currentWeight: 75.0,
      targetWeight: 80.0,
      targetCalories: 2600.0,
      targetProtein: 160.0,
      targetCarbohydrates: 320.0,
      targetFats: 70.0,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );

    final history = [
      WorkoutHistory(
        workoutName: 'Upper Body Hypertrophy',
        dateCompleted: DateTime.now().subtract(const Duration(days: 1)),
        durationSeconds: 3300,
        exercisesCompleted: 4,
        completionPercentage: 1.0,
        totalVolume: 4200.0,
        totalSets: 16,
        totalReps: 160,
        personalRecords: const ['100kg Bench Press (+5kg PR)'],
      ),
    ];

    final nutritionLog = NutritionLog(
      id: 'nutr_today',
      date: DateTime.now(),
      calorieGoal: 2600.0,
      proteinGoal: 160.0,
      meals: [
        MealEntry(
          id: 'meal_1',
          name: 'Breakfast',
          consumedFoods: const [
            ConsumedFood(
              food: FoodItem(
                id: 'egg_whole',
                name: 'Whole Eggs (3 large)',
                calories: 215.0,
                protein: 19.0,
                carbohydrates: 1.5,
                fats: 15.0,
              ),
              quantity: 100,
            ),
          ],
        ),
      ],
    );

    final provider = FitnessProvider.instance;
    await provider.updateProfile(profile);
    await provider.saveGoal(goal);
    await LocalStorage.saveNutritionLog(nutritionLog);
    for (final h in history) {
      await LocalStorage.saveWorkoutCompletion(h);
    }
    provider.refreshWorkoutHistory();

    sampleContext = provider.buildFitnessContext();
  });

  group('Atlas AI Optimization & Intelligence Tuning (Phase 15)', () {
    test('1. AI Request Router: Intent Classification & Direct Retrieval', () {
      const router = AIRequestRouter();

      // 1.1 Direct Retrieval without calling Gemini
      final lastWoDecision = router.route(
        message: 'What was my last workout?',
        context: sampleContext,
      );
      expect(lastWoDecision.needsLLM, isFalse);
      expect(lastWoDecision.isDirectAnswer, isTrue);
      expect(
        lastWoDecision.directResponse?.contains('Upper Body Hypertrophy'),
        isTrue,
      );

      // 1.2 Daily Nutrition Direct Answer
      final nutrDecision = router.route(
        message: 'How much protein have I eaten today?',
        context: sampleContext,
      );
      expect(nutrDecision.needsLLM, isFalse);
      expect(nutrDecision.isDirectAnswer, isTrue);
      expect(
        nutrDecision.directResponse?.contains('19 / 160g protein'),
        isTrue,
      );

      // 1.3 Off-Topic Interception
      final offTopicDecision = router.route(
        message: 'Write a python script to sort an array',
        context: sampleContext,
      );
      expect(offTopicDecision.needsLLM, isFalse);
      expect(offTopicDecision.intent, AIRequestIntent.offTopic);

      // 1.4 Workout Generation Intent requiring LLM/Tool
      final workoutDecision = router.route(
        message: 'Make me a 45 min chest workout',
        context: sampleContext,
      );
      expect(workoutDecision.needsLLM, isTrue);
      expect(workoutDecision.intent, AIRequestIntent.workoutRequest);
      expect(workoutDecision.targetTool, 'WorkoutTool');
    });

    test(
      '2. Smart AI Response Cache: Verified Knowledge, Similarity & Privacy Filter',
      () {
        final cache = AIResponseCache.instance;

        // 2.1 Preloaded verified domain knowledge lookup
        final creatineAnswer = cache.get('benefits of creatine');
        expect(creatineAnswer, isNotNull);
        expect(creatineAnswer!.contains('Creatine Monohydrate'), isTrue);

        // 2.2 Near-identical wording still matches the verified knowledge
        final similarCreatineAnswer = cache.get('Benefits of creatine?');
        expect(similarCreatineAnswer, isNotNull);
        expect(similarCreatineAnswer!.contains('Creatine Monohydrate'), isTrue);

        // 2.3 Exclude sensitive medical queries from caching
        expect(cache.isCacheable('benefits of creatine'), isTrue);
        expect(
          cache.isCacheable('what to do for sharp pain in my knee'),
          isFalse,
        );
        expect(cache.isCacheable('doctor prescription for injury'), isFalse);
      },
    );

    test('3. Intent-Based Prompt Optimization & Token Reduction', () {
      const promptBuilder = CoachPromptBuilder();

      // 3.1 Full prompt baseline
      final fullPrompt = promptBuilder.buildPrompt(
        message: 'Make me a workout',
        context: sampleContext,
        intent: null,
      );

      // 3.2 Workout-targeted prompt
      final workoutPrompt = promptBuilder.buildPrompt(
        message: 'Make me a workout',
        context: sampleContext,
        intent: AIRequestIntent.workoutRequest,
      );

      // 3.3 Token reduction verification
      final fullTokens = AIUsageTracker.estimateTokens(fullPrompt);
      final workoutTokens = AIUsageTracker.estimateTokens(workoutPrompt);

      expect(workoutTokens, lessThan(fullTokens));
      expect(workoutPrompt.contains('[ATHLETE CONTEXT]'), isTrue);
      expect(
        workoutPrompt.contains('Whole Eggs'),
        isFalse,
      ); // Omitted unrelated meal items
    });

    test('4. AI Privacy Filter: PII Redaction & Sanitization', () {
      const filter = AIPrivacyFilter();

      const rawUserMessage =
          'Contact me at alex.gym@gmail.com or call 555-123-4567 for my fitness plan. My SSN is 123-45-6789.';
      final sanitized = filter.sanitizeText(rawUserMessage);

      expect(sanitized.contains('alex.gym@gmail.com'), isFalse);
      expect(sanitized.contains('[REDACTED_EMAIL]'), isTrue);
      expect(sanitized.contains('555-123-4567'), isFalse);
      expect(sanitized.contains('[REDACTED_PHONE]'), isTrue);
      expect(sanitized.contains('123-45-6789'), isFalse);
      expect(sanitized.contains('[REDACTED_ID]'), isTrue);

      expect(filter.anonymizeName('John Doe'), 'John');
      expect(filter.anonymizeName(''), 'Athlete');
    });

    test('5. AI Response Quality Evaluator & Safety Scoring', () {
      const evaluator = AIResponseEvaluator();

      // 5.1 High-Quality Response
      final goodScore = evaluator.evaluate(
        query: 'How should I train my chest today for muscle gain?',
        response:
            'Focus on mechanical tension for muscle gain. Complete 3 sets of 8-10 reps on Incline Dumbbell Press followed by Cable Flyes. Rest 2 minutes between sets.',
        context: sampleContext,
      );
      expect(goodScore.overall, greaterThanOrEqualTo(75));
      expect(goodScore.safety, 100);
      expect(goodScore.isHighQuality, isTrue);

      // 5.2 Dangerous / Unsafe Response
      final dangerousScore = evaluator.evaluate(
        query: 'My shoulder hurts when benching',
        response:
            'Ignore the pain and keep pushing through sharp pain with heavier weight.',
        context: sampleContext,
      );
      expect(dangerousScore.safety, lessThan(70));
      expect(dangerousScore.suggestions.isNotEmpty, isTrue);
    });

    test(
      '6. AI Usage Tracker: Token Estimation, Latency & Cost Calculation',
      () {
        final tracker = AIUsageTracker.instance;

        tracker.recordRequest(
          feature: 'coach_chat',
          inputTokens: 1200,
          outputTokens: 300,
          latencyMs: 450.0,
        );
        tracker.recordCacheHit(feature: 'coach_chat');

        final summary = tracker.getSummary();
        expect(summary.totalRequests, 2);
        expect(summary.cachedRequests, 1);
        expect(summary.cacheHitRate, 0.5);
        expect(summary.totalInputTokens, 1200);
        expect(summary.totalOutputTokens, 300);
        expect(summary.averageLatencyMs, 450.0);
        expect(summary.estimatedCostUsd, greaterThan(0.0));
        expect(summary.featureBreakdown['coach_chat'], 2);
      },
    );

    test(
      '7. Multi-Model Provider Architecture & Fallback Intelligence',
      () async {
        const AIModelProvider mockProvider = MockAIProvider();
        expect(mockProvider.modelIdentifier, 'mock-offline-heuristic');
        expect(mockProvider.supportsVision, isTrue);
        expect(mockProvider.supportsToolCalling, isTrue);

        final geminiProvider = GeminiAIProvider();
        expect(geminiProvider.modelIdentifier, 'gemini-2.5-flash');
        expect(geminiProvider.supportsVision, isTrue);
        expect(geminiProvider.maxContextTokens, 1000000);

        // Offline fallback produces high quality responses without showing 'AI unavailable'
        final response = await mockProvider.generateResponse(
          message: 'How should I perform barbell bench press?',
          context: sampleContext,
          history: const [],
        );

        expect(response.isNotEmpty, isTrue);
        expect(
          response.contains('bench') ||
              response.contains('chest') ||
              response.contains('grip') ||
              response.contains('retract'),
          isTrue,
        );
      },
    );
  });
}
