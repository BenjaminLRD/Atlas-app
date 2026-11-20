import 'package:pedometer/pedometer.dart';

/// The phone's step counter: cumulative steps since the phone last booted.
/// The stream reports an error when the phone has no such sensor.
abstract class StepSensor {
  Stream<int> counts();
}

class PedometerStepSensor implements StepSensor {
  const PedometerStepSensor();

  @override
  Stream<int> counts() => Pedometer.stepCountStream.map((e) => e.steps);
}
