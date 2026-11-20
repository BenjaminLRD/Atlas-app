import '../../data/local_storage.dart';
import '../../models/personal_record.dart';
import '../../models/workout_history.dart';
import '../../models/workout_session.dart';
import 'database_models.dart';
import 'supabase_client.dart';

/// Cloud-first, local-fallback repository for workout sessions, sets, exercises, and PRs.
class SupabaseWorkoutRepository {
  final SupabaseClientManager _clientManager;

  SupabaseWorkoutRepository({SupabaseClientManager? clientManager})
    : _clientManager = clientManager ?? SupabaseClientManager.instance;

  /// Retrieves workout history list: tries Supabase first, falls back to LocalStorage cache.
  Future<List<WorkoutHistory>> getWorkoutHistory({String? userId}) async {
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final rows = await _clientManager
          .from(SupabaseTableNames.workoutSessions)
          .select('user_id', uid);

      final list = rows
          .map((r) => SupabaseModelMappers.tableToWorkoutHistory(r))
          .toList();
      // Update local cache
      if (list.isNotEmpty) {
        await LocalStorage.saveWorkoutHistory(list);
      }
      return list;
    } catch (_) {
      // Offline fallback
    }
    return LocalStorage.getWorkoutHistory();
  }

  /// Retrieves structured workout sessions: tries Supabase first, falls back to LocalStorage cache.
  Future<List<WorkoutSession>> getWorkoutSessions({String? userId}) async {
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final rows = await _clientManager
          .from(SupabaseTableNames.workoutSessions)
          .select('user_id', uid);

      final list = rows
          .map((r) => SupabaseModelMappers.tableToWorkoutSession(r))
          .toList();
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
      if (list.isNotEmpty) {
        await LocalStorage.saveWorkoutSessions(list);
      }
      return list;
    } catch (_) {
      // Offline fallback
    }
    return LocalStorage.getWorkoutSessions();
  }

  /// Saves structured workout session: saves locally first, then attempts cloud sync
  /// including granular workout_sets, workout_exercises, and personal_records.
  Future<void> saveWorkoutSessionModel(
    WorkoutSession session, {
    String? userId,
  }) async {
    // 1. Local Cache
    await LocalStorage.saveWorkoutSession(session);
    final history = session.toWorkoutHistory();
    await LocalStorage.saveWorkoutCompletion(history);

    // 2. Cloud Sync
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      
      // Save Session
      final sessionPayload = SupabaseModelMappers.workoutSessionToTable(
        session,
        userId: uid,
      );
      await _clientManager
          .from(SupabaseTableNames.workoutSessions)
          .upsert(sessionPayload, onConflictColumn: 'id');

      // Save Exercises & Sets
      for (int i = 0; i < session.exercises.length; i++) {
        final ex = session.exercises[i];
        
        final exPayload = {
          'session_id': session.id,
          'exercise_id': ex.id,
          'exercise_name': ex.name,
          'muscle_group': ex.muscleGroup,
          'target_muscle_group': ex.muscleGroup,
          'order_index': i,
          'sets_completed': ex.completedSetsCount,
          'total_reps': ex.totalCompletedReps,
          'volume': ex.totalVolume,
          'max_weight': ex.maxWeight,
          'sets': ex.sets.map((s) => s.toJson()).toList(),
          'sets_data': ex.sets.map((s) => s.toJson()).toList(),
          'created_at': DateTime.now().toIso8601String(),
        };
        await _clientManager
            .from(SupabaseTableNames.workoutExercises)
            .insert(exPayload);

        // Granular Sets
        for (final set in ex.sets) {
          final setPayload = SupabaseModelMappers.workoutSetToTable(
            sessionId: session.id,
            exerciseId: ex.id,
            exerciseName: ex.name,
            setNumber: set.setNumber,
            weight: set.weight,
            reps: set.reps,
            rpe: set.rpe ?? 8.0,
            completed: set.completed,
            isPr: set.isPR,
          );
          await _clientManager
              .from(SupabaseTableNames.workoutSets)
              .insert(setPayload);
        }
      }

      // Save PRs if any
      for (final prName in session.personalRecords) {
        final prPayload = SupabaseModelMappers.personalRecordToTable(
          PersonalRecord(
            id: '',
            exerciseName: prName,
            recordType: 'Session PR',
            value: session.totalVolume,
            achievedDate: session.endTime ?? DateTime.now(),
          ),
          userId: uid,
        );
        await _clientManager
            .from(SupabaseTableNames.personalRecords)
            .insert(prPayload);
      }
    } catch (_) {
      // Offline queue / local cache used
    }
  }

  /// Saves workout session history: saves locally first, then attempts cloud sync.
  Future<void> saveWorkoutSession(
    WorkoutHistory history, {
    String? userId,
  }) async {
    // 1. Local Cache
    await LocalStorage.saveWorkoutCompletion(history);

    // 2. Cloud Sync
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final payload = SupabaseModelMappers.workoutHistoryToTable(
        history,
        userId: uid,
      );
      await _clientManager
          .from(SupabaseTableNames.workoutSessions)
          .upsert(payload, onConflictColumn: 'id');
    } catch (_) {
      // Offline fallback
    }
  }

  /// Fetches Personal Records for the user
  Future<List<PersonalRecord>> getPersonalRecords({String? userId}) async {
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final rows = await _clientManager
          .from(SupabaseTableNames.personalRecords)
          .select('user_id', uid);

      if (rows.isNotEmpty) {
        return rows.map((r) => SupabaseModelMappers.tableToPersonalRecord(r)).toList();
      }
    } catch (_) {
      // Fallback
    }
    return <PersonalRecord>[];
  }
}
