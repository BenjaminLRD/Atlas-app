import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/services/ai/ai_provider.dart';
import 'package:atlas/services/ai/ai_response_cache.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts calls so tests can tell a cache hit from a model call. No network.
class _CountingProvider implements AIProvider {
  int calls = 0;
  final String Function(String message) answer;

  _CountingProvider(this.answer);

  @override
  String get providerName => 'counting fake';
  @override
  bool get isOnline => true;

  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  }) async {
    calls++;
    return answer(message);
  }
}

FitnessContext _contextFor({
  String email = 'a@example.com',
  String weight = '70',
}) => FitnessContext.initial().copyWith(
  userProfile: UserProfile.defaultProfile(
    email: email,
  ).copyWith(weight: weight, fitnessGoal: 'Hypertrophy'),
);

Future<CoachMessage> _ask(
  CoachChatService service,
  String text,
  FitnessContext context,
) async {
  final messages = await service.sendMessage(
    message: text,
    context: context,
    currentMessages: const [],
  );
  return messages.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AIResponseCache.instance.clear();
    AIResponseCache.instance.preloadDomainKnowledge();
  });

  group('preloaded knowledge is local, not AI', () {
    test('a preloaded answer is flagged immutable', () {
      final entry = AIResponseCache.instance.lookup('benefits of creatine');
      expect(entry, isNotNull);
      expect(entry!.isImmutableKnowledge, isTrue);
      expect(entry.response, contains('Creatine Monohydrate'));
    });

    test(
      'the chat labels a preloaded answer local and skips the model',
      () async {
        final provider = _CountingProvider((_) => 'from the model');
        final reply = await _ask(
          CoachChatService(aiProvider: provider),
          'Benefits of creatine?',
          FitnessContext.initial(),
        );
        expect(reply.category, CoachReplySource.local);
        expect(reply.content, contains('Creatine Monohydrate'));
        expect(provider.calls, 0);
      },
    );
  });

  group('genuine AI answers are cached and labeled ai', () {
    test(
      'the second identical question is served from the cache as ai',
      () async {
        final provider = _CountingProvider(
          (_) => 'Eat a banana and some oats.',
        );
        final service = CoachChatService(aiProvider: provider);
        final context = _contextFor();

        final first = await _ask(
          service,
          'Best pre workout snack idea',
          context,
        );
        expect(first.category, CoachReplySource.ai);
        expect(provider.calls, 1);

        final second = await _ask(
          service,
          'Best pre workout snack idea',
          context,
        );
        expect(provider.calls, 1, reason: 'served from the cache');
        expect(second.content, first.content);
        expect(second.category, CoachReplySource.ai);
      },
    );
  });

  group('fuzzy matching safety', () {
    final cache = AIResponseCache.instance;

    test('generated answers are never returned for a similar question', () {
      cache.put('best pre workout snack idea', 'Banana and oats.');
      expect(cache.lookup('best pre workout snack idea'), isNotNull);
      expect(cache.lookup('best pre workout meal idea'), isNull);
      expect(cache.lookup('best pre workout snack ideas for dinner'), isNull);
    });

    test('a longer, more specific question does not get the generic entry', () {
      // Used to match by containment of the entry's words.
      expect(
        cache.lookup('how much protein should i eat if i weigh 90 kg'),
        isNull,
      );
      expect(
        cache.lookup('what are the benefits of creatine for older women'),
        isNull,
      );
    });

    test('near-identical wording still reaches the verified knowledge', () {
      expect(cache.lookup('how much protein should I eat?'), isNotNull);
      expect(cache.lookup('Benefits of creatine'), isNotNull);
    });

    test('the cache survives: exact repeats and eviction still work', () {
      cache.put('query_a', 'answer a');
      expect(cache.get('query_a'), 'answer a');
      expect(cache.hitCount, greaterThanOrEqualTo(1));
    });
  });

  group('personal questions bypass the cache', () {
    test('personal-fact and first-person questions are detected', () {
      for (final q in [
        'how old am I',
        "what's my age",
        'what is my name',
        'what is my bmi',
        'what is my height',
        'how tall am i',
        'what is my weight',
        'when is my birthday',
        'I am 30 what should I eat',
      ]) {
        expect(AIResponseCache.isPersonalQuery(q), isTrue, reason: q);
      }
      for (final q in [
        'benefits of creatine',
        'how long should I rest between sets',
        'what is progressive overload',
        'is the gym open on sunday',
        'tell me about the stage of training',
      ]) {
        expect(AIResponseCache.isPersonalQuery(q), isFalse, reason: q);
      }
    });

    test('a personal answer is neither stored nor served', () {
      final cache = AIResponseCache.instance;
      cache.put('how old am i::sig', 'You are 25.');
      expect(cache.lookup('how old am i::sig'), isNull);
      expect(cache.size, greaterThan(0)); // preloaded entries remain
      expect(cache.isCacheable('how old am i'), isFalse);
      expect(cache.isCacheable('benefits of creatine'), isTrue);
    });

    test(
      'the model is asked every time, never answered from the cache',
      () async {
        var n = 0;
        final provider = _CountingProvider((_) => 'answer ${++n}');
        final service = CoachChatService(aiProvider: provider);
        final context = _contextFor();

        final first = await _ask(service, 'how old am I', context);
        final second = await _ask(service, 'how old am I', context);
        expect(provider.calls, 2);
        expect(first.content, 'answer 1');
        expect(second.content, 'answer 2');
      },
    );

    test(
      'another account or an edited profile never reuses an answer',
      () async {
        var n = 0;
        final provider = _CountingProvider((m) => 'answer ${++n}');
        final service = CoachChatService(aiProvider: provider);

        final a = _contextFor(email: 'a@example.com');
        final firstA = await _ask(service, 'Best pre workout snack idea', a);
        await _ask(service, 'Best pre workout snack idea', a);
        expect(provider.calls, 1, reason: 'same account, same profile: cached');

        await _ask(
          service,
          'Best pre workout snack idea',
          _contextFor(email: 'b@example.com'),
        );
        expect(provider.calls, 2, reason: 'a different account asks again');

        await _ask(
          service,
          'Best pre workout snack idea',
          _contextFor(email: 'a@example.com', weight: '95'),
        );
        expect(provider.calls, 3, reason: 'an edited profile asks again');
        expect(firstA.category, CoachReplySource.ai);
      },
    );

    test('the cache signature changes with account and profile facts', () {
      final base = CoachChatService.cacheSignature(_contextFor());
      expect(
        CoachChatService.cacheSignature(_contextFor(email: 'b@example.com')),
        isNot(base),
      );
      expect(
        CoachChatService.cacheSignature(_contextFor(weight: '99')),
        isNot(base),
      );
      expect(CoachChatService.cacheSignature(_contextFor()), base);
    });
  });
}
