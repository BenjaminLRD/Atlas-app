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
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/memory/memory_item.dart';
import 'package:atlas/services/ai/prompt/adaptive_prompt_builder.dart';
import 'package:atlas/services/athlete/athlete_state_aggregator.dart';
import 'package:atlas/services/knowledge/knowledge_base_service.dart';
import 'package:atlas/services/knowledge/knowledge_document.dart';
import 'package:atlas/services/knowledge/knowledge_update_service.dart';
import 'package:atlas/services/knowledge/rag_service.dart';
import 'package:atlas/services/knowledge/vector_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FitnessMemory.resetInstance();
    await FitnessMemory.instance.initialize();
    VectorSearchService.resetInstance();
    KnowledgeBaseService.resetInstance();
    KnowledgeUpdateService.resetInstance();
    RAGService.resetInstance();

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
          workoutName: 'Upper Body Power',
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
        recoveryScore: 85,
        sleepQuality: 0.85,
        fatigueLevel: FatigueLevel.low,
        isDeloadRecommended: false,
        lastUpdated: now,
      ),
      generatedAt: now,
    );
  });

  group('1. Fitness Knowledge Models & Serialization Tests', () {
    test('Correctly models, copies, and serializes KnowledgeDocument', () {
      final now = DateTime.now();
      final doc = KnowledgeDocument(
        id: 'kb_creatine_loading',
        title: 'Creatine Monohydrate Saturation Kinetics',
        category: KnowledgeCategory.nutrition,
        content: 'Creatine monohydrate increases intramuscular phosphocreatine stores by 20-40%.',
        source: 'Buford TW, et al. ISSN position stand: creatine supplementation. JISSN (2007).',
        tags: const ['creatine', 'supplement', 'power', 'phosphocreatine'],
        createdAt: now,
        updatedAt: now,
        metadata: const {'evidence_level': 'Grade A'},
      );

      final json = doc.toJson();
      expect(json['id'], equals('kb_creatine_loading'));
      expect(json['category'], equals('NUTRITION'));
      expect(json['tags'], contains('creatine'));

      final fromJson = KnowledgeDocument.fromJson(json);
      expect(fromJson.id, equals(doc.id));
      expect(fromJson.title, equals(doc.title));
      expect(fromJson.category, equals(KnowledgeCategory.nutrition));
      expect(fromJson.source, equals(doc.source));
      expect(fromJson.metadata['evidence_level'], equals('Grade A'));
    });
  });

  group('2. Vector Search Engine Tests', () {
    test('Generates normalized 64-dimensional dense vectors', () {
      final vectorEngine = VectorSearchService.instance;
      final embedding = vectorEngine.generateEmbedding('hypertrophy progressive overload muscle protein synthesis');

      expect(embedding.length, equals(VectorSearchService.vectorDimensions));

      // L2 norm must equal 1.0 (unit hypersphere)
      double normSq = 0.0;
      for (final val in embedding) {
        normSq += val * val;
      }
      expect(normSq, closeTo(1.0, 0.01));
    });

    test('Computes accurate cosine similarity between related and unrelated texts', () {
      final vectorEngine = VectorSearchService.instance;

      final vecHypertrophy = vectorEngine.generateEmbedding('hypertrophy muscle overload sets reps');
      final vecHypertrophySimilar = vectorEngine.generateEmbedding('muscle growth progressive overload training volume');
      final vecUnrelated = vectorEngine.generateEmbedding('unrelated random weather astronomy geology telescope');

      final simHigh = vectorEngine.cosineSimilarity(vecHypertrophy, vecHypertrophySimilar);
      final simLow = vectorEngine.cosineSimilarity(vecHypertrophy, vecUnrelated);

      expect(simHigh, greaterThan(0.35));
      expect(simLow, lessThan(0.30));
      expect(simHigh, greaterThan(simLow));
    });

    test('Performs top-k semantic document search with ranking', () {
      final vectorEngine = VectorSearchService.instance;
      final kb = KnowledgeBaseService.instance;

      final results = vectorEngine.search(
        query: 'How much protein should I consume for muscle protein synthesis and leucine threshold?',
        documents: kb.getAllDocuments(),
        topK: 2,
      );

      expect(results.isNotEmpty, isTrue);
      expect(results.first.document.category, equals(KnowledgeCategory.nutrition));
      expect(results.first.document.title.toLowerCase().contains('protein'), isTrue);
      expect(results.first.rank, equals(1));
      expect(results.first.similarity, greaterThan(0.3));
    });
  });

  group('3. Knowledge Base Service Tests', () {
    test('Pre-seeds curated exercise science literature across 5 categories', () {
      final kb = KnowledgeBaseService.instance;
      final docs = kb.getAllDocuments();

      expect(docs.length, greaterThanOrEqualTo(8));

      // Check category coverage
      expect(kb.getDocumentsByCategory(KnowledgeCategory.exerciseScience).isNotEmpty, isTrue);
      expect(kb.getDocumentsByCategory(KnowledgeCategory.nutrition).isNotEmpty, isTrue);
      expect(kb.getDocumentsByCategory(KnowledgeCategory.recovery).isNotEmpty, isTrue);
      expect(kb.getDocumentsByCategory(KnowledgeCategory.safety).isNotEmpty, isTrue);
      expect(kb.getDocumentsByCategory(KnowledgeCategory.training).isNotEmpty, isTrue);
    });

    test('Supports CRUD operations and dynamic document retrieval', () {
      final kb = KnowledgeBaseService.instance;
      final now = DateTime.now();

      final newDoc = KnowledgeDocument(
        id: 'kb_custom_rpe_scale',
        title: 'Borg RPE Scale vs Reps in Reserve',
        category: KnowledgeCategory.training,
        content: 'RPE 8 corresponds precisely to 2 Reps in Reserve (RIR).',
        source: 'Helms ER, et al. Application of RPE scale in powerlifting (2016).',
        createdAt: now,
        updatedAt: now,
      );

      // 1. Create
      kb.storeDocument(newDoc);
      expect(kb.getDocument('kb_custom_rpe_scale'), isNotNull);

      // 2. Read & Search
      final search = kb.searchKnowledge(query: 'What is RPE 8 and reps in reserve?');
      expect(search.any((s) => s.document.id == 'kb_custom_rpe_scale'), isTrue);

      // 3. Update
      final updated = newDoc.copyWith(content: 'RPE 8 is 2 RIR. RPE 9 is 1 RIR.');
      kb.updateDocument(updated);
      expect(kb.getDocument('kb_custom_rpe_scale')?.content.contains('RPE 9'), isTrue);

      // 4. Delete
      final removed = kb.removeDocument('kb_custom_rpe_scale');
      expect(removed, isTrue);
      expect(kb.getDocument('kb_custom_rpe_scale'), isNull);
    });
  });

  group('4. Knowledge Update Pipeline Tests', () {
    test('Ingests, version-tracks, updates, and deprecates documents with audit history', () {
      final updateService = KnowledgeUpdateService.instance;
      final kb = KnowledgeBaseService.instance;

      // 1. Ingest
      final doc = updateService.ingestDocument(
        title: 'Zone 2 Mitochondrial Biogenesis',
        category: KnowledgeCategory.training,
        content: 'Zone 2 cardio at 60-70% max HR stimulates mitochondrial density and lactate clearance.',
        source: 'San Millan I, Brooks GA. Assessment of Metabolic Flexibility. Sports Med (2018).',
        tags: const ['cardio', 'zone2', 'mitochondria', 'lactate'],
        author: 'coach_admin',
      );

      expect(kb.getDocument(doc.id), isNotNull);
      expect(updateService.updateHistory.any((l) => l.documentId == doc.id && l.action == 'create'), isTrue);

      // 2. Update with version bump
      final updated = updateService.updateKnowledge(
        id: doc.id,
        content: 'Zone 2 cardio (65-75% HR max) maximizes fat oxidation and mitochondrial efficiency.',
        changeReason: 'Updated target heart rate bracket',
        author: 'sports_scientist',
      );

      expect(updated?.metadata['version'], equals(2));
      expect(updateService.updateHistory.any((l) => l.action == 'update'), isTrue);

      // 3. Re-index embeddings
      final reindexed = updateService.reindexAllEmbeddings();
      expect(reindexed, greaterThanOrEqualTo(9));

      // 4. Deprecate
      final deprecated = updateService.deprecateDocument(
        id: doc.id,
        reason: 'Superseded by updated protocol',
        author: 'curator',
      );

      expect(deprecated, isTrue);
      expect(kb.getDocument(doc.id), isNull);
    });
  });

  group('5. Advanced Memory System Upgrade Tests', () {
    test('Handles confidence scoring, expiration TTL, and automatic pruning', () async {
      final memory = FitnessMemory.instance;
      final now = DateTime.now();

      // 1. Permanent memory (high confidence)
      final permItem = MemoryItem(
        id: 'mem_perm_knee',
        category: MemoryCategory.trainingPreference,
        title: 'Knee Health',
        content: 'Prefers box squats over deep sissy squats due to patellar tendon load.',
        importanceScore: 8.5,
        confidenceScore: 0.95,
        createdAt: now,
      );
      await memory.recordMemoryItem(permItem);

      // 2. Expired transient memory (TTL in the past)
      final expiredItem = MemoryItem(
        id: 'mem_transient_travel',
        category: MemoryCategory.behaviorPattern,
        title: 'Temporary Travel Schedule',
        content: 'Traveling this weekend, only hotel gym dumbbells available.',
        importanceScore: 6.0,
        confidenceScore: 0.8,
        createdAt: now.subtract(const Duration(days: 5)),
        expiresAt: now.subtract(const Duration(days: 1)), // Expired yesterday
      );
      await memory.recordMemoryItem(expiredItem);

      expect(expiredItem.isExpired, isTrue);
      expect(permItem.isExpired, isFalse);

      // Active retrieval must exclude expired item
      final activeMemories = memory.retrieveMemories();
      expect(activeMemories.any((m) => m.id == 'mem_transient_travel'), isFalse);
      expect(activeMemories.any((m) => m.id == 'mem_perm_knee'), isTrue);

      // Prune expired
      final pruned = await memory.pruneExpiredMemories();
      expect(pruned, equals(1));
    });

    test('Ranks memories using multi-factor formula (importance, query match, confidence, recency)', () async {
      final memory = FitnessMemory.instance;
      final now = DateTime.now();

      await memory.recordMemoryItem(MemoryItem(
        id: 'mem_chest_volume',
        category: MemoryCategory.successfulStrategy,
        title: 'Chest Volume Sweet Spot',
        content: 'Thrives on 14-16 sets of weekly chest pressing for chest hypertrophy.',
        importanceScore: 8.0,
        confidenceScore: 0.95,
        createdAt: now,
      ));

      await memory.recordMemoryItem(MemoryItem(
        id: 'mem_water_intake',
        category: MemoryCategory.behaviorPattern,
        title: 'Hydration Habit',
        content: 'Drinks 3.5 liters of water daily.',
        importanceScore: 5.0,
        confidenceScore: 0.85,
        createdAt: now.subtract(const Duration(days: 20)),
      ));

      final ranked = memory.rankMemoriesForContext('How should I program my chest hypertrophy volume today?');

      expect(ranked.isNotEmpty, isTrue);
      expect(ranked.first.id, equals('mem_chest_volume'));
    });
  });

  group('6. RAG Pipeline & Prompt Context Synthesis Tests', () {
    test('End-to-end RAG query retrieves knowledge and athlete context into structured prompt', () {
      final rag = RAGService.instance;

      final snapshot = AthleteStateSnapshot(
        userId: 'athlete_jordan',
        timestamp: DateTime.now(),
        overallReadinessTier: 'optimal',
        workout: const WorkoutStateSummary(lastWorkoutName: 'Chest Power'),
        nutrition: const NutritionStateSummary(targetCalories: 2600, targetProteinGrams: 175),
        recovery: const RecoveryStateSummary(readinessScore: 88, sleepHours: 8.0),
        health: const HealthStateSummary(),
        behavior: const BehaviorStateSummary(),
        goal: const GoalStateSummary(primaryGoal: 'hypertrophy'),
      );

      final ragContext = rag.retrieveContext(
        query: 'What is the optimal protein distribution and leucine threshold for muscle growth?',
        context: sampleContext,
        stateSnapshot: snapshot,
      );

      expect(ragContext.hasScientificEvidence, isTrue);
      expect(ragContext.retrievedDocuments.any((d) => d.category == KnowledgeCategory.nutrition), isTrue);

      final enrichedPrompt = rag.buildRAGEnrichedPrompt(
        basePrompt: 'YOU ARE ATLAS.',
        ragContext: ragContext,
      );

      expect(enrichedPrompt.contains('RETRIEVAL-AUGMENTED CONTEXT'), isTrue);
      expect(enrichedPrompt.contains('EVIDENCE-BASED FITNESS KNOWLEDGE'), isTrue);
      expect(enrichedPrompt.contains('ISSN Position Stand'), isTrue);
      expect(enrichedPrompt.contains('COACHING INSTRUCTION'), isTrue);
    });

    test('AdaptivePromptBuilder dynamically embeds RAG knowledge block', () {
      final promptBuilder = AdaptivePromptBuilder.instance;

      final prompt = promptBuilder.buildAdaptiveSystemPrompt(
        context: sampleContext,
        currentQuery: 'What are the scientific mechanisms of muscle hypertrophy and progressive overload?',
      );

      expect(prompt.contains('YOU ARE ATLAS'), isTrue);
      expect(prompt.contains('EVIDENCE-BASED FITNESS KNOWLEDGE'), isTrue);
      expect(prompt.contains('Mechanisms of Muscle Hypertrophy') || prompt.contains('Schoenfeld'), isTrue);
    });
  });

  group('7. Privacy & Data Isolation Tests', () {
    test('Curated knowledge base contains no personal identifiable information (PII)', () {
      final kb = KnowledgeBaseService.instance;
      final allDocs = kb.getAllDocuments();

      for (final doc in allDocs) {
        // Knowledge corpus must not contain user names, emails, private IDs
        expect(doc.content.contains('Jordan'), isFalse);
        expect(doc.content.contains('@'), isFalse);
        expect(doc.content.contains('user_'), isFalse);
      }
    });

    test('User memory remains isolated and does not contaminate knowledge base', () async {
      final memory = FitnessMemory.instance;
      final kb = KnowledgeBaseService.instance;

      await memory.recordMemoryItem(MemoryItem(
        id: 'mem_secret_user_fact',
        category: MemoryCategory.behaviorPattern,
        title: 'Private Athlete Biometric Note',
        content: 'Jordan prefers lifting at 6:00 AM before work.',
        importanceScore: 7.0,
        createdAt: DateTime.now(),
      ));

      final kbSearch = kb.searchKnowledge(query: 'When does Jordan like to lift?');
      // Shared knowledge corpus should NOT match private memory content
      expect(kbSearch.any((s) => s.document.content.contains('Jordan')), isFalse);
    });
  });
}
