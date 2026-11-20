/// Biomechanical scoring breakdown for an exercise movement.
class FormScore {
  final double overallScore;
  final double techniqueScore;
  final double stabilityScore;
  final double rangeOfMotionScore;
  final double safetyScore;

  const FormScore({
    required this.overallScore,
    required this.techniqueScore,
    required this.stabilityScore,
    required this.rangeOfMotionScore,
    required this.safetyScore,
  });

  /// Letter grade representation based on overall score.
  String get grade {
    if (overallScore >= 90) return 'A+';
    if (overallScore >= 80) return 'A';
    if (overallScore >= 70) return 'B';
    if (overallScore >= 60) return 'C';
    return 'Needs Work';
  }

  /// Color status indicator helper.
  String get status {
    if (overallScore >= 80) return 'Optimal';
    if (overallScore >= 65) return 'Moderate';
    return 'High Risk';
  }

  factory FormScore.fromJson(Map<String, dynamic> json) {
    return FormScore(
      overallScore: (json['overallScore'] as num?)?.toDouble() ??
          (json['score'] as num?)?.toDouble() ??
          0.0,
      techniqueScore: (json['techniqueScore'] as num?)?.toDouble() ??
          (json['technique'] as num?)?.toDouble() ??
          (json['overallScore'] as num?)?.toDouble() ??
          0.0,
      stabilityScore: (json['stabilityScore'] as num?)?.toDouble() ??
          (json['stability'] as num?)?.toDouble() ??
          80.0,
      rangeOfMotionScore: (json['rangeOfMotionScore'] as num?)?.toDouble() ??
          (json['range_of_motion'] as num?)?.toDouble() ??
          (json['mobility'] as num?)?.toDouble() ??
          85.0,
      safetyScore: (json['safetyScore'] as num?)?.toDouble() ??
          (json['safety'] as num?)?.toDouble() ??
          90.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'techniqueScore': techniqueScore,
    'stabilityScore': stabilityScore,
    'rangeOfMotionScore': rangeOfMotionScore,
    'safetyScore': safetyScore,
  };
}

/// Represents a specific biomechanical issue detected during pose analysis.
class FormIssue {
  final String problem;
  final String severity; // 'low', 'medium', 'high'
  final String solution;
  final double? timestampSeconds;
  final String? metricValue;

  const FormIssue({
    required this.problem,
    required this.severity,
    required this.solution,
    this.timestampSeconds,
    this.metricValue,
  });

  factory FormIssue.fromJson(Map<String, dynamic> json) {
    return FormIssue(
      problem: json['problem']?.toString() ?? json['issue']?.toString() ?? 'Form deviation detected',
      severity: json['severity']?.toString().toLowerCase() ?? 'medium',
      solution: json['solution']?.toString() ?? json['correction']?.toString() ?? 'Maintain proper alignment',
      timestampSeconds: (json['timestampSeconds'] as num?)?.toDouble() ??
          (json['timestamp'] as num?)?.toDouble(),
      metricValue: json['metricValue']?.toString() ?? json['metric']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'problem': problem,
    'severity': severity,
    'solution': solution,
    if (timestampSeconds != null) 'timestampSeconds': timestampSeconds,
    if (metricValue != null) 'metricValue': metricValue,
  };
}
