import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local_storage.dart';
import '../../models/activity_record.dart';
import '../../models/daily_nutrition.dart';
import '../../models/user_goal.dart';
import '../../models/user_profile.dart';
import '../../models/workout_history.dart';
import '../../models/workout_session.dart';
import 'cloud_repositories.dart';
import 'cloud_session.dart';
import 'cloud_sync_queue.dart';

/// Reads the signed-in user's rows. Swappable so tests run offline.
abstract class CloudReader {
  Future<List<Map<String, dynamic>>> fetch(
    String table, {
    required String userColumn,
    required String userId,
    String? orderBy,
    int? limit,
  });
}

class SupabaseCloudReader implements CloudReader {
  const SupabaseCloudReader();

  @override
  Future<List<Map<String, dynamic>>> fetch(
    String table, {
    required String userColumn,
    required String userId,
    String? orderBy,
    int? limit,
  }) async {
    final client = CloudSession.client;
    if (client == null) return const [];
    final filtered = client.from(table).select().eq(userColumn, userId);
    final ordered = orderBy == null
        ? filtered
        : filtered.order(orderBy, ascending: false);
    final rows = await (limit == null ? ordered : ordered.limit(limit));
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }
}

/// Keeps local storage and Supabase in step around sign-in.
///
/// On sign-in: upload what this device already has (once per account), push
/// the outbox, then pull the account's data so a new device is restored.
/// Records with unsynced local edits are never overwritten by a pull.
class CloudSyncCoordinator {
  static CloudSyncCoordinator? _instance;
  static CloudSyncCoordinator get instance =>
      _instance ??= CloudSyncCoordinator();
  static void setInstance(CloudSyncCoordinator c) => _instance = c;
  static void resetInstance() => _instance = null;

  static const int nutritionDaysToSync = 90;

  final CloudSyncQueue _queue;
  final CloudReader _reader;

  CloudSyncCoordinator({CloudSyncQueue? queue, CloudReader? reader})
    : _queue = queue ?? CloudSyncQueue.instance,
      _reader = reader ?? const SupabaseCloudReader();

  static const String localOwnerKey = 'cloud_local_data_owner';

  /// Runs the full sign-in sync. Returns true when local data changed.
  Future<bool> syncAfterSignIn() async {
    final uid = CloudSession.userId;
    if (uid == null) return false;
    try {
      final switchedAccount = await claimLocalData(uid);
      await uploadLocalSnapshotOnce(uid);
      await _queue.flush();
      final pulled = await pullIntoLocal(uid);
      return switchedAccount || pulled;
    } catch (e) {
      debugPrint('[CloudSyncCoordinator] sync failed: $e');
      return false;
    }
  }

  /// Marks this device's local data as belonging to [uid]. If it belonged to
  /// a different account, that data is cleared first so it is neither shown
  /// to nor uploaded into the new account. Returns true when data was cleared.
  Future<bool> claimLocalData(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(localOwnerKey);
    var cleared = false;
    if (owner != null && owner != uid) {
      await LocalStorage.clearUserData(keep: isDeviceSettingKey);
      cleared = true;
    }
    await prefs.setString(localOwnerKey, uid);
    return cleared;
  }

  /// Keys that describe the device or session rather than the athlete.
  static bool isDeviceSettingKey(String key) =>
      key.startsWith('cloud_') ||
      key.startsWith('sb-') ||
      key.contains('supabase') ||
      key.contains('showcase') ||
      key == 'app_theme_mode' ||
      key == 'has_completed_onboarding' ||
      key == 'is_logged_in' ||
      key == 'app_user_session';

  /// Queues everything stored on this device for [uid], the first time that
  /// account signs in here. Upserts are idempotent, so repeats are harmless.
  Future<void> uploadLocalSnapshotOnce(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final flag = 'cloud_snapshot_uploaded_$uid';
    if (prefs.getBool(flag) == true) return;

    for (final entry in LocalStorage.getWorkoutHistory()) {
      await _queue.enqueue(
        CloudWrite.upsert(CloudTables.workoutHistory, {
          'user_id': uid,
          'id': CloudTables.historyId(entry),
          'completed_at': entry.dateCompleted.toUtc().toIso8601String(),
          'data': entry.toJson(),
        }, keyColumns: 'user_id,id'),
      );
    }
    for (final session in LocalStorage.getWorkoutSessions()) {
      await _queue.enqueue(
        CloudWrite.upsert(CloudTables.workoutSessions, {
          'user_id': uid,
          'id': session.id,
          'started_at': session.startTime.toUtc().toIso8601String(),
          'data': session.toJson(),
        }, keyColumns: 'user_id,id'),
      );
    }
    final today = DateTime.now();
    for (var i = 0; i < nutritionDaysToSync; i++) {
      final date = _dateKey(today.subtract(Duration(days: i)));
      final day = LocalStorage.getDailyNutrition(date);
      if (day.meals.every((m) => m.consumedFoods.isEmpty)) continue;
      await _queue.enqueue(
        CloudWrite.upsert(CloudTables.nutritionDays, {
          'user_id': uid,
          'log_date': date,
          'data': day.toJson(),
        }, keyColumns: 'user_id,log_date'),
      );
    }
    for (final cardio in LocalStorage.getCardioSessions()) {
      await _queue.enqueue(CloudCardioSync.writeFor(uid, cardio));
    }
    final goal = LocalStorage.getGoal();
    if (goal != null) {
      await _queue.enqueue(
        CloudWrite.upsert(CloudTables.fitnessGoals, {
          'user_id': uid,
          'data': goal.toJson(),
        }, keyColumns: 'user_id'),
      );
    }

    await prefs.setBool(flag, true);
  }

