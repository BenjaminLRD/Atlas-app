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
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/services/ai/experiments/ai_experiment_engine.dart';
import 'package:atlas/services/ai/learning/athlete_pattern_discovery_service.dart';
import 'package:atlas/services/ai/learning/recommendation_feedback_service.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/monitoring/ai_performance_monitor.dart';
import 'package:atlas/services/knowledge/knowledge_base_service.dart';
import 'package:atlas/services/knowledge/vector_search_service.dart';
import 'package:atlas/services/research/knowledge_update_pipeline.dart';
import 'package:atlas/services/research/knowledge_validation_service.dart';
import 'package:atlas/services/research/research_agent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FitnessMemory.resetInstance();
    await FitnessMemory.instance.initialize();
    VectorSearchService.resetInstance();
    KnowledgeBaseService.resetInstance();
    ResearchAgentService.resetInstance();
    KnowledgeValidationService.resetInstance();
    KnowledgeUpdatePipeline.resetInstance();
    RecommendationFeedbackService.resetInstance();
    AthletePatternDiscoveryService.resetInstance();
    AIExperimentEngine.resetInstance();
    AIPerformanceMonitor.resetInstance();

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
        fitnessGoal: 'Muscle Gain',
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
      workoutHistory: [
        WorkoutHistory(
          workoutName: 'Upper Hypertrophy',
          dateCompleted: now.subtract(const Duration(days: 1)),
          durationSeconds: 3600,
          exercisesCompleted: 6,
          completionPercentage: 100.0,
          totalSets: 18,
          totalReps: 140,
          totalVolume: 5200.0,
          caloriesBurned: 450.0,
        ),
      ],
      recoveryState: RecoveryState(
        id: 'rec_test',
        recoveryScore: 88,
        sleepQuality: 0.88,
        fatigueLevel: FatigueLevel.low,
        isDeloadRecommended: false,
        lastUpdated: now,
      ),
      generatedAt: now,
    );
  });

  group('1. Research Intelligence Agent Tests', () {
    test('Pre-seeds and collects structured sports science research papers', () {
      final agent = ResearchAgentService.instance;
      expect(agent.collectedResearch.length, greaterThanOrEqualTo(4));

      final item = agent.collectResearch(
        title: 'Creatine Supplementation and Satellite Cell Proliferation',
        authors: 'Olsen S, Aagaard P, Kadi F',
        journal: 'The Journal of Physiology',
        publicationYear: 2022,
        category: ResearchCategory.nutrition,
        evidenceLevel: ResearchEvidenceLevel.randomizedControlledTrial,
        abstractSummary: 'Creatine monohydrate combined with strength training amplifies satellite cell expansion.',
        practicalTakeaway: 'Supplement with 5g daily creatine monohydrate for enhanced myonuclei donation.',
        sampleSize: 32,
        effectSize: 0.58,
        tags: const ['creatine', 'satellite cells', 'hypertrophy'],
      );

      expect(item.id.startsWith('res_'), isTrue);
      expect(agent.collectedResearch.contains(item), isTrue);
      expect(agent.getResearchByCategory(ResearchCategory.nutrition).length, greaterThanOrEqualTo(2));
    });
  });

  group('2. Knowledge Validation System Tests', () {
    test('Validates rigorous peer-reviewed meta-analyses and RCTs', () {
      final validator = KnowledgeValidationService.instance;

      final validPaper = ResearchItem(
        id: 'res_valid_test',
        title: 'Meta-Analysis on Training Frequency for Muscle Hypertrophy',
        authors: 'Schoenfeld BJ, Ogborn D, Krieger JW',
        journal: 'Sports Medicine',
        publicationYear: 2019,
        category: ResearchCategory.training,
        evidenceLevel: ResearchEvidenceLevel.metaAnalysis,
        abstractSummary: 'Training a muscle group twice per week is superior to once per week for hypertrophy.',
        practicalTakeaway: 'Distribute weekly volume across at least 2 sessions per muscle group.',
        sampleSize: 420,
        effectSize: 0.49,
        extractedAt: DateTime.now(),
      );

      final result = validator.validateResearch(validPaper);
      expect(result.isValid, isTrue);
      expect(result.safetyPassed, isTrue);
      expect(result.confidenceScore, greaterThanOrEqualTo(0.85));
      expect(result.evidenceGrade, equals('Grade A+'));
      expect(result.validatedDocument, isNotNull);
      expect(result.validatedDocument!.title, equals(validPaper.title));
    });

    test('Rejects dangerous, unscientific, or harmful advice', () {
      final validator = KnowledgeValidationService.instance;

      final harmfulPaper = ResearchItem(
        id: 'res_harmful_test',
        title: 'Extreme Weight Cut Protocols',
        authors: 'Unverified Author',
        journal: 'Internet Blog',
        publicationYear: 2023,
        category: ResearchCategory.health,
        evidenceLevel: ResearchEvidenceLevel.caseSeries,
        abstractSummary: 'Athletes should starve and eat under 800 calories while ignoring sharp joint pain.',
        practicalTakeaway: 'Push through pain and eat minimal calories.',
        sampleSize: 5,
        extractedAt: DateTime.now(),
      );

      final result = validator.validateResearch(harmfulPaper);
      expect(result.isValid, isFalse);
      expect(result.safetyPassed, isFalse);
      expect(result.rejectionReasons.any((r) => r.contains('Violates safety policy')), isTrue);
      expect(result.validatedDocument, isNull);
    });
  });

  group('3. Knowledge Update Pipeline Tests', () {
    test('Processes batch research items, validating and adding approved items to KnowledgeBase', () {
      final pipeline = KnowledgeUpdatePipeline.instance;
      final kb = KnowledgeBaseService.instance;

      final initialDocCount = kb.getAllDocuments().length;

      final report = pipeline.runIngestionCycle();

      expect(report.totalProcessed, greaterThanOrEqualTo(4));
      expect(report.validatedAndAdded, greaterThanOrEqualTo(3));
      expect(kb.getAllDocuments().length, greaterThan(initialDocCount));
    });
  });

  group('4. Recommendation Learning Loop Tests', () {
    test('Tracks recommendation outcomes and computes adaptive category multipliers', () {
      final feedback = RecommendationFeedbackService.instance;

      // Log 3 successful training recommendations
      feedback.recordOutcome(
        recommendationId: 'rec_1',
        category: 'training',
        actionTitle: 'Incline Dumbbell Press 4x10',
        userAction: UserActionOnRecommendation.accepted,
        measuredImpactScore: 0.9,
      );

      feedback.recordOutcome(
        recommendationId: 'rec_2',
        category: 'training',
        actionTitle: 'Cable Flyes 3x12',
        userAction: UserActionOnRecommendation.accepted,
        measuredImpactScore: 0.85,
      );

      feedback.recordOutcome(
        recommendationId: 'rec_3',
        category: 'training',
        actionTitle: 'Lateral Raises 4x15',
        userAction: UserActionOnRecommendation.modified,
        measuredImpactScore: 0.8,
      );

      // Log 2 rejected nutrition recommendations
      feedback.recordOutcome(
        recommendationId: 'rec_4',
        category: 'nutrition',
        actionTitle: 'Eat 6 boiled eggs for breakfast',
        userAction: UserActionOnRecommendation.rejected,
        measuredImpactScore: 0.2,
      );

      feedback.recordOutcome(
        recommendationId: 'rec_5',
        category: 'nutrition',
        actionTitle: 'Strict 500 kcal deficit on rest day',
        userAction: UserActionOnRecommendation.ignored,
        measuredImpactScore: 0.1,
      );

      expect(feedback.getCategorySuccessRate('training'), equals(100.0));
      expect(feedback.getCategorySuccessRate('nutrition'), equals(0.0));
      expect(feedback.getOverallAdherenceRate(), equals(60.0));

      // Training gets boosted multiplier, nutrition gets reduced multiplier
      expect(feedback.getAdaptiveCategoryMultiplier('training'), equals(1.25));
      expect(feedback.getAdaptiveCategoryMultiplier('nutrition'), equals(0.75));
    });
  });

  group('5. Strategy & Pattern Discovery Engine Tests', () {
    test('Discovers latent recovery, volume, and protein patterns and writes them to FitnessMemory', () async {
      final discovery = AthletePatternDiscoveryService.instance;
      final memory = FitnessMemory.instance;

      final patterns = await discovery.analyzeAthleteTelemetry(sampleContext);

      expect(patterns.isNotEmpty, isTrue);
      expect(patterns.any((p) => p.type == PatternType.recoveryPattern), isTrue);
      expect(patterns.any((p) => p.type == PatternType.trainingPattern), isTrue);
      expect(patterns.any((p) => p.type == PatternType.nutritionPattern), isTrue);

      // Check that high-confidence patterns were persisted to FitnessMemory
      final memoryItems = memory.getMemoryItems();
      expect(memoryItems.any((m) => m.tags.contains('discovered_pattern')), isTrue);
      expect(memoryItems.any((m) => m.title.contains('Sleep Quality') || m.title.contains('Volume Tolerance')), isTrue);
    });
  });

  group('6. AI Experimentation Bandit Engine Tests', () {
    test('Routes arms via epsilon-greedy and updates cumulative rewards', () {
      final engine = AIExperimentEngine.instance;

      final selectedArm = engine.selectArm('coaching_style_bandit', userId: 'athlete_123');
      expect(selectedArm.id.isNotEmpty, isTrue);

      final initialReward = selectedArm.cumulativeReward;
      final initialTrials = selectedArm.trials;

      engine.recordArmOutcome(
        experimentId: 'coaching_style_bandit',
        armId: selectedArm.id,
        success: true,
        rewardScore: 0.95,
      );

      expect(selectedArm.trials, equals(initialTrials + 1));
      expect(selectedArm.cumulativeReward, closeTo(initialReward + 0.95, 0.01));

      final reports = engine.getExperimentReports();
      expect(reports.containsKey('coaching_style_bandit'), isTrue);
    });
  });

  group('7. Model Performance Monitoring Tests', () {
    test('Tracks real-time prediction accuracy, recommendation conversion, and safety rate', () {
      final monitor = AIPerformanceMonitor.instance;

      monitor.recordPrediction(predictedReadiness: 85, actualPerformanceScore: 88); // Accurate
      monitor.recordPrediction(predictedReadiness: 40, actualPerformanceScore: 85); // Inaccurate (diff > 15)

      monitor.recordRecommendationOutcome(accepted: true);
      monitor.recordRecommendationOutcome(accepted: false);

      monitor.recordFeedback(isPositive: true);
      monitor.recordFeedback(isPositive: true);

      monitor.recordSafetyIntervention();

      final snapshot = monitor.getPerformanceSnapshot();
      expect(snapshot.predictionAccuracyPct, greaterThanOrEqualTo(75.0));
      expect(snapshot.recommendationSuccessRatePct, greaterThanOrEqualTo(70.0));
      expect(snapshot.userSatisfactionPct, greaterThanOrEqualTo(85.0));
      expect(snapshot.safetyComplianceRatePct, greaterThanOrEqualTo(90.0));
      expect(snapshot.safetyIncidentsBlocked, greaterThan(0));
    });
  });

  group('8. Privacy and Safety Boundaries Tests', () {
    test('Ensures research collection is decoupled from athlete PII', () {
      final agent = ResearchAgentService.instance;
      for (final paper in agent.collectedResearch) {
        expect(paper.abstractSummary.contains('jordan@example.com'), isFalse);
        expect(paper.authors.contains('Jordan'), isFalse);
      }
    });
  });
}
