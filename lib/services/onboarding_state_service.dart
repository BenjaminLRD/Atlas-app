import 'package:shared_preferences/shared_preferences.dart';
import '../data/local_storage.dart';

/// Service managing the first-time onboarding lifecycle state across app launches.
class OnboardingStateService {
  static OnboardingStateService? _instance;
  static const String onboardingKey = 'has_completed_onboarding';

  OnboardingStateService._();

  static OnboardingStateService get instance =>
      _instance ??= OnboardingStateService._();

  /// Whether the athlete has completed the initial onboarding walkthrough.
  bool hasCompletedOnboarding() {
    return LocalStorage.hasCompletedOnboarding();
  }

  /// Alias for quick boolean check
  bool get isCompleted => hasCompletedOnboarding();

  /// Marks the onboarding flow as completed and persists to local storage.
  Future<void> setCompletedOnboarding(bool completed) async {
    await LocalStorage.setCompletedOnboarding(completed);
  }

  /// Resets onboarding state (useful for user logout, testing, or re-onboarding).
  Future<void> reset() async {
    await LocalStorage.resetOnboarding();
  }

  /// Directly checks SharedPreferences if LocalStorage is not yet initialized.
  static Future<bool> checkDirectly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingKey) ?? false;
  }
}
