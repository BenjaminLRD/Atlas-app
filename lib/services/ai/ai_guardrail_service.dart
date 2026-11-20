import '../../models/user_profile.dart';
import 'goal_validation_service.dart';

/// Guardrail service ensuring AI Coach inputs and outputs remain fitness-focused,
/// medically safe, realistic, and free from off-topic requests or dangerous recommendations.
class AIGuardrailService {
  static AIGuardrailService? _instance;
  final GoalValidationService _goalValidator;

  AIGuardrailService({GoalValidationService? goalValidator})
    : _goalValidator = goalValidator ?? GoalValidationService.instance;

  static AIGuardrailService get instance => _instance ??= AIGuardrailService();

  static void resetInstance() {
    _instance = null;
  }

  /// Default friendly off-topic redirect message
  static const String defaultOffTopicResponse =
      'I am your fitness coach. I can help with workouts, nutrition, recovery, and health goals. How can I assist with your fitness journey today?';

  /// Backward compatible constant
  static const String offTopicResponse = defaultOffTopicResponse;

  /// Default safety response when a dangerous or impossible goal is requested
  static const String defaultSafetyResponse =
      '⚠️ **Safety Advisory**: That goal presents physiological safety risks. For sustainable progress, aim for 0.5kg–1.0kg of fat loss per week or 0.5kg–1.5kg of muscle growth per month with balanced nutrition and progressive training.';

  // ===========================================================================
  // 1. FITNESS DOMAIN CLASSIFICATION & INTENT FILTER
  // ===========================================================================

  /// Evaluates whether a user message is relevant to athletic training, nutrition, recovery, or health.
  bool isFitnessRelated(String message) {
    final raw = message.trim().toLowerCase();
    if (raw.isEmpty) return true;

    final clean = raw.replaceAll(RegExp(r'[?!.,;:]+$'), '').trim();

    // 1. Explicit off-topic triggers (politics, coding, homework, unrelated creative writing, entertainment)
    final offTopicKeywords = [
      'write code',
      'python',
      'javascript',
      'html',
      'css',
      'sql',
      'coding',
      'homework',
      'essay',
      'solve math',
      'algebra',
      'calculus',
      'physics problem',
      'president',
      'election',
      'politics',
      'political',
      'movie review',
      'movie',
      'movies',
      'cinema',
      'watch movie',
      'write a story',
      'write a poem',
      'bedtime story',
      'crypto',
      'cryptocurrency',
      'stock market',
      'bitcoin',
      'weather forecast',
      'recipe for cake',
      'joke about',
    ];

    // Whole words only, so "set" does not match "settings" or "rep" "report".
    for (final keyword in offTopicKeywords) {
      if (_containsWord(clean, keyword)) {
        return false;
      }
    }

    // 2. Unsafe goals are domain-specific body transformation topics
    if (containsUnsafeGoal(raw)) {
      return true;
    }

    // 3. Short greetings / meta coaching queries are allowed
    final greetings = [
      'hi',
      'hello',
      'hey',
      'help',
      'good morning',
      'good afternoon',
      'good evening',
      'thanks',
      'thank you',
      'how are you',
      'what can you do',
      'who are you',
    ];
    if (greetings.any(
      (g) =>
          clean == g ||
          clean.startsWith('$g ') ||
          clean.startsWith('$g!') ||
          clean.startsWith('$g?') ||
          clean.contains('what can you do') ||
          clean.contains('who are you'),
    )) {
      return true;
    }

    // 4. Everything else is allowed. Ambiguous questions, general
    // conversation, personal-fact questions and wellness queries go to the
    // model (whose prompt tells it to redirect clearly unrelated requests)
    // instead of being answered with a canned line.
    return true;
  }

  /// True when [phrase] appears in [text] as whole word(s).
  static bool _containsWord(String text, String phrase) => RegExp(
    '(^|[^a-z0-9])${RegExp.escape(phrase)}(?![a-z0-9])',
  ).hasMatch(text);

  // ===========================================================================
  // 2. UNSAFE GOAL & MEASUREMENT VALIDATION
  // ===========================================================================

  /// Checks if a message contains extreme weight loss, impossible muscle gain, or dangerous calorie targets.
  bool containsUnsafeGoal(String message) {
    final result = _goalValidator.validateGoalQuery(message);
    return !result.isSafe;
  }

