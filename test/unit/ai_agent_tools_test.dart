import '../mocks/fake_step_sensor.dart';
import 'package:atlas/services/steps/step_counter_service.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/ai/agent/agent_action.dart';
import 'package:atlas/services/ai/agent/ai_agent.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import '../mocks/mock_ai_provider.dart';
import '../mocks/mock_health_service.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/services/ai/tools/health_tool.dart';
import 'package:atlas/services/ai/tools/nutrition_tool.dart';
import 'package:atlas/services/ai/tools/progress_tool.dart';
import 'package:atlas/services/ai/tools/workout_tool.dart';
import 'package:atlas/services/health/health_service.dart';
import 'package:atlas/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    HealthService.resetInstance();
    AppDependencies.useMock();
  });

  group('WorkoutTool Unit Tests', () {
    test('generate_workout creates equipment-aware routine', () async {
      final tool = WorkoutTool();
      final result = await tool.execute({
        'action': 'generate_workout',
        'muscle_group': 'push',
        'available_equipment': ['dumbbells', 'bench'],
        'duration_minutes': 45,
      });

      expect(result['status'], equals('success'));
      expect(result['workout'], isNotNull);
      final workout = result['workout'] as Map<String, dynamic>;
      expect(workout['focus'], equals('push'));
      expect(workout['duration_minutes'], equals(45));
      expect(workout['exercises'], isNotEmpty);
    });

    test(
      'save_workout requires confirmation when confirmed is false',
      () async {
        final tool = WorkoutTool();
        final result = await tool.execute({
          'action': 'save_workout',
          'workout_name': 'Chest Blaster',
          'exercises': ['Bench Press', 'Incline Dumbbell Press'],
          'duration_minutes': 45,
          'confirmed': false,
        });

        expect(result['status'], equals('confirmation_required'));
        expect(result['requires_confirmation'], isTrue);
        expect(result['prompt'], contains('Chest Blaster'));
        expect(LocalStorage.getWorkoutHistory(), isEmpty);
      },
    );

    test(
      'save_workout keeps a planned workout when confirmed is true',
      () async {
        final tool = WorkoutTool();
        final result = await tool.execute({
          'action': 'save_workout',
          'workout_name': 'Chest Blaster',
          'exercises': ['Bench Press', 'Incline Dumbbell Press'],
          'duration_minutes': 45,
          'confirmed': true,
        });

        expect(result['status'], equals('success'));
        expect(result['saved'], isTrue);
        // A saved suggestion is a plan, not a completed workout.
        expect(result['completed'], isFalse);
        expect(LocalStorage.getWorkoutHistory(), isEmpty);
        expect(
          LocalStorage.getSavedWorkoutPlans().first['name'],
          equals('Chest Blaster'),
        );
      },
    );

    test('modify_workout returns valid exercise replacements', () async {
      final tool = WorkoutTool();
      final result = await tool.execute({
        'action': 'modify_workout',
        'exercise_to_replace': 'Barbell Bench Press',
        'replacement_preference': 'dumbbells',
      });

      expect(result['status'], equals('success'));
      expect(result['suggested_replacements'], isNotEmpty);
    });
  });

  group('NutritionTool Unit Tests', () {
    test('get_today_calories returns calorie progress', () async {
      final tool = NutritionTool();
      final result = await tool.execute({'action': 'get_today_calories'});

      expect(result['status'], equals('success'));
      expect(result['target_calories'], greaterThan(0));
      expect(result.containsKey('consumed_calories'), isTrue);
      expect(result.containsKey('remaining_calories'), isTrue);
    });

    test('get_protein_intake returns protein status', () async {
      final tool = NutritionTool();
      final result = await tool.execute({'action': 'get_protein_intake'});

      expect(result['status'], equals('success'));
      expect(result['target_protein_g'], greaterThan(0));
      expect(result.containsKey('consumed_protein_g'), isTrue);
    });

    test('generate_meal_suggestion returns high protein items', () async {
      final tool = NutritionTool();
      final result = await tool.execute({
        'action': 'generate_meal_suggestion',
        'meal_type': 'post_workout',
        'high_protein': true,
      });

      expect(result['status'], equals('success'));
      expect(result['recommended_items'], isNotEmpty);
      expect(result['total_meal_protein'], greaterThan(0));
    });

    test(
      'adjust_weight_goal_calories requires confirmation before mutating target',
      () async {
        final tool = NutritionTool();
        final result = await tool.execute({
          'action': 'adjust_weight_goal_calories',
          'target_calories': 2800,
          'reason': 'Muscle hypertrophy increase',
          'confirmed': false,
        });

        expect(result['status'], equals('confirmation_required'));
        expect(result['requires_confirmation'], isTrue);
        expect(result['prompt'], contains('2800 kcal'));
      },
    );
  });

  group('HealthTool Unit Tests', () {
    test('get_recovery_score returns readiness metrics', () async {
      HealthService.setInstance(MockHealthService()); // a recorded night of sleep
      final tool = HealthTool();
      final result = await tool.execute({'action': 'get_recovery_score'});

      expect(result['status'], equals('success'));
      expect(result['recovery_score'], inInclusiveRange(0, 100));
      expect(result['readiness_tier'], isNotEmpty);
      expect(result['recommendation'], isNotEmpty);
    });

    test('get_sleep_data reports recorded sleep', () async {
      HealthService.setInstance(
        MockHealthService(), // sample day: 440 minutes of sleep
      );
      final tool = HealthTool();
      final result = await tool.execute({'action': 'get_sleep_data'});

      expect(result['status'], equals('success'));
      expect(result['sleep_hours'], greaterThan(0));
      expect(result['formatted_sleep'], isNotEmpty);
    });

    test('get_sleep_data invents nothing when no sleep is recorded', () async {
      HealthService.setInstance(_EmptyHealthService());
      final tool = HealthTool();
      final result = await tool.execute({'action': 'get_sleep_data'});

      expect(result['status'], equals('success'));
      expect(result['sleep_hours'], isNull);
      expect(result['formatted_sleep'], isNull);
      expect(result['resting_heart_rate_bpm'], isNull);
      expect(result['is_optimal_sleep'], isNull);
      expect(result['data_note'], contains('not recorded'));
    });

    test('get_today_activity reports the step counter total', () async {
      HealthService.setInstance(MockHealthService());
      final sensor = FakeStepSensor();
      final counter = makeStepService(sensor: sensor);
      StepCounterService.setInstance(counter);
      addTearDown(StepCounterService.resetInstance);
      await counter.start();
      sensor.emit(100);
      sensor.emit(8532);
      final tool = HealthTool();
      final result = await tool.execute({'action': 'get_today_activity'});

      expect(result['status'], equals('success'));
      expect(result['steps'], 8432);
      expect(result['step_goal'], equals(10000));
      expect(result['progress_percent'], 84);
      expect(result['data_note'], isNull);
    });

    test('get_today_activity invents no steps when there is no reading', () async {
      HealthService.setInstance(_EmptyHealthService());
      StepCounterService.setInstance(makeStepService());
      addTearDown(StepCounterService.resetInstance);
      final tool = HealthTool();
      final result = await tool.execute({'action': 'get_today_activity'});

      expect(result['steps'], isNull);
      expect(result['progress_percent'], isNull);
      expect(result['goal_achieved'], isNull);
      expect(result['data_note'], contains('do not estimate'));
    });
  });

  group('ProgressTool Unit Tests', () {
    test('get_weight_trend returns starting and target weights', () async {
      final tool = ProgressTool();
      final result = await tool.execute({'action': 'get_weight_trend'});

      expect(result['status'], equals('success'));
      expect(result['current_weight_kg'], greaterThan(0));
      expect(result['target_weight_kg'], greaterThan(0));
    });

    test('analyze_progress computes volume and streak', () async {
      final tool = ProgressTool();
      final result = await tool.execute({'action': 'analyze_progress'});

      expect(result['status'], equals('success'));
      expect(result.containsKey('total_workouts'), isTrue);
      expect(result.containsKey('total_lifetime_volume_kg'), isTrue);
      expect(result.containsKey('current_streak_days'), isTrue);
    });
  });

  group('GeminiAIProvider Function Calling Integration Tests', () {
    test(
      'GeminiAIProvider executes function call and synthesizes response',
      () async {
        int requestCount = 0;

        final mockClient = _TestHttpClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            // Turn 1: Gemini calls health_tool
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'role': 'model',
                      'parts': [
                        {
                          'functionCall': {
                            'name': 'health_tool',
                            'args': {'action': 'get_recovery_score'},
                          },
                        },
                      ],
                    },
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            // Turn 2: Gemini synthesizes response from tool response
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'role': 'model',
                      'parts': [
                        {
                          'text':
                              'Your recovery score is 88% (Optimal readiness). You are fully cleared for heavy training today!',
                        },
                      ],
                    },
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        });

        final provider = GeminiAIProvider(
          config: const AIConfig(apiKey: 'AIzaSy_ValidKeyTest_123456789'),
          httpClient: mockClient,
        );

        final agentResult = await provider.generateAgentResponse(
          message: 'Can I train heavy today?',
          context: FitnessContext.initial(),
          history: const [],
          tools: [HealthTool(), WorkoutTool()],
        );

        expect(requestCount, equals(2));
        expect(agentResult.actionsExecuted.length, equals(1));
        expect(
          agentResult.actionsExecuted.first.toolName,
          equals('health_tool'),
        );
        expect(agentResult.responseText, contains('recovery score is 88%'));
      },
    );
  });

  group('AIAgent Orchestration & Safety Tests', () {
    test('AIAgent orchestrates workout generation intent', () async {
      final agent = AIAgent(aiProvider: const MockAIProvider());
      final result = await agent.processRequest(
        message: 'Create a push workout for today',
        context: FitnessContext.initial(),
      );

      expect(result.actionsExecuted, isNotEmpty);
      expect(
        result.actionsExecuted.any((a) => a.toolName == 'workout_tool'),
        isTrue,
      );
      expect(result.responseText, isNotEmpty);
    });

    test('AIAgent orchestrates health recovery intent', () async {
      final agent = AIAgent(aiProvider: const MockAIProvider());
      final result = await agent.processRequest(
        message: 'What is my recovery score and can I train today?',
        context: FitnessContext.initial(),
      );

      expect(result.actionsExecuted, isNotEmpty);
      expect(
        result.actionsExecuted.any((a) => a.toolName == 'health_tool'),
        isTrue,
      );
      expect(result.responseText, isNotEmpty);
    });

    test(
      'AIAgent safely prevents unauthorized mutation and requires confirmation',
      () async {
        final agent = AIAgent(aiProvider: const MockAIProvider());

        // Try executing save workout through confirmation workflow
        final pendingAction = AgentAction(
          id: 'act_pending',
          toolName: 'workout_tool',
          action: 'save_workout',
          arguments: {
            'action': 'save_workout',
            'workout_name': 'Leg Day Annihilation',
            'exercises': ['Squats', 'Leg Press'],
            'duration_minutes': 50,
            'confirmed': false,
          },
          requiresConfirmation: true,
          timestamp: DateTime.now(),
        );

        // Verify no workouts exist before confirmation
        expect(LocalStorage.getWorkoutHistory(), isEmpty);

        // Confirm action through AIAgent
        final result = await agent.processRequest(
          message: 'Confirm saving workout',
          context: FitnessContext.initial(),
          confirmedAction: pendingAction,
        );

        expect(result.actionsExecuted, isNotEmpty);
        expect(result.actionsExecuted.first.isConfirmed, isTrue);
        // The confirmed save keeps a plan; it is not a completed workout.
        expect(LocalStorage.getWorkoutHistory(), isEmpty);
        expect(
          LocalStorage.getSavedWorkoutPlans().first['name'],
          equals('Leg Day Annihilation'),
        );
      },
    );

    test(
      'CoachChatService sendAgentMessage processes agent result and saves conversation',
      () async {
        final chatService = CoachChatService(
          aiProvider: const MockAIProvider(),
        );
        final result = await chatService.sendAgentMessage(
          message: 'How much protein today?',
          context: FitnessContext.initial(),
        );

        expect(result.responseText, isNotEmpty);
        expect(
          result.actionsExecuted.any((a) => a.toolName == 'nutrition_tool'),
          isTrue,
        );
        expect(chatService.getMessages(), isNotEmpty);
        expect(chatService.getMessages().last.role.name, equals('assistant'));
      },
    );
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

/// A health store with no data at all (no watch, nothing recorded).
class _EmptyHealthService implements HealthService {
  @override
  Future<bool> hasPermissions() async => true;
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<bool> isProviderAvailable() async => true;
  @override
  Future<HealthMetric> getTodayHealthMetric() async => HealthMetric.zero();
  @override
  Future<List<HealthMetric>> getWeeklyHealthHistory() async => [];
  @override
  Stream<int?> watchHeartRate() => const Stream.empty();
  @override
  Future<void> updateHealthMetric(HealthMetric metric) async {}
}
