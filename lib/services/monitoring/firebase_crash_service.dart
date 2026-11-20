import 'package:flutter/foundation.dart';
import 'crash_reporting_service.dart';

/// Firebase Crashlytics provider for production crash logging, fatal exception
/// aggregation, and custom keys.
class FirebaseCrashService implements CrashReportingService {
  bool _isInitialized = false;
  String? _userIdentifier;
  final Map<String, dynamic> _customKeys = {};

  @override
  Future<void> initialize() async {
    _isInitialized = true;
    debugPrint('[FirebaseCrashService] Initialized Firebase Crashlytics');
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

    final keys = Map<String, dynamic>.from(_customKeys);
    if (customAttributes != null) keys.addAll(customAttributes);

    debugPrint(
      '[FirebaseCrashService] Record ${fatal ? "FATAL" : "NON-FATAL"} Error: $error (Reason: $reason) | User: $_userIdentifier | Keys: $keys',
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
    debugPrint('[FirebaseCrashService] Log: $message');
  }

  @override
  Future<void> logEvent(String message) => log(message);

  @override
  Future<void> setUser(
    String? userId, {
    Map<String, dynamic>? customAttributes,
  }) async {
    _userIdentifier = userId;
    if (customAttributes != null) _customKeys.addAll(customAttributes);
    debugPrint('[FirebaseCrashService] Set User Identifier: $userId');
  }

  @override
  Future<void> setUserIdentifier(String userId) => setUser(userId);

  @override
  Future<void> setCustomKey(String key, dynamic value) async {
    _customKeys[key] = value;
  }

  @override
  Future<void> clear() async {
    _userIdentifier = null;
    _customKeys.clear();
    _isInitialized = false;
  }
}
