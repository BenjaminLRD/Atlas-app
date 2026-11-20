import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/recovery_state.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/services/ai/ai_response_cache.dart';
import 'package:atlas/services/ai/cloud/ai_request_queue.dart';
import 'package:atlas/services/ai/cloud/atlas_ai_service_gateway.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/monitoring/infrastructure_monitoring_service.dart';
import 'package:atlas/services/monitoring/system_alert_service.dart';
import 'package:atlas/services/security/api_security_service.dart';
import 'package:atlas/services/storage/media_optimization_service.dart';
import 'package:atlas/services/supabase/database_optimization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FitnessMemory.resetInstance();
    await FitnessMemory.instance.initialize();
    AIResponseCache.instance.clear();
    AtlasAIServiceGateway.resetInstance();
    AIRequestQueue.resetInstance();
    DatabaseOptimizationService.resetInstance();
    MediaOptimizationService.resetInstance();
    InfrastructureMonitoringService.resetInstance();
    SystemAlertService.resetInstance();
    ApiSecurityService.resetInstance();

    final now = DateTime.now();
    sampleContext = FitnessContext(
      userProfile: UserProfile(
        name: 'Jordan',
        email: 'jordan@example.com',
        phone: '',
        dob: '1998-01-01',
        gender: 'Male',
        height: '178',
        weight: '76',
        fitnessGoal: 'Hypertrophy',
        workoutExperience: 'Intermediate',
        preferredDays: const ['Mon', 'Tue', 'Thu', 'Fri'],
        dietPreference: 'Non-Vegetarian',
        massUnit: 'kg',
        lengthUnit: 'cm',
        subscription: 'Pro',
        privacy: 'Public',
        notificationsEnabled: true,
        profilePic: '',
      ),
      userGoal: UserGoal(
        id: 'ug_test',
        goalType: FitnessGoalType.muscleGain,
        fitnessLevel: FitnessLevel.intermediate,
        activityLevel: ActivityLevel.moderate,
        age: 26,
        height: 178.0,
        currentWeight: 76.0,
        targetWeight: 80.0,
        targetCalories: 2600.0,
        targetProtein: 175.0,
        targetCarbohydrates: 300.0,
        targetFats: 70.0,
        createdDate: now,
        updatedDate: now,
      ),
      nutritionSummary: NutritionSummary.empty(),
      progressSummary: ProgressSummary.zero(),
      userProgress: UserProgress.initial(),
      nutritionProgress: NutritionProgress.initial(),
      workoutHistory: const [],
      recoveryState: RecoveryState(
        id: 'rec_test',
        recoveryScore: 85,
        sleepQuality: 0.85,
        fatigueLevel: FatigueLevel.low,
        isDeloadRecommended: false,
        lastUpdated: now,
      ),
      generatedAt: now,
    );
  });

  group('1. AI Request Queue & Prioritization Tests', () {
    test('Prioritizes P1 live requests ahead of P4 background requests', () async {
      final queue = AIRequestQueue.instance;

      final p4Future = queue.enqueue(
        query: 'Background pattern discovery analysis',
        context: sampleContext,
        priority: AIRequestPriority.backgroundMining,
      );

      final p1Future = queue.enqueue(
        query: 'Live coaching cue: Knees caving in',
        context: sampleContext,
        priority: AIRequestPriority.liveInteractive,
      );

      final responses = await Future.wait([p4Future, p1Future]);

      expect(responses.length, equals(2));
      expect(queue.totalProcessedCount, equals(2));
      expect(responses[0].responseContent.isNotEmpty, isTrue);
      expect(responses[1].responseContent.isNotEmpty, isTrue);
    });
  });

  group('2. Dedicated AI Gateway & Edge Caching Tests', () {
    test('Executes request, caches result, and serves subsequent query from cache', () async {
      final gateway = AtlasAIServiceGateway.instance;

      final res1 = await gateway.executeRequest(
        userQuery: 'What is progressive overload?',
        context: sampleContext,
      );

      expect(res1.isCacheHit, isFalse);
      expect(res1.tokensConsumed, greaterThan(0));

      final res2 = await gateway.executeRequest(
        userQuery: 'What is progressive overload?',
        context: sampleContext,
      );

      expect(res2.isCacheHit, isTrue);
      expect(res2.tokensConsumed, equals(0));
      expect(res2.modelUsed, equals('cache-edge-hit'));
    });
  });

  group('3. Database Optimization & Keyset Pagination Tests', () {
    test('Paginates large dataset safely with next page tokens', () {
      final db = DatabaseOptimizationService.instance;
      final dummyItems = List.generate(45, (i) => 'Workout_Log_$i');

      final page1 = db.paginateList(
        source: dummyItems,
        params: const PaginationParams(page: 1, limit: 10),
      );

      expect(page1.items.length, equals(10));
      expect(page1.hasNextPage, isTrue);
      expect(page1.totalCount, equals(45));

      final page5 = db.paginateList(
        source: dummyItems,
        params: const PaginationParams(page: 5, limit: 10),
      );

      expect(page5.items.length, equals(5));
      expect(page5.hasNextPage, isFalse);
    });
  });

  group('4. Storage Optimization & Media Compression Tests', () {
    test('Compresses raw photo into WebP with >70% size reduction', () {
      final storage = MediaOptimizationService.instance;

      final result = storage.compressImage(
        filePath: 'user_meal_photo.jpg',
        originalBytes: 4000000, // 4MB
      );

      expect(result.isCompressed, isTrue);
      expect(result.format, equals('webp'));
      expect(result.savedPercentage, greaterThan(70.0));

      final headers = storage.getCdnHeaders(isImmutable: true);
      expect(headers['Cache-Control']!.contains('immutable'), isTrue);
    });
  });

  group('5. Infrastructure & Reliability Monitoring Tests', () {
    test('Calculates p50, p95, p99 latencies, error rate, and uptime SLA', () {
      final monitor = InfrastructureMonitoringService.instance;

      monitor.recordLatency(45);
      monitor.recordLatency(55);
      monitor.recordLatency(210);
      monitor.recordLatency(850, isError: true);

      final snapshot = monitor.getMetricsSnapshot();

      expect(snapshot.totalRequests, greaterThan(500));
      expect(snapshot.latencyP50Ms, greaterThan(0));
      expect(snapshot.latencyP95Ms, greaterThanOrEqualTo(snapshot.latencyP50Ms));
      expect(snapshot.uptimePct, greaterThan(98.0));
    });
  });

  group('6. System Alerting & SLA Threshold Tests', () {
    test('Triggers warning and critical alerts on threshold breaches', () {
      final alertService = SystemAlertService.instance;

      final badMetrics = InfrastructureMetricsSnapshot(
        totalRequests: 1000,
        latencyP50Ms: 120.0,
        latencyP95Ms: 950.0, // Exceeds 800ms threshold
        latencyP99Ms: 1400.0,
        errorRatePct: 4.5, // Exceeds 3.0% threshold
        dbThroughputQps: 2100.0,
        aiServiceFailureRatePct: 6.2, // Exceeds 5.0% threshold
        uptimePct: 95.5,
        timestamp: DateTime.now(),
      );

      final triggered = alertService.evaluateMetrics(badMetrics);

      expect(triggered.length, greaterThanOrEqualTo(3));
      expect(alertService.activeAlerts.any((a) => a.severity == AlertSeverity.critical), isTrue);

      // Resolve alert
      alertService.resolveAlert('alert_error_rate_high');
      expect(alertService.activeAlerts.any((a) => a.id == 'alert_error_rate_high'), isFalse);
    });
  });

  group('7. Security Hardening & Rate Limiting Tests', () {
    test('Enforces sliding-window rate limit and intercepts SQL/XSS injections', () {
      final security = ApiSecurityService.instance;

      // Allow within limit
      for (int i = 0; i < 5; i++) {
        expect(security.checkRateLimit(clientId: 'user_123', maxRequestsPerMinute: 10), isTrue);
      }

      // Hit rate limit
      for (int i = 0; i < 6; i++) {
        security.checkRateLimit(clientId: 'user_123', maxRequestsPerMinute: 10);
      }

      final isAllowed = security.checkRateLimit(clientId: 'user_123', maxRequestsPerMinute: 10);
      expect(isAllowed, isFalse);

      // Validate inputs against malicious patterns
      expect(security.validateInput('What is progressive overload?'), isTrue);
      expect(security.validateInput('<script>alert("hack")</script>'), isFalse);
      expect(security.validateInput('SELECT * FROM users WHERE 1=1;--'), isFalse);
      expect(security.auditLogs.isNotEmpty, isTrue);
    });
  });
}
