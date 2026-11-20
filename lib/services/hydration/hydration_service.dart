import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local_storage.dart';
import '../../data/profile_provider.dart';
import '../../models/activity_record.dart';
import '../../models/hydration.dart';
import '../../models/workout_history.dart';
import '../../providers/fitness_provider.dart';
import '../../providers/showcase_data_provider.dart';
import '../cardio/cardio_tracker.dart' show parseProfileWeightKg;
import '../cloud/cloud_session.dart';
import 'hydration_goal_calculator.dart';
import 'sample_hydration.dart';

/// Every hydration record Atlas keeps for the device.
class HydrationStore {
  final List<HydrationEntry> entries;

  /// The target that applied on each day, keyed `userId|yyyy-MM-dd`.
  final Map<String, HydrationGoal> goals;

  /// Days the athlete confirmed they drank nothing, keyed the same way.
  final Set<String> confirmedZero;

  /// A target the athlete set, per user.
  final Map<String, int> manualGoal;

  HydrationStore({
    List<HydrationEntry>? entries,
    Map<String, HydrationGoal>? goals,
    Set<String>? confirmedZero,
    Map<String, int>? manualGoal,
  }) : entries = entries ?? [],
       goals = goals ?? {},
       confirmedZero = confirmedZero ?? {},
       manualGoal = manualGoal ?? {};

  Map<String, dynamic> toJson() => {
    'v': 1,
    'entries': [for (final e in entries) e.toJson()],
    'goals': {for (final e in goals.entries) e.key: e.value.toJson()},
    'zeros': confirmedZero.toList(),
    'manual': manualGoal,
  };

  static HydrationStore fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return HydrationStore();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return HydrationStore();
      final goals = <String, HydrationGoal>{};
      final g = m['goals'];
      if (g is Map) {
        g.forEach((k, v) {
          final parsed = HydrationGoal.tryParse(v);
          if (parsed != null) goals['$k'] = parsed;
        });
      }
      final manual = <String, int>{};
      final mm = m['manual'];
      if (mm is Map) {
        mm.forEach((k, v) {
          if (v is num) manual['$k'] = v.toInt();
        });
      }
      return HydrationStore(
        entries: [
          if (m['entries'] is List)
            for (final e in m['entries'] as List) ?HydrationEntry.tryParse(e),
        ],
        goals: goals,
        confirmedZero: {
          if (m['zeros'] is List)
            for (final z in m['zeros'] as List) '$z',
        },
        manualGoal: manual,
      );
    } catch (_) {
      return HydrationStore();
    }
  }
}

/// Water intake: records, daily totals, the personalised target, weekly and
/// historical views.
///
/// Real records are saved on the device and tied to the signed-in account
/// (or `local` when signed out). In Showcase Mode a separate in-memory sample
/// store is used and nothing is written to the real one.
class HydrationService extends ChangeNotifier {
  HydrationService({
    DateTime Function()? clock,
    String Function()? userId,
    bool Function()? isShowcase,
    double? Function()? weightKg,
    List<HydrationActivity> Function(String dayKey)? activities,
    String? Function()? read,
    Future<void> Function(String json)? write,
  }) : _now = clock ?? DateTime.now,
       _userId = userId ?? _defaultUserId,
       _isShowcase = isShowcase ?? LocalStorage.isShowcaseModeEnabled,
       _weightKg = weightKg ?? _defaultWeight,
       _activities = activities ?? _defaultActivities,
       _read = read ?? LocalStorage.getHydrationJson,
       _write = write ?? LocalStorage.saveHydrationJson;

  static HydrationService? _instance;
  static HydrationService get instance => _instance ??= HydrationService();

  @visibleForTesting
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  final DateTime Function() _now;
  final String Function() _userId;
  final bool Function() _isShowcase;
  final double? Function() _weightKg;
  final List<HydrationActivity> Function(String dayKey) _activities;
  final String? Function() _read;
  final Future<void> Function(String json) _write;

  HydrationStore? _real;
  HydrationStore? _sample;
  bool _wasShowcase = false;
  int _seq = 0;

