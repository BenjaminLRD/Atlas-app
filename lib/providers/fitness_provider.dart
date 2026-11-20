import 'dart:async';
import '../services/cloud/auth_availability.dart';
import '../services/cloud/cloud_auth_repository.dart';
import '../services/cloud/cloud_session.dart';
import '../services/cloud/cloud_sync_coordinator.dart';
import '../services/ranked/ranked_service.dart';
import '../services/billing/revenuecat_billing_provider.dart';
import '../services/ranked/ranked_progress_store.dart';
import '../services/ranked/rank_ladder.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/app_dependencies.dart';
import '../data/gamification_service.dart';
import '../data/local_storage.dart';
import '../data/workout_changes.dart';
import '../services/gamification/bonus_xp.dart';
import '../services/nutrition/nutrition_changes.dart';
import '../services/nutrition/nutrition_service.dart';
import 'showcase_data_provider.dart';
import '../models/activity_record.dart';
import '../services/cloud/cloud_repositories.dart';
import '../services/gamification/workout_xp_calculator.dart';
import '../data/profile_provider.dart';
import '../data/workout_service.dart';
import '../models/badge.dart';
import '../models/daily_nutrition.dart';
import '../models/consumed_food.dart';
import '../models/food_item.dart';
import '../services/nutrition/nutrition_calculator.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_log.dart';
import '../models/nutrition_totals.dart';
import '../models/nutrition_summary.dart';
import '../models/user_profile.dart';
import '../models/user_progress.dart';
import '../models/user_xp.dart';
import '../models/transformation_post.dart';
import '../services/transformation_service.dart';
import '../models/user_goal.dart';
import '../models/workout_history.dart';
import '../models/workout_session.dart';
import '../models/reward_event.dart';
import '../models/progress_summary.dart';
import '../models/progress_analytics.dart';
import '../models/food_analysis_result.dart';
import '../services/food_database_service.dart';
import '../services/ai/memory/fitness_memory.dart';
import '../models/streak_data.dart';
import '../models/weekly_challenge.dart';
import '../models/nutrition_progress.dart';
import '../models/fitness_context.dart';
import '../models/health_metric.dart';
import '../models/sleep_record.dart';
import '../models/recovery_insight.dart';
import '../services/health/recovery_service.dart';
import '../models/recommendation.dart';
import '../repositories/goal_repository.dart';
import '../services/achievement_service.dart';
import '../services/analytics/workout_analytics_service.dart';
import '../services/progress_analytics_engine.dart';
import '../services/challenge_service.dart';
import '../services/nutrition_analytics_service.dart';
import '../services/nutrition_gamification_service.dart';
import '../services/progress_summary_service.dart';
import '../services/recommendation_service.dart';
import '../services/reward_queue_service.dart';
import '../models/coach_message.dart';
import '../services/ai/coach_chat_service.dart';
import '../services/ai/ai_config.dart';
import '../services/ai/multimodal/chat_attachment.dart';
import '../models/daily_brief.dart';
import '../services/ai/daily_brief_service.dart';
import '../models/daily_coach_brief.dart';
import '../services/ai/daily_coach_brief_service.dart';
import '../models/weekly_coach_review.dart';
import '../services/ai/decision_engine/ai_decision_engine.dart';
import '../services/ai/adaptation/goal_adaptation_engine.dart';
import '../services/ai/weekly_coach_review_service.dart';
import '../services/ai/coach_notification_service.dart';
import '../services/gamification/xp_service.dart';
import '../services/workout_streak_service.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../models/challenge.dart';
import '../models/user_challenge.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';
import '../models/friendship.dart';
import '../models/activity_item.dart';
import '../services/social_service.dart';
import '../models/fitness_season.dart';
import '../models/season_progress.dart';
import '../services/season_service.dart';
import '../models/health_metrics.dart';
import '../models/connected_device.dart';
import '../services/health/health_sync_service.dart';
import '../models/training_state.dart';
import '../services/training_intelligence_service.dart';
import '../models/recommended_workout.dart';
import '../models/adaptive_workout_plan.dart';
import '../services/step_tracking_service.dart';
import '../services/activity_score_service.dart';
import '../services/workout_planner_service.dart';
import '../models/workout_feedback.dart';
import '../services/workout_adaptation_service.dart';
import '../models/recovery_state.dart';
import '../services/recovery_intelligence_service.dart';
import '../models/recovery/recovery_report.dart';
import '../services/recovery/training_load_engine.dart';
import '../services/recovery/recovery_prediction_engine.dart';
import '../services/recovery/health_prediction_engine.dart';
import '../services/wearables/wearable_service.dart';
import '../models/subscription.dart';
import '../models/premium_feature.dart';
import '../services/subscription_service.dart';
import '../models/user_role.dart';

import '../widgets/common/rank_up_dialog.dart';

/// Result bundle returned by saveWorkoutCompletion containing potential rank up details,
/// newly unlocked achievement badges, and generated RewardEvents queued for presentation.
class WorkoutCompletionResult {
  final RankUpDetails? rankUpDetails;
  final List<AchievementBadge> unlockedBadges;
  final List<RewardEvent> rewards;
  final int xpEarned;

  /// True when this workout had already been recorded: nothing was saved and
  /// no XP was awarded this time.
  final bool isDuplicate;

  const WorkoutCompletionResult({
    this.rankUpDetails,
    this.unlockedBadges = const [],
    this.rewards = const [],
    this.xpEarned = 0,
    this.isDuplicate = false,
  });
}

/// Central reactive AppState / FitnessProvider using Flutter's native ChangeNotifier.
/// Serves as the single source of truth for reactive data binding across
/// bottom navigation tabs and screens without requiring tab switches or app restarts.
class FitnessProvider extends ChangeNotifier {
  static FitnessProvider? _instance;

  final WorkoutService _workoutService;
  final NutritionService _nutritionService;
  final ProfileProvider _profileProvider;
  final GamificationService _gamificationService;
  final ChallengeService _challengeService;
  final NutritionGamificationService _nutritionGamificationService;
  final GoalRepository _goalRepository;
  final NutritionAnalyticsService _nutritionAnalyticsService =
      const NutritionAnalyticsService();
  final RecommendationService _recommendationService;
  final CoachChatService _coachChatService;
  final DailyBriefService _dailyBriefService;
  final DailyCoachBriefService _dailyCoachBriefService;
  final AuthRepository _authRepository;
  final LeaderboardService _leaderboardService;
  final NotificationService _notificationService;
  final SocialService _socialService;
  final SeasonService _seasonService;
  final HealthSyncService _healthSyncService;
  final TrainingIntelligenceService _trainingIntelligenceService;
  final WorkoutPlannerService _workoutPlannerService;
  final WorkoutAdaptationService _workoutAdaptationService;
  final RecoveryIntelligenceService _recoveryIntelligenceService;
  final XPService _xpService;
  final AIDecisionEngine _aiDecisionEngine;
  final GoalAdaptationEngine _goalAdaptationEngine;
  final WeeklyCoachReviewService _weeklyCoachReviewService;
  final CoachNotificationService _coachNotificationService;
  final TransformationService _transformationService;
  final TrainingLoadEngine _trainingLoadEngine;
  final RecoveryPredictionEngine _recoveryPredictionEngine;
  final HealthPredictionEngine _healthPredictionEngine;
  final UniversalWearableManager _wearableManager;

  List<WorkoutHistory> _workoutHistory = [];
  DailyNutrition? _todayNutrition;
  UserProfile? _profile;
  UserProgress? _userProgress;
  UserXP? _userXP;
  RecoveryReport? _latestRecoveryReport;
  HealthMetrics? _todayHealthMetrics;
  WeeklyCoachReview? _weeklyCoachReview;
  AIDecisionReport? _lastDecisionReport;
  UserGoal? _currentGoal;
  NutritionSummary? _cachedNutritionSummary;
  List<Recommendation> _recommendations = [];
  List<CoachMessage> _coachMessages = [];
  DailyBrief? _dailyBrief;
  DailyCoachBrief? _dailyCoachBrief;
  AppUser? _currentUser;
  bool _isCoachReplying = false;
  final bool _isLoading = false;

  List<LeaderboardEntry> _globalLeaderboard = [];
  List<LeaderboardEntry> _localLeaderboard = [];
  List<LeaderboardEntry> _friendsLeaderboard = [];
  bool _isLeaderboardLoading = false;
  String? _leaderboardError;

  List<Challenge> _activeChallenges = [];
  List<UserChallenge> _userChallenges = [];
  bool _isChallengesLoading = false;
  String? _challengesError;

  List<NotificationItem> _notifications = [];

  List<LeaderboardEntry> _friends = [];
  List<Friendship> _friendRequests = [];
  List<ActivityItem> _activityFeed = [];

  FitnessSeason? _currentSeason;
  SeasonProgress? _seasonProgress;
  List<LeaderboardEntry> _seasonLeaderboard = [];

  HealthMetrics? _healthMetrics;
  int _recoveryScore = 0;
  List<ConnectedDevice> _connectedDevices = [];

  TrainingState? _trainingState;

  AdaptiveWorkoutPlan? _adaptiveWorkoutPlan;
  RecommendedWorkout? _todaysRecommendation;

  RecoveryState? _recoveryState;
  final List<WorkoutFeedback> _workoutFeedbackHistory = [];

  // Transparent Sleep & Recovery Tracking State
  List<SleepRecord> _sleepHistory = [];
  SleepRecord? _latestSleep;
  RecoveryInsight _recoveryInsight = RecoveryInsight.insufficientData();

  List<SleepRecord> get sleepHistory => List.unmodifiable(_sleepHistory);
  SleepRecord? get latestSleep => _latestSleep;
  RecoveryInsight get recoveryInsight => _recoveryInsight;

  Subscription _subscription = Subscription.free();
  final SubscriptionService _subscriptionService =
      AppDependencies.instance.subscriptionService;

  UserRole _userRole = UserRole.member;

  bool get isLoading => _isLoading;
  List<CoachMessage> get coachMessages => List.unmodifiable(_coachMessages);
  bool get isCoachReplying => _isCoachReplying;
  DailyBrief? get dailyBrief => _dailyBrief;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoggedIn => isAuthenticated;
  List<LeaderboardEntry> get globalLeaderboard =>
      List.unmodifiable(_globalLeaderboard);
  List<LeaderboardEntry> get localLeaderboard =>
      List.unmodifiable(_localLeaderboard);
  List<LeaderboardEntry> get friendsLeaderboard =>
      List.unmodifiable(_friendsLeaderboard);
  List<LeaderboardEntry> get leaderboard => globalLeaderboard;
  bool get isLeaderboardLoading => _isLeaderboardLoading;
  String? get leaderboardError => _leaderboardError;

  List<Challenge> get activeChallenges => List.unmodifiable(_activeChallenges);
  List<UserChallenge> get userChallenges => List.unmodifiable(_userChallenges);
  bool get isChallengesLoading => _isChallengesLoading;
  String? get challengesError => _challengesError;

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

  List<LeaderboardEntry> get friends => List.unmodifiable(_friends);
  List<Friendship> get friendRequests => List.unmodifiable(_friendRequests);
  List<ActivityItem> get activityFeed => List.unmodifiable(_activityFeed);

  FitnessSeason? get currentSeason => _currentSeason;
  SeasonProgress? get seasonProgress => _seasonProgress;
  List<LeaderboardEntry> get seasonLeaderboard =>
      List.unmodifiable(_seasonLeaderboard);

  HealthMetrics? get healthMetrics => _healthMetrics;
  int get recoveryScore => _recoveryScore;

  TrainingState? get trainingState => _trainingState;

  AdaptiveWorkoutPlan? get adaptiveWorkoutPlan => _adaptiveWorkoutPlan;
  RecommendedWorkout? get todaysRecommendation => _todaysRecommendation;

  List<WorkoutFeedback> get workoutFeedbackHistory =>
      List.unmodifiable(_workoutFeedbackHistory);

  RecoveryState? get recoveryState => _recoveryState;

  Subscription get subscription => _subscription;
  bool get isPremium => _subscription.isPremium;

  bool canAccessFeature(PremiumFeature feature) {
    return _subscriptionService.canAccess(feature, _subscription);
  }

