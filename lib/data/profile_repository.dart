import '../models/user_profile.dart';
import 'local_storage.dart';

/// Abstract interface for profile data operations.
abstract class ProfileRepository {
  UserProfile getProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<void> updateField(String key, dynamic value);
}

/// Default local implementation of ProfileRepository backed by LocalStorage.
class LocalProfileRepository implements ProfileRepository {
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
    await LocalStorage.saveUserProfile(profile);
  }
}