  static String _defaultUserId() => CloudSession.userId ?? 'local';

  static double? _defaultWeight() {
    if (LocalStorage.isShowcaseModeEnabled()) {
      return parseProfileWeightKg(
        ShowcaseDataProvider.instance.getShowcaseUserProfile().weight,
      );
    }
    return parseProfileWeightKg(ProfileProvider().weight);
  }

  /// Today's recorded strength workouts and GPS runs and rides, each once.
  static List<HydrationActivity> _defaultActivities(String dayKey) {
    final showcase = LocalStorage.isShowcaseModeEnabled();
    final list = <HydrationActivity>[];
    final List<WorkoutHistory> workouts =
        FitnessProvider.instance.workoutHistory;
    for (final w in workouts) {
      if (hydrationDayKey(w.dateCompleted) != dayKey) continue;
      list.add(
        HydrationActivity(
          id: 'w|${w.workoutName}|${w.dateCompleted.millisecondsSinceEpoch}',
          minutes: (w.durationSeconds / 60).round(),
          cardio: false,
        ),
      );
    }
    if (!showcase) {
      for (final CardioSession c in LocalStorage.getCardioSessions()) {
        if (!c.isCompleted || hydrationDayKey(c.startTime) != dayKey) continue;
        list.add(
          HydrationActivity(
            id: 'c|${c.id}',
            minutes: (c.durationSeconds / 60).round(),
            cardio: true,
            met: c.metValue > 0 ? c.metValue : null,
          ),
        );
      }
    }
    return list;
  }

  bool get isSample => _isShowcase();

  HydrationStore get _store {
    final showcase = _isShowcase();
    if (showcase != _wasShowcase) {
      _wasShowcase = showcase;
      if (!showcase) _sample = null; // sample data never outlives Showcase
    }
    if (showcase) {
      return _sample ??= SampleHydration.build(
        now: _now(),
        weightKg: _weightKg(),
      );
    }
    return _real ??= HydrationStore.fromJsonString(_read());
  }

  String get _uid => _isShowcase() ? SampleHydration.userId : _userId();

  String get todayKey => hydrationDayKey(_now());

  Future<void> _save() async {
    if (_isShowcase()) return; // Showcase never writes to real storage.
    await _write(jsonEncode(_real!.toJson()));
  }

  /// Reloads from storage, for example after sign-in changes.
  void reload() {
    _real = null;
    notifyListeners();
  }

  // --------------------------------------------------------------- goals

  int? get manualGoalMl => _store.manualGoal[_uid];

  /// The target for today, worked out from what is known right now.
  HydrationGoal currentGoal() => HydrationGoalCalculator.calculate(
    weightKg: _weightKg(),
    activities: _activities(todayKey),
    manualMl: manualGoalMl,
  );

  /// The target that applied on [dayKey], or null when none was recorded.
  /// Past days keep the target they had; they are never re-scored.
  HydrationGoal? goalFor(String dayKey) {
    if (dayKey == todayKey) return currentGoal();
    return _store.goals['$_uid|$dayKey'];
  }

  /// Saves today's target so it stays with today once the day is over.
  /// Returns true when it changed. Safe to call as often as needed.
  Future<bool> refreshTodayGoal() async {
    final g = currentGoal();
    final key = '$_uid|$todayKey';
    if (_store.goals[key] == g) return false;
    _store.goals[key] = g;
    await _save();
    notifyListeners();
    return true;
  }

  /// Sets (or with null clears) the athlete's own daily target.
  Future<void> setManualGoal(int? ml) async {
    if (ml == null) {
      _store.manualGoal.remove(_uid);
    } else {
      _store.manualGoal[_uid] = ml.clamp(
        HydrationGoalCalculator.minManualMl,
        HydrationGoalCalculator.maxManualMl,
      );
    }
    _store.goals['$_uid|$todayKey'] = currentGoal();
    await _save();
    notifyListeners();
  }

  // -------------------------------------------------------------- reading

  List<HydrationEntry> entriesFor(String dayKey) {
    final uid = _uid;
    final list = [
      for (final e in _store.entries)
        if (e.userId == uid && e.dayKey == dayKey) e,
    ]..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    return list;
  }

