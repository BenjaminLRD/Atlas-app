import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'cardio_tracker.dart';

/// Reads the real device GPS through the geolocator plugin.
///
/// Recording keeps going with the screen locked or another app in front:
/// * Android: a foreground service of type `location` with an ongoing
///   notification ("Atlas is recording your run"), and a wake lock so the CPU
///   keeps delivering positions. It starts when the stream is listened to and
///   stops when the stream is cancelled, which the tracker does on finish and
///   discard. Only "while in use" permission is needed, because the service
///   starts while the app is on screen.
/// * iOS: background location updates with the system's blue indicator, which
///   needs the `location` background mode in Info.plist.
///
/// Nothing here is uploaded.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<LocationAccess> ensureAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationAccess.granted;
    }
  }

  /// The settings for the current platform. Public so a test can check that
  /// background tracking is actually configured.
  @visibleForTesting
  static LocationSettings settingsFor(
    TargetPlatform platform, {
    String activityLabel = 'activity',
  }) {
    switch (platform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
          intervalDuration: const Duration(seconds: 2),
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle:
                'Atlas is recording your '
                '${activityLabel.toLowerCase()}',
            notificationText:
                'Distance and route are being tracked. Open Atlas to pause or '
                'finish.',
            notificationChannelName: 'Activity tracking',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.fitness,
          distanceFilter: 2,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
        );
    }
  }

  @override
  Stream<GpsFix> positions({String activityLabel = 'activity'}) {
    return Geolocator.getPositionStream(
      locationSettings: settingsFor(
        defaultTargetPlatform,
        activityLabel: activityLabel,
      ),
    ).map(
      (p) => GpsFix(
        p.latitude,
        p.longitude,
        p.timestamp,
        accuracyM: p.accuracy > 0 ? p.accuracy : null,
      ),
    );
  }

  /// Opens the system settings page for this app, for a permission that was
  /// denied for good.
  static Future<void> openAppSettings() => Geolocator.openAppSettings();

  static Future<void> openLocationSettings() =>
      Geolocator.openLocationSettings();
}
