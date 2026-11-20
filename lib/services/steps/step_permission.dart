import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'step_models.dart';

/// Activity Recognition permission, which Android 10+ requires before the
/// step counter delivers any reading.
abstract class StepPermissionGateway {
  Future<StepPermission> status();

  /// Shows the system dialog (does nothing when already granted or when
  /// Android will no longer show it).
  Future<StepPermission> request();

  /// Opens the app's page in the system settings.
  Future<void> openSettings();
}

/// Android: a small native channel in MainActivity. iOS asks for Motion
/// access itself the first time the sensor is used, so there is nothing to ask
/// ahead of time.
class MethodChannelStepPermission implements StepPermissionGateway {
  static const _channel = MethodChannel('atlas/activity_recognition');

  bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static StepPermission _parse(Object? v) {
    switch (v) {
      case 'granted':
        return StepPermission.granted;
      case 'permanentlyDenied':
        return StepPermission.permanentlyDenied;
      default:
        return StepPermission.denied;
    }
  }

  @override
  Future<StepPermission> status() async {
    if (!_isAndroid) return StepPermission.notRequired;
    try {
      return _parse(await _channel.invokeMethod<String>('status'));
    } catch (_) {
      return StepPermission.denied;
    }
  }

  @override
  Future<StepPermission> request() async {
    if (!_isAndroid) return StepPermission.notRequired;
    try {
      return _parse(await _channel.invokeMethod<String>('request'));
    } catch (_) {
      return StepPermission.denied;
    }
  }

  @override
  Future<void> openSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }
}
