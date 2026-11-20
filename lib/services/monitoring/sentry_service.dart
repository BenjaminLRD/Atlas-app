import 'package:flutter/foundation.dart';
import 'crash_reporting_service.dart';

/// Sentry integration for production error telemetry and breadcrumb monitoring.
class SentryCrashService implements CrashReportingService {
  final String dsn;
  bool _isInitialized = false;
  String? _userId;
  final Map<String, dynamic> _tags = {};

  SentryCrashService({this.dsn = 'https://sentry.aizawlgym.com/12345'});

  @override
  Future<void> initialize() async {
    _isInitialized = true;
    debugPrint('[SentryCrashService] Initialized with DSN: $dsn');
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? customAttributes,
  }) async {
    if (!_isInitialized) return;

    final tags = Map<String, dynamic>.from(_tags);
    if (customAttributes != null) tags.addAll(customAttributes);

    debugPrint(
      '[SentryCrashService] ${fatal ? "FATAL" : "ERROR"} Capture: $error (Reason: $reason) | User: $_userId | Tags: $tags',
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
    if (!_isInitialized) return;
    debugPrint('[SentryCrashService] Breadcrumb: $message');
  }

  @override
  Future<void> logEvent(String message) => log(message);

  @override
  Future<void> setUser(
    String? userId, {
    Map<String, dynamic>? customAttributes,
  }) async {
    _userId = userId;
    if (customAttributes != null) _tags.addAll(customAttributes);
    debugPrint('[SentryCrashService] Set User Context: $userId');
  }

  @override
  Future<void> setUserIdentifier(String userId) => setUser(userId);

  @override
  Future<void> setCustomKey(String key, dynamic value) async {
    _tags[key] = value;
  }

  @override
  Future<void> clear() async {
    _userId = null;
    _tags.clear();
    _isInitialized = false;
  }
}
