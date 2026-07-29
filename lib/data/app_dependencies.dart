import 'profile_repository.dart';
import 'workout_repository.dart';
import 'nutrition_repository.dart';
import 'ai_chat_repository.dart';
import 'notification_repository.dart';
import 'profile_provider.dart';
import 'workout_service.dart';
import 'nutrition_service.dart';
import 'ai_chat_service.dart';
import 'notification_service.dart';

/// Simple manual dependency composition root without external DI packages.
class AppDependencies {
  static AppDependencies? _instance;

  final ProfileRepository profileRepository;
  final WorkoutRepository workoutRepository;
  final NutritionRepository nutritionRepository;
  final AIChatRepository aiChatRepository;
  final NotificationRepository notificationRepository;

  final ProfileProvider profileProvider;
  final WorkoutService workoutService;
  final NutritionService nutritionService;
  final AIChatService aiChatService;
  final NotificationService notificationService;

  AppDependencies._({
    required this.profileRepository,
    required this.workoutRepository,
    required this.nutritionRepository,
    required this.aiChatRepository,
    required this.notificationRepository,
    required this.profileProvider,
    required this.workoutService,
    required this.nutritionService,
    required this.aiChatService,
    required this.notificationService,
  });

  /// Get active singleton composition root
  static AppDependencies get instance {
    _instance ??= AppDependencies.defaults();
    return _instance!;
  }

  /// Reset or inject custom dependencies (useful for testing)
  static void setInstance(AppDependencies dependencies) {
    _instance = dependencies;
  }

  /// Create default production composition tree
  factory AppDependencies.defaults() {
    final profileRepo = LocalProfileRepository();
    final workoutRepo = LocalWorkoutRepository();
    final nutritionRepo = LocalNutritionRepository();
    final aiChatRepo = LocalAIChatRepository();
    final notificationRepo = LocalNotificationRepository();

    return AppDependencies._(
      profileRepository: profileRepo,
      workoutRepository: workoutRepo,
      nutritionRepository: nutritionRepo,
      aiChatRepository: aiChatRepo,
      notificationRepository: notificationRepo,
      profileProvider: ProfileProvider(profileRepo),
      workoutService: WorkoutService(workoutRepo),
      nutritionService: NutritionService(nutritionRepo),
      aiChatService: AIChatService(aiChatRepo),
      notificationService: NotificationService(notificationRepo),
    );
  }
}
