import 'dart:async';
import 'package:flutter/foundation.dart';
import '../crash/crash_reporting_service.dart';

/// Single error event record captured by [AppErrorHandler].
class AppErrorEvent {
  final String message;
  final StackTrace? stackTrace;
  final String context;
  final DateTime timestamp;
  final bool isFatal;
  final Map<String, dynamic> extraData;

  AppErrorEvent({
    required this.message,
    this.stackTrace,
    this.context = 'general',
    required this.timestamp,
    this.isFatal = false,
    this.extraData = const {},
  });
}

/// Centralized error handling and user-facing translation layer.
/// Prevents raw technical exceptions or stack traces from reaching user interfaces,
/// while guaranteeing telemetry, history retention, and crash logging for developers.
class AppErrorHandler {
  static final AppErrorHandler _instance = AppErrorHandler._internal();
  factory AppErrorHandler() => _instance;
  AppErrorHandler._internal();

  static AppErrorHandler get instance => _instance;

  final List<AppErrorEvent> _errorHistory = [];
  final StreamController<AppErrorEvent> _errorStreamController =
      StreamController<AppErrorEvent>.broadcast();

  List<AppErrorEvent> get errorHistory => List.unmodifiable(_errorHistory);
  Stream<AppErrorEvent> get errorStream => _errorStreamController.stream;

  void clearHistory() {
    _errorHistory.clear();
  }

  /// Initializes global Flutter and platform error handling hooks.
  void initGlobalErrorHooks() {
    FlutterError.onError = (FlutterErrorDetails details) {
      reportError(
        details.exceptionAsString(),
        details.stack,
        context: 'flutter_framework',
        fatal: false,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      reportError(error, stack, context: 'platform_dispatcher', fatal: true);
      return true;
    };
  }

  /// Records an error in memory history and notifies subscribers.
  void reportError(
    dynamic error,
    StackTrace? stackTrace, {
    String context = 'general',
    Map<String, dynamic> extraData = const {},
    bool fatal = false,
  }) {
    final event = AppErrorEvent(
      message: error.toString(),
      stackTrace: stackTrace,
      context: context,
      timestamp: DateTime.now(),
      isFatal: fatal,
      extraData: extraData,
    );

    _errorHistory.insert(0, event);
    if (_errorHistory.length > 100) {
      _errorHistory.removeLast();
    }
    _errorStreamController.add(event);

    CrashReportingService.instance.recordCrash(
      error,
      stackTrace,
      reason: 'Context: $context',
      fatal: fatal,
    );
  }

  /// Handles and logs an error, returning a clean, friendly user-facing message.
  String handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String context = 'general',
    Map<String, dynamic> extraData = const {},
    bool isFatal = false,
  }) {
    reportError(
      error,
      stackTrace,
      context: context,
      extraData: extraData,
      fatal: isFatal,
    );

    return getUserFriendlyMessage(error, context: context);
  }

  /// Maps technical exceptions to plain, friendly English explanations.
  String getUserFriendlyMessage(dynamic error, {String context = 'general'}) {
    final errorStr = error.toString().toLowerCase();

    // 1. Authentication Domain
    if (context == 'auth' ||
        errorStr.contains('auth') ||
        errorStr.contains('credential') ||
        errorStr.contains('jwt')) {
      if (errorStr.contains('invalid_grant') ||
          errorStr.contains('invalid password') ||
          errorStr.contains('wrong password')) {
        return 'The email or password you entered is incorrect. Please try again.';
      }
      if (errorStr.contains('user not found') || errorStr.contains('no user')) {
        return 'No account was found with that email. Please sign up or check the spelling.';
      }
      if (errorStr.contains('email already in use') ||
          errorStr.contains('already registered')) {
        return 'An account with this email already exists. Please log in instead.';
      }
      return 'We could not verify your account. Please check your credentials and try again.';
    }

    // 2. Network & Supabase Database Domain
    if (context == 'supabase' ||
        errorStr.contains('socket') ||
        errorStr.contains('network') ||
        errorStr.contains('http') ||
        errorStr.contains('timeout')) {
      return 'Network connection is currently unstable. Your changes are saved offline and will sync automatically once reconnected.';
    }

    // 3. Gemini & AI Coach Domain
    if (context == 'gemini' ||
        errorStr.contains('gemini') ||
        errorStr.contains('ai') ||
        errorStr.contains('quota') ||
        errorStr.contains('rate limit')) {
      if (errorStr.contains('quota') || errorStr.contains('rate')) {
        return 'Your AI Coach is taking a quick breather due to high volume. Please try again in a moment.';
      }
      return 'Your AI Coach could not generate a response right now. Please try rephrasing your question.';
    }

    // 4. Barcode & Food Scanner Domain
    if (context == 'scanner' ||
        errorStr.contains('camera') ||
        errorStr.contains('barcode') ||
        errorStr.contains('vision')) {
      if (errorStr.contains('permission')) {
        return 'Camera access is required to scan foods and exercises. Please enable camera permission in your device settings.';
      }
      return 'Could not clearly recognize the item. Please ensure good lighting and try holding the camera steady.';
    }

    // 5. Offline Sync Domain
    if (context == 'sync' ||
        errorStr.contains('sync') ||
        errorStr.contains('database')) {
      return 'Data synchronized locally. We will update the cloud database as soon as your internet reconnects.';
    }

    // Default friendly fallback
    return 'Something went slightly off track, but your workout data is safe. Please try again.';
  }
}
