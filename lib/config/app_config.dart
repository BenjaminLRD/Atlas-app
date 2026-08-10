enum AppEnvironment {
  development,
  staging,
  production,
}

/// Central configuration container for Aizawl Gym environment settings.
class AppConfig {
  final AppEnvironment environment;
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool enableAnalytics;
  final bool enableCrashReporting;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.enableAnalytics = true,
    this.enableCrashReporting = true,
  });

  /// Development environment settings.
  factory AppConfig.dev() {
    return const AppConfig(
      environment: AppEnvironment.development,
      apiBaseUrl: 'https://dev-api.aizawlgym.com',
      supabaseUrl: 'https://dev.supabase.aizawlgym.co',
      supabaseAnonKey: 'dev_anon_key_mock_123456789',
      enableAnalytics: false,
      enableCrashReporting: false,
    );
  }

  /// Staging environment settings.
  factory AppConfig.staging() {
    return const AppConfig(
      environment: AppEnvironment.staging,
      apiBaseUrl: 'https://staging-api.aizawlgym.com',
      supabaseUrl: 'https://staging.supabase.aizawlgym.co',
      supabaseAnonKey: 'staging_anon_key_mock_987654321',
      enableAnalytics: true,
      enableCrashReporting: true,
    );
  }

  /// Production launch environment settings.
  factory AppConfig.prod() {
    return const AppConfig(
      environment: AppEnvironment.production,
      apiBaseUrl: 'https://api.aizawlgym.com',
      supabaseUrl: 'https://supabase.aizawlgym.co',
      supabaseAnonKey: 'prod_anon_key_secure_000000000',
      enableAnalytics: true,
      enableCrashReporting: true,
    );
  }

  /// Detects active environment from String or String.fromEnvironment.
  factory AppConfig.fromEnvironment({String? envName}) {
    final env = envName ?? const String.fromEnvironment('ENV', defaultValue: 'dev');
    switch (env.toLowerCase().trim()) {
      case 'prod':
      case 'production':
        return AppConfig.prod();
      case 'staging':
        return AppConfig.staging();
      case 'dev':
      case 'development':
      default:
        return AppConfig.dev();
    }
  }

  bool get isProduction => environment == AppEnvironment.production;
  bool get isStaging => environment == AppEnvironment.staging;
  bool get isDevelopment => environment == AppEnvironment.development;
}
