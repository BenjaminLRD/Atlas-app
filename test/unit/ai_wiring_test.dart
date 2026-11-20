import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/ai_provider.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';

class _FakeProvider implements AIProvider {
  _FakeProvider(this.isOnline);

  @override
  final bool isOnline;

  @override
  String get providerName => 'Fake';

  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  }) async => 'ok';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
  });

  tearDown(() {
    FitnessProvider.resetInstance();
    AppDependencies.reset();
  });

  test('the default coach service is the shared AppDependencies one', () {
    final deps = AppDependencies.instance;
    final provider = FitnessProvider();

    expect(provider.coachChatService, same(deps.coachChatService));
    expect(provider.coachChatService.aiProvider, same(deps.aiProvider));
  });

  test('two providers share the coach service', () {
    final a = FitnessProvider();
    FitnessProvider.resetInstance();
    final b = FitnessProvider();

    expect(a.coachChatService, same(b.coachChatService));
  });

  test('injected services still win over the shared ones', () {
    final coach = CoachChatService(aiProvider: _FakeProvider(true));
    final provider = FitnessProvider(coachChatService: coach);

    expect(provider.coachChatService, same(coach));
    expect(
      provider.coachChatService.aiProvider,
      isNot(same(AppDependencies.instance.aiProvider)),
    );
  });

  test('isCoachAvailable reflects the configured AI state', () {
    final provider = FitnessProvider();
    expect(provider.isCoachAvailable, AIConfig.fromEnvironment().isConfigured);
    expect(
      provider.isCoachAvailable,
      AppDependencies.instance.aiProvider.isOnline,
    );

    FitnessProvider.resetInstance();
    expect(
      FitnessProvider(
        coachChatService: CoachChatService(aiProvider: _FakeProvider(true)),
      ).isCoachAvailable,
      isTrue,
    );
    FitnessProvider.resetInstance();
    expect(
      FitnessProvider(
        coachChatService: CoachChatService(aiProvider: _FakeProvider(false)),
      ).isCoachAvailable,
      isFalse,
    );
  });
}
