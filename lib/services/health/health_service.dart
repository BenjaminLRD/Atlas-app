import '../../models/health_metric.dart';
import 'platform_health_service.dart';

/// Abstract health telemetry service interface supporting Health Connect,
/// smartwatches, fitness bands, Apple Health, and offline local fallbacks.
abstract class HealthService {
  static HealthService? _instance;

  /// Global singleton accessor; defaults to the device's health store (no simulated data)
  static HealthService get instance {
    _instance ??= PlatformHealthService();
    return _instance!;
  }

  /// Sets custom or platform-specific instance (useful for dependency injection and tests)
  static void setInstance(HealthService service) {
    _instance = service;
  }

  /// Resets the instance for tests
  static void resetInstance() {
    _instance = null;
  }

  /// Check whether health permissions have been granted
  Future<bool> hasPermissions();

  /// Request permissions for Steps, Distance, Active Calories, Heart Rate, and Sleep
  Future<bool> requestPermissions();

  /// Fetch today's aggregated health telemetry
  Future<HealthMetric> getTodayHealthMetric();

  /// Fetch the trailing 7-day health history
  Future<List<HealthMetric>> getWeeklyHealthHistory();

  /// Check if the underlying health platform (e.g. Health Connect) is available on the device
  Future<bool> isProviderAvailable();

  /// Stream of real-time heart rate BPM readings from connected wearables / sensors
  Stream<int?> watchHeartRate();

  /// Update / record manual health values or mock adjustments
  Future<void> updateHealthMetric(HealthMetric metric);
}
