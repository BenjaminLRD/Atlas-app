import 'dart:async';

/// Production interface for crash reporting and observability providers
/// (Firebase Crashlytics, Sentry, or Mock in-memory recorder).
abstract class CrashReportingService {
  /// Initializes the crash reporting provider.
  Future<void> initialize();

  /// Records an uncaught or caught exception with stack trace.
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? customAttributes,
  });

  /// Convenience helper to record a caught exception
  Future<void> recordException(
    Object exception,
    StackTrace? stackTrace, {
    String? reason,
  }) => recordError(exception, stackTrace, reason: reason, fatal: false);

  /// Logs a breadcrumb or diagnostic log message.
  Future<void> log(String message);

  /// Convenience alias for logging events
  Future<void> logEvent(String message) => log(message);

  /// Associates the active session with an authenticated user identifier.
  Future<void> setUser(
    String? userId, {
    Map<String, dynamic>? customAttributes,
  });

  /// Convenience alias for setting user identifier
  Future<void> setUserIdentifier(String userId) => setUser(userId);

  /// Sets custom diagnostic key-value pair for subsequent crash reports.
  Future<void> setCustomKey(String key, dynamic value);

  /// Clears stored crash reports / breadcrumbs (useful for test resets).
  Future<void> clear();
}
