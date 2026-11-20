import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'local_storage.dart';
import 'profile_repository.dart';
import '../services/showcase_mode_service.dart';

/// Global single source of truth for user profile data.
/// All screens that display profile info should read from this provider.
class ProfileProvider extends ChangeNotifier {
  static ProfileProvider _instance = ProfileProvider._internal(
    LocalProfileRepository(),
  );

  factory ProfileProvider([ProfileRepository? repository]) {
    if (repository != null) {
      _instance = ProfileProvider._internal(repository);
    }
    return _instance;
  }

  ProfileProvider._internal(this._repository) {
    if (LocalStorage.isShowcaseModeEnabled()) {
      _userProfile = ShowcaseModeService.instance.getShowcaseUserProfile();
    } else {
      _userProfile = _repository.getProfile();
    }
  }

  final ProfileRepository _repository;
  late UserProfile _userProfile;

  void onShowcaseModeToggled(bool isEnabled) {
    if (isEnabled) {
      _userProfile = ShowcaseModeService.instance.getShowcaseUserProfile();
    } else {
      _userProfile = _repository.getProfile();
    }
    notifyListeners();
  }

  UserProfile get userProfile => _userProfile;
  Map<String, dynamic> get profile => _userProfile.toJson();

  String get name => _userProfile.name;
  String get email {
    if (_userProfile.email.trim().isNotEmpty) {
      return _userProfile.email;
    }
    return LocalStorage.getAppUser()?.email ?? '';
  }

  String get phone => _userProfile.phone;
  String get dob => _userProfile.dob;
  String get gender => _userProfile.gender;
  String get height => _userProfile.height;
  String get weight => _userProfile.weight;
  String get targetWeight => _userProfile.targetWeight;
  String get bio => _userProfile.bio;
  String get fitnessGoal => _userProfile.fitnessGoal;
  String get workoutExperience => _userProfile.workoutExperience;
  List<String> get preferredDays => _userProfile.preferredDays;
  String get dietPreference => _userProfile.dietPreference;
  String get massUnit => _userProfile.massUnit;
  String get lengthUnit => _userProfile.lengthUnit;
  String get subscription => _userProfile.subscription;
  String get profilePic => _userProfile.profilePic;
  bool get notificationsEnabled => _userProfile.notificationsEnabled;
  String get privacy => _userProfile.privacy;

  /// Calculates age from date of birth
  int get age {
    try {
      final dobStr = _userProfile.dob;
      if (dobStr.isNotEmpty) {
        final dob = DateTime.parse(dobStr);
        final today = DateTime.now();
        int calculatedAge = today.year - dob.year;
        if (today.month < dob.month ||
            (today.month == dob.month && today.day < dob.day)) {
          calculatedAge--;
        }
        return calculatedAge;
      }
    } catch (_) {}
    return 0;
  }

  /// What Showcase Mode shows for the current user instead of the demo
  /// athlete's invented name.
  static const String showcaseSelfLabel = 'YOU';

  /// True only when Showcase Mode is switched on (never inferred from
  /// missing profile data).
  bool get isShowcaseIdentity => LocalStorage.isShowcaseModeEnabled();

  /// Profile photo to display for the current user: none in Showcase Mode, so
  /// screens show the generic avatar instead of the demo athlete's photo.
  String get displayProfilePic => isShowcaseIdentity ? '' : profilePic;

  /// Returns display name (first name or up to two parts); `YOU` in Showcase
  /// Mode.
  String get displayName {
    if (isShowcaseIdentity) return showcaseSelfLabel;
    final sanitized = UserProfile.sanitizeName(name);
    if (sanitized.isEmpty) return '';
    final parts = sanitized.split(' ');
    if (parts.length > 2) return '${parts[0]} ${parts[1]}';
    return sanitized;
  }

  /// Returns first name only
  String get firstName {
    final sanitized = UserProfile.sanitizeName(name);
    if (sanitized.isEmpty) return '';
    final parts = sanitized.split(' ');
    return parts.isNotEmpty ? parts[0] : sanitized;
  }

  /// Reload from repository (e.g. on app resume)
  void reload() {
    _userProfile = _repository.getProfile();
    notifyListeners();
  }

  /// Update strongly typed profile and persist via repository
  Future<void> updateProfile(UserProfile newProfile) async {
    await _repository.saveProfile(newProfile);
    _userProfile = _repository.getProfile();
    notifyListeners();
  }

  /// Update profile from UserProfile model or Map and persist via repository
  Future<void> update(dynamic newProfile) async {
    if (newProfile is UserProfile) {
      await updateProfile(newProfile);
    } else if (newProfile is Map<String, dynamic>) {
      final updated = _userProfile.copyWith(
        name: newProfile['name'] as String?,
        email: newProfile['email'] as String?,
        phone: newProfile['phone'] as String?,
        dob: newProfile['dob'] as String?,
        gender: newProfile['gender'] as String?,
        height: newProfile['height'] as String?,
        weight: newProfile['weight'] as String?,
        fitnessGoal:
            newProfile['fitnessGoal'] as String? ??
            newProfile['goal'] as String?,
        workoutExperience:
            newProfile['workoutExperience'] as String? ??
            newProfile['level'] as String?,
        dietPreference:
            newProfile['dietPreference'] as String? ??
            newProfile['diet'] as String?,
      );
      await updateProfile(updated);
    }
  }

  /// Update a single field and persist via repository
  Future<void> updateField(String key, dynamic value) async {
    await _repository.updateField(key, value);
    _userProfile = _repository.getProfile();
    notifyListeners();
  }
}