  Future<void> purchaseSubscription(String productId) async {
    _subscription = await _subscriptionService.purchasePlan(
      productId,
      userId: currentUser?.id ?? 'usr_local',
    );
    notifyListeners();
  }

  /// UserXP Profile (Gamification 2.0)
  UserXP get userXP =>
      _userXP ?? _xpService.getUserXP(userId: currentUser?.id ?? 'usr_local');
  XPService get xpService => _xpService;

  /// Add XP to current user progress reactively
  Future<void> addXP(int amount) async {
    final userId = currentUser?.id ?? 'usr_local';
    _userXP = await _xpService.awardXP(
      userId: userId,
      amount: amount,
      source: 'manual_bonus',
    );
    _userProgress = _gamificationService.getProgress();
    await _syncUserLeaderboardEntry();
    notifyListeners();
  }

  /// Award XP for completing workout session (+100 XP base, +250 per PR, +50 per streak day)
  Future<UserXP> awardWorkoutXP({int streakDays = 0, int prCount = 0}) async {
    final userId = currentUser?.id ?? 'usr_local';
    final result = await _xpService.awardWorkoutXP(
      userId: userId,
      streakDays: streakDays,
      prCount: prCount,
    );
    _userXP = result;
    _userProgress = _gamificationService.getProgress();
    await _syncUserLeaderboardEntry();
    notifyListeners();
    return result;
  }

  /// Award XP for personal records (+250 XP per PR)
  Future<UserXP> awardPersonalRecordXP({int count = 1}) async {
    final userId = currentUser?.id ?? 'usr_local';
    final result = await _xpService.awardPersonalRecordXP(
      userId: userId,
      count: count,
    );
    _userXP = result;
    _userProgress = _gamificationService.getProgress();
    await _syncUserLeaderboardEntry();
    notifyListeners();
    return result;
  }

  /// Award XP for workout streak (+50 XP per day)
  Future<UserXP> awardStreakXP({required int streakDays}) async {
    final userId = currentUser?.id ?? 'usr_local';
    final result = await _xpService.awardStreakXP(
      userId: userId,
      streakDays: streakDays,
    );
    _userXP = result;
    _userProgress = _gamificationService.getProgress();
    await _syncUserLeaderboardEntry();
    notifyListeners();
    return result;
  }

  /// Award XP for logging daily meal / nutrition (+20 XP)
  Future<UserXP> awardMealLogXP() async {
    final userId = currentUser?.id ?? 'usr_local';
    final result = await _xpService.awardMealLogXP(userId: userId);
    _userXP = result;
    _userProgress = _gamificationService.getProgress();
    await _syncUserLeaderboardEntry();
    notifyListeners();
    return result;
  }

  /// Award XP for community engagement (+30 XP)
  Future<UserXP> awardCommunityXP({String activityType = 'post'}) async {
    final userId = currentUser?.id ?? 'usr_local';
    final result = await _xpService.awardCommunityXP(
      userId: userId,
      activityType: activityType,
    );
    _userXP = result;
    _userProgress = _gamificationService.getProgress();
    await _syncUserLeaderboardEntry();
    notifyListeners();
    return result;
  }

  /// Award XP for challenge completion (+500 XP)
  Future<UserXP> awardChallengeXP({String? challengeId}) async {
    final userId = currentUser?.id ?? 'usr_local';
    final result = await _xpService.awardChallengeXP(
      userId: userId,
      challengeId: challengeId,
    );
    _userXP = result;
    _userProgress = _gamificationService.getProgress();
    await _syncUserLeaderboardEntry();
    notifyListeners();
    return result;
  }

  /// Award custom XP amount
  Future<UserXP> awardCustomXP({
    required int amount,
    required String source,
  }) async {
    final userId = currentUser?.id ?? 'usr_local';
    final result = await _xpService.awardXP(
      userId: userId,
      amount: amount,
      source: source,
    );
    _userXP = result;
    _userProgress = _gamificationService.getProgress();
    await _syncUserLeaderboardEntry();
    notifyListeners();
    return result;
  }

  /// Refresh user XP from storage
  void refreshUserXP({bool notify = true}) {
    final userId = currentUser?.id ?? 'usr_local';
    _userXP = _xpService.getUserXP(userId: userId);
    if (notify) {
      notifyListeners();
    }
  }

  /// The coach chat service in use (the shared one unless one was injected).
  CoachChatService get coachChatService => _coachChatService;

  /// Phase C.2 — Health Prediction & Adaptive Recovery AI
  RecoveryReport? get latestRecoveryReport => _latestRecoveryReport;
  HealthMetrics? get todayHealthMetrics => _todayHealthMetrics;
  TrainingLoadEngine get trainingLoadEngine => _trainingLoadEngine;
  RecoveryPredictionEngine get recoveryPredictionEngine =>
      _recoveryPredictionEngine;
  HealthPredictionEngine get healthPredictionEngine => _healthPredictionEngine;
  UniversalWearableManager get wearableManager => _wearableManager;

  Future<RecoveryReport> evaluateTrainingReadiness({
    DateTime? referenceDate,
  }) async {
    final userId = currentUser?.id ?? 'usr_local';
    final report = await _healthPredictionEngine.predictRecoveryAndReadiness(
      userId: userId,
      workoutHistory: _workoutHistory,
      healthMetrics: _metricsForRecovery(
        _todayHealthMetrics ??
            LocalStorage.getTodayHealthMetrics(userId: userId),
      ),
      todayNutrition: _todayNutritionWithLogged,
      referenceDate: referenceDate,
    );

    _latestRecoveryReport = report;
    await LocalStorage.saveRecoveryReport(report);
    notifyListeners();
    return report;
  }

  Future<HealthMetrics?> syncWearableHealthData({
    WearablePlatform? platform,
  }) async {
    final userId = currentUser?.id ?? 'usr_local';
    if (platform != null) {
      _wearableManager.setActivePlatform(platform);
    }
    final metric = await _wearableManager.syncActiveDevice(userId: userId);
    if (metric != null) {
      _todayHealthMetrics = metric;
      await LocalStorage.saveHealthMetrics(metric);
      await evaluateTrainingReadiness();
    }
    notifyListeners();
    return metric;
  }

  Future<void> saveTodayHealthMetrics(HealthMetrics metric) async {
    _todayHealthMetrics = metric;
    await LocalStorage.saveHealthMetrics(metric);
    await evaluateTrainingReadiness();
    notifyListeners();
  }

  /// AI Decision Engine, Goal Adaptation, Weekly Review & Smart Notifications (Phase 7)
  AIDecisionEngine get aiDecisionEngine => _aiDecisionEngine;
  GoalAdaptationEngine get goalAdaptationEngine => _goalAdaptationEngine;
  WeeklyCoachReviewService get weeklyCoachReviewService =>
      _weeklyCoachReviewService;
  CoachNotificationService get coachNotificationService =>
      _coachNotificationService;
  WeeklyCoachReview? get weeklyCoachReview => _weeklyCoachReview;
  AIDecisionReport? get lastDecisionReport => _lastDecisionReport;

  AIDecisionReport evaluateAIDecisions() {
    final report = _aiDecisionEngine.evaluate(
      workoutHistory: _workoutHistory,
      recovery: dailyCoachBrief.recovery,
      todayNutrition: _todayNutritionWithLogged,
      recentHealthMetrics: LocalStorage.getHealthHistory(),
      goal:
          _currentGoal?.goalType.name ?? _profile?.fitnessGoal ?? 'hypertrophy',
    );
    _lastDecisionReport = report;
    notifyListeners();
    return report;
  }

  GoalAdaptationReport evaluateGoalAdaptation({
    String? goalType,
    required double startWeight,
    required double currentWeight,
    required double targetWeight,
    required int weeksElapsed,
    int plateauWeeks = 0,
    bool hasStrengthPlateau = false,
  }) {
    final report = _goalAdaptationEngine.evaluate(
      goalType:
          goalType ??
          _currentGoal?.goalType.name ??
          _profile?.fitnessGoal ??
          'hypertrophy',
      startWeight: startWeight,
      currentWeight: currentWeight,
      targetWeight: targetWeight,
      weeksElapsed: weeksElapsed,
      consecutivePlateauWeeks: plateauWeeks,
      hasStrengthPlateau: hasStrengthPlateau,
    );
    notifyListeners();
    return report;
  }

  WeeklyCoachReview generateWeeklyCoachReview() {
    final review = _weeklyCoachReviewService.generateReview(
      workoutHistory: _workoutHistory,
      // Showcase mode reviews the demo day, not the athlete's own history.
      nutritionHistory: LocalStorage.isShowcaseModeEnabled()
          ? [todayNutrition]
          : LocalStorage.getNutritionHistory(),
      healthMetrics: LocalStorage.getHealthHistory(),
      currentRecovery: dailyCoachBrief.recovery,
      currentWeight: double.tryParse(_profile?.weight ?? '75.0'),
    );
    _weeklyCoachReview = review;
    notifyListeners();
    return review;
  }

  List<CoachSmartNotification> getCoachNotifications() {
    return _coachNotificationService.generateDailyNotifications(
      recovery: dailyCoachBrief.recovery,
      workout: dailyCoachBrief.workout,
      todayNutrition: _todayNutritionWithLogged,
    );
  }

  Future<void> restoreSubscriptionPurchases() async {
    _subscription = await _subscriptionService.restorePurchases(
      userId: currentUser?.id ?? 'usr_local',
    );
    notifyListeners();
  }

  Future<void> cancelUserSubscription() async {
    _subscription = await _subscriptionService.cancelSubscription(
      userId: currentUser?.id ?? 'usr_local',
    );
    notifyListeners();
  }

  Future<void> refreshSubscription() async {
    _subscription = await _subscriptionService.getSubscription(
      userId: currentUser?.id ?? 'usr_local',
    );
    notifyListeners();
  }

  UserRole get userRole => _userRole;
  bool get isTrainer => _userRole.isTrainer;
  bool get isAdmin => _userRole.isAdmin;

  Future<void> setUserRole(UserRole role) async {
    _userRole = role;
    await LocalStorage.saveUserRole(role);
    notifyListeners();
  }

  List<ConnectedDevice> get connectedDevices {
    if (_connectedDevices.isEmpty) {
      _connectedDevices = _healthSyncService.getConnectedDevices();
    }
    return List.unmodifiable(_connectedDevices);
  }

  Map<String, dynamic> get challengeSummary {
    final completedCount = _userChallenges.where((uc) => uc.completed).length;
    final totalCount = _activeChallenges.length;
    int claimableXP = 0;

    for (final uc in _userChallenges) {
      if (uc.completed && !uc.rewardClaimed) {
        final ch = _activeChallenges.firstWhere(
          (c) => c.id == uc.challengeId,
          orElse: () => Challenge(
            id: uc.challengeId,
            title: '',
            description: '',
            category: 'training',
            targetValue: 1.0,
            rewardXP: 0,
            startDate: DateTime.now(),
            endDate: DateTime.now(),
          ),
        );
        claimableXP += ch.rewardXP;
      }
    }

    return {
      'completedCount': completedCount,
      'totalCount': totalCount,
      'claimableXP': claimableXP,
    };
  }

