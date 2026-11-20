import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/user_progress.dart';
import '../models/user_xp.dart';
import '../models/notification_model.dart';
import '../models/active_workout_session.dart';
import '../models/workout_history.dart';
import '../models/workout_session.dart';
import '../models/daily_nutrition.dart';
import '../models/macro_target.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_log.dart';
import '../models/nutrition_totals.dart';
import '../models/nutrition_progress.dart';
import '../models/user_goal.dart';
import '../models/weekly_challenge.dart';
import '../models/coach_message.dart';
import '../models/app_user.dart';
import '../models/connected_device.dart';
import '../models/subscription.dart';
import '../models/user_role.dart';
import '../models/user_equipment_profile.dart';
import '../models/weight_goal.dart';
import '../models/activity_record.dart';
import '../models/activity_post.dart';
import '../models/post_comment.dart';
import '../models/sleep_record.dart';
import '../models/health_metric.dart';
import '../models/health_metrics.dart';
import '../models/recovery/recovery_report.dart';
import '../services/storage/secure_storage_service.dart';
import '../services/storage/secure_storage_migration.dart';

class LocalStorage {
  static SharedPreferences? _prefs;
  static SecureStorageService _secureStorage = SecureStorageService.instance;

  // In-memory decrypted cache for fast synchronous access
  static AppUser? _cachedAppUser;
  static HealthMetric? _cachedHealthMetric;
  static UserProfile? _cachedUserProfile;
  static List<ActivityRecord>? _cachedActivityRecords;

  /// Sets custom SecureStorageService instance (useful for unit tests).
  static void setSecureStorage(SecureStorageService storage) {
    _secureStorage = storage;
  }

  // --- Corruption-safe reads and writes ---
  // A damaged value is never discarded silently: its raw text is copied to
  // `<key>.corrupt.<timestamp>` before the key is overwritten. Backups are
  // never rewritten by normal saves and are removed with the rest of the
  // user data (clearUserData / clearAll).
  static const String _corruptMarker = '.corrupt.';

