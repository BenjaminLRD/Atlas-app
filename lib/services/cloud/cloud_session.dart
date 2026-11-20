import 'package:supabase_flutter/supabase_flutter.dart';

/// Reports whether a real Supabase backend and signed-in user are available.
///
/// Everything in `services/cloud/` checks this before talking to the network,
/// so local-only builds, showcase mode and tests keep working offline.
class CloudSession {
  CloudSession._();

  /// Overrides the signed-in user id in tests. `null` uses Supabase.
  static String? Function()? debugUserIdOverride;

  /// The Supabase client, or null when the SDK was never initialized.
  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// True when the Supabase SDK is configured for this build.
  static bool get isConfigured => debugUserIdOverride != null || client != null;

  /// The signed-in Supabase user's id, or null when signed out.
  static String? get userId {
    final override = debugUserIdOverride;
    if (override != null) return override();
    return client?.auth.currentUser?.id;
  }
}
