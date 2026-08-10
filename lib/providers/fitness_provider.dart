import 'package:flutter/foundation.dart';
import '../data/app_dependencies.dart';
import '../data/gamification_service.dart';
import '../data/local_storage.dart';
import '../data/nutrition_service.dart';
import '../data/profile_provider.dart';
import '../data/workout_service.dart';
import '../models/badge.dart';
import '../models/daily_nutrition.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_log.dart';
import '../models/nutrition_summary.dart';
import '../models/user_profile.dart';
import '../models/user_progress.dart';
import '../models/user_goal.dart';
import '../models/workout_history.dart';
import '../models/reward_event.dart';
import '../models/progress_summary.dart';
import '../models/streak_data.dart';
import '../models/weekly_challenge.dart';
import '../models/nutrition_progress.dart';
import '../models/fitness_context.dart';
import '../models/recommendation.dart';
import '../repositories/goal_repository.dart';
import '../services/achievement_service.dart';
import '../services/analytics_service.dart';
import '../services/challenge_service.dart';
import '../services/nutrition_analytics_service.dart';
import '../services/nutrition_gamification_service.dart';
import '../services/progress_summary_service.dart';
import '../services/recommendation_service.dart';
import '../services/reward_queue_service.dart';
import '../models/coach_message.dart';
import '../services/ai/coach_chat_service.dart';
import '../models/daily_brief.dart';
import '../services/ai/daily_brief_service.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import '../models/sync_metadata.dart';
import '../services/sync/sync_service.dart';
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
import '../services/workout_planner_service.dart';
import '../models/workout_feedback.dart';
import '../services/workout_adaptation_service.dart';
import '../models/recovery_state.dart';
import '../services/recovery_intelligence_service.dart';
import '../models/subscription.dart';
import '../models/premium_feature.dart';
import '../services/subscription_service.dart';
import '../models/user_role.dart';
import '../models/gym.dart';
import '../models/trainer_profile.dart';
import '../models/coach_note.dart';
import '../services/trainer_service.dart';
import '../services/ai/trainer_ai_assistant.dart';

import '../widgets/common/rank_up_dialog.dart';

/// Result bundle returned by saveWorkoutCompletion containing potential rank up details,
/// newly unlocked achievement badges, and generated RewardEvents queued for presentation.
class WorkoutCompletionResult {
  final RankUpDetails? rankUpDetails;
  final List<AchievementBadge> unlockedBadges;
  final List<RewardEvent> rewards;

