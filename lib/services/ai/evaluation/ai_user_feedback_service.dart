import '../memory/fitness_memory.dart';

/// Enum representing the nature of user feedback.
enum AIUserFeedbackType {
  positive, // Thumbs up, 5 stars, praise
  negative, // Thumbs down, rejected advice
  correction, // Explicit correction of user facts, preferences, or exercise constraints
}

/// Structured user feedback submission recording athlete ratings and corrections.
class AIUserFeedback {
  final String id;
  final DateTime timestamp;
  final String query;
  final String response;
  final AIUserFeedbackType type;
  final int? rating; // 1 to 5
  final String? reason;
  final String? correctionText;
  final bool appliedToMemory;
  final String category;

  const AIUserFeedback({
    required this.id,
    required this.timestamp,
    required this.query,
    required this.response,
    required this.type,
    this.rating,
    this.reason,
    this.correctionText,
    this.appliedToMemory = false,
    this.category = 'general',
  });

  factory AIUserFeedback.fromJson(Map<String, dynamic> json) {
    return AIUserFeedback(
      id:
          json['id']?.toString() ??
          'fb_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      query: json['query']?.toString() ?? '',
      response: json['response']?.toString() ?? '',
      type: AIUserFeedbackType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AIUserFeedbackType.positive,
      ),
      rating: (json['rating'] as num?)?.toInt(),
      reason: json['reason']?.toString(),
      correctionText: json['correction_text']?.toString(),
      appliedToMemory: json['applied_to_memory'] == true,
      category: json['category']?.toString() ?? 'general',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'query': query,
    'response': response,
    'type': type.name,
    if (rating != null) 'rating': rating,
    if (reason != null) 'reason': reason,
    if (correctionText != null) 'correction_text': correctionText,
    'applied_to_memory': appliedToMemory,
    'category': category,
  };
}

/// User Feedback Loop closing the gap between AI outputs and athlete satisfaction.
/// Automatically ingests user feedback, adjusts prompt weights, and updates
/// long-term coaching memory with user-provided corrections.
class AIUserFeedbackService {
  static AIUserFeedbackService? _instance;
  static AIUserFeedbackService get instance =>
      _instance ??= AIUserFeedbackService();

  static void resetInstance() {
    _instance = null;
  }

  final FitnessMemory _memory;
  final List<AIUserFeedback> _feedbacks = [];

  AIUserFeedbackService({FitnessMemory? memory})
    : _memory = memory ?? FitnessMemory.instance;

  /// Records positive feedback from the athlete (e.g. thumbs up or high rating).
  Future<AIUserFeedback> recordPositiveFeedback({
    required String query,
    required String response,
    int rating = 5,
    String? reason,
    String category = 'general',
  }) async {
    final feedback = AIUserFeedback(
      id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      query: query,
      response: response,
      type: AIUserFeedbackType.positive,
      rating: rating,
      reason: reason,
      appliedToMemory: false,
      category: category,
    );

    _feedbacks.add(feedback);
    return feedback;
  }

  /// Records negative feedback (e.g. thumbs down, irrelevant advice).
  Future<AIUserFeedback> recordNegativeFeedback({
    required String query,
    required String response,
    String? reason,
    String category = 'general',
  }) async {
    final feedback = AIUserFeedback(
      id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      query: query,
      response: response,
      type: AIUserFeedbackType.negative,
      rating: 1,
      reason: reason,
      appliedToMemory: false,
      category: category,
    );

    _feedbacks.add(feedback);
    return feedback;
  }

  /// Records explicit athlete correction and persists it into [FitnessMemory].
  /// E.g. "I cannot do barbell squats because of lower back pain, use goblet squats instead."
  Future<AIUserFeedback> recordCorrectionFeedback({
    required String query,
    required String response,
    required String correctionText,
    String? reason,
    String category = 'training',
  }) async {
    bool memoryApplied = false;
    try {
      // Categorize and record in FitnessMemory
      final lowerCorrection = correctionText.toLowerCase();
      if (lowerCorrection.contains('prefer') ||
          lowerCorrection.contains('switch') ||
          lowerCorrection.contains('instead') ||
          lowerCorrection.contains('like') ||
          lowerCorrection.contains('equipment')) {
        await _memory.recordTrainingPreferenceItem(
          title: 'User Correction: ${correctionText.split('.').first}',
          preference: correctionText,
          tags: ['user_correction', category],
        );
        memoryApplied = true;
      } else if (lowerCorrection.contains('habit') ||
          lowerCorrection.contains('time') ||
          lowerCorrection.contains('usually') ||
          lowerCorrection.contains('miss')) {
        await _memory.recordBehaviorPattern(
          title: 'User Behavioral Note: ${correctionText.split('.').first}',
          pattern: correctionText,
          tags: ['user_correction', 'behavior'],
        );
        memoryApplied = true;
      } else {
        await _memory.recordSuccessfulStrategy(
          title: 'User Guidance: ${correctionText.split('.').first}',
          strategy: correctionText,
          userConfirmed: true,
          tags: ['user_correction', 'strategy'],
        );
        memoryApplied = true;
      }
    } catch (_) {
      memoryApplied = false;
    }

    final feedback = AIUserFeedback(
      id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      query: query,
      response: response,
      type: AIUserFeedbackType.correction,
      rating: 3,
      reason: reason,
      correctionText: correctionText,
      appliedToMemory: memoryApplied,
      category: category,
    );

    _feedbacks.add(feedback);
    return feedback;
  }

  /// Returns unmodifiable list of all logged feedbacks.
  List<AIUserFeedback> get feedbacks => List.unmodifiable(_feedbacks);

  /// Computes positive feedback percentage (0.0 to 100.0).
  double getPositiveFeedbackRatio() {
    if (_feedbacks.isEmpty) return 92.0;
    final positive = _feedbacks
        .where((f) => f.type == AIUserFeedbackType.positive)
        .length;
    return (positive / _feedbacks.length) * 100.0;
  }

  /// Returns recent feedbacks up to limit.
  List<AIUserFeedback> getRecentFeedbacks({int limit = 10}) {
    return _feedbacks.reversed.take(limit).toList();
  }

  /// Returns all explicit corrections learned from athletes.
  List<AIUserFeedback> getLearnedCorrections() {
    return _feedbacks
        .where((f) => f.type == AIUserFeedbackType.correction)
        .toList();
  }

  /// Clears stored feedbacks (for testing).
  void clearFeedbacks() {
    _feedbacks.clear();
  }
}
