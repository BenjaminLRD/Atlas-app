import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../../data/local_storage.dart';
import '../supabase/supabase_env.dart';

/// Returns the signed-in user's access token, or null when signed out.
typedef AccessTokenProvider = String? Function();

/// Says whether Showcase Mode is on right now. Read on every request, so
/// switching modes takes effect at once.
typedef ShowcaseModeProvider = bool Function();

/// Why an AI request cannot be made right now.
enum AIUnavailableReason {
  /// This build has no AI backend: the Supabase URL and anon key were not
  /// passed when the app was built (no `--dart-define-from-file=.env`), so the
  /// `ai-proxy` function address is unknown. Signing in cannot fix this.
  backendNotConfigured,

  /// The AI backend is known, but nobody is signed in to Supabase.
  notSignedIn,
}

/// Configuration settings for the Gemini AI Provider.
///
/// Production traffic goes through the Supabase `ai-proxy` Edge Function
/// ([proxyUrl]), which holds the Gemini key server-side and enforces daily
/// quotas. [apiKey] is a developer-only key for calling Google directly from
/// debug builds; release builds never read it.
class AIConfig {
  /// The one client-side limit for an AI request (app, proxy and Gemini).
  /// Gemini 2.5 Flash can take well over 15 s on a long prompt.
  static const Duration requestTimeout = Duration(seconds: 45);

  /// Shown when [requestTimeout] passes without a response.
  static const String timeoutMessage =
      'Atlas AI took too long to respond. Please try again.';

  /// Upper bound on tokens Gemini may generate. For 2.5 models this includes
  /// thinking tokens, so it leaves room for the answer after [thinkingBudget].
  static const int maxOutputTokens = 2048;

  /// Tokens Gemini 2.5 Flash may spend thinking (valid range 0-24576; 0 turns
  /// thinking off, -1 is dynamic). A small cap keeps answers fast.
  static const int thinkingBudget = 512;

  /// `generationConfig` for coach requests. The proxy forwards it unchanged.
  static Map<String, dynamic> coachGenerationConfig(double temperature) => {
    'temperature': temperature,
    'maxOutputTokens': maxOutputTokens,
    'thinkingConfig': {'thinkingBudget': thinkingBudget},
  };

  final String apiKey;
  final String model;
  final double temperature;
  final String proxyUrl;
  final AccessTokenProvider? accessTokenProvider;

  /// The Supabase anon key. It is the public client key (it is already in
  /// every build and is safe to ship); it only identifies the project. Showcase
  /// requests present it instead of a user's access token.
  final String anonKey;

  /// Reports whether Showcase Mode is on. Null means it never is.
  final ShowcaseModeProvider? showcaseModeProvider;

  const AIConfig({
    this.apiKey = '',
    this.model = 'gemini-2.5-flash',
    this.temperature = 0.7,
    this.proxyUrl = '',
    this.accessTokenProvider,
    this.anonKey = '',
    this.showcaseModeProvider,
  });

  /// Builds the runtime configuration from `--dart-define` values.
  ///
  /// The proxy URL is derived from the Supabase project URL. A developer key
  /// (`GEMINI_API_KEY`) is only honoured outside release builds.
  factory AIConfig.fromEnvironment() {
    final supabaseEnv = SupabaseEnv.fromEnvironment();
    const model = String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'gemini-2.5-flash',
    );

    return AIConfig(
      apiKey: kReleaseMode ? '' : _debugApiKey(),
      model: model.isNotEmpty ? model : 'gemini-2.5-flash',
      temperature: 0.7,
      proxyUrl: supabaseEnv.isValid
          ? '${supabaseEnv.supabaseUrl}/functions/v1/ai-proxy'
          : '',
      accessTokenProvider: _supabaseAccessToken,
      anonKey: supabaseEnv.isValid ? supabaseEnv.supabaseAnonKey : '',
      showcaseModeProvider: LocalStorage.isShowcaseModeEnabled,
    );
  }

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    return AIConfig(
      apiKey: json['apiKey'] as String? ?? (json['api_key'] as String? ?? ''),
      model: json['model'] as String? ?? 'gemini-2.5-flash',
      temperature: (json['temperature'] as num? ?? 0.7).toDouble(),
      proxyUrl: json['proxy_url'] as String? ?? '',
    );
  }

  /// Serializes non-secret settings. The developer key is never written out.
  Map<String, dynamic> toJson() => {
    'model': model,
    'temperature': temperature,
    'proxy_url': proxyUrl,
  };

  AIConfig copyWith({
    String? apiKey,
    String? model,
    double? temperature,
    String? proxyUrl,
    AccessTokenProvider? accessTokenProvider,
    String? anonKey,
    ShowcaseModeProvider? showcaseModeProvider,
  }) {
    return AIConfig(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      accessTokenProvider: accessTokenProvider ?? this.accessTokenProvider,
      anonKey: anonKey ?? this.anonKey,
      showcaseModeProvider: showcaseModeProvider ?? this.showcaseModeProvider,
    );
  }

  /// True when a developer key is present for direct Google calls.
  bool get isValidKey => apiKey.isNotEmpty && apiKey.trim().length > 10;

  /// True when requests should go through the Edge Function proxy.
  bool get usesProxy => !isValidKey && proxyUrl.isNotEmpty;

  /// True while Showcase Mode is on.
  bool get isShowcase => showcaseModeProvider?.call() ?? false;

  /// True when requests go to the proxy as Showcase requests: Showcase Mode is
  /// on and the proxy is configured. They carry no user token and no user id,
  /// so a showcase request can never be attributed to a real account, even one
  /// that is signed in on the same device.
  bool get usesShowcaseProxy => usesProxy && isShowcase && anonKey.isNotEmpty;

  /// True when an AI request can be made right now: a developer key is set, or
  /// the proxy is configured and either Showcase Mode is on or a user is
  /// signed in.
  bool get isConfigured {
    if (isValidKey) return true;
    if (proxyUrl.isEmpty) return false;
    if (usesShowcaseProxy) return true;
    final token = accessTokenProvider?.call();
    return token != null && token.isNotEmpty;
  }

  /// Why [isConfigured] is false, or null when a request can be made.
  AIUnavailableReason? get unavailableReason {
    if (isConfigured) return null;
    return proxyUrl.isEmpty
        ? AIUnavailableReason.backendNotConfigured
        : AIUnavailableReason.notSignedIn;
  }

  static String _debugApiKey() {
    const defined = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (defined.isNotEmpty) return defined;
    try {
      return Platform.environment['GEMINI_API_KEY'] ?? '';
    } catch (_) {
      return '';
    }
  }

  static String? _supabaseAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }
}
