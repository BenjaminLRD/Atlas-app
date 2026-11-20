import 'dart:convert';
import 'step_models.dart';

/// Turns raw readings of the phone's step counter into per-day step counts.
///
/// The Android counter is cumulative since the phone last booted and keeps
/// counting while the app is closed. A reading therefore says nothing about
/// which day its steps belong to; the ledger works that out from the previous
/// reading and refuses to guess when it cannot:
///
/// * First ever reading: counting starts now, nothing earlier is credited.
/// * Both readings on the same day: the difference belongs to that day, even if
///   the app was closed in between.
/// * The readings are on different days: if the app listened without a break
///   (`continuousSince`) the new steps happened after the last reading, so
///   they belong to the new day. Otherwise they cannot be placed and are kept
///   as `unattributedSteps`, never added to a day.
/// * Counter lower than before: either the phone restarted (the counter starts
///   again from zero) or the sensor delivered a stale or out-of-order value.
///   The two cannot be told apart from one reading, so the ledger waits
///   ([resetConfirmAfter]): if the counter climbs back to where it was, the dip
///   was a glitch and nothing is credited twice; if it stays lower, the phone
///   restarted, the steps counted since boot before the dip are kept as
///   unattributed, and counting continues from the new, lower counter.
class StepLedger {
  /// How long a lower counter must persist before it is accepted as a phone
  /// restart rather than a stale reading.
  static const Duration resetConfirmAfter = Duration(seconds: 30);

  static const int keepDays = 60;

  int? lastCounter;
  DateTime? lastObservedAt;

  /// The lowest counter seen since it first fell below [lastCounter], and when.
  /// Null when the counter is behaving normally.
  int? resetCandidate;
  DateTime? resetCandidateAt;
  final Map<String, DayStepRecord> days;

  StepLedger({
    this.lastCounter,
    this.lastObservedAt,
    this.resetCandidate,
    this.resetCandidateAt,
    Map<String, DayStepRecord>? days,
  }) : days = days ?? {};

  /// Records one counter reading. [continuousSince] is when the app started
  /// listening without a gap (null when unknown).
  void observe(int counter, DateTime now, {DateTime? continuousSince}) {
    final key = stepDayKey(now);
    var rec = days[key] ?? DayStepRecord(dayKey: key);
    var prevCounter = lastCounter;
    var prevAt = lastObservedAt;

    if (prevCounter == null || prevAt == null) {
      rec = rec.copyWith(
        phoneSteps: rec.phoneSteps ?? 0,
        phoneSince: rec.phoneSince ?? now,
      );
      days[key] = rec;
      lastCounter = counter;
      lastObservedAt = now;
      _prune(now);
      return;
    }

    var unattributed = 0;
    if (counter < prevCounter) {
      // Lower than the highest value seen: a glitch or a restart. Hold off.
      final cand = resetCandidate;
      if (cand == null) {
        resetCandidate = counter;
        resetCandidateAt = now;
        days[key] = rec.copyWith(
          phoneSteps: rec.phoneSteps ?? 0,
          phoneSince: rec.phoneSince ?? now,
        );
        return;
      }
      if (counter < cand) {
        resetCandidate = counter;
        resetCandidateAt = resetCandidateAt ?? now;
        return;
      }
      final since = resetCandidateAt ?? now;
      if (now.difference(since) < resetConfirmAfter) return;
      // Still lower after the wait: the phone restarted. Count from the
      // candidate onwards; what the counter held before it is unplaceable.
      unattributed = cand;
      prevCounter = cand;
      prevAt = since;
      resetCandidate = null;
      resetCandidateAt = null;
    } else {
      // Back at or above the highest value: any dip was a stale reading.
      resetCandidate = null;
      resetCandidateAt = null;
    }

    final delta = counter - prevCounter;
    final sameDay = stepDayKey(prevAt) == key;
    final listenedThroughout =
        continuousSince != null && !continuousSince.isAfter(prevAt);
    if (sameDay || listenedThroughout) {
      rec = rec.copyWith(
        phoneSteps: (rec.phoneSteps ?? 0) + delta,
        phoneSince: rec.phoneSince ?? (sameDay ? prevAt : stepDayStart(now)),
        unattributedSteps: rec.unattributedSteps + unattributed,
      );
    } else {
      rec = rec.copyWith(
        phoneSteps: rec.phoneSteps ?? 0,
        phoneSince: rec.phoneSince ?? now,
        unattributedSteps: rec.unattributedSteps + unattributed + delta,
      );
    }

    days[key] = rec;
    lastCounter = counter;
    lastObservedAt = now;
    _prune(now);
  }

