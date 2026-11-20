import 'dart:async';

import 'package:atlas/services/cardio/cardio_tracker.dart';

/// A scripted location source.
class FakeSource implements LocationSource {
  FakeSource([this.access = LocationAccess.granted]);

  LocationAccess access;

  /// How many times the position stream was opened (a background service
  /// starts each time) and the label shown in its notification.
  int listens = 0;
  String? lastLabel;
  final StreamController<GpsFix> controller = StreamController<GpsFix>();

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Stream<GpsFix> positions({String activityLabel = 'activity'}) {
    listens++;
    lastLabel = activityLabel;
    return controller.stream;
  }
}

/// A clock that only moves when told to.
class FakeClock {
  DateTime now = DateTime(2026, 11, 16, 7);
  DateTime call() => now;
  void advance(int seconds) => now = now.add(Duration(seconds: seconds));
}
