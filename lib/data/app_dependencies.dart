import 'profile_repository.dart';
import 'workout_repository.dart';
import 'nutrition_repository.dart';
import 'ai_chat_repository.dart';
import 'notification_repository.dart';
import '../repositories/goal_repository.dart';
import '../services/auth/auth_provider.dart';
import '../services/auth/mock_auth_provider.dart';
import '../services/sync/sync_provider.dart';
import '../services/sync/mock_sync_provider.dart';
import '../services/supabase/supabase_env.dart';
import '../services/supabase/supabase_client.dart';
import '../services/supabase/supabase_auth_provider.dart';
import '../services/supabase/supabase_sync_provider.dart';
import '../services/supabase/supabase_profile_repository.dart';
import 'profile_provider.dart';
import 'workout_service.dart';
import 'nutrition_service.dart';
import 'ai_chat_service.dart';
import 'notification_service.dart';
import '../repositories/subscription_repository.dart';
import '../services/subscription_service.dart';
import '../repositories/trainer_repository.dart';
import '../services/trainer_service.dart';

import '../services/ai/ai_provider.dart';
import '../services/ai/mock_ai_provider.dart';
import '../services/ai/gemini_ai_provider.dart';
import '../services/ai/ai_config.dart';
import '../services/ai/coach_chat_service.dart';

/// Simple manual dependency composition root without external DI packages.
/// Supports switching between Mock and Supabase backends dynamically.
class AppDependencies {
  static AppDependencies? _instance;

  final ProfileRepository profileRepository;
  final WorkoutRepository workoutRepository;
  final NutritionRepository nutritionRepository;
  final AIChatRepository aiChatRepository;
  final NotificationRepository notificationRepository;
  final GoalRepository goalRepository;
  final SubscriptionRepository subscriptionRepository;
  final TrainerRepository trainerRepository;

  final AuthProvider authProvider;
  final SyncProvider syncProvider;
  final AIProvider aiProvider;

  final ProfileProvider profileProvider;
  final WorkoutService workoutService;
  final NutritionService nutritionService;
  final AIChatService aiChatService;
  final CoachChatService coachChatService;
  final NotificationService notificationService;
  final SubscriptionService subscriptionService;
  final TrainerService trainerService;
  final bool isUsingSupabase;

  AppDependencies._({
    required this.profileRepository,
    required this.workoutRepository,
    required this.nutritionRepository,
    required this.aiChatRepository,
    required this.notificationRepository,
    required this.goalRepository,
    required this.subscriptionRepository,
    required this.trainerRepository,
    required this.authProvider,
    required this.syncProvider,
    required this.aiProvider,
    required this.profileProvider,
    required this.workoutService,
    required this.nutritionService,
    required this.aiChatService,
    required this.coachChatService,
    required this.notificationService,
    required this.subscriptionService,
    required this.trainerService,
    this.isUsingSupabase = false,
  });

  /// Get active singleton composition root.
  static AppDependencies get instance {
    _instance ??= AppDependencies.defaults();
    return _instance!;
  }

  /// Reset or inject custom dependencies (useful for testing).
  static void setInstance(AppDependencies dependencies) {
    _instance = dependencies;
  }

  /// Switch composition root to Mock mode.
  static void useMock() {
    _instance = AppDependencies.defaults();
  }

  /// Switch AI provider to production Gemini AI mode.
  static void useGemini({AIConfig? config}) {
    final activeConfig = config ?? AIConfig.fromEnvironment();
    final geminiProvider = GeminiAIProvider(config: activeConfig);
    final current = instance;

    _instance = AppDependencies._(
      profileRepository: current.profileRepository,
      workoutRepository: current.workoutRepository,
      nutritionRepository: current.nutritionRepository,
      aiChatRepository: current.aiChatRepository,
      notificationRepository: current.notificationRepository,
      goalRepository: current.goalRepository,
      subscriptionRepository: current.subscriptionRepository,
      trainerRepository: current.trainerRepository,
      authProvider: current.authProvider,
      syncProvider: current.syncProvider,
      aiProvider: geminiProvider,
      profileProvider: current.profileProvider,
      workoutService: current.workoutService,
      nutritionService: current.nutritionService,
      aiChatService: current.aiChatService,
      coachChatService: CoachChatService(aiProvider: geminiProvider),
      notificationService: current.notificationService,
      subscriptionService: current.subscriptionService,
      trainerService: current.trainerService,
      isUsingSupabase: current.isUsingSupabase,
    );
  }

