import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import 'profile_repository.dart';

/// Global single source of truth for user profile data.
/// All screens that display profile info should read from this provider.
class ProfileProvider extends ChangeNotifier {
  static ProfileProvider _instance = ProfileProvider._internal(LocalProfileRepository());
  
  factory ProfileProvider([ProfileRepository? repository]) {
    if (repository != null) {
      _instance = ProfileProvider._internal(repository);
    }
    return _instance;
  }

  ProfileProvider._internal(this._repository) {
    _userProfile = _repository.getProfile();
  }

  final ProfileRepository _repository;
  late UserProfile _userProfile;

  UserProfile get userProfile => _userProfile;
  Map<String, dynamic> get profile => _userProfile.toJson();

  String get name => _userProfile.name;
  String get email => _userProfile.email;
  String get phone => _userProfile.phone;
  String get dob => _userProfile.dob;
  String get gender => _userProfile.gender;
  String get height => _userProfile.height;
  String get weight => _userProfile.weight;
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

  /// Returns display name (first name or up to two parts)
  String get displayName {
    final parts = name.trim().split(' ');
    if (parts.length > 2) return '${parts[0]} ${parts[1]}';
    return name;
  }

  /// Returns first name only
  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : name;
  }

  /// Reload from repository (e.g. on app resume)
  void reload() {
    _userProfile = _repository.getProfile();
    notifyListeners();
  }

  /// Update profile and persist via repository
  Future<void> update(dynamic newProfile) async {
    await _repository.saveProfile(newProfile);
    _userProfile = _repository.getProfile();
    notifyListeners();
  }

  /// Update a single field and persist via repository
  Future<void> updateField(String key, dynamic value) async {
    await _repository.updateField(key, value);
    _userProfile = _repository.getProfile();
    notifyListeners();
  }
}
