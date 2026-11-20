import 'dart:async';
import 'package:atlas/services/steps/step_counter_service.dart';
import 'package:atlas/services/steps/step_models.dart';
import 'package:atlas/services/steps/step_permission.dart';
import 'package:atlas/services/steps/step_sensor.dart';

/// A step counter the test drives by hand. [emit] sends a cumulative reading.
class FakeStepSensor implements StepSensor {
  StreamController<int>? _controller;
  int listens = 0;

  bool get isListening => _controller?.hasListener ?? false;

  @override
  Stream<int> counts() {
    listens++;
    _controller = StreamController<int>(sync: true);
    return _controller!.stream;
  }

  void emit(int counter) => _controller?.add(counter);
  void fail(Object error) => _controller?.addError(error);
}

class FakeStepPermission implements StepPermissionGateway {
  StepPermission current;

  /// What the system dialog answers when [request] is called.
  StepPermission answer;
  int requests = 0;
  int settingsOpened = 0;

  FakeStepPermission({
    this.current = StepPermission.granted,
    this.answer = StepPermission.granted,
  });

  @override
  Future<StepPermission> status() async => current;

  @override
  Future<StepPermission> request() async {
    requests++;
    current = answer;
    return current;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class MemoryStepStorage implements StepLedgerStorage {
  String? json;
  int writes = 0;

  @override
  String? read() => json;

  @override
  Future<void> write(String value) async {
    json = value;
    writes++;
  }
}

/// A clock the test moves by hand.
class TestClock {
  DateTime now;
  TestClock(this.now);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

StepCounterService makeStepService({
  FakeStepSensor? sensor,
  FakeStepPermission? permission,
  MemoryStepStorage? storage,
  TestClock? clock,
  HealthStepsReader? healthReader,
}) {
  return StepCounterService(
    sensor: sensor ?? FakeStepSensor(),
    permission: permission ?? FakeStepPermission(),
    storage: storage ?? MemoryStepStorage(),
    healthReader: healthReader,
    clock: clock?.call,
    persistEvery: Duration.zero,
  );
}
