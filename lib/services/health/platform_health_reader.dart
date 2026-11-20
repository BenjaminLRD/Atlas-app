import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// One reading from the device's health store.
class HealthSample {
  final HealthDataType type;
  final double value;
  final DateTime from;
  final DateTime to;
  final String sourceName;

  const HealthSample({
    required this.type,
    required this.value,
    required this.from,
    required this.to,
    this.sourceName = '',
  });
}

/// The parts of the `health` plugin Atlas uses, behind an interface so the
/// reading logic can be tested without a phone.
abstract class HealthDataSource {
  Future<bool> isAvailable();
  Future<bool> requestAuthorization(List<HealthDataType> types);
  Future<bool> hasPermissions(List<HealthDataType> types);
  Future<int?> totalSteps(DateTime start, DateTime end);
  Future<List<HealthSample>> samples(
    List<HealthDataType> types,
    DateTime start,
    DateTime end,
  );
}

/// [HealthDataSource] backed by Apple HealthKit (iOS) or Google Health
/// Connect (Android) through the `health` plugin.
class HealthPluginDataSource implements HealthDataSource {
  final Health _health = Health();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    await _ensureConfigured();
    return _health.isHealthConnectAvailable();
  }

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types) async {
    await _ensureConfigured();
    return _health.requestAuthorization(
      types,
      permissions: types.map((_) => HealthDataAccess.READ).toList(),
    );
  }

  @override
  Future<bool> hasPermissions(List<HealthDataType> types) async {
    await _ensureConfigured();
    // HealthKit never reveals read access and returns null; treat that as
    // "ask again", which is harmless on iOS.
    return await _health.hasPermissions(
          types,
          permissions: types.map((_) => HealthDataAccess.READ).toList(),
        ) ??
        false;
  }

  @override
  Future<int?> totalSteps(DateTime start, DateTime end) async {
    await _ensureConfigured();
    return _health.getTotalStepsInInterval(start, end);
  }

  @override
  Future<List<HealthSample>> samples(
    List<HealthDataType> types,
    DateTime start,
    DateTime end,
  ) async {
    await _ensureConfigured();
    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: start,
      endTime: end,
    );
    return [
      for (final p in points)
        if (p.value is NumericHealthValue)
          HealthSample(
            type: p.type,
            value: (p.value as NumericHealthValue).numericValue.toDouble(),
            from: p.dateFrom,
            to: p.dateTo,
            sourceName: p.sourceName,
          ),
    ];
  }
}

/// One day of health data. A null field means the health store had no data
/// for it; callers must not substitute made-up values.
class DailyHealthReading {
  final DateTime day;
  final int? steps;
  final double? activeCalories;
  final double? averageHeartRate;
  final double? restingHeartRate;
  final double? heartRateVariability;
  final int? sleepMinutes;
  final int? deepSleepMinutes;
  final int? remSleepMinutes;
  final String sourceName;

  const DailyHealthReading({
    required this.day,
    this.steps,
    this.activeCalories,
    this.averageHeartRate,
    this.restingHeartRate,
    this.heartRateVariability,
    this.sleepMinutes,
    this.deepSleepMinutes,
    this.remSleepMinutes,
    this.sourceName = '',
  });

  bool get hasAnyData =>
      (steps ?? 0) > 0 ||
      activeCalories != null ||
      averageHeartRate != null ||
      restingHeartRate != null ||
      heartRateVariability != null ||
      sleepMinutes != null;
}

/// Reads steps, calories, heart rate, HRV and sleep from Apple Health or
/// Health Connect. Phones have no heart-rate sensor: these values come from
/// a watch, ring or strap that writes into the health store.
class PlatformHealthReader {
  static PlatformHealthReader? _instance;
  static PlatformHealthReader get instance =>
      _instance ??= PlatformHealthReader(HealthPluginDataSource());
  static void setInstance(PlatformHealthReader reader) => _instance = reader;
  static void resetInstance() => _instance = null;

  final HealthDataSource source;
  final bool isIOS;

  PlatformHealthReader(this.source, {bool? isIOS})
    : isIOS = isIOS ?? (!kIsWeb && Platform.isIOS);

  /// True on Android and iOS, where a platform health store can exist.
  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  HealthDataType get _hrvType => isIOS
      ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
      : HealthDataType.HEART_RATE_VARIABILITY_RMSSD;

  static const List<HealthDataType> _asleepStages = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  /// Every type Atlas asks to read.
  List<HealthDataType> get readTypes => [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    _hrvType,
    ..._asleepStages,
    if (!isIOS) HealthDataType.SLEEP_SESSION,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.LEAN_BODY_MASS,
  ];

  Future<bool> isAvailable() => source.isAvailable();

  Future<bool> requestPermissions() async {
    if (!await source.isAvailable()) return false;
    return source.requestAuthorization(readTypes);
  }

  Future<bool> hasPermissions() async {
    if (!await source.isAvailable()) return false;
    return source.hasPermissions(readTypes);
  }

