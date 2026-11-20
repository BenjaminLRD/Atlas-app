import '../models/form_feedback.dart';

/// Decides which coaching cue the live form check shows, so the cue does not
/// flip between messages on every camera frame.
///
/// The idea comes from FitnessPipe's `FeedbackCooldownManager`
/// (packages/fitness_counter/lib/src/form_analyzers/feedback_cooldown_manager.dart),
/// MIT License, Copyright (c) 2026 FitnessPipe Contributors; see
/// THIRD_PARTY_NOTICES.md. It is adapted to Atlas's [FormFeedback], which has
/// plain-text warnings and corrections.
///
/// Rules:
/// - **Safety-critical feedback is never delayed.** A frame with any warning
///   (a form fault such as a rounded back, flared elbows or sagging hips) is
///   shown at once, whatever was shown before.
/// - Guidance without a warning (for example "lower the bar fully") may only
///   *change* the shown cue after [globalCooldown] since the last change and
///   [perCueCooldown] since that same cue was last shown. While throttled, the
///   cue already on screen stays.
/// - A cue that is still the current one stays; a frame with nothing to
///   correct clears the cue at once, and so does a fault cue once the fault
///   is gone.
/// - Frames where the body is not visible change nothing.
class FormCueThrottle {
  /// Minimum time between two changes of the guidance cue.
  final Duration globalCooldown;

  /// Minimum time before the same guidance cue is shown again.
  final Duration perCueCooldown;

  final DateTime Function() _clock;

  String? _current;
  bool _currentCritical = false;
  DateTime? _lastChange;
  final Map<String, DateTime> _lastShown = {};

  FormCueThrottle({
    this.globalCooldown = const Duration(seconds: 2),
    this.perCueCooldown = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// True when [feedback] contains a form fault that must be shown at once.
  static bool isSafetyCritical(FormFeedback feedback) =>
      feedback.bodyVisible && feedback.warnings.isNotEmpty;

  /// The cue on screen now, or null when there is none.
  String? get currentCue => _current;

  /// Takes one frame's [feedback] and returns the cue to show (null: nothing
  /// to correct).
  String? update(FormFeedback feedback) {
    if (!feedback.bodyVisible) return _current;

    final cue = feedback.corrections.isNotEmpty
        ? feedback.corrections.first
        : (feedback.warnings.isNotEmpty ? feedback.warnings.first : null);
    if (cue == null) {
      _current = null;
      _currentCritical = false;
      return null;
    }

    final now = _clock();
    if (isSafetyCritical(feedback)) {
      _show(cue, now, critical: true);
      return cue;
    }

    // A fault cue is dropped as soon as the fault is gone; it is not held for
    // the cooldown.
    if (_currentCritical) {
      _current = null;
      _currentCritical = false;
    }
    if (cue == _current) return cue;

    final last = _lastChange;
    if (last != null && now.difference(last) < globalCooldown) return _current;
    final seen = _lastShown[cue];
    if (seen != null && now.difference(seen) < perCueCooldown) return _current;

    _show(cue, now);
    return cue;
  }

  void _show(String cue, DateTime now, {bool critical = false}) {
    if (cue != _current) _lastChange = now;
    _current = cue;
    _currentCritical = critical;
    _lastShown[cue] = now;
  }

  /// Forgets everything (new exercise or a new set).
  void reset() {
    _current = null;
    _currentCritical = false;
    _lastChange = null;
    _lastShown.clear();
  }
}
