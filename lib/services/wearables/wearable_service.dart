import 'dart:async';
import 'dart:io' show Platform;
import '../../models/health_metrics.dart';
import 'health_connect_wearable_service.dart';
import 'health_kit_wearable_service.dart';

/// Health platforms Atlas can read from. Watches, bands and rings reach the app
/// through one of these (Garmin, Fitbit, Pixel Watch and others sync to Health
/// Connect or Apple Health). There is no simulated platform: with nothing
/// connected the app has no readings.
enum WearablePlatform { appleHealth, googleFit }

/// Abstract contract for wearable sensor integrations (smartwatches, rings, chest straps).
abstract class WearableService {
  WearablePlatform get platform;
  String get providerName;

  /// Requests user OS-level read permissions for heart rate, HRV, sleep, and steps.
  Future<bool> requestPermissions();

  /// Checks if permissions are granted.
  Future<bool> hasPermissions();

  /// Synchronizes latest daily telemetry from the connected device into HealthMetrics.
  /// Returns null when the health store has no data.
  Future<HealthMetrics?> syncHealthData({String userId = 'usr_local'});

  /// Streams real heart-rate readings (BPM). Emits nothing without a source.
  Stream<int> streamHeartRate();

  /// Checks whether device is currently paired and authenticated.
  Future<bool> isConnected();

  /// Checks whether wearable hardware or health platform is available on this device.
  Future<bool> isAvailable() => isConnected();
}

/// Universal manager facilitating runtime platform switching and background polling.
class UniversalWearableManager {
  static UniversalWearableManager? _instance;
  static UniversalWearableManager get instance =>
      _instance ??= UniversalWearableManager();

  final Map<WearablePlatform, WearableService> _services = {
    WearablePlatform.appleHealth: HealthKitWearableService(),
    WearablePlatform.googleFit: HealthConnectWearableService(),
  };

  WearablePlatform _activePlatform = _defaultPlatform();

  static WearablePlatform _defaultPlatform() {
    try {
      return Platform.isIOS
          ? WearablePlatform.appleHealth
          : WearablePlatform.googleFit;
    } catch (_) {
      return WearablePlatform.googleFit;
    }
  }

  WearablePlatform get activePlatform => _activePlatform;
  WearableService get activeService => _services[_activePlatform]!;

  void setActivePlatform(WearablePlatform platform) {
    _activePlatform = platform;
  }

  Future<HealthMetrics?> syncActiveDevice({required String userId}) async {
    return activeService.syncHealthData(userId: userId);
  }

  Stream<int> streamActiveHeartRate() {
    return activeService.streamHeartRate();
  }
}
