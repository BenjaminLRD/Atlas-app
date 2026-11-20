import 'dart:convert';

import '../../data/local_storage.dart';
import '../../models/activity_record.dart';
import '../../models/cardio_route.dart';
import 'cardio_tracker.dart' show CardioTracker;

/// A copy of a run or ride that is still being recorded, kept on the device.
///
/// If the operating system ends the app while it is recording (low memory, a
/// crash, a battery saver), the next launch can offer to save what was
/// recorded up to the last copy. Time and distance after the last copy are
/// lost, and that is said plainly to the athlete.
class CardioSnapshot {
  final CardioKind kind;
  final DateTime startedAt;
  final int activeMs;
  final int pausedMs;
  final bool paused;
  final double distanceM;
  final List<RoutePoint> route;
  final DateTime savedAt;

  const CardioSnapshot({
    required this.kind,
    required this.startedAt,
    required this.activeMs,
    required this.pausedMs,
    required this.paused,
    required this.distanceM,
    required this.route,
    required this.savedAt,
  });

  /// Most points kept in the copy, so it stays small.
  static const int maxPoints = 1500;

  Map<String, dynamic> toJson() => {
    'kind': kind.key,
    'start': startedAt.toIso8601String(),
    'active': activeMs,
    'paused': pausedMs,
    'isPaused': paused,
    'dist': distanceM,
    'route': RoutePoint.listToJson(Geo.downsample(route, maxPoints)),
    'saved': savedAt.toIso8601String(),
  };

  static CardioSnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final kind = CardioKind.fromKey(raw['kind'] as String?);
    final start = DateTime.tryParse('${raw['start']}');
    final saved = DateTime.tryParse('${raw['saved']}');
    if (kind == null || start == null || saved == null) return null;
    return CardioSnapshot(
      kind: kind,
      startedAt: start,
      activeMs: (raw['active'] as num?)?.toInt() ?? 0,
      pausedMs: (raw['paused'] as num?)?.toInt() ?? 0,
      paused: raw['isPaused'] as bool? ?? false,
      distanceM: (raw['dist'] as num?)?.toDouble() ?? 0,
      route: RoutePoint.listFromJson(raw['route']),
      savedAt: saved,
    );
  }

  /// A finished-activity result from the last copy.
  CardioSessionDraft toDraft({double? weightKg}) {
    final secs = activeMs / 1000;
    final avg = (secs >= 5 && distanceM >= 10)
        ? (distanceM / secs) * 3.6
        : null;
    return CardioSessionDraft(
      kind: kind,
      startedAt: startedAt,
      endedAt: savedAt,
      activeSeconds: (activeMs / 1000).round(),
      pausedSeconds: (pausedMs / 1000).round(),
      distanceM: distanceM,
      route: route,
      avgSpeedKmh: avg,
      avgPaceSecPerKm: (avg != null && avg >= 1) ? 3600 / avg : null,
      caloriesEstimate: CardioTracker.estimateCalories(
        kind,
        weightKg,
        avg,
        Duration(milliseconds: activeMs),
      ),
    );
  }
}

/// The figures of an activity about to be saved. Same shape as a tracker's
/// result, so a recovered session and a normal one are saved the same way.
class CardioSessionDraft {
  final CardioKind kind;
  final DateTime startedAt;
  final DateTime endedAt;
  final int activeSeconds;
  final int pausedSeconds;
  final double distanceM;
  final List<RoutePoint> route;
  final double? avgSpeedKmh;
  final double? avgPaceSecPerKm;
  final double? caloriesEstimate;

  const CardioSessionDraft({
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

  /// The id a session made from this draft gets: the same draft always gives
  /// the same id, so saving it twice replaces rather than duplicates.
  String get sessionId => 'cardio_${startedAt.millisecondsSinceEpoch}';
}

/// Reads and writes the in-progress copy.
class CardioJournal {
  CardioJournal({
    String? Function()? read,
    Future<void> Function(String json)? write,
    Future<void> Function()? erase,
  }) : _read = read ?? LocalStorage.getCardioJournalJson,
       _write = write ?? LocalStorage.saveCardioJournalJson,
       _erase = erase ?? LocalStorage.clearCardioJournal;

  final String? Function() _read;
  final Future<void> Function(String json) _write;
  final Future<void> Function() _erase;

  Future<void> save(CardioSnapshot s) async {
    try {
      await _write(jsonEncode(s.toJson()));
    } catch (_) {
      // A failed recovery copy must never stop the recording.
    }
  }

  CardioSnapshot? load() {
    final raw = _read();
    if (raw == null || raw.isEmpty) return null;
    try {
      return CardioSnapshot.tryParse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _erase();
    } catch (_) {}
  }
}

/// Turns a finished result or a recovered copy into the records Atlas stores.
class CardioSessionBuilder {
  const CardioSessionBuilder._();

  static (CardioSession, ActivityRecord) build(CardioSessionDraft r) {
    final kcal = r.caloriesEstimate;
    final id = r.sessionId;
    final distanceKm = double.parse(r.distanceKm.toStringAsFixed(3));
    final session = CardioSession(
      id: id,
      exerciseId: r.kind.isRunning ? 'outdoor_run' : 'outdoor_cycling',
      exerciseName: r.kind.isRunning ? 'Outdoor Run' : 'Outdoor Ride',
      category: r.kind.label,
      durationSeconds: r.activeSeconds,
      distanceKm: distanceKm,
      caloriesBurned: kcal == null ? 0 : double.parse(kcal.toStringAsFixed(1)),
      caloriesKnown: kcal != null,
      caloriesEstimated: true,
      startTime: r.startedAt,
      endTime: r.endedAt,
      metValue: r.avgSpeedKmh == null
          ? 0
          : CardioTracker.metFor(r.kind, r.avgSpeedKmh!),
      isCompleted: true,
      route: Geo.downsample(r.route, 600),
      pausedSeconds: r.pausedSeconds,
    );
    final activity = ActivityRecord(
      id: 'act_$id',
      date: r.endedAt,
      activeMinutes: (r.activeSeconds / 60).round(),
      caloriesBurned: session.caloriesBurned,
      distanceKm: distanceKm,
      type: ActivityType.cardio,
      title: session.exerciseName,
    );
    return (session, activity);
  }
}
