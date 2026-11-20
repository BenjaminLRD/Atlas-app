/// Supported deployment environments
enum AppEnvironmentType { development, testing, production }

/// Strongly typed environment configuration model.
///
/// Holds client-safe settings only. The Gemini key is a server secret used by
/// the `ai-proxy` Edge Function and is deliberately not part of this config.
class EnvironmentConfig {
  final AppEnvironmentType environment;
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String? analyticsWriteKey;
  final String? sentryDsn;
  final bool enableAnalytics;
  final bool enableCrashReporting;
  final bool enableLiveAI;
  final bool enableWearableSync;

  const EnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.analyticsWriteKey,
    this.sentryDsn,
    this.enableAnalytics = true,
    this.enableCrashReporting = true,
    this.enableLiveAI = true,
    this.enableWearableSync = true,
  });

  bool get isProduction => environment == AppEnvironmentType.production;
  bool get isTesting => environment == AppEnvironmentType.testing;
  bool get isDevelopment => environment == AppEnvironmentType.development;
}

/// Central environment manager resolving settings from compile-time `--dart-define` parameters.
class EnvironmentManager {
  static EnvironmentManager? _instance;
  EnvironmentConfig _config;

  EnvironmentManager._(this._config);

  static EnvironmentManager get instance {
    _instance ??= EnvironmentManager._(resolveFromDartDefine());
    return _instance!;
  }

  static void setInstance(EnvironmentManager manager) {
    _instance = manager;
  }

  static void resetInstance() {
    _instance = null;
  }

  EnvironmentConfig get config => _config;

  /// Resolves configuration from `--dart-define` with secure defaults
  static EnvironmentConfig resolveFromDartDefine() {
    const envString = String.fromEnvironment('ENV', defaultValue: 'dev');
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.aizawlgym.com',
    );
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://supabase.aizawlgym.co',
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.mock_anon_key',
    );
    const analyticsKey = String.fromEnvironment(
      'ANALYTICS_KEY',
      defaultValue: '',
    );
    const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

    const enableAnalytics = bool.fromEnvironment(
      'ENABLE_ANALYTICS',
      defaultValue: true,
    );
    const enableCrashReporting = bool.fromEnvironment(
      'ENABLE_CRASH_REPORTING',
      defaultValue: true,
    );
    const enableLiveAI = bool.fromEnvironment(
      'ENABLE_LIVE_AI',
      defaultValue: true,
    );
    const enableWearableSync = bool.fromEnvironment(
      'ENABLE_WEARABLE_SYNC',
      defaultValue: true,
    );

    AppEnvironmentType type;
    switch (envString.toLowerCase().trim()) {
      case 'prod':
      case 'production':
        type = AppEnvironmentType.production;
        break;
      case 'test':
      case 'testing':
        type = AppEnvironmentType.testing;
        break;
      case 'dev':
      case 'development':
      default:
        type = AppEnvironmentType.development;
        break;
    }

    return EnvironmentConfig(
      environment: type,
      apiBaseUrl: apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      analyticsWriteKey: analyticsKey.isNotEmpty ? analyticsKey : null,
      sentryDsn: sentryDsn.isNotEmpty ? sentryDsn : null,
      enableAnalytics: enableAnalytics,
      enableCrashReporting: enableCrashReporting,
      enableLiveAI: enableLiveAI,
      enableWearableSync: enableWearableSync,
    );
  }

  /// Sets custom environment config (useful for testing)
  void setConfig(EnvironmentConfig config) {
    _config = config;
  }
}
