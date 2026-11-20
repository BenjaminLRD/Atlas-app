import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'supabase_env.dart';

/// Exception thrown when a Supabase backend or network operation fails.
class SupabaseServiceException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const SupabaseServiceException(
    this.message, {
    this.statusCode,
    this.details,
  });

  @override
  String toString() => 'SupabaseServiceException: $message (Status: $statusCode)';
}

/// Central Supabase Client Service managing SDK lifecycle, connection diagnostics,
/// authentication session state, and database/storage routing.
class SupabaseService {
  static SupabaseService? _instance;
  final SupabaseEnv _env;
  bool _isSdkInitialized = false;

  SupabaseService._({SupabaseEnv? env}) : _env = env ?? SupabaseEnv.fromEnvironment();

  /// Global singleton accessor.
  static SupabaseService get instance => _instance ??= SupabaseService._();

  /// Custom injector for unit tests.
  static void setInstance(SupabaseService service) {
    _instance = service;
  }

  /// Reset singleton instance.
  static void resetInstance() {
    _instance = null;
  }

  /// Active environment configuration.
  SupabaseEnv get env => _env;

  /// Whether Supabase credentials are valid and SDK is initialized.
  bool get isInitialized => _isSdkInitialized || SupabaseClientManager.instance.isInitialized;

  /// Returns the underlying native SupabaseClient instance if initialized.
  SupabaseClient? get client {
    try {
      if (_isSdkInitialized) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  /// Initializes the Supabase SDK before runApp() using credentials from [env].
  Future<void> initialize({SupabaseEnv? customEnv}) async {
    final activeEnv = customEnv ?? _env;
    SupabaseClientManager.instance.initialize(activeEnv);

    if (!activeEnv.isValid) {
      debugPrint('[SupabaseService] ${activeEnv.diagnostic} Operating in offline mode; Atlas AI is unavailable.');
      return;
    }

    try {
      await Supabase.initialize(
        url: activeEnv.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: activeEnv.supabaseAnonKey,
        debug: kDebugMode,
      );
      _isSdkInitialized = true;
      debugPrint('[SupabaseService] Successfully initialized Supabase client connected to ${activeEnv.supabaseUrl}');
    } catch (e) {
      debugPrint('[SupabaseService] Notice: Supabase.initialize caught: $e (Falling back to local client manager)');
      // Keep local client manager initialized for offline resilience
      _isSdkInitialized = false;
    }
  }

  /// Tests connectivity to the Supabase endpoint.
  Future<bool> checkConnection() async {
    if (!_env.isValid) return false;
    if (_isSdkInitialized && client != null) {
      try {
        await client!.from('profiles').select('id').limit(1).maybeSingle();
        return true;
      } catch (e) {
        debugPrint('[SupabaseService] Connectivity check caught: $e');
      }
    }
    return isInitialized;
  }

  /// Gets the current authenticated user's ID if a session is active.
  String? get currentUserId {
    try {
      if (_isSdkInitialized && client != null) {
        return client!.auth.currentUser?.id;
      }
    } catch (_) {}
    return SupabaseClientManager.instance.authenticatedUid;
  }
}