  /// Copies the account's cloud data into local storage. Returns true when
  /// anything changed.
  Future<bool> pullIntoLocal(String uid) async {
    final pending = await _queue.pendingRecordKeys();
    bool isPending(String table, List<Object?> key) =>
        pending.contains('$table|${key.join('|')}');
    var changed = false;

    // Workout history: add entries this device does not have yet.
    final historyRows = await _reader.fetch(
      CloudTables.workoutHistory,
      userColumn: 'user_id',
      userId: uid,
      orderBy: 'completed_at',
      limit: 500,
    );
    final localHistory = LocalStorage.getWorkoutHistory();
    final knownHistory = localHistory.map(CloudTables.historyId).toSet();
    for (final row in historyRows) {
      if (knownHistory.contains(row['id'])) continue;
      localHistory.add(WorkoutHistory.fromJson(_data(row)));
      changed = true;
    }
    if (changed) {
      localHistory.sort((a, b) => b.dateCompleted.compareTo(a.dateCompleted));
      await LocalStorage.saveWorkoutHistory(localHistory);
    }

    // Structured sessions: same merge by id.
    final sessionRows = await _reader.fetch(
      CloudTables.workoutSessions,
      userColumn: 'user_id',
      userId: uid,
      orderBy: 'started_at',
      limit: 200,
    );
    final localSessions = LocalStorage.getWorkoutSessions();
    final knownSessions = localSessions.map((s) => s.id).toSet();
    var sessionsChanged = false;
    for (final row in sessionRows) {
      if (knownSessions.contains(row['id'])) continue;
      localSessions.add(WorkoutSession.fromJson(_data(row)));
      sessionsChanged = true;
    }
    if (sessionsChanged) {
      localSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      await LocalStorage.saveWorkoutSessions(localSessions);
      changed = true;
    }

    // Cardio sessions: same merge by id.
    final cardioRows = await _reader.fetch(
      CloudTables.cardioSessions,
      userColumn: 'user_id',
      userId: uid,
      orderBy: 'started_at',
      limit: 500,
    );
    final localCardio = LocalStorage.getCardioSessions();
    final knownCardio = localCardio.map((c) => c.id).toSet();
    var cardioChanged = false;
    for (final row in cardioRows) {
      if (knownCardio.contains(row['id'])) continue;
      localCardio.add(CardioSession.fromJson(_data(row)));
      cardioChanged = true;
    }
    if (cardioChanged) {
      localCardio.sort((a, b) => b.startTime.compareTo(a.startTime));
      await LocalStorage.saveCardioSessions(localCardio);
      changed = true;
    }

    // Nutrition days: the cloud copy wins unless this device has unsynced edits.
    final nutritionRows = await _reader.fetch(
      CloudTables.nutritionDays,
      userColumn: 'user_id',
      userId: uid,
      orderBy: 'log_date',
      limit: nutritionDaysToSync,
    );
    for (final row in nutritionRows) {
      final date = row['log_date']?.toString() ?? '';
      if (date.isEmpty || isPending(CloudTables.nutritionDays, [uid, date])) {
        continue;
      }
      await LocalStorage.saveDailyNutrition(
        DailyNutrition.fromJson(_data(row)),
      );
      changed = true;
    }

    // Goal.
    if (!isPending(CloudTables.fitnessGoals, [uid])) {
      final goalRows = await _reader.fetch(
        CloudTables.fitnessGoals,
        userColumn: 'user_id',
        userId: uid,
      );
      if (goalRows.isNotEmpty) {
        await LocalStorage.saveGoal(UserGoal.fromJson(_data(goalRows.first)));
        changed = true;
      }
    }

    // Profile, with the server-owned subscription tier.
    if (!isPending(CloudTables.profiles, [uid])) {
      final profileRows = await _reader.fetch(
        CloudTables.profiles,
        userColumn: 'id',
        userId: uid,
      );
      if (profileRows.isNotEmpty) {
        final row = profileRows.first;
        final data = _data(row);
        if (data.isNotEmpty) {
          data['subscription'] = row['subscription_tier'] ?? 'Free';
          await LocalStorage.saveUserProfile(UserProfile.fromJson(data));
          changed = true;
        }
      }
    }

    return changed;
  }

  static Map<String, dynamic> _data(Map<String, dynamic> row) {
    final data = row['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
