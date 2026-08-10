/// Secure management, validation, and masking helper for sensitive API keys and credentials.
class SecretsManager {
  static final Map<String, String> _secretsRegistry = {};

  /// Registers a secret safely in memory.
  static void setSecret(String key, String value) {
    _secretsRegistry[key] = value;
  }

  /// Retrieves a secret by key.
  static String? getSecret(String key) {
    return _secretsRegistry[key];
  }

  /// Checks if a non-empty secret is configured for the key.
  static bool isSecretConfigured(String key) {
    final val = _secretsRegistry[key];
    return val != null && val.trim().isNotEmpty && !val.contains('mock_placeholder');
  }

  /// Obfuscates a sensitive key for display or logging (e.g. AIzaSy...8xY).
  static String maskSecret(String secret) {
    if (secret.isEmpty) return '[EMPTY]';
    if (secret.length <= 8) return '****';
    final prefix = secret.substring(0, 4);
    final suffix = secret.substring(secret.length - 4);
    return '$prefix...$suffix';
  }

  /// Clears in-memory secrets (useful for testing or logouts).
  static void clearSecrets() {
    _secretsRegistry.clear();
  }
}
