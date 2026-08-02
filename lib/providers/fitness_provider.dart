import 'package:flutter/foundation.dart';
import '../data/app_dependencies.dart';
import '../data/nutrition_service.dart';
import '../data/profile_provider.dart';
import '../data/workout_service.dart';
import '../models/daily_nutrition.dart';
import '../models/user_profile.dart';
import '../models/workout_history.dart';

/// Central reactive AppState / FitnessProvider using Flutter's native ChangeNotifier.
/// Serves as the single source of truth for reactive data binding across
/// bottom navigation tabs and screens without requiring tab switches or app restarts.
class FitnessProvider extends ChangeNotifier {
  static FitnessProvider? _instance;

  final WorkoutService _workoutService;
  final NutritionService _nutritionService;
  final ProfileProvider _profileProvider;

  List<WorkoutHistory> _workoutHistory = [];
  DailyNutrition? _todayNutrition;
  UserProfile? _profile;

  FitnessProvider._({
    WorkoutService? workoutService,
    NutritionService? nutritionService,
    ProfileProvider? profileProvider,
  })  : _workoutService =
            workoutService ?? AppDependencies.instance.workoutService,
        _nutritionService =
            nutritionService ?? AppDependencies.instance.nutritionService,
        _profileProvider =
            profileProvider ?? AppDependencies.instance.profileProvider {
    _init();
  }

  /// Factory singleton constructor
  factory FitnessProvider({
    WorkoutService? workoutService,
    NutritionService? nutritionService,
    ProfileProvider? profileProvider,
  }) {
    _instance ??= FitnessProvider._(
      workoutService: workoutService,
      nutritionService: nutritionService,
      profileProvider: profileProvider,
    );
    return _instance!;
  }

  /// Global static accessor
  static FitnessProvider get instance => FitnessProvider();

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

  // --- Refresh Methods ---

  /// Refresh workout history from local storage and notify all listening screens
  void refreshWorkoutHistory() {
    _workoutHistory = _workoutService.getWorkoutHistory();
    notifyListeners();
  }

  /// Refresh nutrition data from local storage and notify all listening screens
  void refreshNutrition() {
    _todayNutrition = _nutritionService.getDailyNutrition();
    notifyListeners();
  }

  /// Refresh user profile from storage and notify all listening screens
  void refreshProfile() {
    _profileProvider.reload();
    _profile = _profileProvider.userProfile;
    notifyListeners();
  }

  /// Refresh all fitness app state and notify listeners
  void refreshAll() {
    _reloadAllData();
    notifyListeners();
  }

  // --- Mutation Pipelines ---

  /// Record completed workout, persist to LocalStorage, and notify listeners
  Future<void> saveWorkoutCompletion(WorkoutHistory entry) async {
    await _workoutService.saveWorkoutCompletion(entry);
    refreshWorkoutHistory();
  }

  /// Save daily nutrition update, persist to LocalStorage, and notify listeners
  Future<void> saveDailyNutrition(DailyNutrition nutrition) async {
    await _nutritionService.saveDailyNutrition(nutrition);
    refreshNutrition();
  }

  /// Toggle meal completion, persist to LocalStorage, and notify listeners
  Future<void> toggleMealCompletion(String mealId) async {
    await _nutritionService.toggleMealCompletion(mealId: mealId);
    refreshNutrition();
  }

  /// Update user profile, persist to LocalStorage, and notify listeners
  Future<void> updateProfile(UserProfile newProfile) async {
    await _profileProvider.updateProfile(newProfile);
    refreshProfile();
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }
}
