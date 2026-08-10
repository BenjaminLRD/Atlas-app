import '../../models/health_metrics.dart';
import '../../models/connected_device.dart';
import '../../data/local_storage.dart';
import 'apple_health_provider.dart';
import 'fitbit_provider.dart';
import 'garmin_provider.dart';
import 'google_fit_provider.dart';
import 'mock_health_provider.dart';

/// Abstract provider contract for health platforms (Apple Health, Google Fit, Garmin, etc.).
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
  final MockHealthProvider _fallbackProvider;

  HealthSyncService({HealthProvider? provider})
      : _activeProvider = provider ?? MockHealthProvider(),
        _fallbackProvider = MockHealthProvider();

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
        return GoogleFitProvider();
      case 'fitbit':
        return FitbitProvider();
      case 'garmin':
        return GarminProvider();
      case 'mock':
      default:
        return MockHealthProvider();
    }
  }

  /// Fetch today's aggregated health metrics with automatic fallback.
  Future<HealthMetrics?> fetchTodayMetrics() async {
    try {
      final metrics = await _activeProvider.fetchTodayMetrics();
      if (metrics != null) return metrics;
      return await _fallbackProvider.fetchTodayMetrics();
    } catch (_) {
      // Fallback seamlessly on SDK / permission / network error
      return await _fallbackProvider.fetchTodayMetrics();
    }
  }

  /// Fetch historical health metrics with automatic fallback.
  Future<List<HealthMetrics>> fetchHistory({int days = 7}) async {
    try {
      final history = await _activeProvider.fetchHistory(days: days);
      if (history.isNotEmpty) return history;
      return await _fallbackProvider.fetchHistory(days: days);
    } catch (_) {
      return await _fallbackProvider.fetchHistory(days: days);
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
    final index = devices.indexWhere((d) => d.id == device.id || d.type == device.type);

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
      devices[index] = devices[index].copyWith(
        isConnected: false,
      );
      await LocalStorage.saveConnectedDevices(devices);
    }

    // Revert provider to mock fallback if no active connected devices remaining
    if (!devices.any((d) => d.isConnected)) {
      _activeProvider = _fallbackProvider;
    }

    return devices;
  }

  /// Calculate an algorithmic recovery readiness score (0 - 100)
  /// based on sleep hours, active volume, and resting heart rate.
  int calculateRecoveryScore(HealthMetrics metrics) {
    // 1. Sleep score (40% weight): Target 8 hours
    final sleepRatio = (metrics.sleepHours / 8.0).clamp(0.0, 1.0);
    final sleepScore = sleepRatio * 40;

    // 2. Activity / Stress score (30% weight): Target ~45 mins active
    final activeRatio = (metrics.activeMinutes / 45.0).clamp(0.0, 1.5);
    final activityScore = (1.5 - activeRatio / 2).clamp(0.0, 1.0) * 30;

    // 3. Resting Heart Rate / Heart Rate Score (30% weight): Target 60 bpm baseline
    final hrDiff = (metrics.heartRateAverage - 60.0).abs();
    final hrScore = (1.0 - (hrDiff / 40.0)).clamp(0.0, 1.0) * 30;

    return (sleepScore + activityScore + hrScore).round().clamp(0, 100);
  }
}
