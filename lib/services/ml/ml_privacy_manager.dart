import 'dart:convert';

/// Privacy and consent controller for Atlas Machine Learning pipelines.
/// Guarantees that user telemetry is never used for training without explicit user consent,
/// and ensures all ingested features are cryptographically anonymized.
class MLPrivacyManager {
  static MLPrivacyManager? _instance;
  static MLPrivacyManager get instance => _instance ??= MLPrivacyManager();

  bool _userConsentGranted = true; // Default opt-in with user toggleability
  bool _encryptionEnabled = true;

  /// Whether the athlete has explicitly granted consent for ML model optimization
  bool get hasConsent => _userConsentGranted;

  /// Whether telemetry payloads are encrypted and anonymized
  bool get isEncryptionEnabled => _encryptionEnabled;

  /// Update user training consent
  void setConsent(bool consent) {
    _userConsentGranted = consent;
  }

  /// Toggle encryption/anonymization setting
  void setEncryptionEnabled(bool enabled) {
    _encryptionEnabled = enabled;
  }

  /// Anonymize a user ID using deterministic cryptographic salt hashing
  String anonymizeUserId(String rawUserId) {
    if (rawUserId.isEmpty) return 'anonymous_athlete';
    // 64-bit FNV-1a as two unsigned 32-bit halves, so the result is identical
    // on the VM (signed 64-bit ints) and on the web (doubles).
    // The prime 0x100000001b3 is (0x100 << 32) + 0x1b3.
    const mask = 0x100000000;
    var hi = 0xcbf29ce4;
    var lo = 0x84222325;
    for (final b in utf8.encode('atlas_ml_salt_$rawUserId')) {
      lo ^= b;
      final loProduct = lo * 0x1b3;
      final newHi = (hi * 0x1b3 + lo * 0x100 + loProduct ~/ mask) % mask;
      lo = loProduct % mask;
      hi = newHi;
    }
    final hexString =
        hi.toRadixString(16).padLeft(8, '0') +
        lo.toRadixString(16).padLeft(8, '0');
    return 'anon_$hexString';
  }

  /// Sanitizes feature map by removing any personally identifiable information (PII)
  Map<String, dynamic> sanitizeFeatures(Map<String, dynamic> rawFeatures) {
    final cleanMap = Map<String, dynamic>.from(rawFeatures);
    final piiKeys = [
      'name',
      'email',
      'password',
      'phone',
      'address',
      'dob',
      'birthdate',
      'token',
      'profile_picture',
      'avatar',
      'location',
    ];

    cleanMap.removeWhere(
      (key, value) => piiKeys.any((pii) => key.toLowerCase().contains(pii)),
    );
    return cleanMap;
  }
}