  /// Switch composition root to Supabase mode.
  static void useSupabase({SupabaseEnv? env}) {
    final activeEnv = env ?? SupabaseEnv.dev();
    SupabaseClientManager.instance.initialize(activeEnv);

    final supabaseProfileRepo = SupabaseProfileRepository();
    final supabaseAuth = SupabaseAuthProvider();
    final supabaseSync = SupabaseSyncProvider();
    final workoutRepo = LocalWorkoutRepository();
    final nutritionRepo = LocalNutritionRepository();
    final aiChatRepo = LocalAIChatRepository();
    final notificationRepo = LocalNotificationRepository();
    final goalRepo = const LocalGoalRepository();
    final subRepo = const LocalSubscriptionRepository();
    final trainerRepo = const LocalTrainerRepository();
    const mockAi = MockAIProvider();

    _instance = AppDependencies._(
      profileRepository: supabaseProfileRepo,
      workoutRepository: workoutRepo,
      nutritionRepository: nutritionRepo,
      aiChatRepository: aiChatRepo,
      notificationRepository: notificationRepo,
      goalRepository: goalRepo,
      subscriptionRepository: subRepo,
      trainerRepository: trainerRepo,
      authProvider: supabaseAuth,
      syncProvider: supabaseSync,
      aiProvider: mockAi,
      profileProvider: ProfileProvider(supabaseProfileRepo),
      workoutService: WorkoutService(workoutRepo),
      nutritionService: NutritionService(nutritionRepo),
      aiChatService: AIChatService(aiChatRepo),
      coachChatService: const CoachChatService(aiProvider: mockAi),
      notificationService: NotificationService(notificationRepo),
      subscriptionService: SubscriptionService(repository: subRepo),
      trainerService: TrainerService(repository: trainerRepo),
      isUsingSupabase: true,
    );
  }

  /// Create default production composition tree (using Mock providers by default).
  factory AppDependencies.defaults() {
    final profileRepo = LocalProfileRepository();
    final workoutRepo = LocalWorkoutRepository();
    final nutritionRepo = LocalNutritionRepository();
    final aiChatRepo = LocalAIChatRepository();
    final notificationRepo = LocalNotificationRepository();
    final goalRepo = const LocalGoalRepository();
    final subRepo = const LocalSubscriptionRepository();
    final trainerRepo = const LocalTrainerRepository();
    final mockAuth = MockAuthProvider();
    final mockSync = MockSyncProvider();
    const mockAi = MockAIProvider();

    return AppDependencies._(
      profileRepository: profileRepo,
      workoutRepository: workoutRepo,
      nutritionRepository: nutritionRepo,
      aiChatRepository: aiChatRepo,
      notificationRepository: notificationRepo,
      goalRepository: goalRepo,
      subscriptionRepository: subRepo,
      trainerRepository: trainerRepo,
      authProvider: mockAuth,
      syncProvider: mockSync,
      aiProvider: mockAi,
      profileProvider: ProfileProvider(profileRepo),
      workoutService: WorkoutService(workoutRepo),
      nutritionService: NutritionService(nutritionRepo),
      aiChatService: AIChatService(aiChatRepo),
      coachChatService: const CoachChatService(aiProvider: mockAi),
      notificationService: NotificationService(notificationRepo),
      subscriptionService: SubscriptionService(repository: subRepo),
      trainerService: TrainerService(repository: trainerRepo),
      isUsingSupabase: false,
    );
  }
}
