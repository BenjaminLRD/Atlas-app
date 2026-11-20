import 'profile_repository.dart';
import 'workout_repository.dart';
import 'nutrition_repository.dart';
import 'local/workout_local_repository.dart';
import 'local/nutrition_local_repository.dart';
import 'local/profile_local_repository.dart';
import 'notification_repository.dart';
import '../repositories/goal_repository.dart';
import '../repositories/ai_repository.dart';
import '../services/auth/auth_provider.dart';
import '../services/auth/local_auth_provider.dart';
import '../services/supabase/supabase_env.dart';
import '../services/supabase/supabase_client.dart';
import '../services/supabase/supabase_auth_provider.dart';
import '../services/supabase/supabase_profile_repository.dart';
import '../services/supabase/supabase_ai_repository.dart';
import 'profile_provider.dart';
import 'workout_service.dart';
import '../services/nutrition/nutrition_service.dart';
import '../services/notification_service.dart';
import '../repositories/subscription_repository.dart';
import '../services/subscription_service.dart';
import '../services/billing/production_billing_config.dart';
import '../repositories/health_repository.dart';
import '../services/supabase/supabase_health_repository.dart';

import '../services/ai/ai_provider.dart';
import '../services/ai/gemini_ai_provider.dart';
import '../services/ai/ai_config.dart';
import '../services/ai/coach_chat_service.dart';
import '../services/cloud/cloud_repositories.dart';
import '../services/cloud/cloud_session.dart';

/// Simple manual dependency composition root without external DI packages.
/// Supports switching between Mock and Supabase backends dynamically.
class AppDependencies {
  static AppDependencies? _instance;

  final ProfileRepository profileRepository;
  final WorkoutRepository workoutRepository;
  final NutritionRepository nutritionRepository;
  final AIRepository aiRepository;
  final NotificationRepository notificationRepository;
  final GoalRepository goalRepository;
  final HealthRepository healthRepository;

  final AuthProvider authProvider;
  final AIProvider aiProvider;

  final ProfileProvider profileProvider;
  final WorkoutService workoutService;
  final NutritionService nutritionService;
  final CoachChatService coachChatService;
  final NotificationService notificationService;
  final SubscriptionService subscriptionService;
  final bool isUsingSupabase;

  AppDependencies._({
    required this.profileRepository,
    required this.workoutRepository,
    required this.nutritionRepository,
    required this.aiRepository,
    required this.notificationRepository,
    required this.goalRepository,
    required this.healthRepository,
    required this.authProvider,
    required this.aiProvider,
    required this.profileProvider,
    required this.workoutService,
    required this.nutritionService,
    required this.coachChatService,
    required this.notificationService,
    required this.subscriptionService,
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

  /// Resolves the active AI provider based on environment variables and AppConfig.
  static AIProvider _resolveAIProvider() {
    final aiConfig = AIConfig.fromEnvironment();
    return GeminiAIProvider(config: aiConfig);
  }

  /// Switch composition root to Supabase mode.
  static void useSupabase({SupabaseEnv? env}) {
    final activeEnv = env ?? SupabaseEnv.fromEnvironment();
    SupabaseClientManager.instance.initialize(activeEnv);

    final supabaseProfileRepo = SupabaseProfileRepository();
    final supabaseAuth = SupabaseAuthProvider();
    final workoutRepo = LocalWorkoutRepository();
    final nutritionRepo = LocalNutritionRepository();
    final aiRepo = SupabaseAIRepository();
    final notificationRepo = LocalNotificationRepository();
    final goalRepo = const LocalGoalRepository();
    final subRepo = const LocalSubscriptionRepository();
    final healthRepo = SupabaseHealthRepository();
    final activeAi = _resolveAIProvider();

    _instance = AppDependencies._(
      profileRepository: supabaseProfileRepo,
      workoutRepository: workoutRepo,
      nutritionRepository: nutritionRepo,
      aiRepository: aiRepo,
      notificationRepository: notificationRepo,
      goalRepository: goalRepo,
      healthRepository: healthRepo,
      authProvider: supabaseAuth,
      aiProvider: activeAi,
      profileProvider: ProfileProvider(supabaseProfileRepo),
      workoutService: WorkoutService(workoutRepo),
      nutritionService: NutritionService(nutritionRepo),
      coachChatService: CoachChatService(aiProvider: activeAi),
      notificationService: NotificationService(repository: notificationRepo),
      subscriptionService: SubscriptionService(
        repository: subRepo,
        billingProvider: ProductionBillingConfig.resolveProvider(),
      ),
      isUsingSupabase: true,
    );
  }

  /// Create default production composition tree.
  ///
  /// When the Supabase SDK is configured, profile, workout, nutrition and goal
  /// saves are mirrored to the signed-in user's cloud rows; otherwise the app
  /// runs fully on-device.
  factory AppDependencies.defaults() {
    final cloud = CloudSession.client != null;
    final ProfileLocalRepository profileRepo = cloud
        ? CloudProfileRepository()
        : ProfileLocalRepository();
    final WorkoutLocalRepository workoutRepo = cloud
        ? CloudWorkoutRepository()
        : WorkoutLocalRepository();
    final NutritionLocalRepository nutritionRepo = cloud
        ? CloudNutritionRepository()
        : NutritionLocalRepository();
    final aiRepo = SupabaseAIRepository();
    final notificationRepo = LocalNotificationRepository();
    final GoalRepository goalRepo = cloud
        ? CloudGoalRepository()
        : const LocalGoalRepository();
    final subRepo = const LocalSubscriptionRepository();
    final healthRepo = LocalHealthRepository();
    final localAuth = LocalAuthProvider();
    final activeAi = _resolveAIProvider();

    return AppDependencies._(
      profileRepository: profileRepo,
      workoutRepository: workoutRepo,
      nutritionRepository: nutritionRepo,
      aiRepository: aiRepo,
      notificationRepository: notificationRepo,
      goalRepository: goalRepo,
      healthRepository: healthRepo,
      authProvider: localAuth,
      aiProvider: activeAi,
      profileProvider: ProfileProvider(profileRepo),
      workoutService: WorkoutService(workoutRepo),
      nutritionService: NutritionService(nutritionRepo),
      coachChatService: CoachChatService(aiProvider: activeAi),
      notificationService: NotificationService(repository: notificationRepo),
      subscriptionService: SubscriptionService(
        repository: subRepo,
        billingProvider: ProductionBillingConfig.resolveProvider(),
      ),
      isUsingSupabase: false,
    );
  }

  /// Reset singleton instance for testing
  static void reset() {
    _instance = null;
  }
}
