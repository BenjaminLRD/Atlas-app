import 'package:health/health.dart';
import 'package:atlas/services/health/platform_health_reader.dart';

/// In-memory stand-in for Apple Health / Health Connect.
class FakeHealthDataSource implements HealthDataSource {
  bool available;
  bool granted;
  int? steps;
  final List<HealthSample> stored;

  FakeHealthDataSource({
    this.available = true,
    this.granted = false,
    this.steps,
    List<HealthSample>? samples,
  }) : stored = samples ?? [];

  /// A typical night and day from a watch that syncs to the health store.
  factory FakeHealthDataSource.withTypicalDay({String source = 'Test Watch'}) {
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    HealthSample s(HealthDataType t, double v, DateTime from, DateTime to) =>
        HealthSample(type: t, value: v, from: from, to: to, sourceName: source);
    final night = midnight.subtract(const Duration(hours: 1));
    return FakeHealthDataSource(
      steps: 8432,
      samples: [
        s(
          HealthDataType.SLEEP_LIGHT,
          0,
          night,
          night.add(const Duration(hours: 4)),
        ),
        s(
          HealthDataType.SLEEP_DEEP,
          0,
          night.add(const Duration(hours: 4)),
          night.add(const Duration(hours: 5, minutes: 30)),
        ),
        s(
          HealthDataType.SLEEP_REM,
          0,
          night.add(const Duration(hours: 5, minutes: 30)),
          night.add(const Duration(hours: 7)),
        ),
        s(
          HealthDataType.HEART_RATE,
          70,
          midnight.add(const Duration(hours: 9)),
          midnight.add(const Duration(hours: 9)),
        ),
        s(
          HealthDataType.HEART_RATE,
          80,
          midnight.add(const Duration(hours: 10)),
          midnight.add(const Duration(hours: 10)),
        ),
        s(
          HealthDataType.RESTING_HEART_RATE,
          61,
          midnight.add(const Duration(hours: 7)),
          midnight.add(const Duration(hours: 7)),
        ),
        s(
          HealthDataType.RESTING_HEART_RATE,
          58,
          midnight.add(const Duration(hours: 8)),
          midnight.add(const Duration(hours: 8)),
        ),
        s(
          HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
          72,
          midnight.add(const Duration(hours: 6)),
          midnight.add(const Duration(hours: 6)),
        ),
        s(
          HealthDataType.HEART_RATE_VARIABILITY_SDNN,
          72,
          midnight.add(const Duration(hours: 6)),
          midnight.add(const Duration(hours: 6)),
        ),
        s(
          HealthDataType.ACTIVE_ENERGY_BURNED,
          300,
          midnight.add(const Duration(hours: 9)),
          midnight.add(const Duration(hours: 10)),
        ),
        s(
          HealthDataType.ACTIVE_ENERGY_BURNED,
          150,
          midnight.add(const Duration(hours: 17)),
          midnight.add(const Duration(hours: 18)),
        ),
      ],
    );
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types) async {
    granted = available;
    return granted;
  }

  @override
  Future<bool> hasPermissions(List<HealthDataType> types) async => granted;

  @override
  Future<int?> totalSteps(DateTime start, DateTime end) async => steps;

  @override
  Future<List<HealthSample>> samples(
    List<HealthDataType> types,
    DateTime start,
    DateTime end,
  ) async => stored
      .where(
        (s) =>
            types.contains(s.type) &&
            !s.to.isBefore(start) &&
            s.from.isBefore(end),
      )
      .toList();
}