  FitnessProvider._({
    WorkoutService? workoutService,
    NutritionService? nutritionService,
    ProfileProvider? profileProvider,
    GamificationService? gamificationService,
    ChallengeService? challengeService,
    NutritionGamificationService? nutritionGamificationService,
    GoalRepository? goalRepository,
    RecommendationService? recommendationService,
    CoachChatService? coachChatService,
    DailyBriefService? dailyBriefService,
    DailyCoachBriefService? dailyCoachBriefService,
    AuthRepository? authRepository,
    LeaderboardService? leaderboardService,
    NotificationService? notificationService,
    SocialService? socialService,
    SeasonService? seasonService,
    HealthSyncService? healthSyncService,
    TrainingIntelligenceService? trainingIntelligenceService,
    WorkoutPlannerService? workoutPlannerService,
    WorkoutAdaptationService? workoutAdaptationService,
    RecoveryIntelligenceService? recoveryIntelligenceService,
    XPService? xpService,
    AIDecisionEngine? aiDecisionEngine,
    GoalAdaptationEngine? goalAdaptationEngine,
    WeeklyCoachReviewService? weeklyCoachReviewService,
    CoachNotificationService? coachNotificationService,
    TransformationService? transformationService,
    TrainingLoadEngine? trainingLoadEngine,
    RecoveryPredictionEngine? recoveryPredictionEngine,
    HealthPredictionEngine? healthPredictionEngine,
    UniversalWearableManager? wearableManager,
  }) : _workoutService =
           workoutService ?? AppDependencies.instance.workoutService,
       _nutritionService =
           nutritionService ?? AppDependencies.instance.nutritionService,
       _profileProvider =
           profileProvider ?? AppDependencies.instance.profileProvider,
       _gamificationService = gamificationService ?? GamificationService(),
       _challengeService = challengeService ?? ChallengeService.instance,
       _nutritionGamificationService =
           nutritionGamificationService ?? NutritionGamificationService(),
       _goalRepository =
           goalRepository ?? AppDependencies.instance.goalRepository,
       _recommendationService =
           recommendationService ?? const RecommendationService(),
       _coachChatService =
           coachChatService ?? AppDependencies.instance.coachChatService,
       _dailyBriefService = dailyBriefService ?? const DailyBriefService(),
       _dailyCoachBriefService =
           dailyCoachBriefService ?? DailyCoachBriefService(),
       _authRepository =
           authRepository ??
           (CloudSession.client != null
               ? CloudAuthRepository()
               : AuthAvailability.isReleaseBuild
               ? UnavailableAuthRepository()
               : LocalAuthRepository()),
       _leaderboardService = leaderboardService ?? LeaderboardService(),
       _notificationService = notificationService ?? NotificationService(),
       _socialService = socialService ?? SocialService(),
       _seasonService = seasonService ?? SeasonService(),
       _healthSyncService = healthSyncService ?? HealthSyncService(),
       _trainingIntelligenceService =
           trainingIntelligenceService ?? TrainingIntelligenceService(),
       _workoutPlannerService =
           workoutPlannerService ?? WorkoutPlannerService(),
       _workoutAdaptationService =
           workoutAdaptationService ?? WorkoutAdaptationService(),
       _recoveryIntelligenceService =
           recoveryIntelligenceService ?? RecoveryIntelligenceService(),
       _xpService = xpService ?? XPService.instance,
       _aiDecisionEngine = aiDecisionEngine ?? AIDecisionEngine.instance,
       _goalAdaptationEngine =
           goalAdaptationEngine ?? GoalAdaptationEngine.instance,
       _weeklyCoachReviewService =
           weeklyCoachReviewService ?? WeeklyCoachReviewService.instance,
       _coachNotificationService =
           coachNotificationService ?? CoachNotificationService.instance,
       _transformationService =
           transformationService ?? TransformationService.instance,
       _trainingLoadEngine = trainingLoadEngine ?? const TrainingLoadEngine(),
       _recoveryPredictionEngine =
           recoveryPredictionEngine ?? const RecoveryPredictionEngine(),
       _healthPredictionEngine =
           healthPredictionEngine ?? HealthPredictionEngine(),
       _wearableManager = wearableManager ?? UniversalWearableManager.instance {
    _init();
  }

  /// Factory singleton constructor
  factory FitnessProvider({
    WorkoutService? workoutService,
    NutritionService? nutritionService,
    ProfileProvider? profileProvider,
    GamificationService? gamificationService,
    NutritionGamificationService? nutritionGamificationService,
    GoalRepository? goalRepository,
    RecommendationService? recommendationService,
    DailyCoachBriefService? dailyCoachBriefService,
    LeaderboardService? leaderboardService,
    NotificationService? notificationService,
    SocialService? socialService,
    SeasonService? seasonService,
    HealthSyncService? healthSyncService,
    TrainingIntelligenceService? trainingIntelligenceService,
    WorkoutPlannerService? workoutPlannerService,
    WorkoutAdaptationService? workoutAdaptationService,
    RecoveryIntelligenceService? recoveryIntelligenceService,
    XPService? xpService,
    AIDecisionEngine? aiDecisionEngine,
    GoalAdaptationEngine? goalAdaptationEngine,
    WeeklyCoachReviewService? weeklyCoachReviewService,
    CoachNotificationService? coachNotificationService,
    TransformationService? transformationService,
    TrainingLoadEngine? trainingLoadEngine,
    RecoveryPredictionEngine? recoveryPredictionEngine,
    HealthPredictionEngine? healthPredictionEngine,
    UniversalWearableManager? wearableManager,
    AuthRepository? authRepository,
    CoachChatService? coachChatService,
  }) {
    _instance ??= FitnessProvider._(
      coachChatService: coachChatService,
      workoutService: workoutService,
      nutritionService: nutritionService,
      profileProvider: profileProvider,
      gamificationService: gamificationService,
      nutritionGamificationService: nutritionGamificationService,
      goalRepository: goalRepository,
      recommendationService: recommendationService,
      dailyCoachBriefService: dailyCoachBriefService,
      leaderboardService: leaderboardService,
      notificationService: notificationService,
      socialService: socialService,
      seasonService: seasonService,
      healthSyncService: healthSyncService,
      trainingIntelligenceService: trainingIntelligenceService,
      workoutPlannerService: workoutPlannerService,
      workoutAdaptationService: workoutAdaptationService,
      recoveryIntelligenceService: recoveryIntelligenceService,
      xpService: xpService,
      authRepository: authRepository,
      aiDecisionEngine: aiDecisionEngine,
      goalAdaptationEngine: goalAdaptationEngine,
      weeklyCoachReviewService: weeklyCoachReviewService,
      coachNotificationService: coachNotificationService,
      transformationService: transformationService,
      trainingLoadEngine: trainingLoadEngine,
      recoveryPredictionEngine: recoveryPredictionEngine,
      healthPredictionEngine: healthPredictionEngine,
      wearableManager: wearableManager,
    );
    return _instance!;
  }

  /// Load leaderboard entries from LeaderboardService.
  Future<void> loadLeaderboard() async {
    _isLeaderboardLoading = true;
    _leaderboardError = null;
    notifyListeners();

    try {
      await _syncUserLeaderboardEntry();

      _globalLeaderboard = await _leaderboardService.getGlobalLeaderboard();
      _localLeaderboard = await _leaderboardService.getLocalLeaderboard();
      _friendsLeaderboard = await _leaderboardService.getFriendsLeaderboard(
        userId: currentUser?.id ?? 'usr_local',
      );
      _isLeaderboardLoading = false;
      notifyListeners();
    } catch (e) {
      _isLeaderboardLoading = false;
      _leaderboardError = e.toString();
      notifyListeners();
    }
  }

  /// Refresh leaderboard datasets.
  Future<void> refreshLeaderboard() async {
    await loadLeaderboard();
  }

  /// Load weekly challenges and user challenge progress.
  Future<void> loadChallenges() async {
    _isChallengesLoading = true;
    _challengesError = null;
    notifyListeners();

    try {
      final userId = currentUser?.id ?? 'usr_local';
      _activeChallenges = await _challengeService.getActiveChallenges();
      _userChallenges = await _challengeService.getUserChallenges(
        userId: userId,
      );
      _isChallengesLoading = false;
      notifyListeners();
    } catch (e) {
      _isChallengesLoading = false;
      _challengesError = e.toString();
      notifyListeners();
    }
  }

  /// Force refresh challenges dataset.
  Future<void> refreshChallenges() async {
    await loadChallenges();
  }

