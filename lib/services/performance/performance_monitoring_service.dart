import 'package:flutter/foundation.dart';

/// Single performance trace capturing operation duration and metadata.
class PerformanceTrace {
  final String name;
  final DateTime startTime;
  final Map<String, dynamic> attributes;
  int? durationMs;

  PerformanceTrace(this.name, {Map<String, dynamic>? attributes})
    : startTime = DateTime.now(),
      attributes = attributes ?? {};

  void stop() {
    durationMs = DateTime.now().difference(startTime).inMilliseconds;
    debugPrint(
      '[PerformanceMonitor] Trace "$name" completed in ${durationMs}ms',
    );
  }
}

/// Central performance monitoring service tracking app startup, screen transitions,
/// network latency, AI generation time, and computer vision processing durations.
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();
  factory PerformanceMonitoringService() => _instance;
  PerformanceMonitoringService._internal();

  static PerformanceMonitoringService get instance => _instance;

  final Map<String, List<int>> _metricHistory = {};
  int _appStartupTimeMs = 0;

  int get appStartupTimeMs => _appStartupTimeMs;
  Map<String, List<int>> get metricHistory => Map.unmodifiable(_metricHistory);

  /// 1. Track App Cold/Warm Startup Duration
  void trackAppStartupTime(int durationMs) {
    _appStartupTimeMs = durationMs;
    _recordMetric('app_startup', durationMs);
    debugPrint('[Performance] App Startup Time: ${durationMs}ms');
  }

  /// 2. Track Screen Loading Duration
  void trackScreenLoadingTime(String screenName, int durationMs) {
    _recordMetric('screen_load_$screenName', durationMs);
    debugPrint('[Performance] Screen "$screenName" Loaded in ${durationMs}ms');
  }

  /// 3. Track REST / Supabase API Latency
  void trackApiLatency(String endpoint, int durationMs) {
    _recordMetric('api_latency_$endpoint', durationMs);
    debugPrint('[Performance] API "$endpoint" Latency: ${durationMs}ms');
  }

  /// 4. Track Gemini AI Coach Response Time
  void trackAiResponseTime(String operation, int durationMs) {
    _recordMetric('ai_response_$operation', durationMs);
    debugPrint(
      '[Performance] AI Operation "$operation" Completed in ${durationMs}ms',
    );
  }

  /// 5. Track Computer Vision / Image Processing Time
  void trackImageProcessingTime(String imageType, int durationMs) {
    _recordMetric('image_processing_$imageType', durationMs);
    debugPrint('[Performance] Image Processing "$imageType": ${durationMs}ms');
  }

  /// Starts a manual trace
  PerformanceTrace startTrace(String name, {Map<String, dynamic>? attributes}) {
    return PerformanceTrace(name, attributes: attributes);
  }

  /// Executes and measures an asynchronous operation automatically
  Future<T> measureAsync<T>(
    String operationName,
    Future<T> Function() block,
  ) async {
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
    if (_metricHistory[key]!.length > 100) {
      _metricHistory[key]!.removeLast();
    }
  }

  /// Returns calculated average latency for a specific metric key
  double getAverageLatency(String metricKey) {
    final list = _metricHistory[metricKey];
    if (list == null || list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  /// Returns summary map of all average metrics
  Map<String, double> getAllAverageLatencies() {
    final averages = <String, double>{};
    _metricHistory.forEach((key, list) {
      if (list.isNotEmpty) {
        averages[key] = list.reduce((a, b) => a + b) / list.length;
      }
    });
    return averages;
  }

  void clearMetrics() {
    _metricHistory.clear();
  }
}
