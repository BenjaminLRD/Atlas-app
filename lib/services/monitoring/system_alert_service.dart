import 'infrastructure_monitoring_service.dart';

/// Severity levels for infrastructure and service alerts.
enum AlertSeverity {
  info('INFO'),
  warning('WARNING'),
  critical('CRITICAL');

  final String code;
  const AlertSeverity(this.code);
}

/// An active or resolved system alert notification.
class SystemAlert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;
  bool isResolved;

  SystemAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.isResolved = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'severity': severity.code,
    'timestamp': timestamp.toIso8601String(),
    'is_resolved': isResolved,
  };
}

/// Real-Time System Alerting & Incident Management Service.
/// Evaluates health metrics against critical SLAs and debounces notification delivery.
class SystemAlertService {
  static SystemAlertService? _instance;
  static SystemAlertService get instance => _instance ??= SystemAlertService();

  static void resetInstance() {
    _instance = null;
  }

  final List<SystemAlert> _activeAlerts = [];

  List<SystemAlert> get activeAlerts =>
      List.unmodifiable(_activeAlerts.where((a) => !a.isResolved));
  List<SystemAlert> get allAlerts => List.unmodifiable(_activeAlerts);

  /// Evaluates current metrics snapshot against infrastructure thresholds.
  List<SystemAlert> evaluateMetrics(InfrastructureMetricsSnapshot metrics) {
    final triggered = <SystemAlert>[];
    final now = DateTime.now();

    // 1. Error Rate Threshold (Critical > 3.0%)
    if (metrics.errorRatePct > 3.0) {
      triggered.add(_triggerAlert(
        id: 'alert_error_rate_high',
        title: 'High API Error Rate Detected',
        message: 'API error rate exceeded threshold: ${metrics.errorRatePct}% (SLA: <1.0%)',
        severity: AlertSeverity.critical,
        timestamp: now,
      ));
    }

    // 2. Latency p95 Threshold (Warning > 800ms)
    if (metrics.latencyP95Ms > 800.0) {
      triggered.add(_triggerAlert(
        id: 'alert_latency_p95_high',
        title: 'API Latency Spike (p95)',
        message: 'p95 latency reached ${metrics.latencyP95Ms.round()}ms (SLA: <300ms)',
        severity: AlertSeverity.warning,
        timestamp: now,
      ));
    }

    // 3. AI Service Failure Rate Threshold (Critical > 5.0%)
    if (metrics.aiServiceFailureRatePct > 5.0) {
      triggered.add(_triggerAlert(
        id: 'alert_ai_gateway_failure',
        title: 'AI Gateway Degradation',
        message: 'AI failure rate spiked to ${metrics.aiServiceFailureRatePct}%',
        severity: AlertSeverity.critical,
        timestamp: now,
      ));
    }

    return triggered;
  }

  /// Triggers a system alert with automatic deduplication.
  SystemAlert _triggerAlert({
    required String id,
    required String title,
    required String message,
    required AlertSeverity severity,
    required DateTime timestamp,
  }) {
    final existingIndex = _activeAlerts.indexWhere((a) => a.id == id && !a.isResolved);
    if (existingIndex >= 0) {
      return _activeAlerts[existingIndex];
    }

    final alert = SystemAlert(
      id: id,
      title: title,
      message: message,
      severity: severity,
      timestamp: timestamp,
    );
    _activeAlerts.add(alert);
    return alert;
  }

  /// Resolves an existing alert.
  void resolveAlert(String id) {
    final alert = _activeAlerts.firstWhere((a) => a.id == id, orElse: () => _activeAlerts.first);
    alert.isResolved = true;
  }
}
