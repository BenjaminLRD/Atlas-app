/// Privacy redaction and sanitization filter for AI prompt context.
/// Strips personal identifiers, credentials, contact details, and sensitive metadata
/// before transmitting data to external AI models (e.g. Gemini, OpenAI).
class AIPrivacyFilter {
  const AIPrivacyFilter();

  static const AIPrivacyFilter instance = AIPrivacyFilter();

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _phoneRegex = RegExp(
    r'(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}',
  );

  static final RegExp _ssnOrIdRegex = RegExp(
    r'\b\d{3}-\d{2}-\d{4}\b|\b\d{9,12}\b',
  );

  static final RegExp _ipAddressRegex = RegExp(
    r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',
  );

  static final RegExp _creditCardRegex = RegExp(r'\b(?:\d[ -]*?){13,16}\b');

  /// Sanitizes a text string by masking emails, phone numbers, SSNs, credit cards, and IP addresses.
  String sanitizeText(String input) {
    if (input.isEmpty) return input;

    String sanitized = input;
    sanitized = sanitized.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    sanitized = sanitized.replaceAll(_phoneRegex, '[REDACTED_PHONE]');
    sanitized = sanitized.replaceAll(_creditCardRegex, '[REDACTED_CARD]');
    sanitized = sanitized.replaceAll(_ssnOrIdRegex, '[REDACTED_ID]');
    sanitized = sanitized.replaceAll(_ipAddressRegex, '[REDACTED_IP]');

    return sanitized;
  }

  /// Extracts an anonymized first name or fitness alias without exposing full legal names or PII.
  String anonymizeName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'Athlete';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'Athlete';
    final first = parts.first;
    // Strip special characters and keep alphanumeric
    final clean = first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return clean.isNotEmpty ? clean : 'Athlete';
  }

  /// Checks whether a raw prompt contains sensitive personal information.
  bool containsSensitiveInfo(String input) {
    if (input.isEmpty) return false;
    return _emailRegex.hasMatch(input) ||
        _phoneRegex.hasMatch(input) ||
        _creditCardRegex.hasMatch(input) ||
        _ssnOrIdRegex.hasMatch(input);
  }
}
