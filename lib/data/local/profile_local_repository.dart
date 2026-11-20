import '../../models/user_profile.dart';
import '../local_storage.dart';
import '../profile_repository.dart';

/// Production offline-first local repository for user profile and settings.
/// Stores encrypted profile data locally. Cloud upload is done by
/// `CloudProfileRepository`, which extends this class.
class ProfileLocalRepository implements ProfileRepository {
  @override
  UserProfile getProfile() {
    return LocalStorage.getUserProfile();
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await LocalStorage.saveUserProfile(profile);
  }

  @override
  Future<void> updateField(String key, dynamic value) async {
    final profile = LocalStorage.getUserProfile();
    profile[key] = value;
    await saveProfile(profile);
  }
}
