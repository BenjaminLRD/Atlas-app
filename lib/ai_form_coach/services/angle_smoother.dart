/// Exponential moving average (EMA) filter for a joint angle that jitters from
/// frame to frame.
///
/// Adapted from FitnessPipe's `AngleSmoother`
/// (packages/fitness_counter/lib/src/core/smoothing.dart), MIT License,
/// Copyright (c) 2026 FitnessPipe Contributors. See THIRD_PARTY_NOTICES.md.
///
/// `smoothed = a * raw + (1 - a) * previous`, where `a` is [alpha]: higher is
/// more responsive and noisier, lower is smoother and lags more. The first
/// [warmupFrames] values after a start or [reset] pass through unchanged
/// (`a = 1`), so the filter does not drag the first readings toward zero.
class AngleSmoother {
  /// Smoothing factor in [0, 1].
  final double alpha;

  /// Frames after a start or [reset] that pass through unsmoothed.
  final int warmupFrames;

  double _value = 0.0;
  bool _initialized = false;
  int _frames = 0;

  AngleSmoother({this.alpha = 0.3, this.warmupFrames = 0}) {
    if (alpha < 0.0 || alpha > 1.0) {
      throw ArgumentError('alpha must be between 0.0 and 1.0');
    }
    if (warmupFrames < 0) {
      throw ArgumentError('warmupFrames must be >= 0');
    }
  }

  /// Blends [raw] into the filter and returns the smoothed value. The first
  /// value after a start or [reset] is returned as it is.
  double smooth(double raw) {
    if (!_initialized) {
      _value = raw;
      _initialized = true;
      _frames = 1;
    } else {
      _frames++;
      final a = _frames <= warmupFrames ? 1.0 : alpha;
      _value = a * raw + (1.0 - a) * _value;
    }
    return _value;
  }

  /// The last smoothed value (0 before the first [smooth]).
  double get value => _value;

  bool get isInitialized => _initialized;

  /// Frames processed since the start or the last [reset].
  int get frameCount => _frames;

  /// Forgets all history; the next value starts the filter again.
  void reset() {
    _value = 0.0;
    _initialized = false;
    _frames = 0;
  }
}