  /// The store's total steps for the local calendar day containing [day], and
  /// nothing else (no heart rate or sleep reads). The total is the health
  /// store's own aggregate, which already removes overlap between the apps and
  /// devices that write steps. Null when it cannot be read.
  Future<int?> stepsOn(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return source.totalSteps(start, start.add(const Duration(days: 1)));
  }

  /// Reads the calendar day containing [day]. Sleep is counted for the night
  /// ending that morning (6 pm the previous day to 2 pm).
  Future<DailyHealthReading> readDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final sleepStart = start.subtract(const Duration(hours: 6));
    final sleepEnd = start.add(const Duration(hours: 14));

    final steps = await source.totalSteps(start, end);
    final daySamples = await source.samples(
      [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        _hrvType,
      ],
      start,
      end,
    );
    final sleepSamples = await source.samples(
      [..._asleepStages, if (!isIOS) HealthDataType.SLEEP_SESSION],
      sleepStart,
      sleepEnd,
    );

    List<HealthSample> of(HealthDataType t) =>
        daySamples.where((s) => s.type == t).toList();

    final energy = of(HealthDataType.ACTIVE_ENERGY_BURNED);
    final heartRates = of(HealthDataType.HEART_RATE);
    final resting = of(HealthDataType.RESTING_HEART_RATE)
      ..sort((a, b) => a.to.compareTo(b.to));
    final hrv = of(_hrvType)..sort((a, b) => a.to.compareTo(b.to));

    int minutesOf(Iterable<HealthSample> samples) =>
        samples.fold(0, (sum, s) => sum + s.to.difference(s.from).inMinutes);
    final stages = sleepSamples.where((s) => _asleepStages.contains(s.type));
    final sessions = sleepSamples.where(
      (s) => s.type == HealthDataType.SLEEP_SESSION,
    );
    final stageMinutes = minutesOf(stages);
    final sleepMinutes = stageMinutes > 0
        ? stageMinutes
        : (sessions.isEmpty ? null : minutesOf(sessions));
    final deep = minutesOf(
      sleepSamples.where((s) => s.type == HealthDataType.SLEEP_DEEP),
    );
    final rem = minutesOf(
      sleepSamples.where((s) => s.type == HealthDataType.SLEEP_REM),
    );

    final sources = {
      ...daySamples.map((s) => s.sourceName),
      ...sleepSamples.map((s) => s.sourceName),
    }..removeWhere((s) => s.isEmpty);

    return DailyHealthReading(
      day: start,
      steps: steps,
      activeCalories: energy.isEmpty
          ? null
          : energy.fold<double>(0, (sum, s) => sum + s.value),
      averageHeartRate: heartRates.isEmpty
          ? null
          : heartRates.fold<double>(0, (sum, s) => sum + s.value) /
                heartRates.length,
      restingHeartRate: resting.isEmpty ? null : resting.last.value,
      heartRateVariability: hrv.isEmpty ? null : hrv.last.value,
      sleepMinutes: sleepMinutes,
      deepSleepMinutes: deep > 0 ? deep : null,
      remSleepMinutes: rem > 0 ? rem : null,
      sourceName: sources.isEmpty
          ? (isIOS ? 'Apple Health' : 'Health Connect')
          : sources.join(', '),
    );
  }

  /// Latest smart-scale readings in the last [window]: weight and lean mass
  /// in kg, body fat in percent. Null when the health store has none.
  Future<({double? weightKg, double? bodyFatPercent, double? leanMassKg})>
  latestBodyComposition({Duration window = const Duration(days: 30)}) async {
    final now = DateTime.now();
    final samples = await source.samples(
      [
        HealthDataType.WEIGHT,
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.LEAN_BODY_MASS,
      ],
      now.subtract(window),
      now,
    );
    double? latest(HealthDataType type) {
      final matching = samples.where((s) => s.type == type).toList()
        ..sort((a, b) => a.to.compareTo(b.to));
      return matching.isEmpty ? null : matching.last.value;
    }

    final fat = latest(HealthDataType.BODY_FAT_PERCENTAGE);
    return (
      weightKg: latest(HealthDataType.WEIGHT),
      // HealthKit reports a fraction (0.168); Health Connect a percent (16.8).
      bodyFatPercent: fat == null ? null : (fat <= 1 ? fat * 100 : fat),
      leanMassKg: latest(HealthDataType.LEAN_BODY_MASS),
    );
  }

  /// The most recent heart-rate reading in the last [window], for live
  /// display during workouts. Health stores are not real-time; a watch
  /// typically writes every few seconds to a few minutes.
  Future<int?> latestHeartRate({
    Duration window = const Duration(minutes: 2),
  }) async {
    final now = DateTime.now();
    final samples = await source.samples(
      [HealthDataType.HEART_RATE],
      now.subtract(window),
      now,
    );
    if (samples.isEmpty) return null;
    samples.sort((a, b) => a.to.compareTo(b.to));
    return samples.last.value.round();
  }
}