  DayHydration day(String dayKey) {
    final entries = entriesFor(dayKey);
    final status = entries.isNotEmpty
        ? HydrationDayStatus.recorded
        : (_store.confirmedZero.contains('$_uid|$dayKey')
              ? HydrationDayStatus.confirmedZero
              : HydrationDayStatus.noData);
    return DayHydration(
      dayKey: dayKey,
      date: hydrationDayFromKey(dayKey),
      entries: entries,
      status: status,
      goal: goalFor(dayKey),
      isToday: dayKey == todayKey,
      isSample: _isShowcase(),
    );
  }

  DayHydration get today => day(todayKey);

  /// Monday to Sunday of the week containing [anchor] (default: today).
  WeekHydration week([DateTime? anchor]) {
    final a = anchor ?? _now();
    final d = DateTime(a.year, a.month, a.day);
    final start = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    return WeekHydration(
      start: start,
      days: [
        for (var i = 0; i < 7; i++)
          day(
            hydrationDayKey(DateTime(start.year, start.month, start.day + i)),
          ),
      ],
    );
  }

  /// Days that have a record, newest first, always including today.
  List<DayHydration> history({int limit = 60}) {
    final uid = _uid;
    final keys = <String>{todayKey};
    for (final e in _store.entries) {
      if (e.userId == uid) keys.add(e.dayKey);
    }
    for (final z in _store.confirmedZero) {
      if (z.startsWith('$uid|')) keys.add(z.substring(uid.length + 1));
    }
    final sorted = keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in sorted.take(limit)) day(k)];
  }

  // -------------------------------------------------------------- writing

  static const int maxEntryMl = 5000;

  /// Records a drink. [requestId] makes the call idempotent: a retry or a
  /// repeated tap with the same id changes nothing. Returns the entry, or
  /// null when [ml] is not between 1 and 5,000.
  Future<HydrationEntry?> log(int ml, {String? requestId, DateTime? at}) async {
    if (ml < 1 || ml > maxEntryMl) return null;
    final id = requestId ?? 'hy_${_now().microsecondsSinceEpoch}_${_seq++}';
    final existing = _store.entries.where((e) => e.id == id).toList();
    if (existing.isNotEmpty) return existing.first;
    final when = at ?? _now();
    final entry = HydrationEntry(
      id: id,
      userId: _uid,
      amountMl: ml,
      loggedAt: when,
      dayKey: hydrationDayKey(when),
    );
    _store.entries.add(entry);
    _store.confirmedZero.remove('$_uid|${entry.dayKey}');
    if (entry.dayKey == todayKey) {
      _store.goals['$_uid|$todayKey'] = currentGoal();
    }
    await _save();
    notifyListeners();
    return entry;
  }

  /// Corrects the amount of an entry. Returns false if it does not exist or
  /// the amount is not between 1 and 5,000.
  Future<bool> edit(String id, int ml) async {
    if (ml < 1 || ml > maxEntryMl) return false;
    final i = _store.entries.indexWhere((e) => e.id == id && e.userId == _uid);
    if (i < 0) return false;
    _store.entries[i] = _store.entries[i].copyWith(amountMl: ml);
    await _save();
    notifyListeners();
    return true;
  }

  Future<bool> remove(String id) async {
    final before = _store.entries.length;
    _store.entries.removeWhere((e) => e.id == id && e.userId == _uid);
    if (_store.entries.length == before) return false;
    await _save();
    notifyListeners();
    return true;
  }

  /// Confirms a day with no entries as a genuine zero, so it is not left as
  /// "no data". Ignored for future days and days that have entries.
  Future<bool> confirmNoWater(String dayKey) async {
    if (dayKey.compareTo(todayKey) > 0) return false;
    if (entriesFor(dayKey).isNotEmpty) return false;
    _store.confirmedZero.add('$_uid|$dayKey');
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> clearConfirmedZero(String dayKey) async {
    if (_store.confirmedZero.remove('$_uid|$dayKey')) {
      await _save();
      notifyListeners();
    }
  }
}
