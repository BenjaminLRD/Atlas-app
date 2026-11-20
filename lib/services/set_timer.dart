/// Times one set, from the moment it starts to the moment it is finished.
///
/// The elapsed time comes from a monotonic clock (a [Stopwatch] by default),
/// never from counting one-second ticks, so a slow frame, a rebuilt widget or
/// the app sitting in the background cannot make the result drift. The widget
/// that shows the time only *reads* [elapsed]; it never owns the count.
///
/// There is exactly one running timing at a time: [start] on a running timer
/// does nothing, so a double tap cannot restart or double the clock.
class SetTimer {
  /// A monotonic clock reading, injectable so tests can move time exactly.
  final Duration Function() _now;
  Duration? _startedAt;

  /// Created with the platform monotonic clock unless a test supplies its own.
  SetTimer({Duration Function()? now}) : _now = now ?? _defaultNow;

  static final Stopwatch _clock = Stopwatch()..start();
  static Duration _defaultNow() => _clock.elapsed;

  bool get isRunning => _startedAt != null;

  /// Time since [start]; zero when no set is being timed.
  Duration get elapsed {
    final started = _startedAt;
    if (started == null) return Duration.zero;
    final d = _now() - started;
    return d.isNegative ? Duration.zero : d;
  }

  /// Begins timing. Returns false (and changes nothing) if already running.
  bool start() {
    if (_startedAt != null) return false;
    _startedAt = _now();
    return true;
  }

  /// Ends the timing and returns the whole seconds it took, or null if no set
  /// was being timed (so nothing can be recorded for a set that never began).
  int? stop() {
    if (_startedAt == null) return null;
    final seconds = (elapsed.inMilliseconds / 1000).round();
    _startedAt = null;
    return seconds;
  }

  /// Throws the timing away without producing a duration (an abandoned set).
  void cancel() => _startedAt = null;

  /// Formats a duration as mm:ss (or h:mm:ss past an hour).
  static String format(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
