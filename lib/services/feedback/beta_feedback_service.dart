import 'package:flutter/foundation.dart';
import '../../models/user_feedback.dart';
import '../analytics/analytics_service.dart';

/// Central coordinator for beta tester feedback submissions, bug reports, and UX telemetry.
class BetaFeedbackService {
  static final BetaFeedbackService _instance = BetaFeedbackService._internal();
  factory BetaFeedbackService() => _instance;
  BetaFeedbackService._internal();

  static BetaFeedbackService get instance => _instance;

  final List<UserFeedback> _feedbackList = [];

  List<UserFeedback> get feedbackList => List.unmodifiable(_feedbackList);

  /// Submits a new feedback item from the user
  Future<bool> submitFeedback({
    required String userId,
    required String feedback,
    required String
    category, // 'bug', 'feature_request', 'ui_issue', 'ai_issue'
    String priority = 'medium',
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    if (feedback.trim().isEmpty) return false;

    final item = UserFeedback(
      id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      feedback: feedback.trim(),
      category: category,
      priority: priority,
      deviceInfo: deviceInfo.isNotEmpty
          ? deviceInfo
          : {'platform': defaultTargetPlatform.name, 'app_version': '1.1.51'},
      timestamp: DateTime.now(),
    );

    _feedbackList.insert(0, item);

    // Track analytics event
    AnalyticsService.instance.trackEvent(
      'beta_feedback_submitted',
      parameters: {'category': category, 'priority': priority},
    );

    debugPrint(
      '[BetaFeedbackService] Submitted $category (Priority: $priority): "${item.feedback}"',
    );
    return true;
  }

  /// Retrieves feedback submitted by a specific user
  List<UserFeedback> getUserFeedbackList(String userId) {
    return _feedbackList.where((f) => f.userId == userId).toList();
  }

  /// Clears in-memory list (useful for tests)
  void clearFeedback() {
    _feedbackList.clear();
  }
}
