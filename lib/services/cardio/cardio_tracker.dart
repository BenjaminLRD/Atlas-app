import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/cardio_route.dart';
import 'cardio_journal.dart';

/// One position reported by the location source.
class GpsFix {
  final double lat;
  final double lng;

  /// Horizontal accuracy in metres, or null when the device does not say.
  final double? accuracyM;
  final DateTime time;

  const GpsFix(this.lat, this.lng, this.time, {this.accuracyM});
}

/// Whether the device lets Atlas read the location.
enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// Where positions come from. The app uses the device GPS; tests use a fake.
abstract class LocationSource {
  /// Checks and, if needed, asks for permission.
  Future<LocationAccess> ensureAccess();

  /// Positions as they arrive. May emit an error when GPS is switched off.
  ///
  /// [activityLabel] is shown in the ongoing notification that keeps tracking
  /// alive in the background on Android ("Running", "Cycling").
  Stream<GpsFix> positions({String activityLabel = 'activity'});
}

enum TrackerState { idle, running, paused, finished, discarded }

/// What the GPS is doing right now, for the status strip.
enum GpsStatus {
  /// Not started yet.
  idle,

  /// Started, still waiting for a usable first position.
  searching,

  /// Recent, accurate positions are arriving.
  good,

  /// Positions stopped arriving or are too inaccurate to use.
  weak,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,

  /// Another run or ride is already being recorded.
  busy,
}

/// The finished activity, as it will be saved. Every figure is measured or
/// null: a missing value is never turned into zero.
class CardioResult {
  final CardioKind kind;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Time spent moving or standing while the session was running, with paused
  /// time taken out.
  final int activeSeconds;
  final int pausedSeconds;
  final double distanceM;
  final List<RoutePoint> route;

  /// Average speed over the active time, or null when too little was recorded.
  final double? avgSpeedKmh;
  final double? avgPaceSecPerKm;

  /// Estimated energy, or null when it cannot be defended (no body weight, or
  /// no measured speed).
  final double? caloriesEstimate;

  const CardioResult({
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.activeSeconds,
    required this.pausedSeconds,
    required this.distanceM,
    required this.route,
    required this.avgSpeedKmh,
    required this.avgPaceSecPerKm,
    required this.caloriesEstimate,
  });

  double get distanceKm => distanceM / 1000;

  /// The same figures in the form that is saved.
  CardioSessionDraft toDraft() => CardioSessionDraft(
    kind: kind,
    startedAt: startedAt,
    endedAt: endedAt,
    activeSeconds: activeSeconds,
    pausedSeconds: pausedSeconds,
    distanceM: distanceM,
    route: route,
    avgSpeedKmh: avgSpeedKmh,
    avgPaceSecPerKm: avgPaceSecPerKm,
    caloriesEstimate: caloriesEstimate,
  );
}

/// Turns a stream of GPS positions into the live figures of a run or ride.
///
/// Rules that keep the numbers honest:
/// * only accurate positions count, glitches that imply an impossible speed
///   are dropped, and tiny wobbles while standing still add no distance;
/// * distance and time only accumulate while the session is running, never
///   while paused, and the stretch travelled across a pause is not counted;
/// * calories are an estimate from the measured average speed and the
///   athlete's body weight, and are null without both.
class CardioTracker extends ChangeNotifier {
  CardioTracker({
    required this.kind,
    required this.source,
    this.weightKg,
    DateTime Function()? clock,
    this.journal,
  }) : _now = clock ?? DateTime.now;

  /// Keeps a recovery copy of the session on the device, so a run is not lost
  /// if Android or iOS ends the app while it is recording.
  final CardioJournal? journal;

  /// The one session that is recording right now. Only one can be, so a second
  /// screen can never start a second GPS service.
  static CardioTracker? _active;

  /// True while some tracker is recording.
  static bool get isAnyRecording => _active?.hasStarted ?? false;

  /// Forgets any recording in progress. For tests, which share this state.
  @visibleForTesting
  static void resetForTest() => _active = null;

  DateTime? _lastJournalAt;
  int _journalPoints = 0;

  final CardioKind kind;
  final LocationSource source;
  final double? weightKg;
  final DateTime Function() _now;

  /// Positions less accurate than this are ignored.
  static const double maxAccuracyM = 30;

  /// Movement smaller than this is treated as GPS jitter.
  static const double minStepM = 3;

  /// No usable position for this long means the signal is lost.
  static const Duration signalTimeout = Duration(seconds: 12);

