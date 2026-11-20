import 'crash_reporting_service.dart';

/// Recorded crash or error event model for test assertions and offline inspection.
class RecordedCrashEvent {
  final Object error;
  final StackTrace? stackTrace;
  final String? reason;
  final bool fatal;
  final Map<String, dynamic> customAttributes;
  final DateTime timestamp;

  RecordedCrashEvent({
    required this.error,
    this.stackTrace,
    this.reason,
    this.fatal = false,
    Map<String, dynamic>? customAttributes,
    DateTime? timestamp,
  }) : customAttributes = customAttributes != null
           ? Map<String, dynamic>.from(customAttributes)
           : {},
       timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'RecordedCrashEvent(error: $error, reason: $reason, fatal: $fatal)';
}

/// In-memory implementation of [CrashReportingService] for unit testing,
/// developer verification, and headless environments.
class MockCrashService implements CrashReportingService {
  bool isInitialized = false;
  String? currentUserId;
  final List<RecordedCrashEvent> recordedErrors = [];
  final List<String> breadcrumbLogs = [];
  final Map<String, dynamic> customKeys = {};

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? customAttributes,
  }) async {
    final attributes = Map<String, dynamic>.from(customKeys);
    if (customAttributes != null) {
      attributes.addAll(customAttributes);
    }

    recordedErrors.add(
      RecordedCrashEvent(
        error: error,
        stackTrace: stackTrace,
        reason: reason,
        fatal: fatal,
        customAttributes: attributes,
      ),
    );
  }

  @override
  Future<void> recordException(
    Object exception,
    StackTrace? stackTrace, {
    String? reason,
  }) => recordError(exception, stackTrace, reason: reason, fatal: false);

  @override
  Future<void> log(String message) async {
    breadcrumbLogs.add(message);
  }

  @override
  Future<void> logEvent(String message) => log(message);

  @override
  Future<void> setUser(
    String? userId, {
    Map<String, dynamic>? customAttributes,
  }) async {
    currentUserId = userId;
    if (customAttributes != null) {
      customKeys.addAll(customAttributes);
    }
  }

  @override
  Future<void> setUserIdentifier(String userId) => setUser(userId);

  @override
  Future<void> setCustomKey(String key, dynamic value) async {
    customKeys[key] = value;
  }

  @override
  Future<void> clear() async {
    recordedErrors.clear();
    breadcrumbLogs.clear();
    customKeys.clear();
    currentUserId = null;
    isInitialized = false;
  }
}