  /// Validates a [UserProfile]'s physical measurements and age for biological plausibility.
  bool validateUserMetrics(UserProfile profile) {
    // Parse Height (handles "175", "175 cm", "5'10", etc.)
    double heightCm = 175.0;
    final rawHeight = profile.height.trim().toLowerCase();
    if (rawHeight.isNotEmpty) {
      if (rawHeight.contains("'")) {
        // Feet & inches format
        final parts = rawHeight.split("'");
        final feet = double.tryParse(parts[0]) ?? 5.0;
        final inches =
            double.tryParse(
              parts.length > 1 ? parts[1].replaceAll('"', '').trim() : '0',
            ) ??
            0.0;
        heightCm = (feet * 30.48) + (inches * 2.54);
      } else {
        final numeric = double.tryParse(
          rawHeight.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        if (numeric != null) {
          heightCm = numeric;
        }
      }
    }

    // Parse Weight (handles "70", "70kg", "154 lbs")
    double weightKg = 70.0;
    final rawWeight = profile.weight.trim().toLowerCase();
    if (rawWeight.isNotEmpty) {
      final isLbs =
          rawWeight.contains('lbs') || profile.massUnit.toLowerCase() == 'lbs';
      final numeric = double.tryParse(
        rawWeight.replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      if (numeric != null) {
        weightKg = isLbs ? numeric * 0.453592 : numeric;
      }
    }

    final result = _goalValidator.validateMetrics(
      age: profile.age,
      heightCm: heightCm,
      weightKg: weightKg,
    );

    return result.isSafe;
  }

  /// Returns tailored safety advice for an unsafe goal or extreme request.
  String getSafetyResponse([String? reason]) {
    if (reason != null && reason.isNotEmpty) {
      return '⚠️ **Safety Advisory**: $reason\n\nFor sustainable progress, aim for 0.5kg–1.0kg of fat loss per week or 0.5kg–1.5kg of muscle growth per month with balanced nutrition and progressive training.';
    }
    return defaultSafetyResponse;
  }

  /// Returns the polite off-topic rejection response.
  String getOffTopicResponse() {
    return defaultOffTopicResponse;
  }

  // ===========================================================================
  // 3. AI RESPONSE SANITIZATION & MEDICAL SAFETY
  // ===========================================================================

  /// Filters and sanitizes AI-generated responses for clinical safety, extreme guarantees, and medical disclaimers.
  String sanitizeAIResponse(String response, String userQuery) {
    var sanitized = response;

    // 1. Harmful extreme weight loss promises
    final extremeWeightLossRegex = RegExp(
      r'(guarantee.*(?:lose|drop).*(?:10|15|20|30|50)\s*kg.*(?:10|7|14|30)\s*days)|((?:lose|drop)\s*(?:10|15|20|30)\s*kg\s*in\s*(?:10|7|14)\s*days)',
      caseSensitive: false,
    );
    if (extremeWeightLossRegex.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(
        extremeWeightLossRegex,
        'Safe and sustainable fat loss is achieved at a rate of 0.5kg to 1.0kg per week.',
      );
    }

    // 2. Harmful injury advice (e.g. "ignore your injury and push through")
    final harmfulInjuryRegex = RegExp(
      r'(ignore\s+(?:your\s+)?injury|train\s+harder\s+through\s+the\s+sharp\s+pain|no\s+pain\s+no\s+gain\s+when\s+injured)',
      caseSensitive: false,
    );
    if (harmfulInjuryRegex.hasMatch(sanitized)) {
      sanitized = sanitized.replaceAll(
        harmfulInjuryRegex,
        'Stop the exercise immediately, rest the affected area, and consult a qualified medical professional.',
      );
    }

    // 3. Clinical & Medical Disclaimer Guardrail
    final lowerQuery = userQuery.toLowerCase();
    if (lowerQuery.contains('diagnos') ||
        lowerQuery.contains('chest pain') ||
        lowerQuery.contains('torn muscle') ||
        lowerQuery.contains('broken bone') ||
        lowerQuery.contains('severe dizziness')) {
      if (!sanitized.contains('Safety Advisory')) {
        sanitized =
            '⚠️ **Safety Advisory**: Atlas AI provides athletic and nutrition coaching, not clinical or medical diagnoses. If you are experiencing acute pain or potential injury, please seek immediate consultation from a qualified physician or healthcare specialist.\n\n$sanitized';
      }
    }

    return sanitized;
  }
}