  /// Window used for the current pace or speed.
  static const Duration rateWindow = Duration(seconds: 15);

  double get _maxPlausibleMps => kind.isRunning ? 12.0 : 25.0;

  TrackerState _state = TrackerState.idle;
  GpsStatus _gps = GpsStatus.idle;
  StreamSubscription<GpsFix>? _sub;

  DateTime? _startedAt;
  DateTime? _segmentStart;
  int _activeMs = 0;
  int _pausedMs = 0;
  DateTime? _pausedAt;

  double _distanceM = 0;
  final List<RoutePoint> _route = [];
  RoutePoint? _anchor;
  DateTime? _anchorTime;
  GpsFix? _lastFix;
  DateTime? _lastGoodFixAt;
  CardioResult? _result;

  TrackerState get state => _state;
  GpsStatus get gps => _gps;
  bool get isRunning => _state == TrackerState.running;
  bool get isPaused => _state == TrackerState.paused;
  bool get hasStarted =>
      _state == TrackerState.running || _state == TrackerState.paused;
  DateTime? get startedAt => _startedAt;
  double get distanceM => _distanceM;
  double get distanceKm => _distanceM / 1000;
  List<RoutePoint> get route => List.unmodifiable(_route);

  /// The latest usable position, for the "you are here" marker.
  RoutePoint? get currentPosition => _lastFix == null
      ? null
      : RoutePoint(
          _lastFix!.lat,
          _lastFix!.lng,
          _lastFix!.time.millisecondsSinceEpoch,
        );

  RoutePoint? get startPoint => _route.isEmpty ? null : _route.first;

