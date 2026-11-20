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
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/ai/platform/atlas_agent_orchestrator.dart';
import 'package:atlas/services/ai/platform/atlas_api_gateway_contracts.dart';
import 'package:atlas/services/ai/platform/atlas_model_architecture.dart';
import 'package:atlas/services/ai/platform/biomechanics_engine.dart';
import 'package:atlas/services/ai/platform/digital_athlete_model.dart';
import 'package:atlas/services/ai/platform/fitness_insights_engine.dart';
import 'package:atlas/services/ai/platform/research_intelligence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FitnessContext sampleContext;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FitnessMemory.resetInstance();
    await FitnessMemory.instance.initialize();
    AtlasModelArchitecture.resetInstance();
    BiomechanicsEngine.resetInstance();
    DigitalAthleteModel.resetInstance();
    FitnessInsightsEngine.resetInstance();
    AtlasAgentOrchestrator.resetInstance();
    ResearchIntelligenceService.resetInstance();

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
        recoveryScore: 88,
        sleepQuality: 0.85,
        fatigueLevel: FatigueLevel.low,
        isDeloadRecommended: false,
        lastUpdated: now,
      ),
      generatedAt: now,
    );
  });

  group('1. Atlas AI Model Architecture & Registry Tests', () {
    test('Registers sports science fine-tuned and on-device quantized models', () {
      final arch = AtlasModelArchitecture.instance;
      expect(arch.registeredModels.isNotEmpty, isTrue);

      final edgeModel = arch.selectModel(prefersOnDevice: true, requiresDeepReasoning: false);
      expect(edgeModel.isEdgeDeployable, isTrue);
      expect(edgeModel.averageLatencyMs, lessThan(30.0));

      final deepModel = arch.selectModel(prefersOnDevice: false, requiresDeepReasoning: true);
      expect(deepModel.family, equals(AIModelFamily.atlasSportsScience));
    });
  });

  group('2. Biomechanics Intelligence Engine Tests', () {
    test('Analyzes joint kinematics, bar path drift, and mechanical efficiency', () {
      final biomech = BiomechanicsEngine.instance;

      final report = biomech.evaluateMovementKinematics(
        pattern: MovementPatternType.squatPattern,
        kneeAngleAtDepth: 75.0, // Clean deep squat
        hipAngleAtDepth: 65.0,
        backInclineAngle: 45.0,
        barPathDriftCm: 2.8, // Elite straight bar path
        eccentricTime: 2.5,
        concentricTime: 1.0,
      );

      expect(report.mechanicalEfficiencyScore, greaterThanOrEqualTo(90.0));
      expect(report.identifiedFlaws.isEmpty, isTrue);
      expect(report.dominantTorqueJoint.isNotEmpty, isTrue);
    });

    test('Identifies shallow depth and horizontal bar path drift flaws', () {
      final biomech = BiomechanicsEngine.instance;

      final report = biomech.evaluateMovementKinematics(
        pattern: MovementPatternType.squatPattern,
        kneeAngleAtDepth: 105.0, // Shallow
        hipAngleAtDepth: 80.0,
        backInclineAngle: 30.0, // Excessive lean
        barPathDriftCm: 8.5, // High drift
        eccentricTime: 0.6, // Dropped down
      );

      expect(report.mechanicalEfficiencyScore, lessThan(60.0));
      expect(report.identifiedFlaws.length, greaterThanOrEqualTo(3));
    });
  });

  group('3. Digital Athlete Simulation Tests', () {
    test('Simulates multi-week impact of missed workouts and caloric variations', () {
      final sim = DigitalAthleteModel.instance;

      final scenario = sim.simulateScenario(const HypotheticalScenario(
        scenarioTitle: 'Busy Travel Week (2 Missed Sessions)',
        missedWorkoutsCount: 2,
        sleepDeltaHoursPerNight: -1.5,
      ));

      expect(scenario.projectedFatigueIndex, greaterThanOrEqualTo(50.0));
      expect(scenario.projected1RMDeltaKg, lessThan(2.5));
      expect(scenario.recommendation.isNotEmpty, isTrue);
    });
  });

  group('4. Global Population Insights Tests', () {
    test('Discovers sports science population correlations under differential privacy', () {
      final engine = FitnessInsightsEngine.instance;
      expect(engine.globalTrends.isNotEmpty, isTrue);

      final nutritionTrends = engine.getTrendsByCategory(InsightCategory.hypertrophyNutrition);
      expect(nutritionTrends.isNotEmpty, isTrue);
      expect(nutritionTrends.first.sampleSizeAthletes, greaterThan(10000));
      expect(nutritionTrends.first.confidenceScore, greaterThan(90.0));
    });
  });

  group('5. Multi-Agent AI Coaching Orchestrator Tests', () {
    test('Deliberates across 4 specialized agents and reaches unified consensus', () {
      final orchestrator = AtlasAgentOrchestrator.instance;

      final consensus = orchestrator.reachConsensus(context: sampleContext);

      expect(consensus.agentOpinions.length, equals(4));
      expect(consensus.consensusConfidence, greaterThan(0.90));
      expect(consensus.unifiedAction.contains('High-Intensity Hypertrophy'), isTrue);
    });

    test('Recovery agent successfully overrides volume when athlete is fatigued', () {
      final orchestrator = AtlasAgentOrchestrator.instance;

      final fatiguedContext = FitnessContext(
        userProfile: sampleContext.userProfile,
        userGoal: sampleContext.userGoal,
        nutritionSummary: sampleContext.nutritionSummary,
        progressSummary: sampleContext.progressSummary,
        userProgress: sampleContext.userProgress,
        nutritionProgress: sampleContext.nutritionProgress,
        workoutHistory: sampleContext.workoutHistory,
        recoveryState: RecoveryState(
          id: 'rec_fatigued',
          recoveryScore: 42, // Critical recovery score
          sleepQuality: 0.45,
          fatigueLevel: FatigueLevel.high,
          isDeloadRecommended: true,
          lastUpdated: DateTime.now(),
        ),
        generatedAt: DateTime.now(),
      );

      final consensus = orchestrator.reachConsensus(context: fatiguedContext);

      expect(consensus.compromisesResolved.isNotEmpty, isTrue);
      expect(consensus.unifiedAction.contains('Light Mobility') || consensus.unifiedAction.contains('Recovery'), isTrue);
    });
  });

  group('6. Research Intelligence & Evidence Platform Tests', () {
    test('Evaluates peer-reviewed literature and assigns highest confidence to meta-analyses', () {
      final research = ResearchIntelligenceService.instance;
      expect(research.papers.isNotEmpty, isTrue);

      final confidence = research.computeEvidenceConfidence(EvidenceHierarchy.metaAnalysisSystematicReview);
      expect(confidence, equals(0.98));
    });
  });

  group('7. AI Platform API Gateway Contracts Tests', () {
    test('Generates structured OpenAPI schemas for workout and biomechanics endpoints', () {
      final workoutContract = AtlasApiGatewayContracts.getWorkoutIntelligenceEndpointContract();
      expect(workoutContract['endpoint'].contains('/workout'), isTrue);
      expect(workoutContract['method'], equals('POST'));

      final biomechContract = AtlasApiGatewayContracts.getBiomechanicsEndpointContract();
      expect(biomechContract['endpoint'].contains('/biomechanics'), isTrue);
      expect(biomechContract['response_schema']['efficiency_score'], isNotNull);
    });
  });
}
