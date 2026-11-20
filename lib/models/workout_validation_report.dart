/// Severity of a workout constraint violation.
enum ConstraintSeverity { info, warning, critical }

/// Represents an individual constraint violation detected during workout validation.
class ConstraintViolation {
  final String constraintName;
  final String exerciseName;
  final String message;
  final ConstraintSeverity severity;
  final String? suggestedFix;

  const ConstraintViolation({
    required this.constraintName,
    required this.exerciseName,
    required this.message,
    this.severity = ConstraintSeverity.warning,
    this.suggestedFix,
  });

  Map<String, dynamic> toJson() => {
    'constraint_name': constraintName,
    'exercise_name': exerciseName,
    'message': message,
    'severity': severity.name,
    'suggested_fix': suggestedFix,
  };

  factory ConstraintViolation.fromJson(Map<String, dynamic> json) {
    final sevStr = json['severity'] as String? ?? 'warning';
    final severity = ConstraintSeverity.values.firstWhere(
      (s) => s.name.toLowerCase() == sevStr.toLowerCase(),
      orElse: () => ConstraintSeverity.warning,
    );
    return ConstraintViolation(
      constraintName: json['constraint_name'] as String? ?? 'general',
      exerciseName: json['exercise_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: severity,
      suggestedFix: json['suggested_fix'] as String?,
    );
  }
}

/// Detailed outcome report produced by the WorkoutValidationEngine.
class WorkoutValidationReport {
  final bool isValid;
  final int qualityScore; // 0 to 100
  final List<ConstraintViolation> violations;
  final List<String> passedChecks;
  final List<Map<String, dynamic>> sanitizedExercises;
  final String summary;

  const WorkoutValidationReport({
    required this.isValid,
    required this.qualityScore,
    this.violations = const [],
    this.passedChecks = const [],
    this.sanitizedExercises = const [],
    required this.summary,
  });

  /// Whether any critical violations exist that make the workout unsafe or unexecutable.
  bool get hasCriticalViolations =>
      violations.any((v) => v.severity == ConstraintSeverity.critical);

  /// Number of warnings that were auto-repaired or flagged.
  int get warningCount =>
      violations.where((v) => v.severity == ConstraintSeverity.warning).length;

  Map<String, dynamic> toJson() => {
    'is_valid': isValid,
    'quality_score': qualityScore,
    'violations_count': violations.length,
    'has_critical_violations': hasCriticalViolations,
    'violations': violations.map((v) => v.toJson()).toList(),
    'passed_checks': passedChecks,
    'sanitized_exercises_count': sanitizedExercises.length,
    'summary': summary,
  };

  factory WorkoutValidationReport.fromJson(Map<String, dynamic> json) {
    final rawViolations = json['violations'] as List? ?? const [];
    final violationsList = rawViolations
        .map(
          (v) =>
              ConstraintViolation.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList();

    final rawPassed = json['passed_checks'] as List? ?? const [];
    final passedList = rawPassed.map((e) => e.toString()).toList();

    final rawSanitized = json['sanitized_exercises'] as List? ?? const [];
    final sanitizedList = rawSanitized
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return WorkoutValidationReport(
      isValid: json['is_valid'] as bool? ?? true,
      qualityScore: (json['quality_score'] as num?)?.toInt() ?? 100,
      violations: violationsList,
      passedChecks: passedList,
      sanitizedExercises: sanitizedList,
      summary: json['summary'] as String? ?? 'Workout validation completed.',
    );
  }
}
