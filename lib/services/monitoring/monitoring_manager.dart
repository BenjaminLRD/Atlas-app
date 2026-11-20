import 'dart:async';
import '../../config/app_config.dart';
import 'crash_reporting_service.dart';
import 'mock_crash_service.dart';
import 'performance_tracker.dart';

/// Central monitoring manager orchestrating crash reporting, service failure tracking,
/// user context binding, and privacy-preserving log sanitization.
class MonitoringManager {
  static MonitoringManager? _instance;

  CrashReportingService _service;
  bool _isEnabled = false;
  final PerformanceTracker _performance = PerformanceTracker.instance;

  MonitoringManager._({CrashReportingService? service})
    : _service = service ?? MockCrashService();

  /// Singleton instance accessor.
  static MonitoringManager get instance {
    _instance ??= MonitoringManager._();
    return _instance!;
  }

  /// Sets custom or mock crash reporting service (useful for tests).
  static void setInstance(MonitoringManager manager) {
    _instance = manager;
  }

  /// Reset singleton instance.
  static void resetInstance() {
    _instance = null;
  }

  /// Active crash reporting service provider.
  CrashReportingService get service => _service;

  /// Performance tracker accessor.
  PerformanceTracker get performance => _performance;

  /// Whether crash reporting and remote observability are enabled.
  bool get isEnabled => _isEnabled;

  /// Initializes monitoring subsystem adhering to [AppConfig] environment flags.
  Future<void> initialize(AppConfig config) async {
    _isEnabled = config.enableCrashReporting;
    if (_isEnabled) {
      await _service.initialize();
      await _service.setCustomKey('environment', config.environment.name);
      await _service.setCustomKey('apiBaseUrl', config.apiBaseUrl);
    }
  }

  /// Changes the underlying crash reporting provider.
  void setService(CrashReportingService service, {bool isEnabled = true}) {
    _service = service;
    _isEnabled = isEnabled;
  }

  /// Privacy sanitizer: Recursively strips sensitive keys from maps.
  static Map<String, dynamic> sanitizeAttributes(Map<String, dynamic>? input) {
    if (input == null) return {};

    final sensitivePatterns = [
      'password',
      'token',
      'secret',
      'auth',
      'dob',
      'birth',
      'heartrate',
      'heart_rate',
      'sleep',
      'restingheartrate',
      'resting_heart_rate',
      'healthmetric',
      'message',
      'phone',
    ];

    final sanitized = <String, dynamic>{};
    for (final entry in input.entries) {
      final keyLower = entry.key.toLowerCase();
      final isSensitive = sensitivePatterns.any((p) => keyLower.contains(p));

      if (isSensitive) {
        sanitized[entry.key] = '[REDACTED_PII]';
      } else if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = sanitizeAttributes(
          entry.value as Map<String, dynamic>,
        );
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  /// Records an uncaught or caught application error with privacy sanitization.
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? customAttributes,
  }) async {
    if (!_isEnabled) return;

    final sanitizedAttributes = sanitizeAttributes(customAttributes);
    await _service.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
      customAttributes: sanitizedAttributes,
    );
  }

  /// Logs a breadcrumb or diagnostic event.
  Future<void> log(String message) async {
    if (!_isEnabled) return;
    await _service.log(message);
  }

  /// Sets sanitized user identity context upon login/registration.
  Future<void> setUserContext(
    String? userId, {
    String? appVersion,
    DateTime? accountCreated,
    String? environment,
  }) async {
    if (!_isEnabled) return;

    final context = <String, dynamic>{};
    if (appVersion != null) context['app_version'] = appVersion;
    if (accountCreated != null) {
      context['account_created'] = accountCreated.toIso8601String();
    }
    if (environment != null) context['environment'] = environment;

    await _service.setUser(userId, customAttributes: context);
  }

  /// Tracks Gemini AI service timeouts, network failures, or invalid responses.
  Future<void> trackAiServiceError(
    Object error,
    StackTrace? stackTrace, {
    String provider = 'gemini',
    String? promptTopic,
  }) async {
    final attributes = <String, dynamic>{
      'service': 'ai_coach',
      'provider': provider,
    };
    if (promptTopic != null) attributes['topic'] = promptTopic;

    await recordError(
      error,
      stackTrace,
      reason: 'AI Service Failure ($provider)',
      fatal: false,
      customAttributes: attributes,
    );
  }

  /// Tracks Supabase authentication, PostgreSQL query, or storage failures.
  Future<void> trackSupabaseError(
    Object error,
    StackTrace? stackTrace, {
    String? table,
    String? operation,
  }) async {
    final attributes = <String, dynamic>{'service': 'supabase'};
    if (table != null) attributes['table'] = table;
    if (operation != null) attributes['operation'] = operation;

    await recordError(
      error,
      stackTrace,
      reason: 'Supabase Cloud Failure ($table:$operation)',
      fatal: false,
      customAttributes: attributes,
    );
  }

  /// Tracks Health Connect / Wearable device errors.
  Future<void> trackHealthConnectError(
    Object error,
    StackTrace? stackTrace, {
    String? operation,
    String? deviceType,
  }) async {
    final attributes = <String, dynamic>{'service': 'health_connect'};
    if (operation != null) attributes['operation'] = operation;
    if (deviceType != null) attributes['device_type'] = deviceType;

    await recordError(
      error,
      stackTrace,
      reason: 'Health Connect Telemetry Failure ($operation)',
      fatal: false,
      customAttributes: attributes,
    );
  }

  /// Tracks offline queue sync failures and retry counts.
  Future<void> trackOfflineActionFailure(
    String actionType,
    int retryCount,
    Object error,
  ) async {
    await recordError(
      error,
      null,
      reason: 'Offline Action Replay Failed ($actionType)',
      fatal: false,
      customAttributes: {
        'service': 'offline_queue',
        'action_type': actionType,
        'retry_count': retryCount,
      },
    );
  }

  /// Clears monitoring records (for test isolation).
  Future<void> clear() async {
    await _service.clear();
    _performance.clear();
  }
}
