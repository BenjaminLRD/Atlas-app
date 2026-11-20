import '../../models/health_metrics.dart';
import '../../models/connected_device.dart';
import '../../data/local_storage.dart';
import 'dart:io' show Platform;
import 'apple_health_provider.dart';
import 'google_fit_provider.dart';

/// Abstract provider contract for health platforms (Apple Health and Health Connect).
/// Garmin, Fitbit, Pixel Watch and other devices reach Atlas by syncing to one of them.
abstract class HealthProvider {
  /// Fetch health metrics recorded for today.
  Future<HealthMetrics?> fetchTodayMetrics();

  /// Fetch historical daily health metrics up to [days] back.
  Future<List<HealthMetrics>> fetchHistory({int days = 7});

  /// Request health data permissions from underlying platform SDK.
  Future<bool> requestPermissions();
}

/// Core service orchestrating wearable health synchronization, device management, and recovery calculations.
class HealthSyncService {
  static HealthSyncService? _instance;
  HealthProvider _activeProvider;

  HealthSyncService({HealthProvider? provider})
    : _activeProvider = provider ?? _platformProvider();

  /// The device's own health store. There is no simulated provider: when the
  /// store is unavailable or empty the service returns no data.
  static HealthProvider _platformProvider() {
    try {
      return Platform.isIOS ? AppleHealthProvider() : GoogleFitProvider();
    } catch (_) {
      return GoogleFitProvider();
    }
  }

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static HealthSyncService get instance {
    _instance ??= HealthSyncService();
    return _instance!;
  }

  /// Current active health provider in use.
  HealthProvider get provider => _activeProvider;

  /// Update active health provider dynamically.
  void setProvider(HealthProvider provider) {
    _activeProvider = provider;
  }

  /// Switch active provider by device type string.
  HealthProvider getProviderForType(String type) {
    switch (type.toLowerCase()) {
      case 'apple_health':
      case 'apple':
        return AppleHealthProvider();
      case 'google_fit':
      case 'google':
      case 'health_connect':
        return GoogleFitProvider();
      default:
        // Watches and bands (Garmin, Fitbit and others) sync into the
        // device's health store, so that store is the only real source.
        return _platformProvider();
    }
  }

  /// Today's metrics from the health store, or null when there is no data,
  /// no permission or the store is unavailable. Never a stand-in reading.
  Future<HealthMetrics?> fetchTodayMetrics() async {
    try {
      return await _activeProvider.fetchTodayMetrics();
    } catch (_) {
      return null;
    }
  }

  /// Historical metrics from the health store; empty when there are none.
  Future<List<HealthMetrics>> fetchHistory({int days = 7}) async {
    try {
      return await _activeProvider.fetchHistory(days: days);
    } catch (_) {
      return const [];
    }
  }

  /// Request health permissions.
  Future<bool> requestPermissions() async {
    try {
      return await _activeProvider.requestPermissions();
    } catch (_) {
      return false;
    }
  }

  /// Retrieves persisted list of wearable devices.
  List<ConnectedDevice> getConnectedDevices() {
    return LocalStorage.getConnectedDevices();
  }

  /// Connects a wearable device, updates permissions/provider, and persists state.
  Future<List<ConnectedDevice>> connectDevice(ConnectedDevice device) async {
    final devices = getConnectedDevices();
    final index = devices.indexWhere(
      (d) => d.id == device.id || d.type == device.type,
    );

    final provider = getProviderForType(device.type);
    final hasPermission = await provider.requestPermissions();
    setProvider(provider);

    final updated = device.copyWith(
      isConnected: hasPermission,
      lastSynced: DateTime.now(),
    );

    if (index != -1) {
      devices[index] = updated;
    } else {
      devices.add(updated);
    }

    await LocalStorage.saveConnectedDevices(devices);
    return devices;
  }

  /// Disconnects a wearable device and reverts provider to fallback if active.
  Future<List<ConnectedDevice>> disconnectDevice(String deviceId) async {
    final devices = getConnectedDevices();
    final index = devices.indexWhere((d) => d.id == deviceId);

    if (index != -1) {
      devices[index] = devices[index].copyWith(isConnected: false);
      await LocalStorage.saveConnectedDevices(devices);
    }

    // With no connected device left, go back to the device's own health store.
    if (!devices.any((d) => d.isConnected)) {
      _activeProvider = _platformProvider();
    }

    return devices;
  }

  /// Recovery readiness score (0 - 100) from the signals the health store
  /// actually reported: sleep (40), active minutes (30, only when recorded) and
  /// heart rate (30). Returns null when none of them is available, so no score
  /// is made up from missing data.
  int? calculateRecoveryScore(HealthMetrics metrics) {
    var earned = 0.0;
    var possible = 0.0;

    final sleep = metrics.sleepHours;
    if (sleep != null) {
      earned += (sleep / 8.0).clamp(0.0, 1.0) * 40;
      possible += 40;
    }

    if (metrics.activeMinutes > 0) {
      final activeRatio = (metrics.activeMinutes / 45.0).clamp(0.0, 1.5);
      earned += (1.5 - activeRatio / 2).clamp(0.0, 1.0) * 30;
      possible += 30;
    }

    final hr = metrics.heartRateAverage;
    if (hr != null) {
      earned += (1.0 - ((hr - 60.0).abs() / 40.0)).clamp(0.0, 1.0) * 30;
      possible += 30;
    }

    if (possible == 0) return null;
    return (earned / possible * 100).round().clamp(0, 100);
  }
}
