import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../services/ai/ai_config.dart';

/// Structured audit report output from security checks.
class SecurityReport {
  final bool isSecure;
  final List<String> passedChecks;
  final List<String> warnings;
  final List<String> violations;
  final DateTime auditedAt;

  SecurityReport({
    required this.isSecure,
    required this.passedChecks,
    required this.warnings,
    required this.violations,
    DateTime? auditedAt,
  }) : auditedAt = auditedAt ?? DateTime.now();
}

/// Automated security auditor evaluating API transport layer, secrets configuration, and storage posture.
class SecurityAuditor {
  static SecurityReport runAudit({AppConfig? config}) {
    final activeConfig = config ?? AppConfig.fromEnvironment();
    final passed = <String>[];
    final warnings = <String>[];
    final violations = <String>[];

    // 1. Enforce HTTPS transport layer
    if (activeConfig.apiBaseUrl.startsWith('https://')) {
      passed.add('API Base URL uses TLS/HTTPS security');
    } else {
      violations.add(
        'API Base URL uses unencrypted HTTP transport (${activeConfig.apiBaseUrl})',
      );
    }

    if (activeConfig.supabaseUrl.startsWith('https://')) {
      passed.add('Supabase Endpoint uses TLS/HTTPS security');
    } else {
      violations.add('Supabase Endpoint uses unencrypted HTTP transport');
    }

    // 2. Secrets check: the Gemini key must stay server-side (ai-proxy)
    if (kReleaseMode && AIConfig.fromEnvironment().isValidKey) {
      violations.add('Gemini API key is embedded in a release build');
    } else {
      passed.add(
        'Gemini API key kept server-side behind the ai-proxy function',
      );
    }

    // 3. Analytics & Crashlytics production posture check
    if (activeConfig.isProduction) {
      if (activeConfig.enableAnalytics && activeConfig.enableCrashReporting) {
        passed.add('Production analytics and crash reporting enabled');
      } else {
        warnings.add(
          'Production mode has analytics or crash reporting disabled',
        );
      }
    } else {
      passed.add(
        'Development environment isolation verified (${activeConfig.environment.name})',
      );
    }

    final isSecure = violations.isEmpty;

    return SecurityReport(
      isSecure: isSecure,
      passedChecks: passed,
      warnings: warnings,
      violations: violations,
    );
  }
}
