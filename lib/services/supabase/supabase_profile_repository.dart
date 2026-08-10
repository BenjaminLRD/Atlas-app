import '../../data/local_storage.dart';
import '../../data/profile_repository.dart';
import '../../models/user_profile.dart';
import 'database_models.dart';
import 'supabase_client.dart';

/// Supabase backed implementation of [ProfileRepository] ensuring local-first
/// persistence to [LocalStorage] while syncing user profile data to Supabase `profiles` table.
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
    final payload = SupabaseModelMappers.userProfileToTable(profile);
    await _clientManager
        .from(SupabaseTableNames.profiles)
        .upsert(payload, onConflictColumn: 'id');
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

    final payload = SupabaseModelMappers.userProfileToTable(profile);
    await _clientManager
        .from(SupabaseTableNames.profiles)
        .upsert(payload, onConflictColumn: 'id');
  }
}
