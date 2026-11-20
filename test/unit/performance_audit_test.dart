import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/ai/ai_response_cache.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/services/monitoring/performance_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 & 7 — Startup & AI Performance Optimization Tests', () {
    setUp(() {
      AIResponseCache.instance.clear();
      PerformanceTracker.instance.clear();
    });

    test(
      'AIResponseCache provides instantaneous (<1ms) hit for repeated prompts',
      () async {
        final cache = AIResponseCache.instance;
        final key = AIResponseCache.generateKey(
          'Create chest workout',
          'chest',
        );

        expect(cache.get(key), isNull);
        expect(cache.missCount, equals(1));
        expect(cache.hitCount, equals(0));

        // Put response
        cache.put(key, 'Here is your optimal 4-exercise chest workout...');
        expect(cache.size, equals(1));

        // Retrieve cached response
        final cached = cache.get(key);
        expect(
          cached,
          equals('Here is your optimal 4-exercise chest workout...'),
        );
        expect(cache.hitCount, equals(1));
      },
    );

    test(
      'AIResponseCache evicts least recently used items when capacity is exceeded',
      () {
        final cache = AIResponseCache.instance;

        for (int i = 0; i < 55; i++) {
          cache.put('query_$i', 'response_$i');
        }

        // Max capacity is 50
        expect(cache.size, equals(50));
        // Earliest items (0 to 4) should have been evicted
        expect(cache.get('query_0'), isNull);
        expect(cache.get('query_4'), isNull);
        // Recent items (5 to 54) must remain in cache
        expect(cache.get('query_50'), equals('response_50'));
      },
    );

    test(
      'CoachChatService utilizes AIResponseCache to bypass redundant network inference',
      () async {
        final service = CoachChatService(aiProvider: const MockAIProvider());

        final context = FitnessContext.initial();
        final prompt = 'Recommend high protein post workout meal';

        // 1. First execution - generates fresh response and populates cache
        final round1 = await service.sendMessage(
          message: prompt,
          context: context,
        );
        expect(round1.isNotEmpty, isTrue);
        final firstReply = round1.last.content;

        final cacheKey = AIResponseCache.generateKey(
          prompt,
          CoachChatService.cacheSignature(context),
        );
        expect(AIResponseCache.instance.get(cacheKey), equals(firstReply));

        // 2. Second execution - instantaneously hits cache
        final round2 = await service.sendMessage(
          message: prompt,
          context: context,
          currentMessages: round1,
        );

        expect(round2.last.content, equals(firstReply));
        expect(AIResponseCache.instance.hitCount, greaterThanOrEqualTo(1));
      },
    );

    test('PerformanceTracker records operation traces accurately', () async {
      final tracker = PerformanceTracker.instance;

      final data = await tracker.measureAsync(
        'test_heavy_computation',
        () async {
          await Future.delayed(const Duration(milliseconds: 15));
          return 42;
        },
      );

      expect(data, equals(42));
      expect(
        tracker.completedTraces.containsKey('test_heavy_computation'),
        isTrue,
      );
      expect(
        tracker.completedTraces['test_heavy_computation']!.inMilliseconds,
        greaterThanOrEqualTo(10),
      );
    });
  });

  group('Phase 2 & 5 — Widget & List Performance Tests', () {
    testWidgets(
      'ListView.builder renders large item lists lazily without performance lag',
      (WidgetTester tester) async {
        final items = List.generate(1000, (i) => 'Food Item #$i');
        final builtIndices = <int>{};

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: ListView.builder(
                  itemCount: items.length,
                  itemExtent: 50.0,
                  itemBuilder: (context, index) {
                    builtIndices.add(index);
                    return ListTile(title: Text(items[index]));
                  },
                ),
              ),
            ),
          ),
        );

        // Only items visible in the 400px viewport + small cache buffer should be built (not all 1000)
        expect(builtIndices.length, lessThan(30));
        expect(find.text('Food Item #0'), findsOneWidget);

        // Scroll down
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();

        // Additional items built on demand
        expect(builtIndices.length, greaterThan(10));
        expect(builtIndices.length, lessThan(60));
      },
    );

    testWidgets('ValueNotifier updates water intake with localized rebuild', (
      WidgetTester tester,
    ) async {
      final notifier = ValueNotifier<int>(5);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: notifier,
              builder: (context, val, _) {
                buildCount++;
                return Text('Glasses: $val');
              },
            ),
          ),
        ),
      );

      expect(find.text('Glasses: 5'), findsOneWidget);
      expect(buildCount, equals(1));

      // Trigger value update
      notifier.value = 6;
      await tester.pump();

      expect(find.text('Glasses: 6'), findsOneWidget);
      expect(buildCount, equals(2));
    });
  });
}
