import '../data/local_storage.dart';
import 'steps/step_counter_service.dart';
import 'steps/step_models.dart';

/// Read access to steps for screens and calculations.
///
/// Every number comes from [StepCounterService]: the phone's step counter and,
/// when allowed, Health Connect (see that class for how they are combined).
/// Steps cannot be typed in, and nothing here is estimated or defaulted: with
/// no reading the total is null and screens show `--`.
class StepTrackingService {
  const StepTrackingService();

  /// Retrieve active daily step goal (defaults to 10,000 steps).
  int getStepGoal() => LocalStorage.getStepGoal();

  /// Update daily step goal.
  Future<void> setStepGoal(int goal) async {
    await LocalStorage.saveStepGoal(goal.clamp(1000, 50000));
  }

  /// Today's total (null steps when there is no reading).
  DayStepTotal get today => StepCounterService.instance.today;

  /// The last seven days, today last. Days with no reading have null steps.
  List<DayStepTotal> get week => StepCounterService.instance.week;

  /// Distance walked, calculated from real steps with an average adult stride
  /// (0.762 m). An estimate; null when there are no steps to calculate from.
  static double? distanceKmFor(int? steps) {
    if (steps == null) return null;
    return double.parse(((steps * 0.762) / 1000.0).toStringAsFixed(2));
  }

  /// Calories from walking, calculated from real steps and body weight
  /// (about 0.042 kcal per step at 70 kg). An estimate; null with no steps.
  static double? caloriesFor(int? steps, {double userWeightKg = 70.0}) {
    if (steps == null) return null;
    final weightFactor = (userWeightKg / 70.0).clamp(0.6, 2.0);
    return double.parse((steps * 0.042 * weightFactor).toStringAsFixed(1));
  }
}
