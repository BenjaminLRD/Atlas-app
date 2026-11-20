import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'secure_storage_service.dart';

/// Handles one-time migration of sensitive user data from plaintext SharedPreferences
/// into hardware-backed encrypted SecureStorageService.
class SecureStorageMigration {
  static const String migrationFlagKey = 'secure_storage_migrated';

  /// Executes migration if not already completed.
  static Future<bool> run({
    required SharedPreferences prefs,
    required SecureStorageService secureStorage,
    bool force = false,
  }) async {
    final alreadyMigrated = prefs.getBool(migrationFlagKey) ?? false;
    if (alreadyMigrated && !force) {
      return false;
    }

    try {
      // 1. Migrate User Auth Session
      if (prefs.containsKey('app_user_session')) {
        final session = prefs.getString('app_user_session');
        if (session != null && session.isNotEmpty) {
          await secureStorage.saveSecureData('app_user_session', session);
        }
        await prefs.remove('app_user_session');
      }

      // 2. Migrate Health Telemetry (Heart rate, sleep, steps, active calories)
      if (prefs.containsKey('user_today_health_metric')) {
        final health = prefs.getString('user_today_health_metric');
        if (health != null && health.isNotEmpty) {
          await secureStorage.saveSecureData(
            'user_today_health_metric',
            health,
          );
        }
        await prefs.remove('user_today_health_metric');
      }

      // 3. Migrate Activity Records (Cardio / GPS telemetry)
      if (prefs.containsKey('user_activity_records')) {
        final records = prefs.getStringList('user_activity_records');
        if (records != null && records.isNotEmpty) {
          await secureStorage.saveSecureData(
            'user_activity_records',
            jsonEncode(records),
          );
        }
        await prefs.remove('user_activity_records');
      }

      // 4. Migrate User Profile with PII (Email, Phone, DOB, Height, Weight)
      if (prefs.containsKey('user_profile')) {
        final profileRaw = prefs.getString('user_profile');
        if (profileRaw != null && profileRaw.isNotEmpty) {
          try {
            final decoded = jsonDecode(profileRaw) as Map<String, dynamic>;
            decoded.remove('password'); // Purge legacy passwords
            await secureStorage.saveSecureData(
              'user_profile',
              jsonEncode(decoded),
            );
          } catch (_) {
            await secureStorage.saveSecureData('user_profile', profileRaw);
          }
        }
        await prefs.remove('user_profile');
      }

      // 5. Remove any standalone legacy password keys
      if (prefs.containsKey('user_password')) {
        await prefs.remove('user_password');
      }

      // Mark migration successful
      await prefs.setBool(migrationFlagKey, true);
      return true;
    } catch (_) {
      // On failure, do not set migrationFlagKey so it will retry safely on next launch
      return false;
    }
  }
}