  /// Claim XP reward for a completed challenge.
  Future<bool> claimChallengeReward(String challengeId) async {
    try {
      final userId = currentUser?.id ?? 'usr_local';
      final updatedUC = await _challengeService.claimReward(
        challengeId,
        userId: userId,
      );
      if (updatedUC != null) {
        final ch = _activeChallenges.firstWhere(
          (c) => c.id == challengeId,
          orElse: () => Challenge(
            id: challengeId,
            title: '',
            description: '',
            category: 'training',
            targetValue: 1.0,
            rewardXP: 100,
            startDate: DateTime.now(),
            endDate: DateTime.now(),
          ),
        );

        // Reward XP via existing GamificationService.addXP pipeline
        final currentProgress = userProgress;
        _userProgress = _gamificationService.addXP(
          ch.rewardXP,
          currentProgress,
        );
        await LocalStorage.saveUserProgress(_userProgress!);

        if (_currentSeason != null && ch.rewardXP > 0) {
          _seasonProgress = await _seasonService.addSeasonXP(
            seasonId: _currentSeason!.id,
            userId: currentUser?.id ?? 'usr_local',
            amount: ch.rewardXP,
          );
          await refreshSeasonLeaderboard();
        }

        await _socialService.createActivity(
          ActivityItem(
            id: 'act_ch_${DateTime.now().millisecondsSinceEpoch}',
            userId: currentUser?.id ?? 'usr_local',
            type: 'challenge',
            title: '${profile.name} completed Weekly Quest!',
            description:
                'Finished "${ch.title}" and claimed +${ch.rewardXP} XP',
            createdAt: DateTime.now(),
          ),
        );

        await loadChallenges();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Sync current user progress entry with remote leaderboard.
  Future<void> _syncUserLeaderboardEntry() async {
    try {
      final user = currentUser;
      final entry = LeaderboardEntry(
        id: 'lb_${user?.id ?? "local"}',
        userId: user?.id ?? 'usr_local',
        displayName: profile.name,
        avatarUrl: profile.profilePic,
        totalXP: totalXP,
        rankTitle: fullRank,
        division: currentDivision,
        country: 'India',
        updatedAt: DateTime.now(),
      );
      await _leaderboardService.updateLeaderboardEntry(entry);
    } catch (_) {}
  }

  /// Load system notifications for the current user.
  Future<void> loadNotifications() async {
    final userId = currentUser?.id ?? 'usr_local';
    _notifications = await _notificationService.getNotifications(
      userId: userId,
    );
    notifyListeners();
  }

  /// Mark specific notification as read.
  Future<void> markNotificationRead(String id) async {
    final userId = currentUser?.id ?? 'usr_local';
    await _notificationService.markAsRead(id, userId: userId);
    await loadNotifications();
  }

  /// Clear all notifications for the current user.
  Future<void> clearNotifications() async {
    final userId = currentUser?.id ?? 'usr_local';
    await _notificationService.clearNotifications(userId: userId);
    await loadNotifications();
  }

  /// Load friends list and pending friend requests.
  Future<void> loadFriends() async {
    final userId = currentUser?.id ?? 'usr_local';
    _friends = await _socialService.getFriends(userId: userId);
    _friendRequests = await _socialService.getPendingRequests(userId: userId);
    notifyListeners();
  }

  /// Send friend request to another user.
  Future<void> sendFriendRequest(String targetUserId) async {
    final userId = currentUser?.id ?? 'usr_local';
    await _socialService.sendFriendRequest(
      requesterId: userId,
      receiverId: targetUserId,
    );
    await _notificationService.createNotification(
      NotificationItem(
        id: 'notif_fr_req_${DateTime.now().millisecondsSinceEpoch}',
        userId: targetUserId,
        title: 'Friend Request 🤝',
        message: '${profile.name} sent you a friend request.',
        type: 'friend',
        createdAt: DateTime.now(),
        actionRoute: '/friends',
      ),
    );
    await loadFriends();
  }

  /// Accept incoming friend request.
  Future<void> acceptFriendRequest(String friendshipId) async {
    final userId = currentUser?.id ?? 'usr_local';
    await _socialService.acceptFriendRequest(
      friendshipId: friendshipId,
      userId: userId,
    );
    await _notificationService.createNotification(
      NotificationItem(
        id: 'notif_fr_acc_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        title: 'Friend Request Accepted 🎉',
        message: 'You are now connected with a workout partner.',
        type: 'friend',
        createdAt: DateTime.now(),
        actionRoute: '/friends',
      ),
    );
    await loadFriends();
  }

  /// Load global/friends activity feed.
  Future<void> loadActivityFeed() async {
    _activityFeed = await _socialService.getActivityFeed();
    notifyListeners();
  }

  /// Load active competitive season and current user's season progress.
  Future<void> loadSeason() async {
    _currentSeason = await _seasonService.getCurrentSeason();
    if (_currentSeason != null) {
      final userId = currentUser?.id ?? 'usr_local';
      _seasonProgress = await _seasonService.getSeasonProgress(
        seasonId: _currentSeason!.id,
        userId: userId,
      );
      await refreshSeasonLeaderboard();
    }
    notifyListeners();
  }

  /// Refresh seasonal leaderboard.
  Future<void> refreshSeasonLeaderboard() async {
    if (_currentSeason != null) {
      _seasonLeaderboard = await _seasonService.getSeasonLeaderboard(
        _currentSeason!.id,
      );
      notifyListeners();
    }
  }

  /// Connect a wearable device, trigger authorization, update device list, and sync health metrics.
  Future<void> connectWearableDevice(ConnectedDevice device) async {
    _connectedDevices = await _healthSyncService.connectDevice(device);
    await syncHealthData();
  }

  /// Disconnect a wearable device, update device list, and sync.
  Future<void> disconnectWearableDevice(String deviceId) async {
    _connectedDevices = await _healthSyncService.disconnectDevice(deviceId);
    await syncHealthData();
  }

  /// Synchronize health metrics from active HealthProvider, calculate recovery score, and trigger intelligence pipeline updates.
  Future<void> syncHealthData() async {
    final metrics = await _healthSyncService.fetchTodayMetrics();
    if (metrics != null) {
      _healthMetrics = metrics;
      // 0 means no score: the store reported nothing the score is built from.
      _recoveryScore = _healthSyncService.calculateRecoveryScore(metrics) ?? 0;
      await refreshTrainingIntelligence();
      refreshDailyBrief(notify: false);
      notifyListeners();
    }
  }

  /// Health metrics for recovery calculations: the health-store reading, plus
  /// last night's sleep when the user logged it (or a watch synced it) as a
  /// sleep record. A sleep record older than 36 hours is not "last night".
  /// Nothing is filled in: a value that no source recorded stays null.
  HealthMetrics? _metricsForRecovery(HealthMetrics? base) {
    final sleep = _latestSleep;
    final recent =
        sleep != null &&
        sleep.durationMinutes > 0 &&
        DateTime.now().difference(sleep.wakeTime).inHours.abs() <= 36;
    if (!recent) return base;
    final hours = sleep.durationHours;
    if (base == null) {
      return HealthMetrics(
        id: 'sleep_${sleep.id}',
        sleepHours: hours,
        restingHeartRate: sleep.restingHeartRate,
        hrv: sleep.hrv,
        sourceDevice: 'Sleep log',
      );
    }
    return base.copyWith(
      sleepHours: base.sleepHours ?? hours,
      restingHeartRate: base.restingHeartRate ?? sleep.restingHeartRate,
      heartRateVariability: base.heartRateVariability ?? sleep.hrv,
    );
  }

  /// Refresh training state, fatigue score, and readiness intelligence.
  Future<void> refreshTrainingIntelligence() async {
    _trainingState = _trainingIntelligenceService.analyzeTrainingState(
      workouts: _workoutHistory,
      healthMetrics: _metricsForRecovery(_healthMetrics),
      recoveryScore: _recoveryScore,
    );
    await refreshRecoveryIntelligence(notify: false);
    await refreshWorkoutRecommendation();
  }

  /// Refresh recovery & deload intelligence analysis.
  Future<void> refreshRecoveryIntelligence({bool notify = true}) async {
    _recoveryState = _recoveryIntelligenceService.analyzeRecoveryState(
      healthMetrics: _metricsForRecovery(_healthMetrics),
      trainingState: _trainingState,
      workouts: _workoutHistory,
      feedbackHistory: _workoutFeedbackHistory,
      customRecoveryScore: _recoveryScore > 0 ? _recoveryScore : null,
    );
    if (notify) {
      notifyListeners();
    }
  }

  /// Generate full adaptive workout plan tailored to user goal and readiness state.
  Future<void> generateWorkoutPlan({bool notify = true}) async {
    _adaptiveWorkoutPlan = _workoutPlannerService.generatePlan(
      goal: _currentGoal,
      trainingState: _trainingState,
      workoutHistory: _workoutHistory,
    );
    await refreshWorkoutRecommendation(notify: notify);
  }

  /// Refresh daily recommended workout session.
  Future<void> refreshWorkoutRecommendation({bool notify = true}) async {
    _todaysRecommendation = _workoutPlannerService.getTodayRecommendation(
      goal: _currentGoal,
      trainingState: _trainingState,
      workoutHistory: _workoutHistory,
    );
    if (notify) {
      notifyListeners();
    }
  }

  /// Submit user workout feedback and trigger adaptive load recalculations.
  Future<void> submitWorkoutFeedback(WorkoutFeedback feedback) async {
    _workoutFeedbackHistory.insert(0, feedback);
    await refreshWorkoutAdaptation();
    await refreshRecoveryIntelligence();
  }

  /// Refresh workout adaptations and update recommendations based on feedback history.
  Future<void> refreshWorkoutAdaptation({bool notify = true}) async {
    _workoutAdaptationService.calculateProgressionFactor(
      _workoutFeedbackHistory,
    );
    await refreshWorkoutRecommendation(notify: false);
    if (notify) {
      notifyListeners();
    }
  }

  /// Reset singleton for testing purposes
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  /// Global singleton instance
  static FitnessProvider get instance {
    _instance ??= FitnessProvider._();
    return _instance!;
  }

  void _init() {
    _profileProvider.addListener(_onProfileChanged);
    // The nutrition service reports its saves here instead of calling us.
    NutritionChanges.instance.addListener(refreshNutrition);
    // Likewise for saved workout completions.
    WorkoutChanges.instance.addListener(refreshWorkoutHistory);
    // Referral and friend-challenge XP is awarded through us so the screen
    // state refreshes with it.
    BonusXp.awarder = addXP;
    _reloadAllData();
  }

  void _onProfileChanged() {
    _profile = _profileProvider.userProfile;
    notifyListeners();
  }

  Future<void> onShowcaseModeToggled(bool isEnabled) async {
    // Whatever was done in Showcase (chat, foods logged from a scan) belongs to
    // that demo only: drop it when Showcase starts or ends, so nothing is
    // carried into the other mode.
    await LocalStorage.clearShowcaseCoachMessages();
    _showcaseLoggedFoods.clear();
    _reloadAllData();
    notifyListeners();
  }

  void _reloadAllData() {
    if (LocalStorage.isShowcaseModeEnabled()) {
      final showcase = ShowcaseDataProvider.instance;
      _workoutHistory = showcase.getShowcaseWorkoutHistory();
      _todayNutrition = showcase.getShowcaseDailyNutrition();
      _profile = showcase.getShowcaseUserProfile();
      _userProgress = showcase.getShowcaseUserProgress();
      _trainingState = showcase.getShowcaseTrainingState();
      _recoveryState = showcase.getShowcaseRecoveryState();
      _todayHealthMetrics = showcase.getShowcaseHealthMetrics();
      _sleepHistory = showcase.getShowcaseSleepHistory();
      _latestSleep = showcase.getShowcaseLatestSleep();
      _recoveryInsight = showcase.getShowcaseRecoveryInsight();
      _recoveryScore = 88;
      _userXP = UserXP(
        userId: 'usr_showcase_athlete',
        totalXP: 14850,
        currentLevel: UserXP.calculateLevel(14850),
        weeklyXP: 1850,
        monthlyXP: 6400,
        lastUpdated: DateTime.now(),
      );
      _currentGoal = showcase.getShowcaseFitnessContext().userGoal;
      _coachMessages = showcase.getShowcaseAIConversations();
      _recommendations = showcase.getShowcaseRecommendations();
      _currentUser = AppUser(
        id: 'usr_showcase_athlete',
        email: 'alex.rivera@atlasfit.ai',
        displayName: 'Alex Rivera',
      );
      _subscription = Subscription(
        id: 'sub_showcase',
        userId: 'usr_showcase_athlete',
        tier: SubscriptionTier.annual,
        status: SubscriptionStatus.active,
        startDate: DateTime.now(),
        productIdentifier: 'annual_pro',
      );
      _userRole = UserRole.member;
      _recalculateAnalytics();
      refreshDailyBrief(notify: false);
      return;
    }

    _workoutHistory = _workoutService.getWorkoutHistory();
    _todayNutrition = _nutritionService.getDailyNutrition();
    _profile = _profileProvider.userProfile;
    _userProgress = _gamificationService.getProgress();
    _userXP = _xpService.getUserXP(userId: _currentUser?.id);
    _currentGoal = _goalRepository.getGoal();
    _coachMessages = _coachChatService.getMessages();
    _currentUser = _authRepository.currentUser;
    _subscription = LocalStorage.getSubscription(
      userId: _currentUser?.id ?? 'usr_local',
    );
    _userRole = LocalStorage.getUserRole();
    _latestRecoveryReport = LocalStorage.getLatestRecoveryReport(
      userId: _currentUser?.id,
    );
    _todayHealthMetrics = LocalStorage.getTodayHealthMetrics(
      userId: _currentUser?.id,
    );

    // Sleep & Recovery Telemetry Integration
    _sleepHistory = LocalStorage.getSleepRecords(userId: _currentUser?.id);
    _latestSleep = _sleepHistory.isNotEmpty ? _sleepHistory.first : null;
    if (_latestSleep != null) {
      _recoveryInsight = RecoveryInsight.fromTelemetry(
        latestSleep: _latestSleep,
        history: _sleepHistory,
        restingHeartRate: _latestSleep?.restingHeartRate,
        hrv: _latestSleep?.hrv,
        source: _latestSleep?.source ?? HealthDataSource.manual,
      );
    } else {
      _recoveryInsight = RecoveryInsight.insufficientData();
    }

    if (_workoutHistory.isEmpty &&
        _todayHealthMetrics == null &&
        _latestRecoveryReport == null) {
      _trainingState = null;
      _recoveryState = null;
      _recoveryScore = 0;
    } else {
      _recoveryScore =
          _latestRecoveryReport?.readinessScore.score.round() ?? 80;
      _trainingState = _trainingIntelligenceService.analyzeTrainingState(
        workouts: _workoutHistory,
        healthMetrics: _metricsForRecovery(_todayHealthMetrics),
        recoveryScore: _recoveryScore,
      );
      _recoveryState = _recoveryIntelligenceService.analyzeRecoveryState(
        healthMetrics: _metricsForRecovery(_todayHealthMetrics),
        trainingState: _trainingState,
        workouts: _workoutHistory,
        feedbackHistory: _workoutFeedbackHistory,
        customRecoveryScore: _recoveryScore,
      );
    }

    _recalculateAnalytics();
    refreshDailyBrief(notify: false);
  }

  /// Manually logs a sleep record and immediately updates sleep and recovery insights
  Future<void> logSleep(SleepRecord record) async {
    await LocalStorage.saveSleepRecord(record);
    _sleepHistory = LocalStorage.getSleepRecords(userId: _currentUser?.id);
    _latestSleep = _sleepHistory.isNotEmpty ? _sleepHistory.first : null;
    if (_latestSleep != null) {
      _recoveryInsight = RecoveryInsight.fromTelemetry(
        latestSleep: _latestSleep,
        history: _sleepHistory,
        restingHeartRate: _latestSleep?.restingHeartRate,
        hrv: _latestSleep?.hrv,
        source: _latestSleep?.source ?? HealthDataSource.manual,
      );
    }
    notifyListeners();
  }

  final WorkoutAnalyticsService _analyticsService =
      WorkoutAnalyticsService.instance;
  final ProgressSummaryService _progressSummaryService =
      ProgressSummaryService.instance;
  final ProgressAnalyticsEngine _progressAnalyticsEngine =
      ProgressAnalyticsEngine.instance;

  VolumeAnalytics? _cachedVolumeAnalytics;
  ConsistencyAnalytics? _cachedConsistencyAnalytics;
  List<StrengthProgression>? _cachedStrengthProgressions;
  Map<String, double>? _cachedMuscleGroupDistribution;
  PersonalRecordSummary? _cachedPersonalRecordsSummary;
  ProgressSummary? _cachedProgressSummary;
  AthleteAnalyticsReport? _cachedAthleteAnalytics;

  void _recalculateAnalytics() {
    _cachedVolumeAnalytics = _analyticsService.calculateVolume(_workoutHistory);
    _cachedConsistencyAnalytics = _analyticsService.calculateConsistency(
      _workoutHistory,
      workoutStreak,
    );
    _cachedStrengthProgressions = _analyticsService
        .calculateStrengthProgression(_workoutHistory);
    _cachedMuscleGroupDistribution = _analyticsService
        .calculateMuscleGroupDistribution(_workoutHistory);
    _cachedPersonalRecordsSummary = _analyticsService.calculatePersonalRecords(
      _workoutHistory,
    );
    _cachedProgressSummary = _progressSummaryService.generateSummary(
      history: _workoutHistory,
      userProgress: userProgress,
      streakData: streakData,
    );
    _cachedAthleteAnalytics = _progressAnalyticsEngine.generateAthleteReport(
      sessions: _workoutService.getWorkoutSessions(),
      history: _workoutHistory,
      bodyWeight:
          double.tryParse(
            (_profile?.weight ?? '75').replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          75.0,
      targetWorkoutsPerWeek: _currentGoal?.fitnessLevel == FitnessLevel.advanced
          ? 5
          : 4,
    );
  }

  // --- Reactive Getters ---

  List<WorkoutHistory> get workoutHistory => List.unmodifiable(_workoutHistory);

  DailyNutrition get todayNutrition {
    _todayNutrition ??= _nutritionService.getDailyNutrition();
    return _todayNutrition!;
  }

  /// [_todayNutrition] with today's logged food counted as consumed, for the
  /// engines that read consumed amounts from a [DailyNutrition]. Read-only
  /// view: it is never saved.
  DailyNutrition? get _todayNutritionWithLogged =>
      LocalStorage.isShowcaseModeEnabled()
      ? _todayNutrition
      : _todayNutrition?.withLogged(todayConsumed);

  UserProfile get profile {
    _profile ??= _profileProvider.userProfile;
    return _profile!;
  }

  UserProgress get userProgress {
    _userProgress ??= _gamificationService.getProgress();
    return _userProgress!;
  }

  UserGoal? get currentGoal => _currentGoal ?? _goalRepository.getGoal();

  int get totalXP => userProgress.totalXP;
  bool get rankedUnlocked => userProgress.rankedUnlocked;
  String get currentRank => userProgress.currentRank;
  String get currentDivision => userProgress.currentDivision;
  String get fullRank => userProgress.fullRank;
  final WorkoutStreakService _workoutStreakService =
      const WorkoutStreakService();
  WorkoutStreakService get workoutStreakService => _workoutStreakService;

  int get workoutStreak => streakData.currentStreak;
  int get nutritionStreak => userProgress.nutritionStreak;
  NutritionProgress get nutritionProgress =>
      _nutritionGamificationService.getNutritionProgress();
  StreakData get streakData {
    if (_workoutHistory.isNotEmpty) {
      final calculated = _workoutStreakService.calculateStreak(_workoutHistory);
      return StreakData(
        currentStreak: calculated.currentStreak,
        longestStreak: calculated.longestStreak > userProgress.longestStreak
            ? calculated.longestStreak
            : userProgress.longestStreak,
        lastWorkoutDate:
            calculated.lastWorkoutDate ?? userProgress.lastWorkoutDate,
      );
    }
    return StreakData(
      currentStreak: userProgress.workoutStreak,
      longestStreak: userProgress.longestStreak,
      lastWorkoutDate: userProgress.lastWorkoutDate,
    );
  }

  List<WeeklyDayActivity> getWeeklyWorkoutCalendar({DateTime? referenceDate}) {
    return _workoutStreakService.getWeeklyCalendar(
      _workoutHistory,
      referenceDate: referenceDate,
    );
  }

  List<WeeklyChallenge> get weeklyChallenges {
    return _challengeService.getChallenges();
  }

  List<String> get achievements => userProgress.achievements;

  /// Next Ranked division and how many milestone levels it takes.
  Map<String, dynamic> get nextRankRequirement =>
      _gamificationService.getNextRankRequirement(
        fallback: RankLadder.parse(
          userProgress.currentRank,
          userProgress.currentDivision,
        ),
      );

  Future<void> joinRankedMode() async {
    final current = userProgress;
    // Joining does not grant a rank: rank comes from verified milestones.
    final rankMap = _gamificationService.calculateRank();
    final updated = current.copyWith(
      rankedUnlocked: true,
      currentRank: rankMap['tier'],
      currentDivision: rankMap['division'],
    );
    await _gamificationService.saveProgress(updated);
    _userProgress = updated;
    notifyListeners();
  }

  int get completedWorkoutsCount => _workoutHistory.length;

  int get totalActiveDurationSeconds {
    return _workoutHistory.fold(0, (sum, item) => sum + item.durationSeconds);
  }

  double get averageCompletionPercentage {
    if (_workoutHistory.isEmpty) return 0.0;
    final total = _workoutHistory.fold(
      0.0,
      (sum, item) => sum + item.completionPercentage,
    );
    return total / _workoutHistory.length;
  }

  double get proteinConsumed => todayConsumed.protein;
  double get proteinGoal => todayNutrition.targets.proteinGrams;
  double get totalCaloriesConsumed => todayConsumed.calories;
  double get carbsConsumed => todayConsumed.carbs;
  double get fatConsumed => todayConsumed.fat;

  List<FoodItem> get availableFoods => _nutritionService.getAvailableFoods();
  List<FoodItem> searchFoods(String query, [String? category]) =>
      _nutritionService.searchFoods(query, category);

  List<FoodItem> get recentFoods => _nutritionService.getRecentFoods();
  List<FoodItem> get favoriteFoods => _nutritionService.getFavoriteFoods();
  List<FoodItem> get scannedFoods => _nutritionService.getScannedFoods();

  Future<FoodItem?> searchByBarcode(String barcode) =>
      _nutritionService.searchByBarcode(barcode);

  Future<FoodItem?> fetchRemoteFood(String barcode) =>
      _nutritionService.fetchRemoteFood(barcode);

  Future<void> saveScannedFood(FoodItem food) async {
    await _nutritionService.saveScannedFood(food);
    notifyListeners();
  }

  bool isFavoriteFood(String foodId) =>
      _nutritionService.foodRepository.isFavorite(foodId);

  Future<void> toggleFavoriteFood(String foodId) async {
    await _nutritionService.toggleFavoriteFood(foodId);
    notifyListeners();
  }

  Future<void> addCustomFood(FoodItem food) async {
    await _nutritionService.addCustomFood(food);
    notifyListeners();
  }

  Future<void> createCustomFood(FoodItem food) async {
    await _nutritionService.createCustomFood(food);
    notifyListeners();
  }

  Future<void> updateCustomFood(FoodItem food) async {
    await _nutritionService.updateCustomFood(food);
    notifyListeners();
  }

  Future<void> deleteCustomFood(String foodId) async {
    await _nutritionService.deleteCustomFood(foodId);
    notifyListeners();
  }

  Future<void> recordRecentFood(String foodId) async {
    await _nutritionService.recordRecentFood(foodId);
    notifyListeners();
  }

  // --- Nutrition Tracking System Getters & Forwarding ---

  NutritionLog get todayNutritionLog => _nutritionService.getTodayNutrition();

  /// Consumed calories and macros today, from the logged meals. Every consumed
  /// getter and screen reads this; targets stay in [todayNutrition].
  ///
  /// Showcase mode shows the demo day instead of the athlete's own log.
  NutritionTotals get todayConsumed => LocalStorage.isShowcaseModeEnabled()
      ? todayNutrition.totalsConsumed + _showcaseLoggedTotals
      : todayNutritionLog.totals;

  /// Foods logged while Showcase Mode is on (from a scan or a search). They
  /// live only in memory: they are added to the demo day's totals, are never
  /// saved, and are dropped when Showcase starts or ends.
  final List<MealEntry> _showcaseLoggedFoods = [];

  /// Read-only view of the Showcase-only food log.
  List<MealEntry> get showcaseLoggedMeals =>
      List.unmodifiable(_showcaseLoggedFoods);

  NutritionTotals get _showcaseLoggedTotals =>
      NutritionTotals.fromMeals(_showcaseLoggedFoods);

  Future<void> _logShowcaseFood(
    String mealId,
    FoodItem food,
    double quantity,
    String unit,
  ) async {
    // The same unit rule as the real log: grams and millilitres never mix.
    if (!NutritionCalculator.isUnitCompatible(food, unit)) {
      throw ArgumentError.value(
        unit,
        'unit',
        '${food.name} is measured per ${food.nutritionBasis.name}, '
            'so it cannot be logged in this unit',
      );
    }
    _showcaseLoggedFoods.add(
      MealEntry(
        id: 'showcase_${DateTime.now().microsecondsSinceEpoch}',
        name: mealId,
        consumedFoods: [
          ConsumedFood(food: food, quantity: quantity, unit: unit),
        ],
        completed: true,
      ),
    );
    notifyListeners();
  }

  List<MealEntry> get todaysMeals => todayNutritionLog.meals;

  double get calorieProgress => todayNutritionLog.calorieProgress;
  double get proteinProgress => todayNutritionLog.proteinProgress;
  double get carbohydrateProgress => todayNutritionLog.carbohydrateProgress;
  double get fatProgress => todayNutritionLog.fatProgress;

  Future<void> addFoodToMeal(
    String mealId,
    FoodItem food, [
    double quantity = 100.0,
    String unit = 'grams',
  ]) async {
    if (LocalStorage.isShowcaseModeEnabled()) {
      // Showcase: an in-memory demo log. No real nutrition log, XP, memory or
      // recent-foods list is touched.
      return _logShowcaseFood(mealId, food, quantity, unit);
    }
    await _nutritionService.addFoodToMeal(mealId, food, quantity, unit);
    await awardMealLogXP();
    await FitnessMemory.instance.recordFoodLogged(food.name);
    refreshRecommendations(notify: false);
    refreshDailyBrief(notify: false);
    notifyListeners();
  }

  /// Logs a structured AI or barcode [FoodAnalysisResult] into the target meal
  Future<void> logFoodAnalysisResult(
    FoodAnalysisResult result, {
    String mealId = 'Breakfast',
  }) async {
    final foodItem = result.toFoodItem();
    if (!LocalStorage.isShowcaseModeEnabled() &&
        result.barcode != null &&
        result.barcode!.isNotEmpty) {
      await FoodDatabaseService.instance.saveScannedProduct(foodItem);
    }
    await addFoodToMeal(
      mealId,
      foodItem,
      result.servingSize,
      result.servingUnit,
    );
  }

  /// Logs a verified barcode product directly into the target meal
  Future<void> logBarcodeProduct(
    FoodItem product,
    double quantity, {
    String mealId = 'Breakfast',
    String unit = 'g',
  }) async {
    if (!LocalStorage.isShowcaseModeEnabled()) {
      await FoodDatabaseService.instance.saveScannedProduct(product);
    }
    await addFoodToMeal(mealId, product, quantity, unit);
  }

  Future<void> removeFoodFromMeal(String mealId, String foodId) async {
    await _nutritionService.removeFoodFromMeal(mealId, foodId);
    notifyListeners();
  }

  Future<void> updateFoodQuantity(
    String mealId,
    String foodId,
    double quantity, [
    String unit = 'grams',
  ]) async {
    await _nutritionService.updateFoodQuantity(mealId, foodId, quantity, unit);
    notifyListeners();
  }

  Future<void> completeMeal(String mealId, [bool completed = true]) async {
    await _nutritionService.completeMeal(mealId, completed);
    if (completed) {
      final daily = todayNutrition;
      // The meal slot (breakfast, lunch, ...) is what is rewarded once a day,
      // however the meal was named when it was completed.
      final lowered = mealId.toLowerCase();
      final slot = todayNutritionLog.meals
          .where((m) => m.id == mealId || m.name.toLowerCase() == lowered)
          .map((m) => m.category.name)
          .firstOrNull;
      final result = await _nutritionGamificationService.processMealCompleted(
        dailyNutrition: daily,
        currentProgress: _userProgress,
        mealSlot: slot ?? lowered,
      );
      _userProgress = result.updatedUserProgress;
      RewardQueueService.instance.enqueueAll(result.rewards);

      final consumed = todayConsumed;
      await _challengeService.updateNutritionProgress(
        userId: currentUser?.id ?? 'usr_local',
        calories: consumed.calories,
        protein: consumed.protein,
        goalMet: consumed.calories >= 1500,
      );
    }
    refreshNutrition();
  }

  // --- Analytics Getters ---

  VolumeAnalytics get volumeAnalytics {
    _cachedVolumeAnalytics ??= _analyticsService.calculateVolume(
      _workoutHistory,
    );
    return _cachedVolumeAnalytics!;
  }

  ConsistencyAnalytics get consistencyAnalytics {
    _cachedConsistencyAnalytics ??= _analyticsService.calculateConsistency(
      _workoutHistory,
      workoutStreak,
    );
    return _cachedConsistencyAnalytics!;
  }

  List<StrengthProgression> get strengthProgressions {
    _cachedStrengthProgressions ??= _analyticsService
        .calculateStrengthProgression(_workoutHistory);
    return _cachedStrengthProgressions!;
  }

  Map<String, double> get muscleGroupDistribution {
    _cachedMuscleGroupDistribution ??= _analyticsService
        .calculateMuscleGroupDistribution(_workoutHistory);
    return _cachedMuscleGroupDistribution!;
  }

  PersonalRecordSummary get personalRecordsSummary {
    _cachedPersonalRecordsSummary ??= _analyticsService
        .calculatePersonalRecords(_workoutHistory);
    return _cachedPersonalRecordsSummary!;
  }

  ProgressSummary get progressSummary {
    _cachedProgressSummary ??= _progressSummaryService.generateSummary(
      history: _workoutHistory,
      userProgress: userProgress,
      streakData: streakData,
    );
    return _cachedProgressSummary!;
  }

  AthleteAnalyticsReport get athleteAnalytics {
    _cachedAthleteAnalytics ??= _progressAnalyticsEngine.generateAthleteReport(
      sessions: _workoutService.getWorkoutSessions(),
      history: _workoutHistory,
      bodyWeight:
          double.tryParse(
            (_profile?.weight ?? '75').replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          75.0,
      targetWorkoutsPerWeek: _currentGoal?.fitnessLevel == FitnessLevel.advanced
          ? 5
          : 4,
    );
    return _cachedAthleteAnalytics!;
  }

  NutritionSummary get nutritionSummary {
    _cachedNutritionSummary ??= _nutritionAnalyticsService.calculateSummary(
      _nutritionService.getNutritionHistory(),
    );
    return _cachedNutritionSummary!;
  }

  // --- Refresh Methods ---

  /// Refresh workout history from local storage and notify all listening screens
  void refreshWorkoutHistory() {
    _workoutHistory = _workoutService.getWorkoutHistory();
    _recalculateAnalytics();
    notifyListeners();
  }

  /// Evaluates current fitness context and generates/refreshes the proactive daily brief.
  void refreshDailyBrief({bool notify = true}) {
    final ctx = buildFitnessContext();
    _dailyBrief = _dailyBriefService.generateBrief(ctx);
    if (notify) {
      notifyListeners();
    }
  }

  /// Active autonomous AI Coach 2.0 daily brief.
  DailyCoachBrief get dailyCoachBrief =>
      _dailyCoachBrief ?? refreshDailyCoachBrief(notify: false);

  /// Generates or refreshes the autonomous AI Coach 2.0 daily brief.
  DailyCoachBrief refreshDailyCoachBrief({bool notify = true}) {
    final ctx = buildFitnessContext();
    _dailyCoachBrief = _dailyCoachBriefService.generateBrief(
      context: ctx,
      healthMetrics: _metricsForRecovery(_healthMetrics ?? _todayHealthMetrics),
      recoveryState: _recoveryState,
    );
    if (notify) {
      notifyListeners();
    }
    return _dailyCoachBrief!;
  }

  /// Refresh nutrition data from local storage and notify all listening screens
  void refreshNutrition() {
    _todayNutrition = _nutritionService.getDailyNutrition();
    _cachedNutritionSummary = null;
    refreshDailyBrief(notify: false);
    notifyListeners();
  }

  /// Refresh user profile from storage and notify all listening screens
  void refreshProfile() {
    _profileProvider.reload();
    _profile = _profileProvider.userProfile;
    notifyListeners();
  }

  /// Refresh gamification progress from storage and notify listeners
  void refreshProgress() {
    _userProgress = _gamificationService.getProgress();
    notifyListeners();
  }

  /// Refresh all fitness app state and notify listeners
  void refreshAll() {
    _reloadAllData();
    notifyListeners();
  }

  // --- Mutation Pipelines ---

  /// Completes and records a full WorkoutSession, persisting to LocalStorage,
  /// evaluating PRs, awarding XP & achievement unlocks, and updating AI memory.
  Future<WorkoutCompletionResult> completeWorkoutSession(
    WorkoutSession session,
  ) async {
    return saveWorkoutCompletion(session.toWorkoutHistory(), session: session);
  }

  /// Submissions being recorded right now, by completion key.
  final Map<String, Future<WorkoutCompletionResult>> _completionsInFlight = {};

  /// Identifies one finished workout. A session is identified by the workout
  /// and its start time, which stay the same however many times the finish
  /// button is pressed; a plain history entry by its name, finish time and
  /// duration.
  static String _completionKey(WorkoutHistory entry, WorkoutSession? session) =>
      session != null
      ? 'session|${session.workoutId}|${session.startTime.millisecondsSinceEpoch}'
      : 'entry|${entry.workoutName}|${entry.dateCompleted.millisecondsSinceEpoch}|${entry.durationSeconds}';

  bool _isAlreadyRecorded(WorkoutHistory entry, WorkoutSession? session) {
    if (session != null) {
      return _workoutService.getWorkoutSessions().any(
        (s) =>
            s.id == session.id ||
            (s.workoutId == session.workoutId &&
                s.startTime == session.startTime),
      );
    }
    return _workoutService.getWorkoutHistory().any(
      (h) =>
          h.workoutName == entry.workoutName &&
          h.dateCompleted == entry.dateCompleted &&
          h.durationSeconds == entry.durationSeconds,
    );
  }

  /// The one way a finished workout is recorded: saves the session and
  /// history, works out the XP once (see [WorkoutXpCalculator]), updates
  /// streak, challenges, achievements and rank, and returns the result.
  ///
  /// Recording the same workout again (a double tap, a retry) saves nothing
  /// and awards nothing; the result has [WorkoutCompletionResult.isDuplicate]
  /// set. A second call made while the first is still running gets the first
  /// call's result.
  Future<WorkoutCompletionResult> saveWorkoutCompletion(
    WorkoutHistory entry, {
    WorkoutSession? session,
  }) {
    final key = _completionKey(entry, session);
    final running = _completionsInFlight[key];
    if (running != null) return running;
    final future = _recordWorkoutCompletion(entry, session).whenComplete(() {
      // A block body on purpose: returning the removed future would make
      // this wait on itself.
      _completionsInFlight.remove(key);
    });
    _completionsInFlight[key] = future;
    return future;
  }

  /// How many recent workout keys are kept in the progress for the
  /// "already rewarded" check.
  static const int _maxAppliedWorkoutKeys = 50;

  /// Test hook: called after each reward stage so a test can simulate the app
  /// stopping there by throwing. Always null in the app.
  @visibleForTesting
  Future<void> Function(String stage)? rewardStageHook;

  Future<void> _afterRewardStage(String stage) async {
    await rewardStageHook?.call(stage);
  }

  /// Keeps the newest [_maxAppliedWorkoutKeys] keys, but never drops a key
  /// whose note is still open: that key is what stops its workout from being
  /// rewarded again.
  List<String> _trimAppliedKeys(List<String> keys) {
    if (keys.length <= _maxAppliedWorkoutKeys) return keys;
    final open = LocalStorage.getPendingWorkoutRewards().keys.toSet();
    var excess = keys.length - _maxAppliedWorkoutKeys;
    final kept = <String>[];
    for (final k in keys) {
      if (excess > 0 && !open.contains(k)) {
        excess--;
      } else {
        kept.add(k);
      }
    }
    return kept;
  }

  Future<void> _recordWorkoutMemory(
    WorkoutHistory entry,
    WorkoutSession? session,
    String key,
  ) => FitnessMemory.instance.recordWorkoutExecution(
    workoutTitle: entry.workoutName,
    totalVolume: entry.totalVolume,
    completedSets: entry.totalSets,
    prs: entry.personalRecords,
    exercises: session?.exercises,
    completionKey: key,
  );

  static bool _isSameRecord(WorkoutHistory a, WorkoutHistory b) =>
      a.workoutName == b.workoutName &&
      a.dateCompleted == b.dateCompleted &&
      a.durationSeconds == b.durationSeconds;

  Future<WorkoutCompletionResult> _recordWorkoutCompletion(
    WorkoutHistory entry,
    WorkoutSession? session,
  ) async {
    if (LocalStorage.isShowcaseModeEnabled()) {
      return _recordShowcaseCompletion(entry);
    }
    final key = _completionKey(entry, session);
    final bool recorded = _isAlreadyRecorded(entry, session);
    final pendingRewards = LocalStorage.getPendingWorkoutRewards()[key];
    // Saved earlier and its rewards were applied: nothing left to do.
    if (recorded && pendingRewards == null) {
      return const WorkoutCompletionResult(isDuplicate: true);
    }
    // Saved earlier but interrupted before its rewards were applied: finish
    // them now, from the record as it was saved.
    final bool resuming = recorded;

    final String prevRank = userProgress.fullRank;
    final int prevXP = userProgress.totalXP;

    if (resuming) {
      final saved = pendingRewards!['entry'];
      if (saved is Map) {
        entry = WorkoutHistory.fromJson(Map<String, dynamic>.from(saved));
      }
      // The session can be saved while the history entry is not (the app
      // stopped between the two saves).
      final savedEntry = entry;
      if (!_workoutService.getWorkoutHistory().any(
        (h) => _isSameRecord(h, savedEntry),
      )) {
        await _workoutService.saveWorkoutCompletion(entry);
      }
      if (!_workoutHistory.any((h) => _isSameRecord(h, entry))) {
        _workoutHistory = [entry, ..._workoutHistory];
      }
    } else {
      // The XP for this workout, worked out once and stored with the record.
      final int streakAfterWorkout = _workoutStreakService.calculateStreak([
        entry,
        ..._workoutHistory,
      ]).currentStreak;
      final int workoutXp = WorkoutXpCalculator.forWorkout(
        completionPercentage: entry.completionPercentage,
        hasPersonalRecord: entry.personalRecords.isNotEmpty,
        streakAfterWorkout: streakAfterWorkout,
      ).total;
      entry = entry.copyWith(xpEarned: workoutXp);
      session = session?.copyWith(xpEarned: workoutXp);

      // Note the workout as "rewards still to apply" before it is saved, so a
      // saved workout can always be found again if the app stops here.
      await LocalStorage.savePendingWorkoutReward(key, {
        'entry': entry.toJson(),
      });

      // 1. Save structured workout session if provided
      if (session != null) {
        await _workoutService.saveWorkoutSession(session);
      }

      // 2. Save workout completion history
      await _workoutService.saveWorkoutCompletion(entry);
      if (!_workoutHistory.any((h) => _isSameRecord(h, entry))) {
        _workoutHistory = [entry, ..._workoutHistory];
      }
    }
    await _afterRewardStage('recordSaved');

    // Already part of the saved progress (the app stopped after saving the
    // progress but before clearing the note): nothing to award again.
    if (LocalStorage.getUserProgress().appliedWorkoutKeys.contains(key)) {
      if (pendingRewards?['progressApplied'] == true) {
        // Stopped after the progress was saved: finish the AI memory note.
        await _recordWorkoutMemory(entry, session, key);
      }
      await LocalStorage.clearPendingWorkoutReward(key);
      return const WorkoutCompletionResult(isDuplicate: true);
    }

    // Start from the saved progress, not the copy in memory: a stopped
    // earlier attempt may have changed the copy without saving it.
    _userProgress = LocalStorage.getUserProgress();

    // 3. Daily streak, from the history that now includes this workout
    final calculatedStreak = _workoutStreakService.calculateStreak(
      _workoutHistory,
    );
    _userProgress = userProgress.copyWith(
      workoutStreak: calculatedStreak.currentStreak,
      longestStreak: max(
        userProgress.longestStreak,
        calculatedStreak.longestStreak,
      ),
      lastWorkoutDate: calculatedStreak.lastWorkoutDate,
    );

    // 4. Weekly challenges. They keep their own stored progress, so this runs
    // once and the outcome is noted before the progress is saved.
    final List<RewardEvent> rewards = [];
    int challengeBonusXP;
    if (pendingRewards?['challengesApplied'] == true) {
      challengeBonusXP = (pendingRewards!['challengeBonusXp'] as num).toInt();
    } else {
      // Both updates are keyed by the completion key, so running them again
      // for the same workout (a retry) counts it only once.
      final newlyCompletedChallenges = await _challengeService
          .updateProgressOnWorkout(entry, completionKey: key);
      await _challengeService.updateWorkoutProgress(
        userId: currentUser?.id ?? 'usr_local',
        workout: entry,
        currentStreak: _userProgress?.workoutStreak ?? 1,
        completionKey: key,
      );
      await _afterRewardStage('challengesUpdated');
      challengeBonusXP = 0;
      for (final challenge in newlyCompletedChallenges) {
        challengeBonusXP += challenge.xpReward;
        rewards.add(
          RewardEvent.weeklyChallenge(
            challengeId: challenge.id,
            title: 'Weekly Challenge Complete!\n${challenge.title}',
            data: challenge,
          ),
        );
      }
      await LocalStorage.savePendingWorkoutReward(key, {
        'entry': entry.toJson(),
        'challengesApplied': true,
        'challengeBonusXp': challengeBonusXP,
      });
    }
    await _afterRewardStage('challengesApplied');

    // 5. Workout XP, challenge bonus, streak and achievements: worked out
    // together and saved in one write, together with the note that this
    // workout has been rewarded.
    // The workout flow saves some achievement ids itself; what counts as newly
    // unlocked is judged against what was earned before this workout.
    final achievementsBefore = List<String>.of(userProgress.achievements);
    var progress = _gamificationService.progressAfterWorkout(
      entry,
      userProgress,
      streakAfterWorkout: calculatedStreak.currentStreak,
    );
    progress = progress.copyWith(
      workoutStreak: calculatedStreak.currentStreak,
      longestStreak: max(
        progress.longestStreak,
        calculatedStreak.longestStreak,
      ),
      lastWorkoutDate: calculatedStreak.lastWorkoutDate,
      totalXP: progress.totalXP + challengeBonusXP,
    );
    final evalResult = AchievementService.evaluateAchievements(
      progress,
      athleteAnalytics: athleteAnalytics,
      hasNewPersonalRecord: entry.personalRecords.isNotEmpty,
      previousAchievements: achievementsBefore,
    );
    _userProgress = evalResult.updatedProgress.copyWith(
      appliedWorkoutKeys: _trimAppliedKeys([
        ...progress.appliedWorkoutKeys,
        key,
      ]),
    );
    await _afterRewardStage('beforeProgressSave');
    await LocalStorage.saveUserProgress(_userProgress!);
    // The rewards are safe. Keep the note until the AI memory is written too;
    // writing it again after a stop only replaces the same notes.
    await LocalStorage.savePendingWorkoutReward(key, {
      'entry': entry.toJson(),
      'progressApplied': true,
    });
    await _afterRewardStage('rewardsApplied');

    // 6. Update AI Fitness Memory with real completed performance
    await _recordWorkoutMemory(entry, session, key);
    await LocalStorage.clearPendingWorkoutReward(key);
    await _afterRewardStage('memoryRecorded');

    // The steps below (feed post, notifications, season XP) are not repeated
    // if the app stops here: they have no saved copy to retry from.

    refreshWorkoutHistory();

    final String newRank = userProgress.fullRank;
    final int newXP = userProgress.totalXP;
    final int xpGained = (newXP - prevXP).clamp(0, 10000);

    RankUpDetails? rankUp;
    if (prevRank != newRank) {
      rankUp = RankUpDetails(
        previousRank: prevRank,
        newRank: newRank,
        xpGained: xpGained,
        message:
            "You've pushed past your limits and achieved a new competitive tier!",
      );
    }

    // Create activity item for workout completion
    await _socialService.createActivity(
      ActivityItem(
        id: 'act_w_${DateTime.now().millisecondsSinceEpoch}',
        userId: currentUser?.id ?? 'usr_local',
        type: 'workout',
        title: '${profile.name} completed ${entry.workoutName}',
        description:
            '${entry.exercisesCompleted} exercises completed • ${entry.totalVolume.toInt()} kg volume lifted',
        createdAt: DateTime.now(),
      ),
    );

    // Enqueue Rank Up and Achievement rewards & create notifications / activities
    if (rankUp != null) {
      rewards.add(RewardEvent.rankUp(rankUp));
      await _announceRankUp(rankUp.previousRank, rankUp.newRank);
    }
    for (final badge in evalResult.newlyUnlockedBadges) {
      rewards.add(RewardEvent.achievement(badge));
      await _notificationService.createNotification(
        NotificationItem(
          id: 'notif_badge_${badge.id}_${DateTime.now().millisecondsSinceEpoch}',
          userId: currentUser?.id ?? 'usr_local',
          title: 'Achievement Unlocked! 🎖️',
          message: 'You earned the "${badge.title}" badge!',
          type: 'achievement',
          createdAt: DateTime.now(),
          actionRoute: '/ranked',
        ),
      );
      await _socialService.createActivity(
        ActivityItem(
          id: 'act_b_${badge.id}_${DateTime.now().millisecondsSinceEpoch}',
          userId: currentUser?.id ?? 'usr_local',
          type: 'achievement',
          title: '${profile.name} unlocked "${badge.title}"',
          description: badge.description,
          createdAt: DateTime.now(),
        ),
      );
    }
    if (xpGained > 0) {
      rewards.add(
        RewardEvent.xpBonus(amount: xpGained, source: entry.workoutName),
      );
      if (_currentSeason != null) {
        _seasonProgress = await _seasonService.addSeasonXP(
          seasonId: _currentSeason!.id,
          userId: currentUser?.id ?? 'usr_local',
          amount: xpGained,
        );
        await refreshSeasonLeaderboard();
      }
    }

    // Enqueue all generated rewards into centralized RewardQueueService
    RewardQueueService.instance.enqueueAll(rewards);

    await refreshTrainingIntelligence();

    // 6. Notify listeners across reactive UI
    refreshDailyBrief(notify: false);
    notifyListeners();

    // 7. A new lift may complete a Ranked milestone (verified by the server).
    if (CloudSession.userId != null) unawaited(refreshRanked());

    return WorkoutCompletionResult(
      rankUpDetails: rankUp,
      unlockedBadges: evalResult.newlyUnlockedBadges,
      rewards: rewards,
      xpEarned: xpGained > 0 ? xpGained : entry.xpEarned,
    );
  }

  /// Records a finished cardio session and its XP.
  ///
  /// Showcase mode only adds the XP to the in-memory demo progress: no
  /// session, activity record, progress or cloud write touches the athlete's
  /// own data. Returns the XP awarded.
  Future<int> recordCardioCompletion(
    CardioSession session,
    ActivityRecord activity,
  ) async {
    final int xp = WorkoutXpCalculator.forCardio(
      durationSeconds: session.durationSeconds,
    );
    if (LocalStorage.isShowcaseModeEnabled()) {
      _userProgress = userProgress.copyWith(totalXP: userProgress.totalXP + xp);
      notifyListeners();
      return xp;
    }
    // On the device and, when signed in, the cloud. Both are keyed by the
    // session id, so saving them again replaces the same records.
    await CloudCardioSync.save(session);
    await LocalStorage.saveActivityRecord(activity);
    await _afterRewardStage('cardioSaved');

    // The XP is saved together with a key for this session, so a retry after
    // a stop awards it once.
    final key = 'cardio|${session.id}';
    final saved = LocalStorage.getUserProgress();
    if (saved.appliedWorkoutKeys.contains(key)) return 0;
    final updated = _gamificationService
        .addXP(xp, saved)
        .copyWith(
          appliedWorkoutKeys: _trimAppliedKeys([
            ...saved.appliedWorkoutKeys,
            key,
          ]),
        );
    await _gamificationService.saveProgress(updated);
    _userProgress = updated;
    notifyListeners();
    return xp;
  }

  /// Showcase mode: the demo athlete finishes a workout. Only the in-memory
  /// demo state changes; nothing is written to the athlete's own storage,
  /// cloud data, feed or notifications.
  Future<WorkoutCompletionResult> _recordShowcaseCompletion(
    WorkoutHistory entry,
  ) async {
    final alreadyShown = _workoutHistory.any(
      (h) =>
          h.workoutName == entry.workoutName &&
          h.dateCompleted == entry.dateCompleted &&
          h.durationSeconds == entry.durationSeconds,
    );
    if (alreadyShown) return const WorkoutCompletionResult(isDuplicate: true);

    final streak = _workoutStreakService.calculateStreak([
      entry,
      ..._workoutHistory,
    ]).currentStreak;
    final xp = WorkoutXpCalculator.forWorkout(
      completionPercentage: entry.completionPercentage,
      hasPersonalRecord: entry.personalRecords.isNotEmpty,
      streakAfterWorkout: streak,
    ).total;
    _workoutHistory = [entry.copyWith(xpEarned: xp), ..._workoutHistory];
    _userProgress = userProgress.copyWith(
      totalXP: userProgress.totalXP + xp,
      completedWorkouts: userProgress.completedWorkouts + 1,
    );
    notifyListeners();
    return WorkoutCompletionResult(xpEarned: xp);
  }

  /// Save daily nutrition update, process XP rewards, evaluate achievement unlocks, persist to LocalStorage, and notify listeners
  Future<List<AchievementBadge>> saveDailyNutrition(
    DailyNutrition nutrition,
  ) async {
    await _nutritionService.saveDailyNutrition(nutrition);
    final result = await _nutritionGamificationService.processDailyNutrition(
      dailyNutrition: nutrition,
      currentProgress: _userProgress,
    );
    _userProgress = result.updatedUserProgress;
    RewardQueueService.instance.enqueueAll(result.rewards);

    refreshNutrition();
    return result.unlockedBadges;
  }

  /// Toggle meal completion, persist to LocalStorage, and notify listeners
  Future<void> toggleMealCompletion(String mealId) async {
    await _nutritionService.toggleMealCompletion(mealId: mealId);
    final daily = todayNutrition;
    final isCompleted = daily.meals.any((m) => m.id == mealId && m.isCompleted);
    if (isCompleted) {
      final slot = daily.meals.firstWhere((m) => m.id == mealId).category.name;
      final result = await _nutritionGamificationService.processMealCompleted(
        dailyNutrition: daily,
        currentProgress: _userProgress,
        mealSlot: slot,
      );
      _userProgress = result.updatedUserProgress;
      RewardQueueService.instance.enqueueAll(result.rewards);
    }
    refreshNutrition();
  }

  /// Update user profile, persist to LocalStorage, and notify listeners
  Future<void> updateProfile(UserProfile newProfile) async {
    await _profileProvider.updateProfile(newProfile);
    refreshProfile();
  }

  // --- User Fitness Goal Management ---

  /// Save new fitness goal, persist via GoalRepository, and notify listeners
  Future<void> saveGoal(UserGoal goal) async {
    await _goalRepository.saveGoal(goal);
    _currentGoal = goal;
    await generateWorkoutPlan(notify: false);
    refreshDailyBrief(notify: false);
    notifyListeners();
  }

  /// Update existing fitness goal, persist via GoalRepository, and notify listeners
  Future<void> updateGoal(UserGoal goal) async {
    await _goalRepository.saveGoal(goal);
    _currentGoal = goal;
    await generateWorkoutPlan(notify: false);
    refreshDailyBrief(notify: false);
    notifyListeners();
  }

  /// Clear active fitness goal, persist via GoalRepository, and notify listeners
  Future<void> clearGoal() async {
    await _goalRepository.clearGoal();
    _currentGoal = null;
    refreshDailyBrief(notify: false);
    notifyListeners();
  }

  // --- AI Coach Recommendation Engine ---

  /// Compiles a complete FitnessContext snapshot from active provider state
  FitnessContext buildFitnessContext() {
    // Steps come from the step service only (null when there is no reading).
    final todaySteps = const StepTrackingService().today;
    final now = DateTime.now();
    final cardioToday = LocalStorage.getCardioSessions().where(
      (s) =>
          s.isCompleted &&
          s.startTime.year == now.year &&
          s.startTime.month == now.month &&
          s.startTime.day == now.day,
    );
    // Minutes, calories and distance of today's completed cardio sessions. The
    // record carries no steps: use FitnessContext.todaySteps for those.
    final todayAct = ActivityRecord(
      id: 'act_today_${now.year}_${now.month}_${now.day}',
      date: now,
      activeMinutes: cardioToday.fold<int>(
        0,
        (sum, s) => sum + (s.durationSeconds ~/ 60),
      ),
      caloriesBurned: cardioToday.fold<double>(
        0.0,
        (sum, s) => sum + s.caloriesBurned,
      ),
      distanceKm: cardioToday.fold<double>(0.0, (sum, s) => sum + s.distanceKm),
      type: ActivityType.cardio,
      title: "Today's cardio",
    );
    final score = const ActivityScoreService().getTodayScore();

    var healthMetric = LocalStorage.getHealthMetric() ?? HealthMetric.zero();
    // Last night's sleep from a sleep record (logged by the user or synced from
    // a watch) when the health reading has none.
    final lastSleep = _latestSleep;
    if ((healthMetric.sleepMinutes ?? 0) <= 0 &&
        lastSleep != null &&
        lastSleep.durationMinutes > 0 &&
        DateTime.now().difference(lastSleep.wakeTime).inHours.abs() <= 36) {
      healthMetric = healthMetric.copyWith(
        sleepMinutes: lastSleep.durationMinutes,
      );
    }
    final recoveryBreakdown = RecoveryService.instance
        .calculateFromHealthMetric(
          healthMetric,
          stepsToday: todaySteps.steps,
          workouts: _workoutHistory,
        );

    return FitnessContext(
      userGoal: _currentGoal,
      weightGoal: LocalStorage.getWeightGoal(),
      userProfile: _profile,
      workoutHistory: List.unmodifiable(_workoutHistory),
      nutritionSummary: nutritionSummary,
      progressSummary: progressSummary,
      athleteAnalytics: athleteAnalytics,
      userProgress: userProgress,
      nutritionProgress: nutritionProgress,
      // Showcase mode describes the demo day, never the athlete's own log.
      todayNutritionLog: LocalStorage.isShowcaseModeEnabled()
          ? NutritionLog(
              id: 'showcase_day',
              date: DateTime.now(),
              meals: ShowcaseDataProvider.instance.getShowcaseMeals(),
            )
          : todayNutritionLog,
      todayNutrition: LocalStorage.isShowcaseModeEnabled()
          ? todayNutrition
          : todayNutrition.withLogged(todayConsumed),
      recoveryState: _recoveryState,
      recoveryBreakdown: recoveryBreakdown,
      equipmentProfile: LocalStorage.getUserEquipmentProfile(),
      todayActivity: todayAct,
      todayHealthMetric: healthMetric,
      stepGoal: LocalStorage.getStepGoal(),
      todaySteps: todaySteps.steps,
      todayStepsSource: todaySteps.source?.name,
      activityScore: score.totalScore,
      recentCardio: LocalStorage.getCardioSessions().take(5).toList(),
      generatedAt: DateTime.now(),
    );
  }

  /// Returns reactive list of active, non-dismissed recommendations
  List<Recommendation> get recommendations {
    if (_recommendations.isEmpty) {
      refreshRecommendations(notify: false);
    }
    return List.unmodifiable(
      _recommendations.where((r) => !r.isDismissed && !r.isExpired),
    );
  }

  /// Evaluates fitness context and updates recommendations reactively
  void refreshRecommendations({bool notify = true}) {
    final ctx = buildFitnessContext();
    _recommendations = _recommendationService.evaluateContext(
      ctx,
      existingRecommendations: _recommendations,
    );
    if (notify) {
      notifyListeners();
    }
  }

  /// Dismisses a recommendation by ID and notifies listeners
  void dismissRecommendation(String id) {
    final index = _recommendations.indexWhere((r) => r.id == id);
    if (index != -1) {
      _recommendations[index] = _recommendations[index].copyWith(
        isDismissed: true,
      );
      notifyListeners();
    }
  }

  /// Sends a message to the AI Coach, updates chat state, and notifies listeners.
  Future<void> sendCoachMessage(
    String message, {
    ChatAttachment? attachment,
  }) async {
    final trimmed = message.trim();
    if ((trimmed.isEmpty && attachment == null) || _isCoachReplying) return;

    _isCoachReplying = true;
    notifyListeners();

    try {
      _coachMessages = await _coachChatService.sendMessage(
        message: trimmed,
        context: buildFitnessContext(),
        currentMessages: _coachMessages,
        attachment: attachment,
      );
    } catch (e) {
      // CoachChatService turns provider failures into error replies itself.
      // Anything that still escapes (for example storing the conversation
      // failed) must not vanish: show it as an error reply, never as AI text.
      if (kDebugMode) {
        debugPrint(
          '[FitnessProvider] sendCoachMessage failed: ${e.runtimeType}',
        );
      }
      List<CoachMessage> thread;
      try {
        thread = List<CoachMessage>.from(_coachChatService.getMessages());
      } catch (_) {
        thread = List<CoachMessage>.from(_coachMessages);
      }
      final now = DateTime.now();
      if (!(thread.isNotEmpty &&
          thread.last.role == CoachRole.user &&
          thread.last.content.trim() == trimmed)) {
        thread.add(
          CoachMessage(
            id: 'msg_user_${now.millisecondsSinceEpoch}',
            role: CoachRole.user,
            content: trimmed.isNotEmpty ? trimmed : 'Attached Image',
            timestamp: now,
          ),
        );
      }
      thread.add(
        CoachMessage(
          id: 'msg_error_${now.millisecondsSinceEpoch}',
          role: CoachRole.assistant,
          content:
              'Something went wrong sending that message. Please try again.',
          timestamp: now,
          category: CoachReplySource.error,
        ),
      );
      _coachMessages = thread;
    } finally {
      _isCoachReplying = false;
      notifyListeners();
    }
  }

  /// Whether Atlas AI can be used right now: signed in and the AI backend
  /// configured. This is local state, not a connectivity check.
  bool get isCoachAvailable => _coachChatService.isOnline;

  /// Why Atlas AI cannot be used (this build has no AI backend, or nobody is
  /// signed in). Null when it can be used.
  AIUnavailableReason? get coachUnavailableReason =>
      _coachChatService.unavailableReason;

  /// Clears stored AI Coach conversation thread and notifies listeners.
  Future<void> clearCoachConversation() async {
    await _coachChatService.clearConversation();
    _coachMessages = [];
    notifyListeners();
  }

  // --- Authentication Pipeline ---

  /// Authenticates user with email & password, updates currentUser state, and notifies listeners.
  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    final user = await _authRepository.signIn(email: email, password: password);
    _currentUser = user;
    notifyListeners();
    unawaited(syncWithCloud());
    return _currentUser;
  }

  /// Registers new user, persists session state, and notifies listeners.
  Future<AppUser?> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = await _authRepository.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    _currentUser = user;
    notifyListeners();
    unawaited(syncWithCloud());
    return _currentUser;
  }

  /// Terminates active authentication session and notifies listeners.
  Future<void> logout() async {
    await RevenueCatBillingProvider.logOut();
    await _authRepository.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Sends a password reset email to the specified address.
  Future<void> resetPassword({required String email}) async {
    await _authRepository.resetPassword(email: email);
  }

  /// Permanently deletes the active user account, wipes local data, and notifies listeners.
  Future<void> deleteAccount() async {
    await _authRepository.deleteAccount();
    _currentUser = null;
    notifyListeners();
  }

  /// Restores session on app startup and notifies listeners.
  Future<AppUser?> restoreSession() async {
    final user = await _authRepository.restoreSession();
    _currentUser = user;
    notifyListeners();
    if (user != null) unawaited(syncWithCloud());
    return _currentUser;
  }

  /// Refreshes Ranked progress (verified by the server when signed in) and
  /// updates the rank shown everywhere.
  Future<void> refreshRanked() async {
    if (LocalStorage.isShowcaseModeEnabled()) return;
    await RankedService.instance.refresh();
    await applyRankedSnapshot();
  }

  /// Copies the cached Ranked rank into progress and announces promotions.
  Future<void> applyRankedSnapshot() async {
    final previous = userProgress.fullRank;
    final previousIndex = _rankIndexOf(previous);
    final rank = _gamificationService.calculateRank();
    final updated = userProgress.copyWith(
      currentRank: rank['tier'],
      currentDivision: rank['division'],
    );
    await _gamificationService.saveProgress(updated);
    _userProgress = updated;
    final position = RankedProgressStore.position;
    if (position.index > previousIndex) {
      await _announceRankUp(previous, position.title);
    }
    notifyListeners();
  }

  /// Ladder index of a title like "Gold II" (-1 when unranked or unknown).
  static int _rankIndexOf(String title) {
    final parts = title.split(' ');
    if (parts.length != 2) return -1;
    final tier = RankLadder.tierIndex(parts[0]);
    final division = RankLadder.divisions.indexOf(parts[1]);
    if (tier < 0 || division < 0) return -1;
    return tier * RankLadder.divisions.length + division;
  }

  Future<void> _announceRankUp(String previousRank, String newRank) async {
    await _notificationService.createNotification(
      NotificationItem(
        id: 'notif_rank_${DateTime.now().millisecondsSinceEpoch}',
        userId: currentUser?.id ?? 'usr_local',
        title: 'Rank Promoted! 🏆',
        message: "You've reached $newRank!",
        type: 'rank_up',
        createdAt: DateTime.now(),
        actionRoute: '/ranked',
      ),
    );
    await _socialService.createActivity(
      ActivityItem(
        id: 'act_r_${DateTime.now().millisecondsSinceEpoch}',
        userId: currentUser?.id ?? 'usr_local',
        type: 'rank_up',
        title: '${profile.name} promoted to $newRank!',
        description: 'Hit a new Ranked milestone',
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Pushes unsynced changes and pulls the signed-in account's cloud data,
  /// then refreshes the UI if anything changed. No-op when signed out or
  /// running without Supabase.
  Future<void> syncWithCloud() async {
    if (LocalStorage.isShowcaseModeEnabled()) return;
    final uid = CloudSession.userId;
    if (uid != null) {
      try {
        await RevenueCatBillingProvider.logIn(uid);
        _subscription = await _subscriptionService.refreshFromStore(
          userId: uid,
        );
      } catch (_) {
        // Offline or store unavailable: keep the stored subscription.
      }
    }
    final changed = await CloudSyncCoordinator.instance.syncAfterSignIn();
    if (changed) {
      _reloadAllData();
      notifyListeners();
    }
    await refreshRanked();
  }

  /// Updates authenticated user details and notifies listeners.
  Future<void> updateAuthUser(AppUser updatedUser) async {
    await _authRepository.updateUserProfile(updatedUser);
    _currentUser = updatedUser;
    notifyListeners();
  }

  // --- Phase 8: Gamification, Ranking & Social Integrations ---

  /// Retrieves user gamification progress
  UserProgress getUserProgress() {
    return _gamificationService.getProgress();
  }

  /// Retrieves filtered leaderboard entries
  Future<List<LeaderboardEntry>> getLeaderboard({
    String scope = 'Global',
    String timeframe = 'Weekly',
    String metric = 'Total XP',
    int limit = 50,
  }) {
    return _leaderboardService.getFilteredLeaderboard(
      scope: scope,
      timeframe: timeframe,
      metric: metric,
      limit: limit,
    );
  }

  /// Retrieves active challenges
  Future<List<Challenge>> getActiveChallenges() {
    return _challengeService.getActiveChallenges();
  }

  /// Retrieves transformation milestones
  List<TransformationPost> getTransformations({
    String? viewerUserId,
    bool isFollowing = false,
    String? targetUserId,
  }) {
    return _transformationService.getTransformations(
      viewerUserId: viewerUserId,
      isFollowing: isFollowing,
      targetUserId: targetUserId,
    );
  }

  /// Adds a transformation milestone
  Future<void> addTransformation(TransformationPost post) async {
    await _transformationService.addTransformation(post);
    notifyListeners();
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onProfileChanged);
    NutritionChanges.instance.removeListener(refreshNutrition);
    WorkoutChanges.instance.removeListener(refreshWorkoutHistory);
    if (BonusXp.awarder == addXP) BonusXp.awarder = BonusXp.saveOnly;
    super.dispose();
  }
}
