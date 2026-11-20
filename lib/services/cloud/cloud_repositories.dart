import '../../data/local/nutrition_local_repository.dart';
import '../../data/local/profile_local_repository.dart';
import '../../data/local/workout_local_repository.dart';
import '../../data/local_storage.dart';
import '../../models/activity_record.dart';
import '../../models/daily_nutrition.dart';
import '../../models/user_goal.dart';
import '../../models/user_profile.dart';
import '../../models/workout_history.dart';
import '../../models/workout_session.dart';
import '../../repositories/goal_repository.dart';
import 'cloud_session.dart';
import 'cloud_sync_queue.dart';

/// Supabase tables written by the cloud repositories. Each stores the app's
/// own JSON in a `data` column, plus the columns needed for ordering.
/// Schema: supabase/migrations/20261007000000_atlas_baseline.sql.
class CloudTables {
  static const String profiles = 'profiles';
  static const String workoutSessions = 'workout_session_records';
  static const String workoutHistory = 'workout_history_records';
  static const String nutritionDays = 'nutrition_day_records';
  static const String fitnessGoals = 'fitness_goal_records';
  static const String cardioSessions = 'cardio_session_records';

  /// Stable id for a [WorkoutHistory] entry, which has no id of its own.
  static String historyId(WorkoutHistory entry) =>
      entry.dateCompleted.toUtc().microsecondsSinceEpoch.toString();
}

/// Workout repository that saves locally, then queues the same change for
/// Supabase when a user is signed in.
class CloudWorkoutRepository extends WorkoutLocalRepository {
  final CloudSyncQueue _cloud;

  CloudWorkoutRepository({CloudSyncQueue? cloudQueue})
    : _cloud = cloudQueue ?? CloudSyncQueue.instance;

  @override
  Future<void> saveWorkoutSession(
    WorkoutSession session, {
    String userId = 'usr_local_01',
  }) async {
    await super.saveWorkoutSession(session, userId: userId);
    final uid = CloudSession.userId;
    if (uid == null) return;
    await _cloud.enqueue(
      CloudWrite.upsert(CloudTables.workoutSessions, {
        'user_id': uid,
        'id': session.id,
        'started_at': session.startTime.toUtc().toIso8601String(),
        'data': session.toJson(),
      }, keyColumns: 'user_id,id'),
    );
  }

  @override
  Future<void> saveWorkoutCompletion(
    WorkoutHistory entry, {
    String userId = 'usr_local_01',
  }) async {
    await super.saveWorkoutCompletion(entry, userId: userId);
    final uid = CloudSession.userId;
    if (uid == null) return;
    await _cloud.enqueue(
      CloudWrite.upsert(CloudTables.workoutHistory, {
        'user_id': uid,
        'id': CloudTables.historyId(entry),
        'completed_at': entry.dateCompleted.toUtc().toIso8601String(),
        'data': entry.toJson(),
      }, keyColumns: 'user_id,id'),
    );
  }
}

/// Nutrition repository that saves locally, then queues the whole day for
/// Supabase. Food logging and meal toggles both go through
/// [saveDailyNutrition], so they sync too.
class CloudNutritionRepository extends NutritionLocalRepository {
  final CloudSyncQueue _cloud;

  CloudNutritionRepository({CloudSyncQueue? cloudQueue})
    : _cloud = cloudQueue ?? CloudSyncQueue.instance;

  @override
  Future<void> saveDailyNutrition(
    DailyNutrition dailyNutrition, {
    String userId = 'usr_local_01',
  }) async {
    await super.saveDailyNutrition(dailyNutrition, userId: userId);
    final uid = CloudSession.userId;
    if (uid == null) return;
    await _cloud.enqueue(
      CloudWrite.upsert(CloudTables.nutritionDays, {
        'user_id': uid,
        'log_date': dailyNutrition.date,
        'data': dailyNutrition.toJson(),
      }, keyColumns: 'user_id,log_date'),
    );
  }
}

/// Goal repository that saves locally, then mirrors the goal to Supabase.
class CloudGoalRepository extends LocalGoalRepository {
  final CloudSyncQueue _cloud;

  CloudGoalRepository({CloudSyncQueue? cloudQueue})
    : _cloud = cloudQueue ?? CloudSyncQueue.instance;

  @override
  Future<void> saveGoal(UserGoal goal) async {
    await super.saveGoal(goal);
    final uid = CloudSession.userId;
    if (uid == null) return;
    await _cloud.enqueue(
      CloudWrite.upsert(CloudTables.fitnessGoals, {
        'user_id': uid,
        'data': goal.toJson(),
      }, keyColumns: 'user_id'),
    );
  }

  @override
  Future<void> clearGoal() async {
    await super.clearGoal();
    final uid = CloudSession.userId;
    if (uid == null) return;
    await _cloud.enqueue(
      CloudWrite.delete(CloudTables.fitnessGoals, {
        'user_id': uid,
      }, keyColumns: 'user_id'),
    );
  }
}

/// Profile repository that saves locally, then mirrors the profile into the
/// user's `profiles` row. The subscription tier is never sent; the server
/// owns it.
class CloudProfileRepository extends ProfileLocalRepository {
  final CloudSyncQueue _cloud;

  CloudProfileRepository({CloudSyncQueue? cloudQueue})
    : _cloud = cloudQueue ?? CloudSyncQueue.instance;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await super.saveProfile(profile);
    final uid = CloudSession.userId;
    if (uid == null) return;
    final data = profile.toJson()..remove('subscription');
    await _cloud.enqueue(
      CloudWrite.upsert(CloudTables.profiles, {
        'id': uid,
        'email': profile.email,
        'full_name': profile.name,
        'data': data,
      }, keyColumns: 'id'),
    );
  }
}

/// Cardio sessions are saved straight to local storage by the cardio screen;
/// this mirrors each one to Supabase (needed for the Ranked Cardio stat).
class CloudCardioSync {
  CloudCardioSync._();

  static CloudWrite writeFor(String uid, CardioSession session) =>
      CloudWrite.upsert(CloudTables.cardioSessions, {
        'user_id': uid,
        'id': session.id,
        'started_at': session.startTime.toUtc().toIso8601String(),
        'data': session.toJson(),
      }, keyColumns: 'user_id,id');

  /// Saves [session] locally and queues it for the signed-in account.
  static Future<void> save(
    CardioSession session, {
    CloudSyncQueue? cloudQueue,
  }) async {
    await LocalStorage.saveCardioSession(session);
    final uid = CloudSession.userId;
    if (uid == null) return;
    await (cloudQueue ?? CloudSyncQueue.instance).enqueue(
      writeFor(uid, session),
    );
  }
}
