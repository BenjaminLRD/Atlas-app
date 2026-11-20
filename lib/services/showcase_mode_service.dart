import 'package:flutter/material.dart';
import '../data/local_storage.dart';
import '../models/activity_post.dart';
import '../models/badge.dart';
import '../models/coach_message.dart';
import '../models/digital_athlete.dart';
import '../models/fitness_context.dart';
import '../models/food_scan_result.dart';
import '../models/health_metrics.dart';
import '../models/meal_entry.dart';
import '../models/recommendation.dart';
import '../models/recovery_state.dart';
import '../models/sleep_record.dart';
import '../models/recovery_insight.dart';
import '../models/training_state.dart';
import '../models/user_profile.dart';
import '../models/user_progress.dart';
import '../models/workout_history.dart';
import '../models/daily_nutrition.dart';
import '../providers/showcase_data_provider.dart';
import 'athlete/athlete_state_engine.dart';

/// Comprehensive Showcase Mode Service providing rich, deterministic showcase data
/// allowing recruiters, reviewers, and athletes to instantly explore Atlas
/// without requiring account registration, cloud credentials, or manual setup.
class ShowcaseModeService {
  static ShowcaseModeService? _instance;
  bool _isShowcaseModeEnabled = false;

  ShowcaseModeService();

  static ShowcaseModeService get instance =>
      _instance ??= ShowcaseModeService();

  static void resetInstance() {
    _instance = null;
  }

  bool get isShowcaseMode => _isShowcaseModeEnabled;
  bool get isDemoMode => _isShowcaseModeEnabled;

  void enableShowcaseMode() {
    _isShowcaseModeEnabled = true;
  }

  void enableDemoMode() {
    _isShowcaseModeEnabled = true;
  }

  void disableShowcaseMode() {
    _isShowcaseModeEnabled = false;
  }

  void disableDemoMode() {
    _isShowcaseModeEnabled = false;
  }

  /// Showcase Athlete Profile: Advanced Powerbuilder
  UserProfile getShowcaseUserProfile() =>
      ShowcaseDataProvider.instance.getShowcaseUserProfile();

  /// 48 Historical workout sessions totaling 580,000 kg volume and verified PRs
  List<WorkoutHistory> getShowcaseWorkoutHistory() =>
      ShowcaseDataProvider.instance.getShowcaseWorkoutHistory();

  /// Showcase User Progress
  UserProgress getShowcaseUserProgress() =>
      ShowcaseDataProvider.instance.getShowcaseUserProgress();

  /// Showcase Achievement Badges
  List<AchievementBadge> getShowcaseBadges() =>
      ShowcaseDataProvider.instance.getShowcaseBadges();

  /// Showcase Community Feed Posts
  List<ActivityPost> getShowcaseCommunityPosts() =>
      ShowcaseDataProvider.instance.getShowcaseCommunityPosts();

  /// Showcase Nutrition Meals
  List<MealEntry> getShowcaseMeals() =>
      ShowcaseDataProvider.instance.getShowcaseMeals();

  /// Daily nutrition model reflecting 2,153 kcal and 142g protein
  DailyNutrition getShowcaseDailyNutrition() =>
      ShowcaseDataProvider.instance.getShowcaseDailyNutrition();

  /// Showcase 7-day Sleep History
  List<SleepRecord> getShowcaseSleepHistory() =>
      ShowcaseDataProvider.instance.getShowcaseSleepHistory();

  /// Showcase Latest Night's Sleep Record
  SleepRecord getShowcaseLatestSleep() =>
      ShowcaseDataProvider.instance.getShowcaseLatestSleep();

  /// Showcase Recovery Insight (Factual Telemetry Interpretation)
  RecoveryInsight getShowcaseRecoveryInsight() =>
      ShowcaseDataProvider.instance.getShowcaseRecoveryInsight();

  /// Health and biometric recovery telemetry
  HealthMetrics getShowcaseHealthMetrics() =>
      ShowcaseDataProvider.instance.getShowcaseHealthMetrics();

  /// Training readiness state (76% readiness, 28% fatigue)
  TrainingState getShowcaseTrainingState() =>
      ShowcaseDataProvider.instance.getShowcaseTrainingState();

  /// Recovery state (88% recovery score)
  RecoveryState getShowcaseRecoveryState() =>
      ShowcaseDataProvider.instance.getShowcaseRecoveryState();

  /// 6-month weight trends
  WeightTrendSummary getShowcaseWeightTrendSummary() =>
      ShowcaseDataProvider.instance.getShowcaseWeightTrendSummary();

  /// Showcase Scanned Food Item
  FoodScanResult getShowcaseFoodScan() =>
      ShowcaseDataProvider.instance.getShowcaseFoodScan();

  /// Showcase AI Recommendations
  List<Recommendation> getShowcaseRecommendations() =>
      ShowcaseDataProvider.instance.getShowcaseRecommendations();

  /// Showcase AI Coach Conversations
  List<CoachMessage> getShowcaseAIConversations() =>
      ShowcaseDataProvider.instance.getShowcaseAIConversations();

  /// Full Showcase FitnessContext for AI Coach and Dashboard
  FitnessContext getShowcaseFitnessContext() =>
      ShowcaseDataProvider.instance.getShowcaseFitnessContext();

  /// Full Digital Athlete twin model for showcase presentation
  DigitalAthlete getShowcaseDigitalAthlete() =>
      ShowcaseDataProvider.instance.getShowcaseDigitalAthlete();

  /// One-click loader initializing the full Showcase Mode state in local storage
  Future<void> loadDemoAthleteMode() async {
    enableShowcaseMode();
    AthleteStateEngine.instance.setAthlete(getShowcaseDigitalAthlete());
    await LocalStorage.saveUserProfile(getShowcaseUserProfile());
    debugPrint(
      '[ShowcaseModeService] Showcase Athlete Mode activated successfully!',
    );
  }

  // Backwards compatibility aliases
  UserProfile getDemoUserProfile() => getShowcaseUserProfile();
  List<WorkoutHistory> getDemoWorkoutHistory() => getShowcaseWorkoutHistory();
  List<AchievementBadge> getDemoBadges() => getShowcaseBadges();
  List<ActivityPost> getDemoCommunityPosts() => getShowcaseCommunityPosts();
  List<MealEntry> getDemoMeals() => getShowcaseMeals();
  FoodScanResult getDemoFoodScan() => getShowcaseFoodScan();
  List<CoachMessage> getDemoAIConversations() => getShowcaseAIConversations();
  FitnessContext getDemoFitnessContext() => getShowcaseFitnessContext();
  DigitalAthlete getDemoDigitalAthlete() => getShowcaseDigitalAthlete();
}