  const WorkoutCompletionResult({
    this.rankUpDetails,
    this.unlockedBadges = const [],
    this.rewards = const [],
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
  final NutritionAnalyticsService _nutritionAnalyticsService = const NutritionAnalyticsService();
  final RecommendationService _recommendationService;
  final CoachChatService _coachChatService;
  final DailyBriefService _dailyBriefService;
  final AuthRepository _authRepository;
  final SyncService _syncService;
  final LeaderboardService _leaderboardService;
  final NotificationService _notificationService;
  final SocialService _socialService;
  final SeasonService _seasonService;
  final HealthSyncService _healthSyncService;
  final TrainingIntelligenceService _trainingIntelligenceService;
  final WorkoutPlannerService _workoutPlannerService;
  final WorkoutAdaptationService _workoutAdaptationService;
  final RecoveryIntelligenceService _recoveryIntelligenceService;

  List<WorkoutHistory> _workoutHistory = [];
  DailyNutrition? _todayNutrition;
  UserProfile? _profile;
  UserProgress? _userProgress;
  UserGoal? _currentGoal;
  NutritionSummary? _cachedNutritionSummary;
  List<Recommendation> _recommendations = [];
  List<CoachMessage> _coachMessages = [];
  DailyBrief? _dailyBrief;
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
  int _recoveryScore = 85;
  List<ConnectedDevice> _connectedDevices = [];

  TrainingState? _trainingState;

  AdaptiveWorkoutPlan? _adaptiveWorkoutPlan;
  RecommendedWorkout? _todaysRecommendation;

  final List<WorkoutFeedback> _workoutFeedbackHistory = [];

  RecoveryState? _recoveryState;

  Subscription _subscription = Subscription.free();
  final SubscriptionService _subscriptionService = AppDependencies.instance.subscriptionService;

  UserRole _userRole = UserRole.member;
  Gym? _activeGym;
  TrainerProfile? _activeTrainerProfile;
  List<AppUser> _assignedMembers = [];
  final TrainerService _trainerService = AppDependencies.instance.trainerService;
  final TrainerAIAssistant _trainerAIAssistant = const TrainerAIAssistant();

  bool get isLoading => _isLoading;
  List<CoachMessage> get coachMessages => List.unmodifiable(_coachMessages);
  bool get isCoachReplying => _isCoachReplying;
  DailyBrief? get dailyBrief => _dailyBrief;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  SyncMetadata get syncMetadata => _syncService.metadata;
  SyncService get syncService => _syncService;

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
  List<LeaderboardEntry> get seasonLeaderboard => List.unmodifiable(_seasonLeaderboard);

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

  /// Add XP to current user progress reactively
  Future<void> addXP(int amount) async {
    final current = userProgress;
    _userProgress = current.copyWith(
      totalXP: current.totalXP + amount,
    );
    notifyListeners();
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
  Gym? get activeGym => _activeGym;
  TrainerProfile? get activeTrainerProfile => _activeTrainerProfile;
  List<AppUser> get assignedMembers => List.unmodifiable(_assignedMembers);

  Future<void> setUserRole(UserRole role) async {
    _userRole = role;
    await LocalStorage.saveUserRole(role);
    if (role.isTrainer) {
      await refreshTrainerData();
    }
    notifyListeners();
  }

  Future<void> refreshTrainerData() async {
    _activeGym = await _trainerService.getGymDetails();
    _activeTrainerProfile = await _trainerService.getTrainerProfile();
    if (_activeTrainerProfile != null) {
      _assignedMembers = await _trainerService.getAssignedMembers(
        trainerId: _activeTrainerProfile!.id,
      );
    }
    notifyListeners();
  }

  Future<void> assignMemberToTrainer(String memberId) async {
    final trainerId = _activeTrainerProfile?.id ?? 'tp_01';
    _activeTrainerProfile = await _trainerService.assignMember(
      trainerId: trainerId,
      memberId: memberId,
    );
    _assignedMembers = await _trainerService.getAssignedMembers(trainerId: trainerId);
    notifyListeners();
  }

  Future<void> removeMemberFromTrainer(String memberId) async {
    final trainerId = _activeTrainerProfile?.id ?? 'tp_01';
    _activeTrainerProfile = await _trainerService.removeMemberAssignment(
      trainerId: trainerId,
      memberId: memberId,
    );
    _assignedMembers = await _trainerService.getAssignedMembers(trainerId: trainerId);
    notifyListeners();
  }

  Future<CoachNote> addCoachNote({
    required String memberId,
    required String noteText,
    String category = 'general',
  }) async {
    final trainerId = _activeTrainerProfile?.id ?? 'tp_01';
    final note = await _trainerService.addCoachNote(
      trainerId: trainerId,
      memberId: memberId,
      noteText: noteText,
      category: category,
    );
    notifyListeners();
    return note;
  }

  Future<List<CoachNote>> getMemberCoachNotes(String memberId) async {
    return _trainerService.getMemberCoachNotes(memberId: memberId);
  }

  MemberAISummary generateMemberAISummary({
    required FitnessContext memberContext,
    String? memberName,
  }) {
    return _trainerAIAssistant.generateMemberSummary(
      context: memberContext,
      memberName: memberName ?? 'Athlete',
    );
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
    AuthRepository? authRepository,
    SyncService? syncService,
    LeaderboardService? leaderboardService,
    NotificationService? notificationService,
    SocialService? socialService,
    SeasonService? seasonService,
    HealthSyncService? healthSyncService,
    TrainingIntelligenceService? trainingIntelligenceService,
    WorkoutPlannerService? workoutPlannerService,
    WorkoutAdaptationService? workoutAdaptationService,
    RecoveryIntelligenceService? recoveryIntelligenceService,
  })  : _workoutService =
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
        _coachChatService = coachChatService ?? const CoachChatService(),
        _dailyBriefService = dailyBriefService ?? const DailyBriefService(),
        _authRepository = authRepository ?? LocalAuthRepository(),
        _syncService = syncService ?? SyncService(),
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
            recoveryIntelligenceService ?? RecoveryIntelligenceService() {
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
    SyncService? syncService,
    LeaderboardService? leaderboardService,
    NotificationService? notificationService,
    SocialService? socialService,
    SeasonService? seasonService,
    HealthSyncService? healthSyncService,
    TrainingIntelligenceService? trainingIntelligenceService,
    WorkoutPlannerService? workoutPlannerService,
    WorkoutAdaptationService? workoutAdaptationService,
    RecoveryIntelligenceService? recoveryIntelligenceService,
  }) {
    _instance ??= FitnessProvider._(
      workoutService: workoutService,
      nutritionService: nutritionService,
      profileProvider: profileProvider,
      gamificationService: gamificationService,
      nutritionGamificationService: nutritionGamificationService,
      goalRepository: goalRepository,
      recommendationService: recommendationService,
      syncService: syncService,
      leaderboardService: leaderboardService,
      notificationService: notificationService,
      socialService: socialService,
      seasonService: seasonService,
      healthSyncService: healthSyncService,
      trainingIntelligenceService: trainingIntelligenceService,
      workoutPlannerService: workoutPlannerService,
      workoutAdaptationService: workoutAdaptationService,
      recoveryIntelligenceService: recoveryIntelligenceService,
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

      _globalLeaderboard =
          await _leaderboardService.getGlobalLeaderboard();
      _localLeaderboard =
          await _leaderboardService.getLocalLeaderboard();
      _friendsLeaderboard =
          await _leaderboardService.getFriendsLeaderboard(
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
      _userChallenges =
          await _challengeService.getUserChallenges(userId: userId);
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
      final updatedUC =
          await _challengeService.claimReward(challengeId, userId: userId);
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
        _userProgress =
            _gamificationService.addXP(ch.rewardXP, currentProgress);
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
            description: 'Finished "${ch.title}" and claimed +${ch.rewardXP} XP',
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
    _notifications = await _notificationService.getNotifications(userId: userId);
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
    await _socialService.sendFriendRequest(requesterId: userId, receiverId: targetUserId);
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
    await _socialService.acceptFriendRequest(friendshipId: friendshipId, userId: userId);
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
      _seasonLeaderboard =
          await _seasonService.getSeasonLeaderboard(_currentSeason!.id);
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
      _recoveryScore = _healthSyncService.calculateRecoveryScore(metrics);
      await refreshTrainingIntelligence();
      refreshDailyBrief(notify: false);
      notifyListeners();
    }
  }

  /// Refresh training state, fatigue score, and readiness intelligence.
  Future<void> refreshTrainingIntelligence() async {
    _trainingState = _trainingIntelligenceService.analyzeTrainingState(
      workouts: _workoutHistory,
      healthMetrics: _healthMetrics,
      recoveryScore: _recoveryScore,
    );
    await refreshRecoveryIntelligence(notify: false);
    await refreshWorkoutRecommendation();
  }

  /// Refresh recovery & deload intelligence analysis.
  Future<void> refreshRecoveryIntelligence({bool notify = true}) async {
    _recoveryState = _recoveryIntelligenceService.analyzeRecoveryState(
      healthMetrics: _healthMetrics,
      trainingState: _trainingState,
      workouts: _workoutHistory,
      feedbackHistory: _workoutFeedbackHistory,
      customRecoveryScore: _recoveryScore,
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
    _workoutAdaptationService.calculateProgressionFactor(_workoutFeedbackHistory);
    await refreshWorkoutRecommendation(notify: false);
    if (notify) {
      notifyListeners();
    }
  }

  /// Synchronize local fitness data with remote sync service.
  /// Notifies listeners on sync start, sync complete, and sync failure.
  Future<void> syncData() async {
    // Notify listeners on sync start
    notifyListeners();

    try {
      await _syncService.synchronize(
        localDataToUpload: {
          'user_profile': _profile?.toJson(),
          'workout_history_count': _workoutHistory.length,
          'user_progress': _userProgress?.toJson(),
        },
      );
      // Notify listeners on sync complete
      notifyListeners();
    } catch (_) {
      // Notify listeners on sync failure
      notifyListeners();
      rethrow;
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
    _reloadAllData();
  }

  void _onProfileChanged() {
    _profile = _profileProvider.userProfile;
    notifyListeners();
  }

  void _reloadAllData() {
    _workoutHistory = _workoutService.getWorkoutHistory();
    _todayNutrition = _nutritionService.getDailyNutrition();
    _profile = _profileProvider.userProfile;
    _userProgress = _gamificationService.getProgress();
    _currentGoal = _goalRepository.getGoal();
    _coachMessages = _coachChatService.getMessages();
    _currentUser = _authRepository.currentUser;
    _subscription = LocalStorage.getSubscription(userId: _currentUser?.id ?? 'usr_local');
    _userRole = LocalStorage.getUserRole();
    _recalculateAnalytics();
    refreshDailyBrief(notify: false);
  }

  final AnalyticsService _analyticsService = AnalyticsService.instance;
  final ProgressSummaryService _progressSummaryService = ProgressSummaryService.instance;

  VolumeAnalytics? _cachedVolumeAnalytics;
  ConsistencyAnalytics? _cachedConsistencyAnalytics;
  List<StrengthProgression>? _cachedStrengthProgressions;
  Map<String, double>? _cachedMuscleGroupDistribution;
  PersonalRecordSummary? _cachedPersonalRecordsSummary;
  ProgressSummary? _cachedProgressSummary;

  void _recalculateAnalytics() {
    _cachedVolumeAnalytics = _analyticsService.calculateVolume(_workoutHistory);
    _cachedConsistencyAnalytics = _analyticsService.calculateConsistency(_workoutHistory, workoutStreak);
    _cachedStrengthProgressions = _analyticsService.calculateStrengthProgression(_workoutHistory);
    _cachedMuscleGroupDistribution = _analyticsService.calculateMuscleGroupDistribution(_workoutHistory);
    _cachedPersonalRecordsSummary = _analyticsService.calculatePersonalRecords(_workoutHistory);
    _cachedProgressSummary = _progressSummaryService.generateSummary(
      history: _workoutHistory,
      userProgress: userProgress,
      streakData: streakData,
    );
  }

  // --- Reactive Getters ---

  List<WorkoutHistory> get workoutHistory =>
      List.unmodifiable(_workoutHistory);

  DailyNutrition get todayNutrition {
    _todayNutrition ??= _nutritionService.getDailyNutrition();
    return _todayNutrition!;
  }

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
  int get workoutStreak => userProgress.workoutStreak;
  int get nutritionStreak => userProgress.nutritionStreak;
  NutritionProgress get nutritionProgress =>
      _nutritionGamificationService.getNutritionProgress();
  StreakData get streakData {
    return StreakData(
      currentStreak: userProgress.workoutStreak,
      longestStreak: userProgress.longestStreak,
      lastWorkoutDate: userProgress.lastWorkoutDate,
    );
  }

  List<WeeklyChallenge> get weeklyChallenges {
    return _challengeService.getChallenges();
  }
  List<String> get achievements => userProgress.achievements;
  Map<String, dynamic> get nextRankRequirement =>
      _gamificationService.getNextRankRequirement(totalXP, rankedUnlocked);

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

  double get proteinConsumed => todayNutrition.totalProteinConsumed;
  double get proteinGoal => todayNutrition.targets.proteinGrams;
  double get totalCaloriesConsumed => todayNutrition.totalCaloriesConsumed;

  List<FoodItem> get availableFoods => _nutritionService.getAvailableFoods();
  List<FoodItem> searchFoods(String query) => _nutritionService.searchFoods(query);

  // --- Nutrition Tracking System Getters & Forwarding ---

  NutritionLog get todayNutritionLog => _nutritionService.getTodayNutrition();
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
    await _nutritionService.addFoodToMeal(mealId, food, quantity, unit);
    notifyListeners();
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
      final result = await _nutritionGamificationService.processMealCompleted(
        dailyNutrition: daily,
        currentProgress: _userProgress,
      );
      _userProgress = result.updatedUserProgress;
      RewardQueueService.instance.enqueueAll(result.rewards);

      await _challengeService.updateNutritionProgress(
        userId: currentUser?.id ?? 'usr_local',
        calories: daily.totalCaloriesConsumed,
        protein: daily.totalProteinConsumed,
        goalMet: daily.totalCaloriesConsumed >= 1500,
      );
    }
    refreshNutrition();
  }

  // --- Analytics Getters ---

  VolumeAnalytics get volumeAnalytics {
    _cachedVolumeAnalytics ??= _analyticsService.calculateVolume(_workoutHistory);
    return _cachedVolumeAnalytics!;
  }

  ConsistencyAnalytics get consistencyAnalytics {
    _cachedConsistencyAnalytics ??= _analyticsService.calculateConsistency(_workoutHistory, workoutStreak);
    return _cachedConsistencyAnalytics!;
  }

  List<StrengthProgression> get strengthProgressions {
    _cachedStrengthProgressions ??= _analyticsService.calculateStrengthProgression(_workoutHistory);
    return _cachedStrengthProgressions!;
  }

  Map<String, double> get muscleGroupDistribution {
    _cachedMuscleGroupDistribution ??= _analyticsService.calculateMuscleGroupDistribution(_workoutHistory);
    return _cachedMuscleGroupDistribution!;
  }

  PersonalRecordSummary get personalRecordsSummary {
    _cachedPersonalRecordsSummary ??= _analyticsService.calculatePersonalRecords(_workoutHistory);
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

  /// Record completed workout, process XP rewards, evaluate achievement unlocks, persist to LocalStorage, and return WorkoutCompletionResult
  Future<WorkoutCompletionResult> saveWorkoutCompletion(WorkoutHistory entry) async {
    final String prevRank = userProgress.fullRank;
    final int prevXP = userProgress.totalXP;

    // 1. Save workout completion history
    await _workoutService.saveWorkoutCompletion(entry);

    // 2. Update Daily Streak System
    final StreakData activeStreak = streakData;
    final StreakData updatedStreak = activeStreak.updateWithWorkout(entry.dateCompleted);
    _userProgress = userProgress.copyWith(
      workoutStreak: updatedStreak.currentStreak,
      longestStreak: updatedStreak.longestStreak,
      lastWorkoutDate: updatedStreak.lastWorkoutDate,
    );

    // 3. Update Weekly Challenges System
    final newlyCompletedChallenges = await _challengeService.updateProgressOnWorkout(entry);
    await _challengeService.updateWorkoutProgress(
      userId: currentUser?.id ?? 'usr_local',
      workout: entry,
      currentStreak: _userProgress?.workoutStreak ?? 1,
    );

    // 4. Reward XP (Workout XP + Weekly Challenge XP Bonuses)
    _userProgress = await _gamificationService.awardWorkoutXP(entry, _userProgress);

    final List<RewardEvent> rewards = [];
    int challengeBonusXP = 0;

    for (final challenge in newlyCompletedChallenges) {
      challengeBonusXP += challenge.xpReward;
      rewards.add(RewardEvent.weeklyChallenge(
        challengeId: challenge.id,
        title: 'Weekly Challenge Complete!\n${challenge.title}',
        data: challenge,
      ));
    }

    if (challengeBonusXP > 0) {
      _userProgress = _userProgress!.copyWith(
        totalXP: _userProgress!.totalXP + challengeBonusXP,
      );
    }

    // Evaluate achievement unlocks
    final evalResult = AchievementService.evaluateAchievements(_userProgress!);
    _userProgress = evalResult.updatedProgress;

    // 5. Save UserProgress to LocalStorage
    await LocalStorage.saveUserProgress(_userProgress!);

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
        message: "You've pushed past your limits and achieved a new competitive tier!",
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
      await _notificationService.createNotification(
        NotificationItem(
          id: 'notif_rank_${DateTime.now().millisecondsSinceEpoch}',
          userId: currentUser?.id ?? 'usr_local',
          title: 'Rank Promoted! 🏆',
          message: "You've reached ${rankUp.newRank}!",
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
          title: '${profile.name} promoted to ${rankUp.newRank}!',
          description: 'Climbed XP on the competitive leaderboard',
          createdAt: DateTime.now(),
        ),
      );
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
      rewards.add(RewardEvent.xpBonus(
        amount: xpGained,
        source: entry.workoutName,
      ));
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

    return WorkoutCompletionResult(
      rankUpDetails: rankUp,
      unlockedBadges: evalResult.newlyUnlockedBadges,
      rewards: rewards,
    );
  }

  /// Save daily nutrition update, process XP rewards, evaluate achievement unlocks, persist to LocalStorage, and notify listeners
  Future<List<AchievementBadge>> saveDailyNutrition(DailyNutrition nutrition) async {
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
      final result = await _nutritionGamificationService.processMealCompleted(
        dailyNutrition: daily,
        currentProgress: _userProgress,
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
    return FitnessContext(
      userGoal: _currentGoal,
      userProfile: _profile,
      workoutHistory: List.unmodifiable(_workoutHistory),
      nutritionSummary: nutritionSummary,
      progressSummary: progressSummary,
      userProgress: userProgress,
      nutritionProgress: nutritionProgress,
      recoveryState: _recoveryState,
      generatedAt: DateTime.now(),
    );
  }

  /// Returns reactive list of active, non-dismissed recommendations
  List<Recommendation> get recommendations {
    if (_recommendations.isEmpty) {
      refreshRecommendations(notify: false);
    }
    return List.unmodifiable(
        _recommendations.where((r) => !r.isDismissed && !r.isExpired));
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
      _recommendations[index] =
          _recommendations[index].copyWith(isDismissed: true);
      notifyListeners();
    }
  }

  /// Sends a message to the AI Coach, updates chat state, and notifies listeners.
  Future<void> sendCoachMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _isCoachReplying) return;

    _isCoachReplying = true;
    notifyListeners();

    try {
      _coachMessages = await _coachChatService.sendMessage(
        message: trimmed,
        context: buildFitnessContext(),
        currentMessages: _coachMessages,
      );
    } catch (_) {
      // Offline fallback handling
    } finally {
      _isCoachReplying = false;
      notifyListeners();
    }
  }

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
    return _currentUser;
  }

  /// Terminates active authentication session and notifies listeners.
  Future<void> logout() async {
    await _authRepository.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Updates authenticated user details and notifies listeners.
  Future<void> updateAuthUser(AppUser updatedUser) async {
    await _authRepository.updateUserProfile(updatedUser);
    _currentUser = updatedUser;
    notifyListeners();
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }
}
