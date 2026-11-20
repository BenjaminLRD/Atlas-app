/// Where a daily step total comes from. Both are real measurements and are
/// never added together: a day's total is the larger of the two (the other
/// source simply missed part of the day), shown with its source.
enum StepSource { phoneSensor, healthConnect }

/// State of the phone's step counter as the app sees it.
enum StepSensorStatus {
  /// Not started yet, or no reading has been asked for.
  idle,

  /// Permission is needed and has not been granted. Can be asked again.
  needsPermission,

  /// Permission was refused and Android will not ask again. Only the system
  /// settings can change it.
  permissionPermanentlyDenied,

  /// This phone has no step-counter sensor (or it reported an error).
  unavailable,

  /// Listening, but the sensor has not delivered a reading yet.
  waitingForFirstReading,

  /// Listening and receiving readings.
  active,
}

/// Result of an Activity Recognition permission check or request.
enum StepPermission {
  granted,
  denied,
  permanentlyDenied,

  /// This platform has no separate permission to ask for (the system asks
  /// the first time the sensor is used).
  notRequired,
}

/// Local calendar day as `yyyy-MM-dd`. Steps always belong to the phone's
/// local day.
String stepDayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

DateTime stepDayStart(DateTime t) => DateTime(t.year, t.month, t.day);

/// What was recorded for one local day, per source. A null count means that
/// source recorded nothing for the day (not "zero steps").
class DayStepRecord {
  final String dayKey;

  /// Steps counted by the phone's sensor on this day, from [phoneSince].
  final int? phoneSteps;

  /// When the phone count for this day began. Steps before this moment were
  /// not observed by the phone sensor.
  final DateTime? phoneSince;

  /// Steps for this day reported by Health Connect (or Apple Health).
  final int? healthConnectSteps;
  final DateTime? healthConnectAt;

  /// Steps the sensor counted across a restart or a midnight that could not be
  /// placed on a day. They are kept for the record and never added to a total.
  final int unattributedSteps;

  const DayStepRecord({
    required this.dayKey,
    this.phoneSteps,
    this.phoneSince,
    this.healthConnectSteps,
    this.healthConnectAt,
    this.unattributedSteps = 0,
  });

  DayStepRecord copyWith({
    int? phoneSteps,
    DateTime? phoneSince,
    int? healthConnectSteps,
    DateTime? healthConnectAt,
    int? unattributedSteps,
  }) => DayStepRecord(
    dayKey: dayKey,
    phoneSteps: phoneSteps ?? this.phoneSteps,
    phoneSince: phoneSince ?? this.phoneSince,
    healthConnectSteps: healthConnectSteps ?? this.healthConnectSteps,
    healthConnectAt: healthConnectAt ?? this.healthConnectAt,
    unattributedSteps: unattributedSteps ?? this.unattributedSteps,
  );

  Map<String, dynamic> toJson() => {
    'day': dayKey,
    if (phoneSteps != null) 'phone': phoneSteps,
    if (phoneSince != null) 'phoneSince': phoneSince!.toIso8601String(),
    if (healthConnectSteps != null) 'hc': healthConnectSteps,
    if (healthConnectAt != null) 'hcAt': healthConnectAt!.toIso8601String(),
    if (unattributedSteps != 0) 'unattributed': unattributedSteps,
  };

  factory DayStepRecord.fromJson(Map<String, dynamic> j) => DayStepRecord(
    dayKey: j['day'] as String,
    phoneSteps: (j['phone'] as num?)?.toInt(),
    phoneSince: j['phoneSince'] == null
        ? null
        : DateTime.tryParse(j['phoneSince'] as String),
    healthConnectSteps: (j['hc'] as num?)?.toInt(),
    healthConnectAt: j['hcAt'] == null
        ? null
        : DateTime.tryParse(j['hcAt'] as String),
    unattributedSteps: (j['unattributed'] as num?)?.toInt() ?? 0,
  );
}

/// The one daily total every screen and calculation uses.
class DayStepTotal {
  final String dayKey;

  /// The day's total, or null when no source has a reading for it.
  final int? steps;

  /// Which source [steps] comes from (null when [steps] is null).
  final StepSource? source;

  final int? phoneSteps;
  final DateTime? phoneSince;
  final int? healthConnectSteps;

  /// Both sources have a count and they differ by more than a fifth.
  final bool sourcesDisagree;

  const DayStepTotal({
    required this.dayKey,
    this.steps,
    this.source,
    this.phoneSteps,
    this.phoneSince,
    this.healthConnectSteps,
    this.sourcesDisagree = false,
  });

  bool get hasReading => steps != null;

  /// Today's number for display: the count, or `--` when there is no reading.
  String get display => steps == null ? '--' : '$steps';

  /// Combines the two sources for one day without adding them: the larger
  /// count wins (ties go to the phone), because the smaller one is missing
  /// part of the day (app closed, watch off the wrist, sensor started late).
  factory DayStepTotal.fromRecord(String dayKey, DayStepRecord? r) {
    final phone = r?.phoneSteps;
    final hc = r?.healthConnectSteps;
    if (phone == null && hc == null) {
      return DayStepTotal(dayKey: dayKey, phoneSince: r?.phoneSince);
    }
    final useHc = hc != null && (phone == null || hc > phone);
    final steps = useHc ? hc : phone!;
    var disagree = false;
    if (phone != null && hc != null) {
      final high = phone > hc ? phone : hc;
      final low = phone > hc ? hc : phone;
      disagree = high >= 100 && (high - low) > high * 0.2;
    }
    return DayStepTotal(
      dayKey: dayKey,
      steps: steps,
      source: useHc ? StepSource.healthConnect : StepSource.phoneSensor,
      phoneSteps: phone,
      phoneSince: r?.phoneSince,
      healthConnectSteps: hc,
      sourcesDisagree: disagree,
    );
  }
}
