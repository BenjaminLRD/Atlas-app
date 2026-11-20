import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/exercise.dart';

/// Centralized reactive service managing active rest intervals between sets.
/// Provides automatic timer countdown, pause/resume, extend, skip, and duration calculation.
class RestTimerService {
  static RestTimerService? _instance;

  RestTimerService();

  static RestTimerService get instance {
    _instance ??= RestTimerService();
    return _instance!;
  }

  /// Reset singleton instance for testing
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  Timer? _timer;
  int _remainingSeconds = 0;
  int _totalDurationSeconds = 90;
  bool _isResting = false;
  bool _isPaused = false;
  String? _activeExerciseName;

  final ValueNotifier<int> remainingNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isRestingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);

  int get remainingSeconds => _remainingSeconds;
  int get totalDurationSeconds => _totalDurationSeconds;
  bool get isResting => _isResting;
  bool get isPaused => _isPaused;
  String? get activeExerciseName => _activeExerciseName;

  /// Progress ratio from 0.0 (just started) to 1.0 (completed)
  double get progressRatio {
    if (_totalDurationSeconds <= 0) return 1.0;
    return (1.0 - (_remainingSeconds / _totalDurationSeconds)).clamp(0.0, 1.0);
  }

  /// Calculates recommended rest duration in seconds based on exercise type and difficulty.
  /// - Heavy compound movements (Squat, Bench, Deadlift, Advanced): 180 seconds (3 min)
  /// - Standard Hypertrophy movements (Machines, DB Presses, Intermediate): 90 seconds (1.5 min)
  /// - Isolation / Accessory movements (Curls, Lateral Raises, Beginner): 60 seconds (1 min)
  int calculateRecommendedRestSeconds(dynamic exerciseOrName) {
    if (exerciseOrName is Exercise) {
      if (exerciseOrName.isCompound ||
          exerciseOrName.difficulty == 'Advanced' ||
          exerciseOrName.name.toLowerCase().contains('squat') ||
          exerciseOrName.name.toLowerCase().contains('deadlift') ||
          exerciseOrName.name.toLowerCase().contains('bench press')) {
        return 180;
      }
      if (exerciseOrName.exerciseType.toLowerCase().contains('isolation') ||
          exerciseOrName.movementPattern == 'isolation' ||
          exerciseOrName.difficulty == 'Beginner') {
        return 60;
      }
      return 90;
    }

    final nameLower = exerciseOrName.toString().toLowerCase().trim();
    if (nameLower.contains('squat') ||
        nameLower.contains('deadlift') ||
        nameLower.contains('bench press') ||
        nameLower.contains('overhead press') ||
        nameLower.contains('barbell row')) {
      return 180;
    }
    if (nameLower.contains('curl') ||
        nameLower.contains('lateral raise') ||
        nameLower.contains('fly') ||
        nameLower.contains('pushdown') ||
        nameLower.contains('extension') ||
        nameLower.contains('calf')) {
      return 60;
    }
    return 90;
  }

  /// Starts a rest countdown with the given duration.
  void startRest({required int durationSeconds, String? exerciseName}) {
    _timer?.cancel();
    _totalDurationSeconds = durationSeconds > 0 ? durationSeconds : 90;
    _remainingSeconds = _totalDurationSeconds;
    _isResting = true;
    _isPaused = false;
    _activeExerciseName = exerciseName;

    remainingNotifier.value = _remainingSeconds;
    isRestingNotifier.value = true;
    isPausedNotifier.value = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _isResting) {
        if (_remainingSeconds > 1) {
          _remainingSeconds--;
          remainingNotifier.value = _remainingSeconds;
        } else {
          _remainingSeconds = 0;
          remainingNotifier.value = 0;
          _isResting = false;
          isRestingNotifier.value = false;
          _timer?.cancel();
        }
      }
    });
  }

  /// Pauses active rest timer countdown.
  void pause() {
    if (_isResting && !_isPaused) {
      _isPaused = true;
      isPausedNotifier.value = true;
    }
  }

  /// Resumes paused rest timer countdown.
  void resume() {
    if (_isResting && _isPaused) {
      _isPaused = false;
      isPausedNotifier.value = false;
    }
  }

  /// Skips remaining rest and ends timer immediately.
  void skip() {
    _timer?.cancel();
    _remainingSeconds = 0;
    _isResting = false;
    _isPaused = false;
    remainingNotifier.value = 0;
    isRestingNotifier.value = false;
    isPausedNotifier.value = false;
  }

  /// Extends active rest timer by specified seconds (default +30s).
  void extend({int seconds = 30}) {
    if (_isResting) {
      _remainingSeconds += seconds;
      _totalDurationSeconds += seconds;
      remainingNotifier.value = _remainingSeconds;
    }
  }

  /// Resets timer state cleanly.
  void reset() {
    skip();
    _totalDurationSeconds = 90;
    _activeExerciseName = null;
  }

  /// Dispose timer resources and listeners
  void dispose() {
    _timer?.cancel();
    remainingNotifier.dispose();
    isRestingNotifier.dispose();
    isPausedNotifier.dispose();
  }
}
