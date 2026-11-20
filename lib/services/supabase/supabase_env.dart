import 'dart:io';

/// Supported deployment environments.
enum Environment { development, production }

/// Environment configuration holder for Supabase credentials and settings.
class SupabaseEnv {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final Environment environment;

  const SupabaseEnv({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.environment = Environment.development,
  });

  /// Factory creating environment configuration from `--dart-define` values
  /// (e.g. `flutter run --dart-define-from-file=.env`) or process variables.
  factory SupabaseEnv.fromEnvironment({
    Environment environment = Environment.development,
  }) {
    String url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    String anonKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );

    if (url.isEmpty) {
      try {
        url = Platform.environment['SUPABASE_URL'] ?? '';
      } catch (_) {}
    }
    if (anonKey.isEmpty) {
      try {
        anonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';
      } catch (_) {}
    }

    // No placeholder fallback: a build without the settings has empty values
    // and reports exactly what is missing (see [missingSettings]).
    return SupabaseEnv(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      environment: environment,
    );
  }

  /// Factory for development environment.
  factory SupabaseEnv.dev({
    String url = 'https://dev-project.supabase.co',
    String anonKey = 'dev_anon_key',
  }) {
    return SupabaseEnv(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      environment: Environment.development,
    );
  }

  /// Factory for production environment.
  factory SupabaseEnv.prod({required String url, required String anonKey}) {
    return SupabaseEnv(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      environment: Environment.production,
    );
  }

  bool get isValid =>
      supabaseUrl.isNotEmpty &&
      supabaseUrl.startsWith('http') &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey.length > 20;

  /// Names of the build settings that are absent or unusable. Never contains
  /// a value, so it is safe to log or show.
  List<String> get missingSettings => [
    if (!(supabaseUrl.startsWith('https://') ||
        supabaseUrl.startsWith('http://')))
      'SUPABASE_URL',
    if (supabaseAnonKey.length <= 20) 'SUPABASE_ANON_KEY',
  ];

  /// The build command that supplies both settings.
  static const String buildCommand =
      'flutter build apk --release --no-pub --dart-define-from-file=.env';

  /// A one-line diagnostic for a build with missing settings, or null when the
  /// configuration is usable. It names the settings only, never their values.
  String? get diagnostic {
    final missing = missingSettings;
    if (missing.isEmpty) return null;
    return 'Atlas was built without ${missing.join(' and ')}. '
        'Rebuild with: $buildCommand';
  }

  bool get isProduction => environment == Environment.production;
  bool get isDevelopment => environment == Environment.development;
}
