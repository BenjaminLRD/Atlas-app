import 'package:flutter/foundation.dart';

/// A synchronous "something was saved" signal between a service and whoever
/// shows its data.
///
/// The service calls [notifyChanged]; the app-level state listens and reloads.
/// The service never learns who is listening, so it can be built and tested on
/// its own. Rules, matching `ChangeNotifier`:
/// * Notifying is synchronous: every listener has run when [notifyChanged]
///   returns.
/// * Adding the same listener twice registers it once.
/// * A listener removed while a notification is running is not called after
///   that point; the others still are.
/// * A listener that throws is reported (`FlutterError.reportError`) and the
///   remaining listeners still run. The save that caused the notification has
///   already succeeded, so it is not turned into a failure.
class ChangeSignal {
  ChangeSignal(this._library);

  /// Names this signal in error reports.
  final String _library;

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Number of listeners, for tests.
  @visibleForTesting
  int get listenerCount => _listeners.length;

  void notifyChanged() {
    // Walk a copy, so listeners may add or remove listeners while they run.
    for (final listener in List<VoidCallback>.of(_listeners)) {
      // Removed by an earlier listener in this same notification.
      if (!_listeners.contains(listener)) continue;
      try {
        listener();
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: _library,
            context: ErrorDescription('while notifying a change'),
          ),
        );
      }
    }
  }
}
