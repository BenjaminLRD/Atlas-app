/// One standard glass of water, in millilitres.
const int hydrationGlassMl = 250;

/// `yyyy-MM-dd` of the athlete's local calendar day.
String hydrationDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime hydrationDayFromKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// One recorded drink. The amount is stored exactly as entered.
class HydrationEntry {
  final String id;

  /// The account the entry belongs to, or `local` when signed out.
  final String userId;
  final int amountMl;
  final DateTime loggedAt;

  /// The local calendar day when it was logged. Fixed at that moment, so a
  /// change of time zone never moves an old record to another day.
  final String dayKey;

  const HydrationEntry({
    required this.id,
    required this.userId,
    required this.amountMl,
    required this.loggedAt,
    required this.dayKey,
  });

  HydrationEntry copyWith({int? amountMl}) => HydrationEntry(
    id: id,
    userId: userId,
    amountMl: amountMl ?? this.amountMl,
    loggedAt: loggedAt,
    dayKey: dayKey,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'ml': amountMl,
    'at': loggedAt.toIso8601String(),
    'day': dayKey,
  };

  static HydrationEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final ml = raw['ml'];
    final at = DateTime.tryParse('${raw['at']}');
    if (id is! String || ml is! num || at == null || ml <= 0) return null;
    final day = raw['day'] is String
        ? raw['day'] as String
        : hydrationDayKey(at);
    return HydrationEntry(
      id: id,
      userId: raw['userId'] is String ? raw['userId'] as String : 'local',
      amountMl: ml.toInt(),
      loggedAt: at,
      dayKey: day,
    );
  }
}

/// How a daily target was reached.
enum HydrationGoalBasis {
  /// No body weight is known, so a general starting value is used.
  provisional('Provisional'),

  /// From body weight alone.
  baseline('Baseline'),

  /// Body weight plus the day's recorded activity.
  activityAdjusted('Activity-adjusted'),

  /// Set by the athlete.
  manual('Set by you');

  final String label;
  const HydrationGoalBasis(this.label);
}

/// The target that applied on one day, kept so old days are never re-scored
/// with a newer target.
class HydrationGoal {
  final int goalMl;
  final int baselineMl;
  final int activityMl;
  final HydrationGoalBasis basis;
  final String explanation;

  const HydrationGoal({
    required this.goalMl,
    required this.baselineMl,
    required this.activityMl,
    required this.basis,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
    'goal': goalMl,
    'base': baselineMl,
    'act': activityMl,
    'basis': basis.name,
    'why': explanation,
  };

  static HydrationGoal? tryParse(Object? raw) {
    if (raw is! Map || raw['goal'] is! num) return null;
    return HydrationGoal(
      goalMl: (raw['goal'] as num).toInt(),
      baselineMl: (raw['base'] as num?)?.toInt() ?? 0,
      activityMl: (raw['act'] as num?)?.toInt() ?? 0,
      basis: HydrationGoalBasis.values.firstWhere(
        (b) => b.name == raw['basis'],
        orElse: () => HydrationGoalBasis.baseline,
      ),
      explanation: raw['why'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HydrationGoal &&
      other.goalMl == goalMl &&
      other.baselineMl == baselineMl &&
      other.activityMl == activityMl &&
      other.basis == basis;

  @override
  int get hashCode => Object.hash(goalMl, baselineMl, activityMl, basis);
}

/// Whether anything is known about a day.
enum HydrationDayStatus {
  /// At least one drink was recorded.
  recorded,

  /// The athlete confirmed they drank nothing.
  confirmedZero,

  /// Nothing recorded: not the same as zero.
  noData,
}

/// Everything shown about one day.
class DayHydration {
  final String dayKey;
  final DateTime date;
  final List<HydrationEntry> entries;
  final HydrationDayStatus status;

  /// The target that applied that day, or null when none was recorded.
  final HydrationGoal? goal;
  final bool isToday;
  final bool isSample;

  const DayHydration({
    required this.dayKey,
    required this.date,
    required this.entries,
    required this.status,
    required this.goal,
    required this.isToday,
    this.isSample = false,
  });

  /// Total recorded, or null when the day has no record at all.
  int? get totalMl => status == HydrationDayStatus.noData
      ? null
      : entries.fold<int>(0, (a, e) => a + e.amountMl);

  int get consumedMl => totalMl ?? 0;
  int? get goalMl => goal?.goalMl;

  /// Actual progress, which can pass 1.0. Null without a total or a goal.
  double? get progress {
    final t = totalMl;
    final g = goalMl;
    if (t == null || g == null || g <= 0) return null;
    return t / g;
  }

  int? get remainingMl {
    final t = totalMl;
    final g = goalMl;
    if (t == null || g == null) return null;
    return (g - t) < 0 ? 0 : g - t;
  }

  int? get overMl {
    final t = totalMl;
    final g = goalMl;
    if (t == null || g == null) return null;
    return t > g ? t - g : 0;
  }
}

/// Seven days, Monday to Sunday.
class WeekHydration {
  final DateTime start;
  final List<DayHydration> days;
  const WeekHydration({required this.start, required this.days});

  /// Total of the days that have a record. Days with no data add nothing and
  /// are not assumed to be zero.
  int get totalKnownMl => days.fold<int>(0, (a, d) => a + (d.totalMl ?? 0));
  int get knownDays =>
      days.where((d) => d.status != HydrationDayStatus.noData).length;
  double get totalLitres => totalKnownMl / 1000;
}

/// How the glasses are filled. Pure arithmetic, so it can be tested alone.
class GlassMath {
  const GlassMath._();

  /// How many glasses the target needs, rounded up: 2,500 ml is 10, 2,300 ml
  /// is 10 (the last one partly).
  static int totalGlasses(int goalMl) =>
      goalMl <= 0 ? 0 : (goalMl / hydrationGlassMl).ceil();

  /// Fill of each glass from 0.0 to 1.0. The recorded amount is never
  /// rounded: 375 ml fills one glass and half of the next.
  static List<double> fills(int consumedMl, int goalMl) {
    final n = totalGlasses(goalMl);
    return [
      for (var i = 0; i < n; i++)
        ((consumedMl - i * hydrationGlassMl) / hydrationGlassMl).clamp(
          0.0,
          1.0,
        ),
    ];
  }

  /// Glass equivalents consumed, exact (375 ml is 1.5).
  static double glassesConsumed(int ml) => ml / hydrationGlassMl;

  /// Glass equivalents still to drink, never below 0.
  static double glassesRemaining(int consumedMl, int goalMl) =>
      (goalMl - consumedMl) <= 0 ? 0 : (goalMl - consumedMl) / hydrationGlassMl;

  /// `1.5` or `2`: no trailing zero.
  static String glassLabel(double g) {
    final r = (g * 10).round() / 10;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  }

  /// `750 ml` below 1 L, otherwise `1.25 L`.
  static String volumeLabel(int ml) {
    if (ml < 1000) return '$ml ml';
    final s = (ml / 1000).toStringAsFixed(2);
    final t = s
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$t L';
  }
}