  /// Active time, with paused time taken out.
  Duration get elapsed {
    var ms = _activeMs;
    if (_state == TrackerState.running && _segmentStart != null) {
      ms += _now().difference(_segmentStart!).inMilliseconds;
    }
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  Duration get paused {
    var ms = _pausedMs;
    if (_state == TrackerState.paused && _pausedAt != null) {
      ms += _now().difference(_pausedAt!).inMilliseconds;
    }
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  /// Average speed over the active time. Null until there is both a little
  /// time and a little distance, so it never shows a made-up figure.
  double? get avgSpeedKmh {
    final s = elapsed.inMilliseconds / 1000;
    if (s < 5 || _distanceM < 10) return null;
    return (_distanceM / s) * 3.6;
  }

  double? get avgPaceSecPerKm {
    final v = avgSpeedKmh;
    if (v == null || v < 1) return null;
    return 3600 / v;
  }

  /// Speed over roughly the last [rateWindow], or null while standing still or
  /// before two usable positions exist.
  double? get currentSpeedKmh {
    if (_route.length < 2) return null;
    final nowMs = _now().millisecondsSinceEpoch;
    final cutoff = nowMs - rateWindow.inMilliseconds;
    if (_route.last.timeMs == 0 || _route.last.timeMs < cutoff) {
      // Nothing recorded lately: standing still, or no signal.
      return null;
    }
    // Start from the last position before the window so a slow stretch is
    // measured over the whole window, not just between its own fixes.
    var i = _route.length - 1;
    while (i > 0 && _route[i].timeMs >= cutoff) {
      i--;
    }
    final base = _route[i];
    final dtS = (nowMs - base.timeMs) / 1000;
    if (dtS < 3) return null;
    var d = 0.0;
    for (var k = i + 1; k < _route.length; k++) {
      d += Geo.distanceM(
        _route[k - 1].lat,
        _route[k - 1].lng,
        _route[k].lat,
        _route[k].lng,
      );
    }
    final v = (d / dtS) * 3.6;
    return v < 1 ? null : v;
  }

  double? get currentPaceSecPerKm {
    final v = currentSpeedKmh;
    return v == null ? null : 3600 / v;
  }

  /// Estimated energy from body weight and the measured average speed.
  double? get caloriesEstimate =>
      estimateCalories(kind, weightKg, avgSpeedKmh, elapsed);

  /// Starts a session. Returns false, with [gps] telling why, when the device
  /// will not give a location.
  Future<bool> start() async {
    if (_state != TrackerState.idle) return false;
    if (_active != null && _active != this && _active!.hasStarted) {
      _gps = GpsStatus.busy;
      notifyListeners();
      return false;
    }
    final access = await source.ensureAccess();
    switch (access) {
      case LocationAccess.denied:
        _gps = GpsStatus.permissionDenied;
        notifyListeners();
        return false;
      case LocationAccess.deniedForever:
        _gps = GpsStatus.permissionDeniedForever;
        notifyListeners();
        return false;
      case LocationAccess.serviceDisabled:
        _gps = GpsStatus.serviceDisabled;
        notifyListeners();
        return false;
      case LocationAccess.granted:
        break;
    }
    final now = _now();
    _startedAt = now;
    _segmentStart = now;
    _state = TrackerState.running;
    _gps = GpsStatus.searching;
    _active = this;
    _sub = source
        .positions(activityLabel: kind.label)
        .listen(onFix, onError: _onStreamError);
    _writeJournal(force: true);
    notifyListeners();
    return true;
  }

  CardioSnapshot _snapshot() => CardioSnapshot(
    kind: kind,
    startedAt: _startedAt!,
    activeMs: elapsed.inMilliseconds,
    pausedMs: paused.inMilliseconds,
    paused: _state == TrackerState.paused,
    distanceM: _distanceM,
    route: List.of(_route),
    savedAt: _now(),
  );

  /// Saves a recovery copy now and then: every 20 positions or 15 seconds,
  /// and always on start, pause and resume.
  void _writeJournal({bool force = false}) {
    final j = journal;
    if (j == null || _startedAt == null || !hasStarted) return;
    final last = _lastJournalAt;
    final due =
        force ||
        _journalPoints >= 20 ||
        last == null ||
        _now().difference(last) >= const Duration(seconds: 15);
    if (!due) return;
    _lastJournalAt = _now();
    _journalPoints = 0;
    j.save(_snapshot());
  }

  void _releaseActive() {
    if (identical(_active, this)) _active = null;
  }

  void _onStreamError(Object _) {
    _gps = GpsStatus.serviceDisabled;
    notifyListeners();
  }

  /// Handles one position. Public so tests can drive the tracker directly.
  void onFix(GpsFix fix) {
    if (_state != TrackerState.running && _state != TrackerState.paused) {
      return;
    }
    final acc = fix.accuracyM;
    if (acc != null && acc > maxAccuracyM) {
      // Too rough to use. Keep the marker where it was.
      _gps = GpsStatus.weak;
      notifyListeners();
      return;
    }
    _lastFix = fix;
    _lastGoodFixAt = _now();
    _gps = GpsStatus.good;

    if (_state == TrackerState.paused) {
      // Show where the athlete is, but record nothing.
      notifyListeners();
      return;
    }

    final point = RoutePoint(fix.lat, fix.lng, fix.time.millisecondsSinceEpoch);
    final anchor = _anchor;
    if (anchor == null || _anchorTime == null) {
      _anchor = point;
      _anchorTime = fix.time;
      _route.add(point);
      notifyListeners();
      return;
    }
    final d = Geo.distanceM(anchor.lat, anchor.lng, point.lat, point.lng);
    final dt = fix.time.difference(_anchorTime!).inMilliseconds / 1000;
    if (dt <= 0) return;
    if (d / dt > _maxPlausibleMps) {
      // A jump no runner or rider could make: a bad fix, not movement.
      return;
    }
    if (d < minStepM) {
      notifyListeners();
      return;
    }
    _distanceM += d;
    _anchor = point;
    _anchorTime = fix.time;
    _route.add(point);
    _journalPoints++;
    _writeJournal();
    notifyListeners();
  }

  /// Call about once a second: updates the signal status when positions stop
  /// arriving. Cheap, and safe to call in any state.
  void tick() {
    if (_state == TrackerState.running) {
      final last = _lastGoodFixAt;
      final since = _now().difference(last ?? _startedAt ?? _now());
      if (since > signalTimeout && _gps != GpsStatus.serviceDisabled) {
        _gps = GpsStatus.weak;
      }
    }
    notifyListeners();
  }

  void pause() {
    if (_state != TrackerState.running) return;
    final now = _now();
    _activeMs += now.difference(_segmentStart!).inMilliseconds;
    _segmentStart = null;
    _pausedAt = now;
    _state = TrackerState.paused;
    _writeJournal(force: true);
    notifyListeners();
  }

  void resume() {
    if (_state != TrackerState.paused) return;
    final now = _now();
    _pausedMs += now.difference(_pausedAt!).inMilliseconds;
    _pausedAt = null;
    _segmentStart = now;
    // Whatever was travelled while paused is not counted: the next position
    // starts a fresh anchor.
    _anchor = null;
    _anchorTime = null;
    _state = TrackerState.running;
    _writeJournal(force: true);
    notifyListeners();
  }

  /// Ends the session and returns the result. Calling it again returns the same
  /// result, so finishing twice can never produce two activities.
  CardioResult? finish() {
    if (_result != null) return _result;
    if (!hasStarted) return null;
    if (_state == TrackerState.running) {
      _activeMs += _now().difference(_segmentStart!).inMilliseconds;
    } else if (_pausedAt != null) {
      _pausedMs += _now().difference(_pausedAt!).inMilliseconds;
    }
    _segmentStart = null;
    _pausedAt = null;
    _state = TrackerState.finished;
    _sub?.cancel(); // ends the background location service
    _sub = null;
    _releaseActive();
    final secs = _activeMs / 1000;
    final avg = (secs >= 5 && _distanceM >= 10)
        ? (_distanceM / secs) * 3.6
        : null;
    _result = CardioResult(
      kind: kind,
      startedAt: _startedAt!,
      endedAt: _now(),
      activeSeconds: (_activeMs / 1000).round(),
      pausedSeconds: (_pausedMs / 1000).round(),
      distanceM: _distanceM,
      route: List.unmodifiable(_route),
      avgSpeedKmh: avg,
      avgPaceSecPerKm: (avg != null && avg >= 1) ? 3600 / avg : null,
      caloriesEstimate: estimateCalories(
        kind,
        weightKg,
        avg,
        Duration(milliseconds: _activeMs),
      ),
    );
    notifyListeners();
    return _result;
  }

  /// Throws the session away. Nothing is saved.
  void discard() {
    if (_state == TrackerState.finished) return;
    _sub?.cancel(); // ends the background location service
    _sub = null;
    _releaseActive();
    journal?.clear();
    _state = TrackerState.discarded;
    notifyListeners();
  }

  /// True while the location stream, and so the Android foreground service or
  /// iOS background updates, is running.
  bool get isLocationServiceRunning => _sub != null;

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    _releaseActive();
    super.dispose();
  }

  // ---- calories -----------------------------------------------------------

  /// MET values from the Compendium of Physical Activities, chosen by average
  /// speed. The result is an estimate (MET x body weight x hours), never a
  /// measurement, and is null without a body weight and a measured speed.
  static double? estimateCalories(
    CardioKind kind,
    double? weightKg,
    double? avgSpeedKmh,
    Duration active,
  ) {
    if (weightKg == null || weightKg < 30 || weightKg > 300) return null;
    if (avgSpeedKmh == null || active.inSeconds < 60) return null;
    final met = metFor(kind, avgSpeedKmh);
    return met * weightKg * (active.inMilliseconds / 3600000.0);
  }

  static double metFor(CardioKind kind, double kmh) {
    if (kind.isRunning) {
      const table = <(double, double)>[
        (6.4, 6.0),
        (8.0, 8.3),
        (9.7, 9.8),
        (11.3, 11.0),
        (12.9, 11.8),
        (14.5, 12.8),
        (16.1, 14.5),
      ];
      if (kmh < 6.4) return 4.5; // walking or a very slow jog
      var met = table.first.$2;
      for (final row in table) {
        if (kmh >= row.$1) met = row.$2;
      }
      return met;
    }
    if (kmh < 16) return 4.0;
    if (kmh < 19.2) return 6.8;
    if (kmh < 22.4) return 8.0;
    if (kmh < 25.6) return 10.0;
    if (kmh < 30.6) return 12.0;
    return 15.8;
  }
}

/// Display helpers shared by the live screen, the cards and the detail view.
class CardioFormat {
  const CardioFormat._();

  static String distanceKm(double km) => km.toStringAsFixed(2);

  static String duration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// `m:ss` per km, or an en dash when there is no pace.
  static String pace(double? secPerKm) {
    if (secPerKm == null || secPerKm.isNaN || secPerKm.isInfinite) return '–';
    final total = secPerKm.round();
    if (total <= 0 || total > 99 * 60) return '–';
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  static String speed(double? kmh) =>
      kmh == null || kmh.isNaN ? '–' : kmh.toStringAsFixed(1);

  static String calories(double? kcal) =>
      kcal == null ? '–' : kcal.round().toString();
}

/// Reads a body weight typed in the profile ("72", "72.5 kg", "160 lb").
/// Returns null when it is empty or not a plausible weight.
double? parseProfileWeightKg(String raw) {
  final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(raw);
  if (m == null) return null;
  var v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
  if (v == null) return null;
  if (RegExp(r'lb|pound', caseSensitive: false).hasMatch(raw)) v *= 0.45359237;
  return (v >= 30 && v <= 300) ? v : null;
}
