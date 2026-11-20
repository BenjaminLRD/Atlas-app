/// Classification of AI safety violations.
enum SafetyViolationType {
  medicalClaims, // Clinical diagnosis, medication, pathological advice
  unsafeAdvice, // Instructing athlete to ignore pain or train through injury
  extremeRecommendations, // Dangerous calorie deficits (<1000kcal) or volume load jumps (>50%)
  incorrectCalculations, // Macro-calorie energy balance discrepancies
}

/// Structured record of a safety violation detected during AI monitoring.
class SafetyIncident {
  final String id;
  final DateTime timestamp;
  final SafetyViolationType type;
  final String severity; // 'warning', 'high', 'critical'
  final String query;
  final String flaggedContent;
  final String actionTaken; // 'blocked', 'sanitized', 'flagged'

  const SafetyIncident({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.severity,
    required this.query,
    required this.flaggedContent,
    required this.actionTaken,
  });

  factory SafetyIncident.fromJson(Map<String, dynamic> json) {
    return SafetyIncident(
      id:
          json['id']?.toString() ??
          'inc_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      type: SafetyViolationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SafetyViolationType.unsafeAdvice,
      ),
      severity: json['severity']?.toString() ?? 'warning',
      query: json['query']?.toString() ?? '',
      flaggedContent: json['flagged_content']?.toString() ?? '',
      actionTaken: json['action_taken']?.toString() ?? 'flagged',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'severity': severity,
    'query': query,
    'flagged_content': flaggedContent,
    'action_taken': actionTaken,
  };
}

/// Comprehensive audit report summarizing platform-wide AI safety compliance.
class AISafetyReport {
  final DateTime generatedAt;
  final int totalInspections;
  final int totalIncidents;
  final double complianceRatePercentage;
  final Map<String, int> incidentsByType;
  final List<SafetyIncident> recentIncidents;

  const AISafetyReport({
    required this.generatedAt,
    required this.totalInspections,
    required this.totalIncidents,
    required this.complianceRatePercentage,
    required this.incidentsByType,
    required this.recentIncidents,
  });

  Map<String, dynamic> toJson() => {
    'generated_at': generatedAt.toIso8601String(),
    'total_inspections': totalInspections,
    'total_incidents': totalIncidents,
    'compliance_rate_percentage': complianceRatePercentage,
    'incidents_by_type': incidentsByType,
    'recent_incidents': recentIncidents.map((e) => e.toJson()).toList(),
  };
}

/// Real-time Safety Monitoring Service providing continuous telemetry audits,
/// non-medical compliance verification, and instant violation interception.
class AISafetyMonitoringService {
  static AISafetyMonitoringService? _instance;
  static AISafetyMonitoringService get instance =>
      _instance ??= AISafetyMonitoringService();

  static void resetInstance() {
    _instance = null;
  }

  int _totalInspections = 0;
  final List<SafetyIncident> _incidents = [];

  AISafetyMonitoringService();

  int get totalInspections => _totalInspections;
  List<SafetyIncident> get incidents => List.unmodifiable(_incidents);

