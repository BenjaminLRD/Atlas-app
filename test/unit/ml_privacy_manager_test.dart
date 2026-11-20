import 'package:atlas/services/ml/ml_privacy_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MLPrivacyManager Cross-Platform Consistency & Privacy Tests', () {
    late MLPrivacyManager privacy;

    setUp(() {
      privacy = MLPrivacyManager.instance;
      privacy.setConsent(true);
      privacy.setEncryptionEnabled(true);
    });

    test('returns anonymous_athlete for empty user ID', () {
      expect(privacy.anonymizeUserId(''), equals('anonymous_athlete'));
    });

    test(
      'produces deterministic 64-bit FNV-1a hash matching known test vectors',
      () {
        // Golden vectors to ensure cross-platform consistency across VM and Web (dart2js)
        expect(
          privacy.anonymizeUserId('user_12345_sensitive'),
          equals('anon_6044fc6f8884d00a'),
        );
        expect(
          privacy.anonymizeUserId('test'),
          equals('anon_37ced17bda0b68f2'),
        );
        expect(
          privacy.anonymizeUserId('athlete_99'),
          equals('anon_c190326e5370f6f4'),
        );
      },
    );

    test('is deterministic across repeated calls', () {
      const user = 'athlete_cross_platform_user_42';
      final hash1 = privacy.anonymizeUserId(user);
      final hash2 = privacy.anonymizeUserId(user);

      expect(hash1, equals(hash2));
    });

    test(
      'generates valid 16-hex-digit 64-bit format without exposing raw ID',
      () {
        const user = 'secret_user_id_987';
        final anonId = privacy.anonymizeUserId(user);

        expect(anonId, startsWith('anon_'));
        expect(anonId, isNot(contains('secret')));
        expect(anonId, isNot(contains('987')));

        final hexPart = anonId.substring('anon_'.length);
        expect(hexPart.length, equals(16));
        expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hexPart), isTrue);
      },
    );

    test('different user IDs produce distinct anonymized hashes', () {
      final id1 = privacy.anonymizeUserId('athlete_A');
      final id2 = privacy.anonymizeUserId('athlete_B');
      expect(id1, isNot(equals(id2)));
    });

    test('sanitizes feature map by stripping all PII keys', () {
      final sanitized = privacy.sanitizeFeatures({
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'phone': '123-456-7890',
        'location': 'Gym A',
        'workout_volume': 15000.0,
        'reps': 45,
      });

      expect(sanitized.containsKey('name'), isFalse);
      expect(sanitized.containsKey('email'), isFalse);
      expect(sanitized.containsKey('phone'), isFalse);
      expect(sanitized.containsKey('location'), isFalse);
      expect(sanitized['workout_volume'], equals(15000.0));
      expect(sanitized['reps'], equals(45));
    });

    test('manages consent and encryption toggles correctly', () {
      expect(privacy.hasConsent, isTrue);
      privacy.setConsent(false);
      expect(privacy.hasConsent, isFalse);

      expect(privacy.isEncryptionEnabled, isTrue);
      privacy.setEncryptionEnabled(false);
      expect(privacy.isEncryptionEnabled, isFalse);
    });
  });
}
