import 'apple_health_provider.dart';

/// Google Health Connect on Android (Google Fit's successor).
class GoogleFitProvider extends PlatformHealthProvider {
  GoogleFitProvider({super.reader}) : super(idPrefix: 'hm_health_connect');
}
