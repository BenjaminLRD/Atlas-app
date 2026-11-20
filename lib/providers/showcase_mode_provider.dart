import 'package:flutter/material.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../services/showcase_mode_service.dart';
import 'fitness_provider.dart';

/// Global Showcase Mode Provider managing the application-wide demo data toggle.
/// Allows recruiters, investors, and reviewers to instantly explore Atlas
/// with realistic, fully populated athlete data across all standard screens,
/// without maintaining disconnected fake dashboards or separate pages.
class ShowcaseModeProvider extends ChangeNotifier {
  static ShowcaseModeProvider? _instance;
  bool _isShowcaseModeEnabled = false;

  ShowcaseModeProvider._() {
    _isShowcaseModeEnabled = LocalStorage.isShowcaseModeEnabled();
  }

  static ShowcaseModeProvider get instance =>
      _instance ??= ShowcaseModeProvider._();

  static void resetInstance() {
    _instance = null;
  }

  bool get isShowcaseModeEnabled => _isShowcaseModeEnabled;
  bool get isDemoMode => _isShowcaseModeEnabled;

  /// Enables global Showcase Mode and populates all providers with realistic demo athlete data
  Future<void> enableShowcaseMode() async {
    if (_isShowcaseModeEnabled) return;
    _isShowcaseModeEnabled = true;
    await LocalStorage.setShowcaseModeEnabled(true);
    ShowcaseModeService.instance.enableShowcaseMode();

    // Trigger state propagation
    await _propagateState(true);
    notifyListeners();
  }

  /// Disables Showcase Mode and restores the real user's actual local / cloud data
  Future<void> disableShowcaseMode() async {
    if (!_isShowcaseModeEnabled) return;
    _isShowcaseModeEnabled = false;
    await LocalStorage.setShowcaseModeEnabled(false);
    ShowcaseModeService.instance.disableShowcaseMode();

    // Trigger state restoration
    await _propagateState(false);
    notifyListeners();
  }

  /// Toggles Showcase Mode on or off
  Future<void> toggleShowcaseMode() async {
    if (_isShowcaseModeEnabled) {
      await disableShowcaseMode();
    } else {
      await enableShowcaseMode();
    }
  }

  /// Internal helper to synchronize providers when showcase mode changes
  Future<void> _propagateState(bool isEnabled) async {
    // 1. Notify FitnessProvider
    await FitnessProvider.instance.onShowcaseModeToggled(isEnabled);

    // 2. Notify ProfileProvider
    final profileProvider = AppDependencies.instance.profileProvider;
    profileProvider.onShowcaseModeToggled(isEnabled);
  }
}