  /// The day changed while the sensor kept listening but did not report (the
  /// counter only reports when it changes). No steps happened since the last
  /// reading, so today starts at 0 counted from midnight.
  void startDayIfListening(DateTime now, {required DateTime? continuousSince}) {
    final key = stepDayKey(now);
    if (days[key]?.phoneSteps != null) return;
    final midnight = stepDayStart(now);
    if (continuousSince == null || continuousSince.isAfter(midnight)) return;
    days[key] = (days[key] ?? DayStepRecord(dayKey: key)).copyWith(
      phoneSteps: 0,
      phoneSince: midnight,
    );
  }

  /// Stores a Health Connect (or Apple Health) total for one day. A null
  /// [steps] (no data) leaves the day untouched.
  void setHealthConnect(String dayKey, int? steps, DateTime at) {
    if (steps == null) return;
    final rec = days[dayKey] ?? DayStepRecord(dayKey: dayKey);
    days[dayKey] = rec.copyWith(healthConnectSteps: steps, healthConnectAt: at);
  }

  DayStepTotal totalFor(DateTime day) {
    final key = stepDayKey(day);
    return DayStepTotal.fromRecord(key, days[key]);
  }

  /// The last [count] days ending at [today], oldest first. Days without any
  /// reading have a null total.
  List<DayStepTotal> lastDays(DateTime today, {int count = 7}) {
    final start = stepDayStart(today);
    return [
      for (var i = count - 1; i >= 0; i--)
        totalFor(DateTime(start.year, start.month, start.day - i)),
    ];
  }

  void _prune(DateTime now) {
    if (days.length <= keepDays) return;
    final keys = days.keys.toList()..sort();
    for (final k in keys.take(days.length - keepDays)) {
      days.remove(k);
    }
  }

  String encode() => jsonEncode({
    'v': 1,
    if (lastCounter != null) 'lastCounter': lastCounter,
    if (lastObservedAt != null)
      'lastObservedAt': lastObservedAt!.toIso8601String(),
    if (resetCandidate != null) 'cand': resetCandidate,
    if (resetCandidateAt != null) 'candAt': resetCandidateAt!.toIso8601String(),
    'days': days.values.map((d) => d.toJson()).toList(),
  });

  factory StepLedger.decode(String? raw) {
    if (raw == null || raw.isEmpty) return StepLedger();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final recs = <String, DayStepRecord>{};
      for (final d in (j['days'] as List? ?? const [])) {
        final r = DayStepRecord.fromJson(d as Map<String, dynamic>);
        recs[r.dayKey] = r;
      }
      return StepLedger(
        resetCandidate: (j['cand'] as num?)?.toInt(),
        resetCandidateAt: j['candAt'] == null
            ? null
            : DateTime.tryParse(j['candAt'] as String),
        lastCounter: (j['lastCounter'] as num?)?.toInt(),
        lastObservedAt: j['lastObservedAt'] == null
            ? null
            : DateTime.tryParse(j['lastObservedAt'] as String),
        days: recs,
      );
    } catch (_) {
      // An unreadable file is dropped rather than guessed at.
      return StepLedger();
    }
  }
}
