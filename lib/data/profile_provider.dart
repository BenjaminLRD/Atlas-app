import 'package:flutter/foundation.dart';
import 'local_storage.dart';

/// Global single source of truth for user profile data.
/// All screens that display profile info should read from this provider.
class ProfileProvider extends ChangeNotifier {
  static final ProfileProvider _instance = ProfileProvider._internal();
  factory ProfileProvider() => _instance;
  ProfileProvider._internal() {
    _profile = LocalStorage.getUserProfile();
  }

  late Map<String, dynamic> _profile;

  Map<String, dynamic> get profile => _profile;

  String get name => _profile['name'] as String? ?? 'User';
  String get email => _profile['email'] as String? ?? '';
  String get phone => _profile['phone'] as String? ?? '';
  String get dob => _profile['dob'] as String? ?? '';
  String get gender => _profile['gender'] as String? ?? 'Male';
  String get height => _profile['height']?.toString() ?? '175';
  String get weight => _profile['weight']?.toString() ?? '68.2';
  String get fitnessGoal => _profile['fitnessGoal'] as String? ?? 'Build Muscle';
  String get workoutExperience => _profile['workoutExperience'] as String? ?? 'Intermediate';
  List<String> get preferredDays =>
      (_profile['preferredDays'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
  String get dietPreference => _profile['dietPreference'] as String? ?? 'High Protein';
  String get massUnit => _profile['massUnit'] as String? ?? 'kg';
  String get lengthUnit => _profile['lengthUnit'] as String? ?? 'cm';
  String get subscription => _profile['subscription'] as String? ?? 'Free';
  String get profilePic => _profile['profilePic'] as String? ?? '';
  bool get notificationsEnabled => _profile['notificationsEnabled'] as bool? ?? true;
  String get privacy => _profile['privacy'] as String? ?? 'Friends Only';

  /// Calculates age from date of birth
  int get age {
    try {
      final dobStr = _profile['dob'];
      if (dobStr != null && dobStr.isNotEmpty) {
        final dob = DateTime.parse(dobStr as String);
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

  /// Reload from local storage (e.g. on app resume)
  void reload() {
    _profile = LocalStorage.getUserProfile();
    notifyListeners();
  }

  /// Update profile and persist to local storage
  Future<void> update(Map<String, dynamic> newProfile) async {
    _profile = Map<String, dynamic>.from(newProfile);
    await LocalStorage.saveUserProfile(_profile);
    notifyListeners();
  }

  /// Update a single field and persist
  Future<void> updateField(String key, dynamic value) async {
    _profile[key] = value;
    await LocalStorage.saveUserProfile(_profile);
    notifyListeners();
  }
}
