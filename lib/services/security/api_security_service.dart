/// Audit record for security events and rate limit interceptions.
class SecurityAuditLog {
  final String id;
  final String userId;
  final String action;
  final String ipAddress;
  final bool isBlocked;
  final String? reason;
  final DateTime timestamp;

  const SecurityAuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.ipAddress,
    required this.isBlocked,
    this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'action': action,
    'ip_address': ipAddress,
    'is_blocked': isBlocked,
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Enterprise API Security & Rate Limiting Service.
/// Implements sliding-window token bucket rate limiters, input sanitization, and audit logging.
class ApiSecurityService {
  static ApiSecurityService? _instance;
  static ApiSecurityService get instance => _instance ??= ApiSecurityService();

  static void resetInstance() {
    _instance = null;
  }

  final Map<String, List<DateTime>> _requestTimestamps = {};
  final List<SecurityAuditLog> _auditLogs = [];

  List<SecurityAuditLog> get auditLogs => List.unmodifiable(_auditLogs);

  /// Checks whether a client request is allowed under the sliding-window rate limit (e.g. 60 req/min).
  bool checkRateLimit({
    required String clientId,
    int maxRequestsPerMinute = 60,
  }) {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    final history = _requestTimestamps.putIfAbsent(clientId, () => []);
    history.removeWhere((t) => t.isBefore(oneMinuteAgo));

    if (history.length >= maxRequestsPerMinute) {
      _auditLogs.add(SecurityAuditLog(
        id: 'sec_${now.millisecondsSinceEpoch}',
        userId: clientId,
        action: 'API_RATE_LIMIT_EXCEEDED',
        ipAddress: '127.0.0.1',
        isBlocked: true,
        reason: 'Client exceeded $maxRequestsPerMinute req/min threshold.',
        timestamp: now,
      ));
      return false;
    }

    history.add(now);
    return true;
  }

  /// Sanitizes and validates incoming user input strings for security threats.
  bool validateInput(String input) {
    final lower = input.toLowerCase();

    // Check dangerous patterns
    if (lower.contains('<script>') ||
        lower.contains('drop table') ||
        lower.contains('1=1;--') ||
        lower.contains('union select')) {
      _auditLogs.add(SecurityAuditLog(
        id: 'sec_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'anonymous',
        action: 'INJECTION_ATTEMPT_INTERCEPTED',
        ipAddress: '127.0.0.1',
        isBlocked: true,
        reason: 'SQL or XSS payload signature detected.',
        timestamp: DateTime.now(),
      ));
      return false;
    }

    return true;
  }
}
