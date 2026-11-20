import 'package:flutter/foundation.dart';

/// Single recorded performance metric trace.
class PerformanceTrace {
  final String name;
  final Stopwatch _stopwatch = Stopwatch();
  final Map<String, dynamic> attributes = {};
  Duration? _duration;

  PerformanceTrace(this.name) {
    _stopwatch.start();
  }

  /// Puts custom metadata attribute on the active trace.
  void putAttribute(String key, dynamic value) {
    attributes[key] = value;
  }

  /// Stops timer and records duration.
  Duration stop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _duration = _stopwatch.elapsed;
      debugPrint(
        '[PerformanceTracker] Trace "$name" finished in ${_duration!.inMilliseconds}ms ($attributes)',
      );
    }
    return _duration ?? Duration.zero;
  }

  /// Elapsed duration.
  Duration get duration => _duration ?? _stopwatch.elapsed;

  /// Whether trace is still actively measuring.
  bool get isRunning => _stopwatch.isRunning;
}

/// Central performance monitoring service measuring app startup, screen rendering,
/// AI response times, and database query latency.
class PerformanceTracker {
  static final PerformanceTracker _instance = PerformanceTracker._internal();
  factory PerformanceTracker() => _instance;
  PerformanceTracker._internal();

  static PerformanceTracker get instance => _instance;

  final Map<String, Duration> _completedTraces = {};
  final List<PerformanceTrace> _traceHistory = [];

  Map<String, Duration> get completedTraces =>
      Map.unmodifiable(_completedTraces);

  /// Measures cold or warm app launch duration.
  void recordAppStartup({
    required Duration duration,
    bool isColdLaunch = true,
  }) {
    final key = isColdLaunch ? 'app_startup_cold' : 'app_startup_warm';
    _completedTraces[key] = duration;
    debugPrint(
      '[PerformanceTracker] App Startup (${isColdLaunch ? "Cold" : "Warm"}): ${duration.inMilliseconds}ms',
    );
  }

  /// Starts a performance trace timer.
  PerformanceTrace startTrace(String name) {
    final trace = PerformanceTrace(name);
    _traceHistory.add(trace);
    return trace;
  }

  /// Helper to record execution time of an asynchronous operation.
  Future<T> measureAsync<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, dynamic>? attributes,
  }) async {
    final trace = startTrace(traceName);
    if (attributes != null) {
      attributes.forEach((k, v) => trace.putAttribute(k, v));
    }
    try {
      final result = await operation();
      final duration = trace.stop();
      _completedTraces[traceName] = duration;
      return result;
    } catch (e) {
      trace.putAttribute('error', e.toString());
      final duration = trace.stop();
      _completedTraces[traceName] = duration;
      rethrow;
    }
  }

  /// Clears recorded performance metrics.
  void clear() {
    _completedTraces.clear();
    _traceHistory.clear();
  }
}
