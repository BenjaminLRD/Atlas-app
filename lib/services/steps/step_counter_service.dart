import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../../data/local_storage.dart';
import '../health/platform_health_reader.dart';
import 'step_ledger.dart';
import 'step_models.dart';
import 'step_permission.dart';
import 'step_sensor.dart';

/// Where the ledger is saved.
abstract class StepLedgerStorage {
  String? read();
  Future<void> write(String json);
}

class LocalStepLedgerStorage implements StepLedgerStorage {
  const LocalStepLedgerStorage();
  @override
  String? read() => LocalStorage.getStepLedgerJson();
  @override
  Future<void> write(String json) => LocalStorage.saveStepLedgerJson(json);
}

/// Steps per day from Health Connect / Apple Health for the given days,
/// keyed by [stepDayKey]. Days without data are left out.
typedef HealthStepsReader =
    Future<Map<String, int>> Function(List<DateTime> days);

/// Reads the device's health store only when it is available and the user has
/// already granted access; it never asks by itself.
Future<Map<String, int>> readHealthStoreSteps(List<DateTime> days) async {
  final reader = PlatformHealthReader.instance;
  if (!await reader.isAvailable() || !await reader.hasPermissions()) {
    return {};
  }
  final out = <String, int>{};
  for (final day in days) {
    // Steps only (the store's own de-duplicated total for the local day).
    final steps = await reader.stepsOn(day);
    if (steps != null && steps > 0) out[stepDayKey(day)] = steps;
  }
  return out;
}

/// The single source of truth for steps.
///
/// * Live count: the phone's own step counter (no watch or other app needed).
/// * History / completeness: Health Connect, when the user has allowed it.
/// * Per day the larger of the two is used, never their sum (see
///   [DayStepTotal.fromRecord]); both stay stored so the source is always known.
/// * No reading means null. Nothing is estimated, defaulted or typed in.
///
/// Limits: the app counts only while its process is alive, plus the steps the
/// phone counted in between on the same day (the counter keeps running without
/// the app). Steps counted across midnight or a phone restart while the app was
/// not listening cannot be placed on a day and are not credited.
class StepCounterService extends ChangeNotifier {
  /// Phones only: the step counter does not exist on desktop or web builds.
  static bool get isSupportedPlatform {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static StepCounterService? _instance;
  static StepCounterService get instance => _instance ??= StepCounterService();
  static void setInstance(StepCounterService service) => _instance = service;
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }

  final StepSensor _sensor;
  final StepPermissionGateway _permission;
  final StepLedgerStorage _storage;

  /// Null turns Health Connect off (used by tests).
  final HealthStepsReader? healthReader;
  final DateTime Function() _clock;
  final Duration persistEvery;

  StepCounterService({
    StepSensor? sensor,
    StepPermissionGateway? permission,
    StepLedgerStorage? storage,
    this.healthReader = readHealthStoreSteps,
    DateTime Function()? clock,
    this.persistEvery = const Duration(seconds: 5),
  }) : _sensor = sensor ?? const PedometerStepSensor(),
       _permission = permission ?? MethodChannelStepPermission(),
       _storage = storage ?? const LocalStepLedgerStorage(),
       _clock = clock ?? DateTime.now;

  StepLedger _ledger = StepLedger();
  StepSensorStatus _status = StepSensorStatus.idle;
  StreamSubscription<int>? _subscription;
  DateTime? _continuousSince;
  DateTime? _lastPersist;
  bool _loaded = false;
  bool _healthConnectHasData = false;
  String? _lastError;

  StepSensorStatus get status => _status;

  /// The last sensor error text, for diagnostics (never shown as a step count).
  String? get lastError => _lastError;

  /// Whether Health Connect currently supplied step data.
  bool get healthConnectHasData => _healthConnectHasData;

  /// Today's total, or a total with no steps when nothing was read yet.
  DayStepTotal get today {
    _load();
    _startDayIfListening();
    return _ledger.totalFor(_clock());
  }

