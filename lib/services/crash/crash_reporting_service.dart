import 'package:flutter/foundation.dart';

/// Foundation service for crash reporting (Firebase Crashlytics / Sentry abstraction).
class CrashReportingService {
  static final CrashReportingService _instance = CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  static CrashReportingService get instance => _instance;

  final List<Map<String, dynamic>> _crashLogQueue = [];
  final Map<String, String> _customKeys = {};

  List<Map<String, dynamic>> get crashLogQueue => List.unmodifiable(_crashLogQueue);
  Map<String, String> get customKeys => Map.unmodifiable(_customKeys);

  /// Records an exception or crash event.
  void recordCrash(
    Object exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    final entry = {
      'exception': exception.toString(),
      'reason': reason ?? 'Unspecified runtime exception',
      'fatal': fatal,
      'stackTrace': stackTrace?.toString(),
      'customKeys': Map<String, String>.from(_customKeys),
      'timestamp': DateTime.now().toIso8601String(),
    };

    _crashLogQueue.insert(0, entry);
    if (_crashLogQueue.length > 50) {
      _crashLogQueue.removeLast();
    }

    debugPrint('[CrashReportingService] ${fatal ? "FATAL" : "NON-FATAL"} CRASH: $exception');
  }

  /// Sets custom context key for crash reports.
  void setCustomKey(String key, String value) {
    _customKeys[key] = value;
  }

  /// Clears queued crash logs.
  void clearCrashLogs() {
    _crashLogQueue.clear();
  }
}
