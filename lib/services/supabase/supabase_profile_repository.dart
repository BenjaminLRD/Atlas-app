import '../../data/local_storage.dart';
import '../../data/profile_repository.dart';
import '../../models/user_goal.dart';
import '../../models/user_profile.dart';
import 'database_models.dart';
import 'supabase_client.dart';

/// Supabase backed implementation of [ProfileRepository] ensuring local-first
/// persistence to [LocalStorage] while syncing user profile, preferences, and goals to Supabase.
class SupabaseProfileRepository implements ProfileRepository {
  final SupabaseClientManager _clientManager;

  SupabaseProfileRepository({SupabaseClientManager? clientManager})
    : _clientManager = clientManager ?? SupabaseClientManager.instance;

  @override
  UserProfile getProfile() {
    return LocalStorage.getUserProfile();
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    // 1. Local-first update
    await LocalStorage.saveUserProfile(profile);

    // 2. Cloud sync to Supabase profiles table
    try {
      final uid = _clientManager.authenticatedUid ?? 'usr_local_01';
      final payload = SupabaseModelMappers.userProfileToTable(profile, userId: uid);
      await _clientManager
          .from(SupabaseTableNames.profiles)
          .upsert(payload, onConflictColumn: 'id');

      // Also sync fitness_profiles
      final fitnessPayload = SupabaseModelMappers.userProfileToFitnessProfileTable(
        profile,
        userId: uid,
      );
      await _clientManager
          .from(SupabaseTableNames.fitnessProfiles)
          .upsert(fitnessPayload, onConflictColumn: 'id');

      // Also sync user_preferences
      final prefPayload = SupabaseModelMappers.userPreferencesToTable(
        userId: uid,
        trainingStyle: profile.workoutExperience,
        notificationsEnabled: profile.notificationsEnabled,
      );
      await _clientManager
          .from(SupabaseTableNames.userPreferences)
          .upsert(prefPayload, onConflictColumn: 'user_id');
    } catch (_) {
      // Offline fallback
    }
  }

  /// Alias for saving/updating profile to Supabase and LocalStorage.
  Future<void> updateProfile(UserProfile profile) async {
    await saveProfile(profile);
  }

  @override
  Future<void> updateField(String key, dynamic value) async {
    final profile = LocalStorage.getUserProfile();
    profile[key] = value;
    await LocalStorage.saveUserProfile(profile);

    try {
      final uid = _clientManager.authenticatedUid ?? 'usr_local_01';
      final payload = SupabaseModelMappers.userProfileToTable(profile, userId: uid);
      await _clientManager
          .from(SupabaseTableNames.profiles)
          .upsert(payload, onConflictColumn: 'id');
    } catch (_) {
      // Offline fallback
    }
  }

  /// Saves or syncs UserGoal to `user_goals` table
  Future<void> saveUserGoal(UserGoal goal, {String? userId}) async {
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final payload = SupabaseModelMappers.userGoalToTable(goal, userId: uid);
      await _clientManager
          .from(SupabaseTableNames.userGoals)
          .upsert(payload, onConflictColumn: 'id');
    } catch (_) {
      // Offline resilience
    }
  }
}
