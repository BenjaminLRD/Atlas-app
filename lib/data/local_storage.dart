import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/user_progress.dart';
import '../models/notification_model.dart';
import '../models/chat_message.dart';
import '../models/active_workout_session.dart';
import '../models/workout_history.dart';
import '../models/daily_nutrition.dart';
import '../models/macro_target.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_log.dart';
import '../models/nutrition_progress.dart';
import '../models/user_goal.dart';
import '../models/weekly_challenge.dart';
import '../models/coach_message.dart';
import '../models/app_user.dart';
import '../models/connected_device.dart';
import '../models/subscription.dart';
import '../models/user_role.dart';
import '../models/gym.dart';
import '../models/trainer_profile.dart';
import '../models/coach_note.dart';

class LocalStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Pre-populate user profile, notifications, and user progress if they do not exist
    if (_prefs?.getString('user_profile') == null) {
      await saveUserProfile(_getDefaultProfile());
    }
    if (_prefs?.getString('notifications_list') == null) {
      await saveNotifications(_getDefaultNotifications());
    }
    if (_prefs?.getString('user_progress') == null) {
      await saveUserProgress(UserProgress.initial());
    }
  }

  // --- User Gamification & Progress ---
  static UserProgress getUserProgress() {
    final str = _prefs?.getString('user_progress');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return UserProgress.fromJson(decoded);
      } catch (_) {}
    }
    return UserProgress.initial();
  }

  static Future<void> saveUserProgress(UserProgress progress) async {
    await _prefs?.setString('user_progress', jsonEncode(progress.toJson()));
  }

  // --- Protein Nutrition ---
  static double getProteinConsumed() {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final todayVal = _prefs?.getDouble('protein_consumed_$todayStr');
    if (todayVal != null) {
      return todayVal;
    }
    final lastDate = _prefs?.getString('protein_last_date');
    if (lastDate == todayStr) {
      return _prefs?.getDouble('protein_consumed') ?? 0.0;
    }
    return 0.0;
  }

  static double getProteinGoal() {
    return _prefs?.getDouble('protein_goal') ?? 140.0;
  }

  static Future<void> saveProteinConsumed(double val) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    await _prefs?.setString('protein_last_date', todayStr);
    await _prefs?.setDouble('protein_consumed', val);
    await _prefs?.setDouble('protein_consumed_$todayStr', val);
  }

  static Future<void> saveProteinGoal(double val) async {
    await _prefs?.setDouble('protein_goal', val);
  }

  // --- Daily Nutrition & Macros ---
  static DailyNutrition getDailyNutrition(String date) {
    final str = _prefs?.getString('nutrition_daily_$date');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return DailyNutrition.fromJson(decoded);
      } catch (_) {
        return DailyNutrition.defaultForDate(date, getMacroTarget());
      }
    }
    return DailyNutrition.defaultForDate(date, getMacroTarget());
  }

  static Future<void> saveDailyNutrition(DailyNutrition dailyNutrition) async {
    await _prefs?.setString('nutrition_daily_${dailyNutrition.date}', jsonEncode(dailyNutrition.toJson()));
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (dailyNutrition.date == todayStr) {
      await saveProteinConsumed(dailyNutrition.totalProteinConsumed);
    }
  }

  static MacroTarget getMacroTarget() {
    final str = _prefs?.getString('macro_target');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return MacroTarget.fromJson(decoded);
      } catch (_) {
        return MacroTarget.defaultTarget();
      }
    }
    return MacroTarget.defaultTarget();
  }

  static Future<void> saveMacroTarget(MacroTarget target) async {
    await _prefs?.setString('macro_target', jsonEncode(target.toJson()));
    await saveProteinGoal(target.proteinGrams);
  }

  // --- Workout Session ---
  static ActiveWorkoutSession? getActiveSession() {
    final str = _prefs?.getString('active_workout_session');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return ActiveWorkoutSession.fromJson(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> saveActiveSession(dynamic session) async {
    if (session is ActiveWorkoutSession) {
      await _prefs?.setString('active_workout_session', jsonEncode(session.toJson()));
    } else if (session is Map<String, dynamic>) {
      await _prefs?.setString('active_workout_session', jsonEncode(session));
    }
  }

  static Future<void> clearActiveSession() async {
    await _prefs?.remove('active_workout_session');
  }

  // --- Workout History ---
  static List<WorkoutHistory> getWorkoutHistory() {
    final str = _prefs?.getString('workout_history');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map((e) => WorkoutHistory.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static Future<void> saveWorkoutCompletion(WorkoutHistory entry) async {
    final history = getWorkoutHistory()..add(entry);
    await _prefs?.setString(
      'workout_history',
      jsonEncode(history.map((e) => e.toJson()).toList()),
    );
  }

  // --- Auth State ---
  static bool isLoggedIn() {
    return _prefs?.getBool('is_logged_in') ?? false;
  }

  static Future<void> setLoggedIn(bool value) async {
    await _prefs?.setBool('is_logged_in', value);
  }

  // --- Theme Mode ---
  static String getThemeModeString() {
    return _prefs?.getString('app_theme_mode') ?? 'system';
  }

  static Future<void> saveThemeModeString(String mode) async {
    await _prefs?.setString('app_theme_mode', mode);
  }

  static bool getBool(String key, {bool defaultValue = true}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  static Future<void> saveBool(String key, bool val) async {
    await _prefs?.setBool(key, val);
  }

  static Future<void> clearAll() async {
    await _prefs?.clear();
  }

  // --- UI User Profile ---
  static UserProfile getUserProfile() {
    final str = _prefs?.getString('user_profile');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return UserProfile.fromJson(decoded);
      } catch (_) {
        return _getDefaultProfile();
      }
    }
    return _getDefaultProfile();
  }

  static Future<void> saveUserProfile(dynamic profile) async {
    if (profile is UserProfile) {
      await _prefs?.setString('user_profile', jsonEncode(profile.toJson()));
    } else if (profile is Map<String, dynamic>) {
      await _prefs?.setString('user_profile', jsonEncode(profile));
    }
  }

  static UserProfile _getDefaultProfile() {
    return UserProfile.defaultProfile();
  }

  // --- Notifications ---
  static List<NotificationModel> getNotificationModels() {
    final str = _prefs?.getString('notifications_list');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return _getDefaultNotifications();
      }
    }
    return _getDefaultNotifications();
  }

  static List<Map<String, dynamic>> getNotifications() {
    return getNotificationModels().map((e) => e.toJson()).toList();
  }

  static Future<void> saveNotifications(dynamic list) async {
    if (list is List<NotificationModel>) {
      final jsonList = list.map((e) => e.toJson()).toList();
      await _prefs?.setString('notifications_list', jsonEncode(jsonList));
    } else if (list is List) {
      final jsonList = list.map((e) {
        if (e is NotificationModel) return e.toJson();
        if (e is Map<String, dynamic>) return e;
        return NotificationModel.fromJson(Map<String, dynamic>.from(e as Map)).toJson();
      }).toList();
      await _prefs?.setString('notifications_list', jsonEncode(jsonList));
    }
  }

  static List<NotificationModel> _getDefaultNotifications() {
    return [
      NotificationModel(
        id: '1',
        title: 'Workout Reminder',
        body: 'Your Wednesday leg workout protocol begins in 30 minutes! Get ready.',
        timestamp: '10 mins ago',
        isRead: false,
      ),
      NotificationModel(
        id: '2',
        title: 'Protein Goal Reached',
        body: 'Impressive! You just reached your target consumption profile of 140g today.',
        timestamp: '2 hours ago',
        isRead: false,
      ),
      NotificationModel(
        id: '3',
        title: 'Weekly Progress Report',
        body: 'Consistency score increased by 12%! Your analytics chart has been generated.',
        timestamp: '1 day ago',
        isRead: false,
      ),
      NotificationModel(
        id: '4',
        title: 'New Workout Generated',
        body: 'AI Coach suggested a mobility block replacement for Goblet Squats.',
        timestamp: '2 days ago',
        isRead: true,
      ),
      NotificationModel(
        id: '5',
        title: 'Subscription Renewal',
        body: 'Your Pro plan will renew automatically on July 15th.',
        timestamp: '4 days ago',
        isRead: true,
      ),
      NotificationModel(
        id: '6',
        title: 'Personal Best Achieved',
        body: 'High intensity volume squat record unlocked: 120kg!',
        timestamp: '1 week ago',
        isRead: true,
      ),
    ];
  }

  // --- AI Chat History ---
  static List<ChatMessage> getChatHistoryModels() {
    final str = _prefs?.getString('chat_history');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return _getDefaultChat();
      }
    }
    return _getDefaultChat();
  }

  static List<Map<String, dynamic>> getChatHistory() {
    return getChatHistoryModels().map((e) => e.toJson()).toList();
  }

  static Future<void> saveChatHistory(dynamic history) async {
    if (history is List<ChatMessage>) {
      final jsonList = history.map((e) => e.toJson()).toList();
      await _prefs?.setString('chat_history', jsonEncode(jsonList));
    } else if (history is List) {
      final jsonList = history.map((e) {
        if (e is ChatMessage) return e.toJson();
        if (e is Map<String, dynamic>) return e;
        return ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)).toJson();
      }).toList();
      await _prefs?.setString('chat_history', jsonEncode(jsonList));
    }
  }

  static List<ChatMessage> _getDefaultChat() {
    return [
      ChatMessage(
        sender: 'bot',
        text: "I've reviewed your biometric data from yesterday's recovery cycle. Your heart rate variability is up by 8%, suggesting you're ready for a higher-intensity session today.",
        tags: ['High Intensity Recommended', 'Restorative Focus'],
      ),
      ChatMessage(
        sender: 'user',
        text: "Thanks, Coach. I'm feeling a bit tight in my hip flexors after sitting all day. Should I adjust the warmup?",
      ),
      ChatMessage(
        sender: 'bot',
        text: 'Absolutely. Let\'s integrate 5 minutes of "90/90 Hip Switches" and "Pigeon Pose" into your session. Precision in mobility prevents injury in performance.',
        routineCard: true,
      ),
      ChatMessage(
        sender: 'bot',
        text: "Also, don't forget your post-workout hydration. Since today's session is more intense, aim for 20g of clean protein within 45 minutes of finishing to maximize muscle protein synthesis.",
      ),
    ];
  }

  // --- AI Coach Conversation ---
  static List<CoachMessage> getCoachMessages() {
    final str = _prefs?.getString('coach_conversation_messages');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map((e) => CoachMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveCoachMessages(List<CoachMessage> messages) async {
    final jsonList = messages.map((e) => e.toJson()).toList();
    await _prefs?.setString('coach_conversation_messages', jsonEncode(jsonList));
  }

  static Future<void> clearCoachMessages() async {
    await _prefs?.remove('coach_conversation_messages');
  }

  // --- Reward Pipeline Persistence ---
  static List<String> getProcessedRewardIds() {
    return _prefs?.getStringList('processed_reward_ids') ?? [];
  }

  static Future<void> saveProcessedRewardIds(List<String> ids) async {
    await _prefs?.setStringList('processed_reward_ids', ids);
  }

  // --- Weekly Challenges Persistence ---
  static List<WeeklyChallenge> getWeeklyChallenges() {
    final str = _prefs?.getString('weekly_challenges');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map((e) => WeeklyChallenge.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static Future<void> saveWeeklyChallenges(List<WeeklyChallenge> challenges) async {
    final jsonList = challenges.map((e) => e.toJson()).toList();
    await _prefs?.setString('weekly_challenges', jsonEncode(jsonList));
  }

  // --- NutritionLog Persistence ---
  static List<NutritionLog> getNutritionLogHistory() {
    final str = _prefs?.getString('nutrition_log_history');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map((e) => NutritionLog.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static Future<void> saveNutritionLog(NutritionLog log) async {
    final history = getNutritionLogHistory();
    final index = history.indexWhere((item) => item.id == log.id);
    if (index >= 0) {
      history[index] = log;
    } else {
      history.insert(0, log);
    }
    final jsonList = history.map((e) => e.toJson()).toList();
    await _prefs?.setString('nutrition_log_history', jsonEncode(jsonList));
  }

  static NutritionLog getTodayNutritionLog() {
    final history = getNutritionLogHistory();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    for (final item in history) {
      final itemDateStr = item.date.toIso8601String().split('T')[0];
      if (itemDateStr == todayStr) {
        return item;
      }
    }

    // Default template meals for a new day log
    return NutritionLog(
      id: 'log_$todayStr',
      date: DateTime.now(),
      meals: [
        MealEntry(id: 'meal_breakfast', mealType: MealCategory.breakfast, timeLabel: '8:00 AM'),
        MealEntry(id: 'meal_lunch', mealType: MealCategory.lunch, timeLabel: '1:00 PM'),
        MealEntry(id: 'meal_dinner', mealType: MealCategory.dinner, timeLabel: '7:30 PM'),
        MealEntry(id: 'meal_snack', mealType: MealCategory.snack, timeLabel: '4:00 PM'),
      ],
    );
  }

  // --- Nutrition Gamification & Progress ---
  static NutritionProgress getNutritionProgress() {
    final str = _prefs?.getString('nutrition_progress');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return NutritionProgress.fromJson(decoded);
      } catch (_) {}
    }
    return NutritionProgress.initial();
  }

  static Future<void> saveNutritionProgress(NutritionProgress progress) async {
    await _prefs?.setString('nutrition_progress', jsonEncode(progress.toJson()));
  }

  // --- User Fitness Goals ---
  static UserGoal? getGoal() {
    final str = _prefs?.getString('user_goal');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return UserGoal.fromJson(decoded);
      } catch (_) {}
    }
    return null;
  }

  static Future<void> saveGoal(UserGoal goal) async {
    await _prefs?.setString('user_goal', jsonEncode(goal.toJson()));
  }

  static Future<void> clearGoal() async {
    await _prefs?.remove('user_goal');
  }

  static bool isGoalOnboardingCompleted() {
    return _prefs?.getBool('is_goal_onboarding_completed') ?? false;
  }

  static Future<void> setGoalOnboardingCompleted(bool completed) async {
    await _prefs?.setBool('is_goal_onboarding_completed', completed);
  }

  // --- App User Identity & Auth Session ---
  static AppUser? getAppUser() {
    final str = _prefs?.getString('app_user_session');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return AppUser.fromJson(decoded);
      } catch (_) {}
    }
    return null;
  }

  static Future<void> saveAppUser(AppUser user) async {
    await _prefs?.setString('app_user_session', jsonEncode(user.toJson()));
  }

  static Future<void> clearAppUser() async {
    await _prefs?.remove('app_user_session');
  }

  // --- Wearable Health Integration Persistence ---
  static List<ConnectedDevice> getConnectedDevices() {
    final str = _prefs?.getString('connected_wearable_devices');
    if (str != null) {
      try {
        final List<dynamic> list = jsonDecode(str);
        return list
            .map((e) => ConnectedDevice.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return [
      const ConnectedDevice(
        id: 'dev_apple',
        name: 'Apple Health (Watch Ultra)',
        type: 'apple_health',
        isConnected: false,
        iconName: 'apple',
      ),
      const ConnectedDevice(
        id: 'dev_gfit',
        name: 'Google Fit (Pixel Watch 2)',
        type: 'google_fit',
        isConnected: false,
        iconName: 'google',
      ),
      const ConnectedDevice(
        id: 'dev_fitbit',
        name: 'Fitbit Charge 6',
        type: 'fitbit',
        isConnected: false,
        iconName: 'fitbit',
      ),
      const ConnectedDevice(
        id: 'dev_garmin',
        name: 'Garmin Forerunner 265',
        type: 'garmin',
        isConnected: false,
        iconName: 'garmin',
      ),
    ];
  }

  static Future<void> saveConnectedDevices(List<ConnectedDevice> devices) async {
    final jsonList = devices.map((d) => d.toJson()).toList();
    await _prefs?.setString('connected_wearable_devices', jsonEncode(jsonList));
  }

  // --- Subscription & Premium Access Persistence ---
  static Subscription getSubscription({String userId = 'usr_local'}) {
    final str = _prefs?.getString('user_subscription');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return Subscription.fromJson(decoded);
      } catch (_) {}
    }
    return Subscription.free(userId: userId);
  }

  static Future<void> saveSubscription(Subscription subscription) async {
    await _prefs?.setString('user_subscription', jsonEncode(subscription.toJson()));
  }

  static Future<void> clearSubscription() async {
    await _prefs?.remove('user_subscription');
  }

  // --- Trainer & Gym Management Persistence ---
  static UserRole getUserRole() {
    final str = _prefs?.getString('user_role');
    return UserRoleExtension.fromString(str);
  }

  static Future<void> saveUserRole(UserRole role) async {
    await _prefs?.setString('user_role', role.roleKey);
  }

  static Gym getGym() {
    final str = _prefs?.getString('gym_info');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return Gym.fromJson(decoded);
      } catch (_) {}
    }
    return Gym.defaultGym();
  }

  static Future<void> saveGym(Gym gym) async {
    await _prefs?.setString('gym_info', jsonEncode(gym.toJson()));
  }

  static TrainerProfile getTrainerProfile() {
    final str = _prefs?.getString('trainer_profile');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return TrainerProfile.fromJson(decoded);
      } catch (_) {}
    }
    return TrainerProfile.defaultTrainer();
  }

  static Future<void> saveTrainerProfile(TrainerProfile profile) async {
    await _prefs?.setString('trainer_profile', jsonEncode(profile.toJson()));
  }

  static List<CoachNote> getCoachNotes({String? memberId}) {
    final str = _prefs?.getString('coach_notes_list');
    List<CoachNote> notes = [];
    if (str != null) {
      try {
        final List<dynamic> list = jsonDecode(str);
        notes = list
            .map((e) => CoachNote.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    if (notes.isEmpty) {
      notes = [
        CoachNote(
          id: 'note_1',
          trainerId: 'tp_01',
          memberId: memberId ?? 'usr_local',
          noteText: 'Great form on barbell back squats today. Increased working set weight by +5kg.',
          category: 'training',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        CoachNote(
          id: 'note_2',
          trainerId: 'tp_01',
          memberId: memberId ?? 'usr_local',
          noteText: 'Targeting +25g protein intake post-workout for recovery.',
          category: 'nutrition',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];
    }
    if (memberId != null) {
      return notes.where((n) => n.memberId == memberId).toList();
    }
    return notes;
  }

  static Future<void> saveCoachNote(CoachNote note) async {
    final notes = getCoachNotes();
    notes.insert(0, note);
    final jsonList = notes.map((n) => n.toJson()).toList();
    await _prefs?.setString('coach_notes_list', jsonEncode(jsonList));
  }

  // --- Offline Action Queue Persistence ---
  static List<Map<String, dynamic>> getOfflineQueue() {
    final str = _prefs?.getString('offline_actions_queue');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveOfflineQueue(List<Map<String, dynamic>> queue) async {
    await _prefs?.setString('offline_actions_queue', jsonEncode(queue));
  }
}
