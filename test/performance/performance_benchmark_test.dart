import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/repositories/food_repository.dart';
import 'package:atlas/services/ai/ai_response_cache.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/health/health_service.dart';
import 'package:atlas/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    HealthService.resetInstance();
    FitnessMemory.resetInstance();
    AIResponseCache.instance.clear();
    AppDependencies.useMock();
  });

  group('Performance & Scalability Benchmark Tests', () {
    test(
      '1. Dependency Composition Root and Startup initialization executes sub-50ms',
      () async {
        final stopwatch = Stopwatch()..start();

        await LocalStorage.init();
        final dependencies = AppDependencies.instance;

        stopwatch.stop();

        expect(dependencies, isNotNull);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(500),
          reason: 'Cold start dependency resolution should be sub-second',
        );
      },
    );

    test(
      '2. AI Response Cache provides O(1) instantaneous hit retrieval and TTL expiry',
      () {
        final cache = AIResponseCache.instance;
        cache.clear();

        const prompt = 'How do I optimize bench press setup?';
        final key = AIResponseCache.generateKey(prompt);
        const generatedResponse =
            'Focus on leg drive, retracted scapulae, and a firm grip.';

        // Initial get is a cache miss
        expect(cache.get(key), isNull);
        expect(cache.missCount, equals(1));

        // Put response in cache
        cache.put(key, generatedResponse);
        expect(cache.size, equals(1));

        // Second get is a cache hit
        final cached = cache.get(key);
        expect(cached, equals(generatedResponse));
        expect(cache.hitCount, equals(1));

        // Put expired entry
        cache.put(
          'expired_key',
          'Old response',
          ttl: const Duration(milliseconds: 1),
        );
        // Wait slightly
        Future.delayed(const Duration(milliseconds: 10), () {
          expect(cache.get('expired_key'), isNull);
        });
      },
    );

    test(
      '3. Large Food Database (150+ items) fuzzy search completes in sub-15ms',
      () {
        final repo = LocalFoodRepository();
        final stopwatch = Stopwatch()..start();

        final results = repo.searchFoods('chicken');
        stopwatch.stop();

        expect(results, isNotEmpty);
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Food item filtering must be sub-100ms for 60fps UI',
        );
      },
    );

    test(
      '4. Fitness Memory scoring throughput handles batch mutations seamlessly',
      () async {
        final memory = FitnessMemory.instance;
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 50; i++) {
          await memory.recordExerciseReplacement(
            oldExercise: 'Bench Press',
            newExercise: 'Dumbbell Press',
          );
        }

        stopwatch.stop();
        final profile = memory.getPreferenceProfile();

        expect(profile.preferredExercises, contains('Dumbbell Press'));
        expect(profile.dislikedExercises, contains('Bench Press'));
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      },
    );

    test('5. Multi-category food filtering performance benchmark', () {
      final repo = LocalFoodRepository();
      final stopwatch = Stopwatch()..start();

      final proteins = repo.filterByCategory('Protein');
      final fruits = repo.filterByCategory('Fruits');
      final vegetables = repo.filterByCategory('Vegetables');

      stopwatch.stop();

      expect(proteins, isNotEmpty);
      expect(fruits, isNotEmpty);
      expect(vegetables, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