  /// The last seven days (today last). Days without a reading have no steps.
  List<DayStepTotal> get week {
    _load();
    _startDayIfListening();
    return _ledger.lastDays(_clock());
  }

  /// The last [count] days (today last). Days without a reading have no
  /// steps. Used for weekly comparisons.
  List<DayStepTotal> daysBack(int count) {
    _load();
    _startDayIfListening();
    return _ledger.lastDays(_clock(), count: count);
  }

  /// Loads saved data and starts listening if permission allows. Safe to call
  /// again (for example when the app comes back to the foreground).
  Future<void> start() {
    // The app calls this at launch and again on the first "resumed" event,
    // and on every return from the background. Overlapping calls share one
    // run, so there is never more than one counter subscription being set up.
    final running = _starting;
    if (running != null) return running;
    final run = _startOnce().whenComplete(() => _starting = null);
    _starting = run;
    return run;
  }

  Future<void>? _starting;

  Future<void> _startOnce() async {
    _load();
    final permission = await _permission.status();
    switch (permission) {
      case StepPermission.granted:
      case StepPermission.notRequired:
        _listen();
        break;
      case StepPermission.denied:
        await _stopListening();
        _setStatus(StepSensorStatus.needsPermission);
        break;
      case StepPermission.permanentlyDenied:
        await _stopListening();
        _setStatus(StepSensorStatus.permissionPermanentlyDenied);
        break;
    }
    await refreshHealthConnect();
  }

  /// Shows the system permission dialog and starts counting when granted.
  Future<StepPermission> requestPermission() async {
    final result = await _permission.request();
    await start();
    return result;
  }

  Future<void> openSettings() => _permission.openSettings();

  /// App came back to the foreground: permission may have changed.
  Future<void> onResumed() => start();

  /// App is going to the background: save what has been counted.
  Future<void> onPaused() => _persist(force: true);

  /// Pulls the last seven days from Health Connect, if connected.
  Future<void> refreshHealthConnect() async {
    final reader = healthReader;
    if (reader == null) return;
    try {
      final now = _clock();
      final start = stepDayStart(now);
      final days = [
        for (var i = 0; i < 7; i++)
          DateTime(start.year, start.month, start.day - i),
      ];
      final steps = await reader(days);
      _healthConnectHasData = steps.isNotEmpty;
      for (final e in steps.entries) {
        _ledger.setHealthConnect(e.key, e.value, now);
      }
      await _persist(force: true);
    } catch (_) {
      // No health data this time; counts already stored stay as they are.
    }
    notifyListeners();
  }

  void _load() {
    if (_loaded) return;
    _loaded = true;
    _ledger = StepLedger.decode(_storage.read());
  }

  void _listen() {
    // Replace, never add: the old subscription is dropped before the new one
    // is made, so each sensor event is processed once.
    final previous = _subscription;
    _subscription = null;
    previous?.cancel();
    _continuousSince = _clock();
    _lastError = null;
    _setStatus(StepSensorStatus.waitingForFirstReading);
    _subscription = _sensor.counts().listen(
      _onCount,
      onError: _onError,
      cancelOnError: false,
    );
  }

  Future<void> _stopListening() async {
    final sub = _subscription;
    _subscription = null;
    _continuousSince = null;
    await sub?.cancel();
  }

  void _onCount(int counter) {
    _ledger.observe(counter, _clock(), continuousSince: _continuousSince);
    _status = StepSensorStatus.active;
    _persist();
    notifyListeners();
  }

  void _onError(Object error) {
    _lastError = error.toString();
    _stopListening();
    _setStatus(StepSensorStatus.unavailable);
  }

  void _startDayIfListening() {
    if (_subscription == null) return;
    _ledger.startDayIfListening(_clock(), continuousSince: _continuousSince);
  }

  void _setStatus(StepSensorStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  Future<void> _persist({bool force = false}) async {
    final now = _clock();
    final last = _lastPersist;
    if (!force && last != null && now.difference(last) < persistEvery) return;
    _lastPersist = now;
    try {
      await _storage.write(_ledger.encode());
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