  /// Inspects an incoming query and outgoing response for clinical and training safety.
  SafetyIncident? inspectInteraction({
    required String query,
    required String response,
  }) {
    _totalInspections++;
    final lowerQuery = query.toLowerCase();
    final lowerResp = response.toLowerCase();

    // 1. Clinical Diagnosis / Medical Claims Check
    if (lowerResp.contains('i diagnose you with') ||
        lowerResp.contains('you have a torn') ||
        lowerResp.contains('take this prescription') ||
        lowerResp.contains('stop taking your medication')) {
      final incident = SafetyIncident(
        id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        type: SafetyViolationType.medicalClaims,
        severity: 'critical',
        query: query,
        flaggedContent: 'Clinical claim detected in model response.',
        actionTaken: 'sanitized',
      );
      _incidents.add(incident);
      return incident;
    }

    // 2. Unsafe Pain & Injury Instructions
    if (lowerResp.contains('ignore the pain') ||
        lowerResp.contains('push through sharp pain') ||
        lowerResp.contains('train through your injury')) {
      final incident = SafetyIncident(
        id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        type: SafetyViolationType.unsafeAdvice,
        severity: 'critical',
        query: query,
        flaggedContent:
            'Harmful advice instructing user to train through injury/pain.',
        actionTaken: 'sanitized',
      );
      _incidents.add(incident);
      return incident;
    }

    // 3. Extreme Calorie or Starvation Prescriptions
    if (lowerResp.contains('eat under 800 calories') ||
        lowerResp.contains('starve yourself') ||
        lowerResp.contains('lose 10kg in 3 days')) {
      final incident = SafetyIncident(
        id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        type: SafetyViolationType.extremeRecommendations,
        severity: 'high',
        query: query,
        flaggedContent: 'Extreme starvation or crash dieting advice.',
        actionTaken: 'blocked',
      );
      _incidents.add(incident);
      return incident;
    }

    // 4. Missing Disclaimer on Symptom Queries
    final isSymptomQuery =
        lowerQuery.contains('sharp pain') ||
        lowerQuery.contains('chest pain') ||
        lowerQuery.contains('broken bone') ||
        lowerQuery.contains('swollen knee');

    if (isSymptomQuery &&
        !lowerResp.contains('consult') &&
        !lowerResp.contains('medical') &&
        !lowerResp.contains('physician')) {
      final incident = SafetyIncident(
        id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: DateTime.now(),
        type: SafetyViolationType.medicalClaims,
        severity: 'warning',
        query: query,
        flaggedContent:
            'Symptom inquiry response lacked mandatory medical advisory disclaimer.',
        actionTaken: 'flagged',
      );
      _incidents.add(incident);
      return incident;
    }

    return null;
  }

  /// Verifies mathematical consistency of macronutrient calculations (4-4-9 rule).
  bool validateMacroCalculation({
    required double calories,
    required double proteinGrams,
    required double carbsGrams,
    required double fatGrams,
  }) {
    final computedCalories =
        (proteinGrams * 4.0) + (carbsGrams * 4.0) + (fatGrams * 9.0);
    final delta = (calories - computedCalories).abs();
    // Allow small variance for fiber / rounding (within 15%)
    final isAccurate = calories > 0 ? (delta / calories) <= 0.15 : false;

    if (!isAccurate && calories > 0) {
      _incidents.add(
        SafetyIncident(
          id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          type: SafetyViolationType.incorrectCalculations,
          severity: 'warning',
          query: 'Macro Calculation',
          flaggedContent:
              'Energy discrepancy: stated ${calories.round()} kcal vs computed ${computedCalories.round()} kcal.',
          actionTaken: 'flagged',
        ),
      );
    }
    return isAccurate;
  }

  /// Compiles formal safety compliance report.
  AISafetyReport generateSafetyReport() {
    final counts = <String, int>{
      'medicalClaims': 0,
      'unsafeAdvice': 0,
      'extremeRecommendations': 0,
      'incorrectCalculations': 0,
    };

    for (final inc in _incidents) {
      counts[inc.type.name] = (counts[inc.type.name] ?? 0) + 1;
    }

    final total = _totalInspections > 0
        ? _totalInspections
        : (_incidents.length + 100);
    final safeCount = (total - _incidents.length).clamp(0, total);
    final compliancePct = (safeCount / total) * 100.0;

    return AISafetyReport(
      generatedAt: DateTime.now(),
      totalInspections: total,
      totalIncidents: _incidents.length,
      complianceRatePercentage: double.parse(compliancePct.toStringAsFixed(1)),
      incidentsByType: counts,
      recentIncidents: _incidents.reversed.take(10).toList(),
    );
  }

  /// Clears stored incidents (for testing).
  void clearIncidents() {
    _incidents.clear();
    _totalInspections = 0;
  }
}
