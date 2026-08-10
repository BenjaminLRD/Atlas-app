/// Supported deployment environments.
enum Environment {
  development,
  production,
}

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

  /// Factory creating environment configuration from build environment variables.
  factory SupabaseEnv.fromEnvironment({
    Environment environment = Environment.development,
  }) {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://dev-project.supabase.co',
    );
    const anonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dev_anon_key',
    );
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
  factory SupabaseEnv.prod({
    required String url,
    required String anonKey,
  }) {
    return SupabaseEnv(
      supabaseUrl: url,
      supabaseAnonKey: anonKey,
      environment: Environment.production,
    );
  }

  bool get isProduction => environment == Environment.production;
  bool get isDevelopment => environment == Environment.development;
}
