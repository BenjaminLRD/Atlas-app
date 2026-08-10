import 'package:flutter/foundation.dart';

/// Abstract contract for user analytics event tracking.
abstract class AnalyticsProvider {
  void logEvent(String eventName, {Map<String, dynamic>? parameters});
  void setUserProperty(String key, String value);
  void setCurrentScreen(String screenName);
}

/// Debug implementation of [AnalyticsProvider] logging events in memory.
class DebugAnalyticsProvider implements AnalyticsProvider {
  final List<Map<String, dynamic>> loggedEvents = [];

  @override
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    final entry = {
      'event': eventName,
      'parameters': parameters ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };
    loggedEvents.insert(0, entry);
    debugPrint('[Analytics] Event: $eventName $parameters');
  }

  @override
  void setUserProperty(String key, String value) {
    debugPrint('[Analytics] UserProperty: $key = $value');
  }

  @override
  void setCurrentScreen(String screenName) {
    debugPrint('[Analytics] Screen: $screenName');
  }
}

/// Central Analytics Service delegating events to active provider.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static AnalyticsService get instance => _instance;

  AnalyticsProvider _provider = DebugAnalyticsProvider();

  void setProvider(AnalyticsProvider provider) {
    _provider = provider;
  }

  AnalyticsProvider get provider => _provider;

  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    _provider.logEvent(eventName, parameters: parameters);
  }

  void setUserProperty(String key, String value) {
    _provider.setUserProperty(key, value);
  }

  void setCurrentScreen(String screenName) {
    _provider.setCurrentScreen(screenName);
  }
}
