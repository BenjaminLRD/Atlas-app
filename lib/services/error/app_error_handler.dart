import 'dart:async';
import 'package:flutter/foundation.dart';

enum ErrorSeverity {
  info,
  warning,
  error,
  fatal,
}

/// Structured error record for central logging and crash reporting.
class AppError {
  final String id;
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;
  final ErrorSeverity severity;
  final String? context;
  final DateTime timestamp;

  AppError({
    required this.id,
    required this.message,
    this.originalError,
    this.stackTrace,
    this.severity = ErrorSeverity.error,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Central error handling service capturing uncaught exceptions and app runtime errors.
class AppErrorHandler {
  static final AppErrorHandler _instance = AppErrorHandler._internal();
  factory AppErrorHandler() => _instance;
  AppErrorHandler._internal();

  static AppErrorHandler get instance => _instance;

  final List<AppError> _errorHistory = [];
  final StreamController<AppError> _errorStreamController =
      StreamController<AppError>.broadcast();

  List<AppError> get errorHistory => List.unmodifiable(_errorHistory);
  Stream<AppError> get errorStream => _errorStreamController.stream;

  /// Reports a runtime or uncaught error.
  void reportError(
    Object error,
    StackTrace? stackTrace, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? context,
    String? customMessage,
  }) {
    final appError = AppError(
      id: 'err_${DateTime.now().millisecondsSinceEpoch}',
      message: customMessage ?? error.toString(),
      originalError: error,
      stackTrace: stackTrace,
      severity: severity,
      context: context,
    );

    _errorHistory.insert(0, appError);
    if (_errorHistory.length > 100) {
      _errorHistory.removeLast();
    }

    _errorStreamController.add(appError);
    debugPrint('[AppErrorHandler] [${severity.name.toUpperCase()}] ${appError.message}');
  }

  /// Initializes global error hooks for Flutter and PlatformDispatcher.
  void initGlobalErrorHooks() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      reportError(
        details.exception,
        details.stack,
        severity: ErrorSeverity.error,
        context: 'FlutterError.onError',
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      reportError(
        error,
        stack,
        severity: ErrorSeverity.fatal,
        context: 'PlatformDispatcher.onError',
      );
      return true;
    };
  }

  /// Clears stored error history (useful for tests or diagnostics).
  void clearHistory() {
    _errorHistory.clear();
  }
}