  /// Parses a JSON array of independent records one entry at a time. Valid
  /// records are kept; [damaged] is true when the value was not a JSON array
  /// or any entry could not be read. A missing value is simply empty.
  static ({List<T> records, bool damaged}) _decodeRecords<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final records = <T>[];
    if (raw == null) return (records: records, damaged: false);
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return (records: records, damaged: true);
    }
    if (decoded is! List) return (records: records, damaged: true);
    var damaged = false;
    for (final entry in decoded) {
      try {
        records.add(fromJson(Map<String, dynamic>.from(entry as Map)));
      } catch (_) {
        damaged = true;
      }
    }
    return (records: records, damaged: damaged);
  }

  /// Copies the stored value of [key] to a corruption key when [isDamaged]
  /// says it cannot be fully read. Call before overwriting [key].
  static Future<void> _preserveIfDamaged(
    String key,
    bool Function(String raw) isDamaged,
  ) async {
    final raw = _prefs?.getString(key);
    if (raw == null || !isDamaged(raw)) return;
    await _backupCorruptRaw(key, raw);
  }

  static Future<void> _backupCorruptRaw(String key, String raw) async {
    final prefs = _prefs;
    if (prefs == null || raw.trim().isEmpty) return;
    final prefix = '$key$_corruptMarker';
    for (final k in prefs.getKeys()) {
      if (k.startsWith(prefix) && prefs.getString(k) == raw) return;
    }
    // The clock can return the same value twice (coarse resolution, calls in
    // the same tick), so step forward until the key is free: a later backup
    // must never replace an earlier one.
    var stamp = DateTime.now().microsecondsSinceEpoch;
    while (prefs.containsKey('$prefix$stamp')) {
      stamp++;
    }
    await prefs.setString('$prefix$stamp', raw);
    debugPrint('LocalStorage: preserved unreadable "$key" before replacing it');
  }

  static Future<void> init({SecureStorageService? secureStorage}) async {
    if (secureStorage != null) {
      _secureStorage = secureStorage;
    }
    _prefs = await SharedPreferences.getInstance();

    if (_prefs != null) {
      if (_prefs!.getKeys().isEmpty) {
        await _secureStorage.clearAllSecure();
      }
      await SecureStorageMigration.run(
        prefs: _prefs!,
        secureStorage: _secureStorage,
      );
    }

    await _loadSecureCache();
    await clearSyncQueueOperations();
    // The canned AI chat history is gone; drop what older builds stored.
    await _prefs?.remove('chat_history');
    // Form reports were only written by a form analysis nothing could start.
    await _prefs?.remove('Atlas_exercise_form_reports');

    // Pre-populate user profile, notifications, user progress, and equipment profile if they do not exist
    if (_cachedUserProfile == null) {
      await saveUserProfile(_getDefaultProfile());
    } else if (UserProfile.isLegacyDemoProfile(_cachedUserProfile!)) {
      await saveUserProfile(_getDefaultProfile());
    }

    if (_prefs?.getString('notifications_list') == null) {
      await saveNotifications(_getDefaultNotifications());
    }
    if (_prefs?.getString('user_progress') == null) {
      await saveUserProgress(UserProgress.initial());
    }
    if (_prefs?.getString('user_equipment_profile') == null) {
      await saveUserEquipmentProfile(UserEquipmentProfile.fullCommercialGym());
    }
    if (_prefs?.getInt('user_step_goal') == null) {
      await saveStepGoal(10000);
    }
    await migrateLegacyCredentials();
  }

  /// Hydrates in-memory cache from hardware-encrypted secure storage.
  static Future<void> _loadSecureCache() async {
    _cachedUserProfile = null;
    _cachedHealthMetric = null;
    _cachedAppUser = null;
    _cachedActivityRecords = null;

    // 1. User Profile
    final profileStr = await _secureStorage.readSecureData('user_profile');
    if (profileStr != null && profileStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(profileStr) as Map<String, dynamic>;
        _cachedUserProfile = UserProfile.fromJson(decoded);
      } catch (_) {
        _cachedUserProfile = null;
        // init() replaces a missing profile with the default one, so keep
        // the unreadable original (in secure storage, where it came from).
        // Secure storage cannot be listed, so one fixed key is used and the
        // first preserved original is never replaced.
        const backupKey = 'user_profile${_corruptMarker}secure';
        if (await _secureStorage.readSecureData(backupKey) == null) {
          await _secureStorage.saveSecureData(backupKey, profileStr);
        }
      }
    } else {
      final rawFromPrefs = _prefs?.getString('user_profile');
      if (rawFromPrefs != null) {
        try {
          final decoded = jsonDecode(rawFromPrefs) as Map<String, dynamic>;
          _cachedUserProfile = UserProfile.fromJson(decoded);
        } catch (_) {
          _cachedUserProfile = null;
          await _backupCorruptRaw('user_profile', rawFromPrefs);
        }
      }
    }

    // 2. Health Metric
    final healthStr = await _secureStorage.readSecureData(
      'user_today_health_metric',
    );
    if (healthStr != null && healthStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(healthStr) as Map<String, dynamic>;
        _cachedHealthMetric = HealthMetric.fromJson(decoded);
      } catch (_) {
        _cachedHealthMetric = null;
      }
    } else {
      final rawHealth = _prefs?.getString('user_today_health_metric');
      if (rawHealth != null) {
        try {
          _cachedHealthMetric = HealthMetric.fromJson(
            jsonDecode(rawHealth) as Map<String, dynamic>,
          );
        } catch (_) {
          _cachedHealthMetric = null;
        }
      }
    }

    // 3. User Session
    final sessionStr = await _secureStorage.readSecureData('app_user_session');
    if (sessionStr != null && sessionStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(sessionStr) as Map<String, dynamic>;
        _cachedAppUser = AppUser.fromJson(decoded);
      } catch (_) {
        _cachedAppUser = null;
      }
    } else {
      final rawSession = _prefs?.getString('app_user_session');
      if (rawSession != null) {
        try {
          _cachedAppUser = AppUser.fromJson(
            jsonDecode(rawSession) as Map<String, dynamic>,
          );
        } catch (_) {
          _cachedAppUser = null;
        }
      }
    }

    // 4. Activity Records
    final activityStr = await _secureStorage.readSecureData(
      'user_activity_records',
    );
    if (activityStr != null && activityStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(activityStr);
        if (decoded is List) {
          _cachedActivityRecords = decoded
              .map((item) {
                if (item is String) {
                  try {
                    return ActivityRecord.fromJson(
                      jsonDecode(item) as Map<String, dynamic>,
                    );
                  } catch (_) {
                    return null;
                  }
                } else if (item is Map) {
                  return ActivityRecord.fromJson(
                    Map<String, dynamic>.from(item),
                  );
                }
                return null;
              })
              .whereType<ActivityRecord>()
              .toList();
        }
      } catch (_) {
        _cachedActivityRecords = null;
      }
    } else {
      final list = _prefs?.getStringList('user_activity_records');
      if (list != null) {
        _cachedActivityRecords = list
            .map((item) {
              try {
                return ActivityRecord.fromJson(
                  jsonDecode(item) as Map<String, dynamic>,
                );
              } catch (_) {
                return null;
              }
            })
            .whereType<ActivityRecord>()
            .toList();
      }
    }
  }

  /// Migrates legacy stored profiles by stripping any stored plaintext passwords
  /// while preserving all user profile data, goals, and active sessions.
  static Future<void> migrateLegacyCredentials() async {
    final rawProfile = _prefs?.getString('user_profile');
    if (rawProfile != null && rawProfile.contains('"password"')) {
      try {
        final decoded = jsonDecode(rawProfile) as Map<String, dynamic>;
        decoded.remove('password');
        final cleanProfile = UserProfile.fromJson(decoded);
        await saveUserProfile(cleanProfile);
      } catch (_) {}
    }
    if (_prefs?.containsKey('user_password') ?? false) {
      await _prefs?.remove('user_password');
    }
  }

  // --- Step Goal & Activity Records ---
  static int getStepGoal() {
    return _prefs?.getInt('user_step_goal') ?? 10000;
  }

  static Future<void> saveStepGoal(int goal) async {
    await _prefs?.setInt('user_step_goal', goal);
  }

  /// The phone step counter's per-day ledger (see StepLedger), as JSON.
  static String? getStepLedgerJson() => _prefs?.getString('step_ledger_v1');

  static Future<void> saveStepLedgerJson(String json) async {
    await _prefs?.setString('step_ledger_v1', json);
  }

  /// Water intake records, day targets and confirmations, as JSON. Real
  /// records only: Showcase Mode keeps its sample hydration in memory.
  static String? getHydrationJson() => _prefs?.getString('hydration_store_v1');

  static Future<void> saveHydrationJson(String json) async {
    await _prefs?.setString('hydration_store_v1', json);
  }

  // --- Cardio recording support ---

  /// Recovery copy of a run or ride that is still being recorded.
  static String? getCardioJournalJson() =>
      _prefs?.getString('cardio_active_session_v1');

  static Future<void> saveCardioJournalJson(String json) async {
    await _prefs?.setString('cardio_active_session_v1', json);
  }

  static Future<void> clearCardioJournal() async {
    await _prefs?.remove('cardio_active_session_v1');
  }

  /// How the athlete chose to hide their route when sharing (a
  /// `RoutePrivacyMode` name).
  static String? getCardioPrivacyMode() =>
      _prefs?.getString('cardio_route_privacy_v1');

  static Future<void> saveCardioPrivacyMode(String mode) async {
    await _prefs?.setString('cardio_route_privacy_v1', mode);
  }

  /// Whether the athlete has seen the note about recording with the screen
  /// locked.
  static bool getCardioBackgroundExplained() =>
      _prefs?.getBool('cardio_background_explained') ?? false;

  static Future<void> setCardioBackgroundExplained() async {
    await _prefs?.setBool('cardio_background_explained', true);
  }

  static List<ActivityRecord> getActivityRecords() {
    return List<ActivityRecord>.from(_cachedActivityRecords ?? []);
  }

  static Future<void> saveActivityRecord(ActivityRecord record) async {
    final existing = getActivityRecords();
    final updated = [record, ...existing.where((r) => r.id != record.id)];
    await saveActivityRecords(updated);
  }

  static Future<void> saveActivityRecords(List<ActivityRecord> records) async {
    _cachedActivityRecords = List<ActivityRecord>.from(records);
    final encoded = jsonEncode(records.map((r) => r.toJson()).toList());
    await _secureStorage.saveSecureData('user_activity_records', encoded);
    await _prefs?.remove('user_activity_records');
  }

  // --- Cardio Sessions ---
  static List<CardioSession> getCardioSessions() {
    final list = _prefs?.getStringList('user_cardio_sessions') ?? [];
    return list
        .map((item) {
          try {
            return CardioSession.fromJson(
              jsonDecode(item) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<CardioSession>()
        .toList();
  }

  static Future<void> saveCardioSession(CardioSession session) async {
    final existing = getCardioSessions();
    final updated = [session, ...existing.where((s) => s.id != session.id)];
    await saveCardioSessions(updated);
  }

  static Future<void> saveCardioSessions(List<CardioSession> sessions) async {
    final encoded = sessions.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs?.setStringList('user_cardio_sessions', encoded);
  }

  // --- Weight Goal Transformation Program ---
  static WeightGoal? getWeightGoal() {
    final str = _prefs?.getString('weight_goal');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return WeightGoal.fromJson(decoded);
      } catch (_) {}
    }
    return null;
  }

  static Future<void> saveWeightGoal(WeightGoal goal) async {
    await _prefs?.setString('weight_goal', jsonEncode(goal.toJson()));
  }

  static Future<void> clearWeightGoal() async {
    await _prefs?.remove('weight_goal');
  }

  // --- User Equipment Profile ---
  static UserEquipmentProfile getUserEquipmentProfile() {
    final str = _prefs?.getString('user_equipment_profile');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return UserEquipmentProfile.fromJson(decoded);
      } catch (_) {}
    }
    return UserEquipmentProfile.fullCommercialGym();
  }

  static Future<void> saveUserEquipmentProfile(
    UserEquipmentProfile profile,
  ) async {
    await _prefs?.setString(
      'user_equipment_profile',
      jsonEncode(profile.toJson()),
    );
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
    // A single object: if the stored one cannot be read, keep its raw value
    // before it is replaced (getUserProgress falls back to initial()).
    await _preserveIfDamaged('user_progress', (raw) {
      try {
        UserProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        return false;
      } catch (_) {
        return true;
      }
    });
    await _prefs?.setString('user_progress', jsonEncode(progress.toJson()));
  }

  // --- Fitness XP & Gamification 2.0 ---
  static UserXP getUserXP({String userId = 'local_user'}) {
    final str =
        _prefs?.getString('user_xp_$userId') ?? _prefs?.getString('user_xp');
    if (str != null) {
      try {
        final decoded = jsonDecode(str) as Map<String, dynamic>;
        return UserXP.fromJson(decoded);
      } catch (_) {}
    }
    // Backward compatibility with legacy totalXP in UserProgress
    final legacyProgress = getUserProgress();
    if (legacyProgress.totalXP > 0) {
      return UserXP(
        userId: userId,
        totalXP: legacyProgress.totalXP,
        currentLevel: UserXP.calculateLevel(legacyProgress.totalXP),
        weeklyXP: legacyProgress.totalXP,
        monthlyXP: legacyProgress.totalXP,
        lastUpdated: DateTime.now(),
      );
    }
    return UserXP.initial(userId: userId);
  }

  static Future<void> saveUserXP(UserXP userXP) async {
    final encoded = jsonEncode(userXP.toJson());
    await _prefs?.setString('user_xp_${userXP.userId}', encoded);
    await _prefs?.setString('user_xp', encoded);
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
  static DailyNutrition getDailyNutrition(String date, {String? userId}) {
    if (userId != null && userId.isNotEmpty && userId != 'usr_local_01') {
      final str = _prefs?.getString('nutrition_daily_${userId}_$date');
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

  static Future<void> saveDailyNutrition(
    DailyNutrition dailyNutrition, {
    String? userId,
  }) async {
    final encoded = jsonEncode(dailyNutrition.toJson());
    if (userId != null && userId.isNotEmpty && userId != 'usr_local_01') {
      await _prefs?.setString(
        'nutrition_daily_${userId}_${dailyNutrition.date}',
        encoded,
      );
    } else {
      await _prefs?.setString(
        'nutrition_daily_${dailyNutrition.date}',
        encoded,
      );
    }
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
      await _prefs?.setString(
        'active_workout_session',
        jsonEncode(session.toJson()),
      );
    } else if (session is Map<String, dynamic>) {
      await _prefs?.setString('active_workout_session', jsonEncode(session));
    }
  }

  static Future<void> clearActiveSession() async {
    await _prefs?.remove('active_workout_session');
  }

  // --- Completed Workout Sessions ---
  static String _workoutSessionsKey(String? userId) =>
      userId != null && userId.isNotEmpty && userId != 'usr_local_01'
      ? 'completed_workout_sessions_$userId'
      : 'completed_workout_sessions';

  static List<WorkoutSession> getWorkoutSessions({String? userId}) {
    final list = _decodeRecords(
      _prefs?.getString(_workoutSessionsKey(userId)),
      WorkoutSession.fromJson,
    ).records;
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  static Future<void> saveWorkoutSession(
    WorkoutSession session, {
    String? userId,
  }) async {
    final sessions = getWorkoutSessions(userId: userId);
    final existingIndex = sessions.indexWhere((s) => s.id == session.id);
    if (existingIndex >= 0) {
      sessions[existingIndex] = session;
    } else {
      sessions.insert(0, session);
    }
    await saveWorkoutSessions(sessions, userId: userId);
  }

  static Future<void> saveWorkoutSessions(
    List<WorkoutSession> sessions, {
    String? userId,
  }) async {
    final encoded = jsonEncode(sessions.map((e) => e.toJson()).toList());
    final key = _workoutSessionsKey(userId);
    await _preserveIfDamaged(
      key,
      (raw) => _decodeRecords(raw, WorkoutSession.fromJson).damaged,
    );
    await _prefs?.setString(key, encoded);
  }

  // --- Workout History ---
  static String _workoutHistoryKey(String? userId) =>
      userId != null && userId.isNotEmpty && userId != 'usr_local_01'
      ? 'workout_history_$userId'
      : 'workout_history';

  static List<WorkoutHistory> _decodeWorkoutHistory(String? raw) {
    final list = _decodeRecords(raw, WorkoutHistory.fromJson).records;
    list.sort((a, b) => b.dateCompleted.compareTo(a.dateCompleted));
    return list;
  }

  static List<WorkoutHistory> getWorkoutHistory({String? userId}) {
    return _decodeWorkoutHistory(_prefs?.getString(_workoutHistoryKey(userId)));
  }

  static Future<void> saveWorkoutCompletion(
    WorkoutHistory entry, {
    String? userId,
  }) async {
    final history = getWorkoutHistory(userId: userId)..insert(0, entry);
    history.sort((a, b) => b.dateCompleted.compareTo(a.dateCompleted));
    await saveWorkoutHistory(history, userId: userId);
  }

  static Future<void> saveWorkoutHistory(
    List<WorkoutHistory> history, {
    String? userId,
  }) async {
    final encoded = jsonEncode(history.map((e) => e.toJson()).toList());
    final key = _workoutHistoryKey(userId);
    await _preserveIfDamaged(
      key,
      (raw) => _decodeRecords(raw, WorkoutHistory.fromJson).damaged,
    );
    await _prefs?.setString(key, encoded);
  }

  // --- Workout rewards still to apply ---
  // A finished workout is saved before its rewards (XP, streak, challenge
  // bonus) are applied. This records which workouts are between those two
  // points, so an interrupted completion can be finished when it is submitted
  // again. Keyed by the completion key; each value holds the saved record and
  // the progress made so far.
  static const String _pendingRewardsKey = 'pending_workout_rewards';

  static Map<String, Map<String, dynamic>> getPendingWorkoutRewards() {
    final raw = _prefs?.getString(_pendingRewardsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map;
      return {
        for (final e in decoded.entries)
          e.key as String: Map<String, dynamic>.from(e.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writePendingWorkoutRewards(
    Map<String, Map<String, dynamic>> pending,
  ) async {
    await _preserveIfDamaged(_pendingRewardsKey, (raw) {
      try {
        return jsonDecode(raw) is! Map;
      } catch (_) {
        return true;
      }
    });
    if (pending.isEmpty) {
      await _prefs?.remove(_pendingRewardsKey);
    } else {
      await _prefs?.setString(_pendingRewardsKey, jsonEncode(pending));
    }
  }

  static Future<void> savePendingWorkoutReward(
    String key,
    Map<String, dynamic> data,
  ) async {
    final pending = getPendingWorkoutRewards()..[key] = data;
    await _writePendingWorkoutRewards(pending);
  }

  static Future<void> clearPendingWorkoutReward(String key) async {
    final pending = getPendingWorkoutRewards();
    if (pending.remove(key) != null) {
      await _writePendingWorkoutRewards(pending);
    }
  }

  // --- Meals already rewarded ---
  // One entry per meal slot per day ("2026-10-17|lunch"), so completing the
  // same meal again, or ticking it off and on, does not pay its XP again.
  static const String _rewardedMealsKey = 'rewarded_meal_completions';

  /// Entries older than this many days are dropped when a new one is added.
  static const int _rewardedMealDays = 30;

  static bool hasRewardedMeal(String key) =>
      (_prefs?.getStringList(_rewardedMealsKey) ?? const []).contains(key);

  static Future<void> markMealRewarded(String key) async {
    final cutoff = DateTime.now().subtract(
      const Duration(days: _rewardedMealDays),
    );
    final keys = (_prefs?.getStringList(_rewardedMealsKey) ?? const []).where((
      k,
    ) {
      final date = DateTime.tryParse(k.split('|').first);
      return date == null || date.isAfter(cutoff);
    }).toList();
    if (!keys.contains(key)) keys.add(key);
    await _prefs?.setStringList(_rewardedMealsKey, keys);
  }

  static Future<void> unmarkMealRewarded(String key) async {
    final keys = List<String>.of(
      _prefs?.getStringList(_rewardedMealsKey) ?? const [],
    )..remove(key);
    await _prefs?.setStringList(_rewardedMealsKey, keys);
  }

  // --- Claimed referral codes ---
  // Codes an athlete has redeemed, so the same code cannot give its XP twice.
  // Kept per account, on this device.
  static String _claimedCodesKey(String userId) =>
      'claimed_referral_codes_$userId';

  static bool hasClaimedReferralCode(String userId, String code) =>
      (_prefs?.getStringList(_claimedCodesKey(userId)) ?? const []).contains(
        code,
      );

  static Future<void> markReferralCodeClaimed(
    String userId,
    String code,
  ) async {
    final codes = List<String>.of(
      _prefs?.getStringList(_claimedCodesKey(userId)) ?? const [],
    );
    if (!codes.contains(code)) codes.add(code);
    await _prefs?.setStringList(_claimedCodesKey(userId), codes);
  }

  static Future<void> unmarkReferralCodeClaimed(
    String userId,
    String code,
  ) async {
    final codes = List<String>.of(
      _prefs?.getStringList(_claimedCodesKey(userId)) ?? const [],
    )..remove(code);
    await _prefs?.setStringList(_claimedCodesKey(userId), codes);
  }

  // --- Saved workout plans ---
  // Workouts the athlete asked to keep for later (for example one the AI
  // coach suggested). They are plans: nothing here counts as a completed
  // workout, and no volume, sets, calories or XP are recorded for them.
  static const String _savedPlansKey = 'saved_workout_plans';

  static List<Map<String, dynamic>> getSavedWorkoutPlans() =>
      _decodeRecords<Map<String, dynamic>>(
        _prefs?.getString(_savedPlansKey),
        (json) => json,
      ).records;

  /// Saves [plan], replacing a plan with the same `id` so saving twice keeps
  /// one copy.
  static Future<void> saveWorkoutPlan(Map<String, dynamic> plan) async {
    final plans = getSavedWorkoutPlans()
      ..removeWhere((p) => p['id'] == plan['id'])
      ..insert(0, plan);
    await _preserveIfDamaged(
      _savedPlansKey,
      (raw) => _decodeRecords<Map<String, dynamic>>(raw, (j) => j).damaged,
    );
    await _prefs?.setString(_savedPlansKey, jsonEncode(plans));
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

  static Future<void> setBool(String key, bool val) async {
    await saveBool(key, val);
  }

  /// Removes the athlete's data but keeps keys for which [keep] returns true
  /// (device settings, the auth session). Used when a different account signs
  /// in on this device.
  static Future<void> clearUserData({
    required bool Function(String key) keep,
  }) async {
    _cachedAppUser = null;
    _cachedHealthMetric = null;
    _cachedUserProfile = null;
    _cachedActivityRecords = null;
    final prefs = _prefs;
    if (prefs == null) return;
    for (final key in prefs.getKeys().toList()) {
      if (!keep(key)) await prefs.remove(key);
    }
  }

  static Future<void> clearAll() async {
    _cachedAppUser = null;
    _cachedHealthMetric = null;
    _cachedUserProfile = null;
    _cachedActivityRecords = null;
    await _secureStorage.clearAllSecure();
    await _prefs?.clear();
  }

  // --- UI User Profile ---
  static UserProfile getUserProfile() {
    return _cachedUserProfile ?? _getDefaultProfile();
  }

  static Future<void> saveUserProfile(dynamic profile) async {
    UserProfile cleanProfile;
    if (profile is UserProfile) {
      cleanProfile = profile;
    } else if (profile is Map<String, dynamic>) {
      final cleanMap = Map<String, dynamic>.from(profile)..remove('password');
      cleanProfile = UserProfile.fromJson(cleanMap);
    } else {
      cleanProfile = _getDefaultProfile();
    }
    _cachedUserProfile = cleanProfile;
    await _secureStorage.saveSecureData(
      'user_profile',
      jsonEncode(cleanProfile.toJson()),
    );
    await _prefs?.remove('user_profile');
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
            .map(
              (e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)),
            )
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
        return NotificationModel.fromJson(
          Map<String, dynamic>.from(e as Map),
        ).toJson();
      }).toList();
      await _prefs?.setString('notifications_list', jsonEncode(jsonList));
    }
  }

  static List<NotificationModel> _getDefaultNotifications() {
    return [
      NotificationModel(
        id: '1',
        title: 'Welcome to Atlas! 🏋️',
        body:
            'Track your workouts, log nutrition, and reach your goals with AI Coach.',
        timestamp: 'Just now',
        isRead: false,
      ),
      NotificationModel(
        id: '2',
        title: 'Weekly Quests Unlocked 🏆',
        body:
            'Complete your workouts this week to earn bonus XP and climb the leaderboard.',
        timestamp: '1 hour ago',
        isRead: false,
      ),
    ];
  }

  // --- AI Coach Conversation ---
  /// Showcase Mode keeps its conversation under its own key, so a demo thread
  /// never lands in (or is read from) a real user's chat history.
  static const String _coachKey = 'coach_conversation_messages';
  static const String _showcaseCoachKey =
      'showcase_coach_conversation_messages';
  static String get _activeCoachKey =>
      isShowcaseModeEnabled() ? _showcaseCoachKey : _coachKey;

  static List<CoachMessage> getCoachMessages() {
    final str = _prefs?.getString(_activeCoachKey);
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map(
              (e) => CoachMessage.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveCoachMessages(List<CoachMessage> messages) async {
    final jsonList = messages.map((e) => e.toJson()).toList();
    await _prefs?.setString(_activeCoachKey, jsonEncode(jsonList));
  }

  static Future<void> clearCoachMessages() async {
    await _prefs?.remove(_activeCoachKey);
  }

  /// Forgets the Showcase conversation (when Showcase Mode starts or ends).
  /// Never touches the real conversation.
  static Future<void> clearShowcaseCoachMessages() async {
    await _prefs?.remove(_showcaseCoachKey);
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

  static Future<void> saveWeeklyChallenges(
    List<WeeklyChallenge> challenges,
  ) async {
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
        MealEntry(
          id: 'meal_breakfast',
          mealType: MealCategory.breakfast,
          timeLabel: '8:00 AM',
        ),
        MealEntry(
          id: 'meal_lunch',
          mealType: MealCategory.lunch,
          timeLabel: '1:00 PM',
        ),
        MealEntry(
          id: 'meal_dinner',
          mealType: MealCategory.dinner,
          timeLabel: '7:30 PM',
        ),
        MealEntry(
          id: 'meal_snack',
          mealType: MealCategory.snack,
          timeLabel: '4:00 PM',
        ),
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
    await _prefs?.setString(
      'nutrition_progress',
      jsonEncode(progress.toJson()),
    );
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

  // --- Initial App Onboarding State ---
  static bool hasCompletedOnboarding() {
    return _prefs?.getBool('has_completed_onboarding') ?? false;
  }

  static Future<void> setCompletedOnboarding(bool completed) async {
    await _prefs?.setBool('has_completed_onboarding', completed);
  }

  static Future<void> resetOnboarding() async {
    await _prefs?.remove('has_completed_onboarding');
  }

  // --- App User Identity & Auth Session ---
  static AppUser? getAppUser() {
    return _cachedAppUser;
  }

  static Future<void> saveAppUser(AppUser user) async {
    final sanitized = UserProfile.sanitizeName(user.displayName);
    final cleaned = sanitized != user.displayName
        ? user.copyWith(displayName: sanitized)
        : user;
    _cachedAppUser = cleaned;
    await _secureStorage.saveSecureData(
      'app_user_session',
      jsonEncode(cleaned.toJson()),
    );
    await _prefs?.remove('app_user_session');
  }

  static Future<void> clearAppUser() async {
    _cachedAppUser = null;
    await _secureStorage.deleteSecureData('app_user_session');
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
    // Watches and rings (Apple Watch, Pixel Watch, Fitbit, Garmin, Oura...)
    // reach Atlas through the phone's health store, so the phone's own store
    // is the one connection to offer.
    const appleHealth = ConnectedDevice(
      id: 'dev_apple',
      name: 'Apple Health',
      type: 'apple_health',
      isConnected: false,
      iconName: 'apple',
    );
    const healthConnect = ConnectedDevice(
      id: 'dev_gfit',
      name: 'Health Connect',
      type: 'google_fit',
      isConnected: false,
      iconName: 'google',
    );
    if (!kIsWeb && Platform.isIOS) return [appleHealth];
    if (!kIsWeb && Platform.isAndroid) return [healthConnect];
    return [appleHealth, healthConnect];
  }

  static Future<void> saveConnectedDevices(
    List<ConnectedDevice> devices,
  ) async {
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
    await _prefs?.setString(
      'user_subscription',
      jsonEncode(subscription.toJson()),
    );
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

  // --- Custom Foods & Food Database Persistence ---
  static List<Map<String, dynamic>> getCustomFoods() {
    final str = _prefs?.getString('custom_foods_list');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveCustomFoods(List<Map<String, dynamic>> foods) async {
    await _prefs?.setString('custom_foods_list', jsonEncode(foods));
  }

  static List<String> getFavoriteFoodIds() {
    return _prefs?.getStringList('favorite_food_ids') ?? [];
  }

  static Future<void> saveFavoriteFoodIds(List<String> ids) async {
    await _prefs?.setStringList('favorite_food_ids', ids);
  }

  static List<String> getRecentFoodIds() {
    return _prefs?.getStringList('recent_food_ids') ?? [];
  }

  static Future<void> saveRecentFoodIds(List<String> ids) async {
    await _prefs?.setStringList('recent_food_ids', ids);
  }

  // --- Scanned Foods & Barcode Cache Persistence ---
  static List<Map<String, dynamic>> getScannedFoods() {
    final str = _prefs?.getString('scanned_foods_list');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveScannedFoods(List<Map<String, dynamic>> foods) async {
    await _prefs?.setString('scanned_foods_list', jsonEncode(foods));
  }

  // --- Community Posts & Feed Persistence ---
  static List<ActivityPost> getCommunityPosts() {
    final str = _prefs?.getString('user_community_posts');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map(
              (e) => ActivityPost.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {}
    }
    return <ActivityPost>[];
  }

  static Future<void> saveCommunityPosts(List<ActivityPost> posts) async {
    // Sample posts are built-in demo content, never the user's own records.
    final jsonList = posts
        .where((p) => !p.isSample)
        .map((e) => e.toJson())
        .toList();
    await _prefs?.setString('user_community_posts', jsonEncode(jsonList));
  }

  /// Ids of sample posts the user liked. Kept apart from the user's own
  /// posts so sample content never mixes into real records.
  static Set<String> getSampleLikedPostIds() =>
      (_prefs?.getStringList('sample_community_liked_ids') ?? const <String>[])
          .toSet();

  static Future<void> setSamplePostLiked(String postId, bool liked) async {
    final ids = getSampleLikedPostIds();
    if (liked ? ids.add(postId) : ids.remove(postId)) {
      await _prefs?.setStringList('sample_community_liked_ids', ids.toList());
    }
  }

  /// Replaces the stored copy of one of the user's own posts (for example
  /// after a like). Sample posts and unknown ids are ignored.
  static Future<void> updateCommunityPost(ActivityPost post) async {
    if (post.isSample) return;
    final posts = getCommunityPosts();
    final idx = posts.indexWhere((p) => p.id == post.id);
    if (idx == -1) return;
    posts[idx] = post;
    await saveCommunityPosts(posts);
  }

  static Future<void> clearCommunityPosts() async {
    await _prefs?.remove('user_community_posts');
  }

  static Future<void> addCommunityPost(ActivityPost post) async {
    final list = List<ActivityPost>.from(getCommunityPosts());
    list.insert(0, post);
    await saveCommunityPosts(list);
  }

  // --- Post Comments Persistence ---
  static List<PostComment> getCommentsForPost(String postId) {
    final str = _prefs?.getString('post_comments_$postId');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map(
              (e) => PostComment.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {}
    }
    return <PostComment>[];
  }

  static Future<void> saveCommentsForPost(
    String postId,
    List<PostComment> comments,
  ) async {
    final jsonList = comments.map((e) => e.toJson()).toList();
    await _prefs?.setString('post_comments_$postId', jsonEncode(jsonList));

    // Also update post in user_community_posts if it is stored there
    final posts = getCommunityPosts();
    final idx = posts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      posts[idx] = posts[idx].copyWith(
        commentsList: comments,
        comments: comments.length,
      );
      await saveCommunityPosts(posts);
    }
  }

  static Future<void> addCommentToPost(
    String postId,
    PostComment comment,
  ) async {
    final list = List<PostComment>.from(getCommentsForPost(postId));
    list.add(comment);
    await saveCommentsForPost(postId, list);
  }

  // --- Saved Posts & Programs Persistence ---
  static List<ActivityPost> getSavedPosts() {
    final str = _prefs?.getString('user_saved_posts');
    if (str != null) {
      try {
        final List<dynamic> decoded = jsonDecode(str);
        return decoded
            .map(
              (e) => ActivityPost.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveSavedPosts(List<ActivityPost> posts) async {
    final jsonList = posts.map((e) => e.toJson()).toList();
    await _prefs?.setString('user_saved_posts', jsonEncode(jsonList));
  }

  // --- Social Following Persistence ---
  static List<String> getFollowingUserIds() {
    return _prefs?.getStringList('user_following_list') ?? [];
  }

  static Future<void> saveFollowingUserIds(List<String> userIds) async {
    await _prefs?.setStringList('user_following_list', userIds);
  }

  // --- Moderation (Blocked Users & Hidden Posts) ---
  static List<String> getBlockedUserIds() {
    return _prefs?.getStringList('user_blocked_users') ?? [];
  }

  static Future<void> saveBlockedUserIds(List<String> userIds) async {
    await _prefs?.setStringList('user_blocked_users', userIds);
  }

  static List<String> getHiddenPostIds() {
    return _prefs?.getStringList('user_hidden_posts') ?? [];
  }

  static Future<void> saveHiddenPostIds(List<String> postIds) async {
    await _prefs?.setStringList('user_hidden_posts', postIds);
  }

  // --- Health Telemetry & Wearables Persistence ---
  static HealthMetric? getHealthMetric() {
    return _cachedHealthMetric;
  }

  static Future<void> saveHealthMetric(HealthMetric metric) async {
    _cachedHealthMetric = metric;
    await _secureStorage.saveSecureData(
      'user_today_health_metric',
      jsonEncode(metric.toJson()),
    );
    await _prefs?.remove('user_today_health_metric');
  }

  static String getConnectedWearableName() {
    return _prefs?.getString('user_connected_wearable') ??
        'Google Health Connect';
  }

  static Future<void> saveConnectedWearableName(String name) async {
    await _prefs?.setString('user_connected_wearable', name);
  }

  // --- Health & Nutrition History Helpers ---
  static List<HealthMetric> getHealthHistory() {
    final today = getHealthMetric();
    return today != null ? [today] : [];
  }

  /// The last 7 days that have consumed nutrition, newest first. Consumed
  /// amounts come from the logged meals in [getNutritionLogHistory]; a day
  /// with nothing logged is left out instead of being counted as zero intake.
  static List<DailyNutrition> getNutritionHistory() {
    final now = DateTime.now();
    final logs = getNutritionLogHistory();
    final list = <DailyNutrition>[];
    for (int i = 0; i < 7; i++) {
      // Calendar arithmetic, so a daylight-saving change cannot skip or
      // repeat a local day.
      final dateStr = DateTime(
        now.year,
        now.month,
        now.day - i,
      ).toIso8601String().split('T')[0];
      final logged = NutritionTotals.fromMeals([
        for (final log in logs)
          if (log.date.toIso8601String().split('T')[0] == dateStr) ...log.meals,
      ]);
      final day = getDailyNutrition(dateStr).withLogged(logged);
      // A day whose only foods have unknown values still has food logged.
      if (day.totalCaloriesConsumed > 0 ||
          day.totalProteinConsumed > 0 ||
          day.totalCarbsConsumed > 0 ||
          day.totalFatConsumed > 0 ||
          day.totalsConsumed.hasUnknownValues) {
        list.add(day);
      }
    }
    return list;
  }

  // --- Sync Queue & Offline Action Persistence ---
  static List<Map<String, dynamic>> getSyncQueueOperations() {
    final str = _prefs?.getString('Atlas_sync_queue_operations');
    if (str != null && str.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(str);
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return [];
  }

  static Future<void> saveSyncQueueOperations(
    List<Map<String, dynamic>> operations,
  ) async {
    await _prefs?.setString(
      'Atlas_sync_queue_operations',
      jsonEncode(operations),
    );
  }

  /// Removes the queue of the retired local sync, which nothing reads or
  /// sends any more. [init] calls it; safe to call again.
  static Future<void> clearSyncQueueOperations() async {
    await _prefs?.remove('Atlas_sync_queue_operations');
  }

  // --- Phase C.2 Health Metrics & Training Readiness ---
  static List<HealthMetrics> getHealthMetricsList({String? userId}) {
    final raw = _prefs?.getStringList('Atlas_health_metrics_history') ?? [];
    final metrics = raw
        .map((str) {
          try {
            return HealthMetrics.fromJson(
              jsonDecode(str) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<HealthMetrics>()
        .toList();

    if (userId != null && userId.isNotEmpty) {
      return metrics.where((m) => m.userId == userId).toList();
    }
    return metrics;
  }

  static HealthMetrics? getTodayHealthMetrics({String? userId}) {
    final all = getHealthMetricsList(userId: userId);
    if (all.isEmpty) return null;
    return all.first;
  }

  static Future<void> saveHealthMetrics(HealthMetrics metric) async {
    final existing = getHealthMetricsList();
    final updated = [metric, ...existing.where((m) => m.id != metric.id)];
    final encoded = updated.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs?.setStringList('Atlas_health_metrics_history', encoded);
  }

  static RecoveryReport? getLatestRecoveryReport({String? userId}) {
    final raw = _prefs?.getString('Atlas_latest_recovery_report');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final report = RecoveryReport.fromJson(decoded);
        if (userId == null || report.userId == userId) {
          return report;
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<void> saveRecoveryReport(RecoveryReport report) async {
    await _prefs?.setString(
      'Atlas_latest_recovery_report',
      jsonEncode(report.toJson()),
    );
  }

  // --- Sleep & Recovery Records Storage ---

  static List<SleepRecord> getSleepRecords({String? userId}) {
    final rawList = _prefs?.getStringList('Atlas_sleep_records_history') ?? [];
    final records = <SleepRecord>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final record = SleepRecord.fromJson(decoded);
        if (userId == null || record.userId == userId) {
          records.add(record);
        }
      } catch (_) {}
    }
    // Sort descending by date (most recent first)
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  static SleepRecord? getLatestSleepRecord({String? userId}) {
    final records = getSleepRecords(userId: userId);
    if (records.isEmpty) return null;
    return records.first;
  }

  static Future<void> saveSleepRecord(SleepRecord record) async {
    final existing = getSleepRecords();
    final updated = [record, ...existing.where((r) => r.id != record.id)];
    final encoded = updated.map((r) => jsonEncode(r.toJson())).toList();
    await _prefs?.setStringList('Atlas_sleep_records_history', encoded);
  }

  static Future<void> clearSleepRecords() async {
    await _prefs?.remove('Atlas_sleep_records_history');
  }

  // --- Wearable Connection State ---

  static bool getIsWearableConnected() =>
      _prefs?.getBool('Atlas_wearable_connected') ?? false;

  static String getConnectedWearableSource() =>
      _prefs?.getString('Atlas_wearable_source') ?? 'Apple Health';

  static Future<void> setWearableConnected(
    bool connected, {
    String source = 'Apple Health',
  }) async {
    await _prefs?.setBool('Atlas_wearable_connected', connected);
    await _prefs?.setString('Atlas_wearable_source', source);
  }

  // --- Showcase Mode Global Toggle ---
  static bool isShowcaseModeEnabled() =>
      _prefs?.getBool('Atlas_showcase_mode_enabled') ?? false;

  static Future<void> setShowcaseModeEnabled(bool enabled) async =>
      await _prefs?.setBool('Atlas_showcase_mode_enabled', enabled);

  static String? getString(String key) => _prefs?.getString(key);
  static Future<void> setString(String key, String val) async =>
      await _prefs?.setString(key, val);
}
