import 'package:flutter/foundation.dart';

/// Single performance trace capturing operation duration.
class PerformanceTrace {
  final String name;
  final DateTime startTime;
  int? durationMs;

  PerformanceTrace(this.name) : startTime = DateTime.now();

  void stop() {
    durationMs = DateTime.now().difference(startTime).inMilliseconds;
    debugPrint('[PerformanceMonitor] Trace "$name" completed in ${durationMs}ms');
  }
}

/// Service measuring app performance traces, async latency, and frame durations.
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  static PerformanceMonitor get instance => _instance;

  final Map<String, List<int>> _metricHistory = {};

  Map<String, double> get averageLatencies {
    final averages = <String, double>{};
    _metricHistory.forEach((key, list) {
      if (list.isNotEmpty) {
        final sum = list.reduce((a, b) => a + b);
        averages[key] = sum / list.length;
      }
    });
    return averages;
  }

  /// Starts a manual trace.
  PerformanceTrace startTrace(String name) {
    return PerformanceTrace(name);
  }

  /// Measures execution time of an asynchronous block.
  Future<T> measure<T>(String operationName, Future<T> Function() block) async {
    final trace = startTrace(operationName);
    try {
      return await block();
    } finally {
      trace.stop();
      if (trace.durationMs != null) {
        _recordMetric(operationName, trace.durationMs!);
      }
    }
  }

  void _recordMetric(String key, int durationMs) {
    _metricHistory.putIfAbsent(key, () => []);
    _metricHistory[key]!.insert(0, durationMs);
    if (_metricHistory[key]!.length > 20) {
      _metricHistory[key]!.removeLast();
    }
  }

  /// Clears recorded performance metrics.
  void clearMetrics() {
    _metricHistory.clear();
  }
}
