import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  tearDown(AppDependencies.reset);

  group('the retired chat history is removed from storage', () {
    test('init removes a leftover chat_history and nothing else', () async {
      SharedPreferences.setMockInitialValues({
        'chat_history': '[{"sender":"bot","text":"old"}]',
        'coach_conversation_messages': '[]',
        'user_step_goal': 7000,
      });
      await LocalStorage.init();

      final p = await prefs();
      expect(p.containsKey('chat_history'), isFalse);
      expect(p.containsKey('coach_conversation_messages'), isTrue);
      expect(p.getInt('user_step_goal'), 7000);
    });

    test('running init again is harmless', () async {
      SharedPreferences.setMockInitialValues({'chat_history': '[]'});
      await LocalStorage.init();
      await LocalStorage.init();

      expect((await prefs()).containsKey('chat_history'), isFalse);
    });

    test('a store without the key is left as it was', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();

      expect((await prefs()).containsKey('chat_history'), isFalse);
    });
  });

  group('the unused form-report storage is removed', () {
    test('init removes leftover form reports and nothing else', () async {
      SharedPreferences.setMockInitialValues({
        'Atlas_exercise_form_reports': ['{"id":"r1"}'],
        'user_step_goal': 7000,
      });
      await LocalStorage.init();

      final p = await prefs();
      expect(p.containsKey('Atlas_exercise_form_reports'), isFalse);
      expect(p.getInt('user_step_goal'), 7000);
    });

    test('running init again is harmless', () async {
      SharedPreferences.setMockInitialValues({
        'Atlas_exercise_form_reports': ['{"id":"r1"}'],
      });
      await LocalStorage.init();
      await LocalStorage.init();

      expect(
        (await prefs()).containsKey('Atlas_exercise_form_reports'),
        isFalse,
      );
    });
  });

  group('the remaining AppDependencies composition', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      AppDependencies.reset();
    });

    test('defaults still provide the supported services', () async {
      final deps = AppDependencies.instance;

      expect(deps.aiProvider, isA<GeminiAIProvider>());
      expect(deps.coachChatService.aiProvider, same(deps.aiProvider));
      expect(deps.profileProvider, isNotNull);
      expect(deps.workoutService, isNotNull);
      expect(deps.nutritionService, isNotNull);
      expect(deps.notificationService, isNotNull);
      expect(deps.goalRepository, isNotNull);
      expect(deps.aiRepository, isNotNull);
      expect(deps.isUsingSupabase, isFalse);

      final subscription = await deps.subscriptionService.getSubscription();
      expect(subscription.isPremium, isFalse);
    });

    test('useMock and useSupabase still switch the composition', () {
      AppDependencies.useSupabase();
      expect(AppDependencies.instance.isUsingSupabase, isTrue);

      AppDependencies.useMock();
      expect(AppDependencies.instance.isUsingSupabase, isFalse);
    });
  });
}
