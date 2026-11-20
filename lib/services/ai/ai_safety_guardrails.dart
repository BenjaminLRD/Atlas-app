/// Outcome of an AI Safety validation check.
class SafetyCheckResult {
  final bool isSafe;
  final String?
  violationType; // 'medical_diagnosis', 'unsafe_training', 'unauthorized_plan_change', 'missing_reasoning'
  final String? warningMessage;
  final String? sanitizedResponse;

  const SafetyCheckResult({
    required this.isSafe,
    this.violationType,
    this.warningMessage,
    this.sanitizedResponse,
  });

  factory SafetyCheckResult.safe([String? response]) =>
      SafetyCheckResult(isSafe: true, sanitizedResponse: response);

  factory SafetyCheckResult.violation({
    required String violationType,
    required String warningMessage,
    String? sanitizedResponse,
  }) => SafetyCheckResult(
    isSafe: false,
    violationType: violationType,
    warningMessage: warningMessage,
    sanitizedResponse: sanitizedResponse,
  );
}

/// Strict Safety System ensuring Atlas AI Coach adheres to clinical, physiological,
/// and permission boundaries at all times.
class AISafetyGuardrails {
  static AISafetyGuardrails? _instance;
  static AISafetyGuardrails get instance => _instance ??= AISafetyGuardrails();

  static const String medicalDisclaimer =
      '⚠️ **Medical Advisory**: Atlas AI provides athletic fitness and nutrition coaching, not medical diagnoses or treatment. If you are experiencing acute pain, suspected injury, or medical symptoms, please consult a qualified physician or healthcare provider immediately.';

  // ===========================================================================
  // 1. MEDICAL & CLINICAL SAFETY CHECK
  // ===========================================================================

  /// Validates user queries against clinical symptom inquiries or medical diagnosis requests.
  SafetyCheckResult validateUserQuery(String query) {
    final lower = query.toLowerCase();

    // Clinical red flag keywords
    final medicalSymptoms = [
      'diagnose',
      'diagnosis',
      'chest pain',
      'heart palpitation',
      'torn ligament',
      'torn muscle',
      'torn acl',
      'broken bone',
      'fracture',
      'severe dizziness',
      'concussion',
      'herniated disc',
      'blood in urine',
      'sharp shooting pain',
    ];

    for (final symptom in medicalSymptoms) {
      if (lower.contains(symptom)) {
        return SafetyCheckResult.violation(
          violationType: 'medical_diagnosis',
          warningMessage:
              'Query references medical condition or symptom ("$symptom"). Directing athlete to physician.',
          sanitizedResponse: medicalDisclaimer,
        );
      }
    }

    return SafetyCheckResult.safe();
  }

  // ===========================================================================
  // 2. TRAINING PHYSIOLOGICAL SAFETY CHECK
  // ===========================================================================

  /// Validates workout volume adjustments, load jumps, and training during critical fatigue.
  SafetyCheckResult validateTrainingAdjustment({
    required double currentVolumeOrLoad,
    required double proposedVolumeOrLoad,
    required int recoveryScore,
    bool isInjuryReported = false,
    bool userConfirmed = false,
  }) {
    // 1. Injury reported: never force training through injury
    if (isInjuryReported) {
      return SafetyCheckResult.violation(
        violationType: 'unsafe_training',
        warningMessage:
            'Cannot prescribe compound training through active acute injury.',
        sanitizedResponse:
            '⚠️ **Safety Warning**: Please rest the injured area and consult a medical professional. Active rehabilitation or complete rest is recommended.',
      );
    }

    // 2. Extreme load spike (>50% single session jump)
    if (currentVolumeOrLoad > 0) {
      final percentageIncrease =
          ((proposedVolumeOrLoad - currentVolumeOrLoad) / currentVolumeOrLoad) *
          100.0;
      if (percentageIncrease > 50.0) {
        return SafetyCheckResult.violation(
          violationType: 'unsafe_training',
          warningMessage:
              'Proposed load spike of +${percentageIncrease.toStringAsFixed(1)}% exceeds safe progressive overload ceiling (+10%).',
          sanitizedResponse:
              '⚠️ **Safety Advisory**: A volume increase of over 50% in a single session significantly increases tendon and ligament strain. Limit progressive overload to +2.5% to +10% increments.',
        );
      }
    }

    // 3. High overload during critical recovery (<40% readiness)
    if (recoveryScore < 40 && proposedVolumeOrLoad > currentVolumeOrLoad) {
      return SafetyCheckResult.violation(
        violationType: 'unsafe_training',
        warningMessage:
            'Readiness score is critical ($recoveryScore%). Forcing overload presents high overtraining risk.',
        sanitizedResponse:
            '⚠️ **Recovery Guardrail**: Your recovery score ($recoveryScore%) indicates high systemic fatigue. Increasing intensity today is counterproductive; a deload or rest day is required.',
      );
    }

    return SafetyCheckResult.safe();
  }

  // ===========================================================================
  // 3. PERMISSION GATE VALIDATION
  // ===========================================================================

  /// Enforces that major workout plan modifications or calorie shifts require user confirmation.
  SafetyCheckResult validatePlanModification({
    required String modificationType,
    required bool isConfirmed,
  }) {
    if (!isConfirmed) {
      return SafetyCheckResult.violation(
        violationType: 'unauthorized_plan_change',
        warningMessage:
            'Plan modification ("$modificationType") cannot be executed autonomously without athlete consent.',
      );
    }

    return SafetyCheckResult.safe();
  }

  // ===========================================================================
  // 4. MANDATORY REASONING CHECK
  // ===========================================================================

  /// Validates that all AI coach recommendations include explicit physiological rationale.
  SafetyCheckResult validateReasoning({
    required String recommendation,
    required String reasoning,
  }) {
    if (reasoning.trim().isEmpty) {
      return SafetyCheckResult.violation(
        violationType: 'missing_reasoning',
        warningMessage:
            'Every recommendation must provide transparent physiological/biomechanical reasoning.',
      );
    }

    return SafetyCheckResult.safe();
  }

  // ===========================================================================
  // 5. RESPONSE SANITIZATION
  // ===========================================================================

  /// Sanitizes any outgoing AI response for safety disclaimers and unverified claims.
  String sanitizeResponse(String response, {String? userQuery}) {
    var result = response;

    if (userQuery != null) {
      final queryCheck = validateUserQuery(userQuery);
      if (!queryCheck.isSafe && queryCheck.sanitizedResponse != null) {
        return '$medicalDisclaimer\n\n$response';
      }
    }

    // Guard against harmful "train through the pain" phrases
    final harmfulInjuryRegex = RegExp(
      r'(ignore\s+(?:your\s+)?injury|train\s+harder\s+through\s+the\s+(?:sharp\s+)?pain|push\s+through\s+the\s+injury)',
      caseSensitive: false,
    );
    if (harmfulInjuryRegex.hasMatch(result)) {
      result = result.replaceAll(
        harmfulInjuryRegex,
        'Stop the exercise immediately, rest the affected area, and consult a qualified medical professional.',
      );
    }

    return result;
  }
}
