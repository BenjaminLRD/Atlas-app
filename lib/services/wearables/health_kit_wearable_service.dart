import 'health_connect_wearable_service.dart';
import 'wearable_service.dart';

/// iOS: Apple HealthKit.
class HealthKitWearableService extends PlatformWearableService {
  HealthKitWearableService({super.reader});

  @override
  WearablePlatform get platform => WearablePlatform.appleHealth;

  @override
  String get providerName => 'Apple HealthKit';
}
