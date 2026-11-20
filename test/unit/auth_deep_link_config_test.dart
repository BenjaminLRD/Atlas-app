import 'dart:io';

import 'package:atlas/services/cloud/cloud_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final callback = Uri.parse(CloudAuthRepository.authCallbackUri);
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').existsSync()
      ? File('android/app/build.gradle.kts').readAsStringSync()
      : File('android/app/build.gradle').readAsStringSync();

  test('callback scheme is derived from the Android application ID', () {
    expect(gradle, contains('applicationId = "${callback.scheme}"'));
    expect(callback.host, 'login-callback');
  });

  test('MainActivity declares a VIEW/DEFAULT/BROWSABLE filter for it', () {
    final filter = RegExp(
      r'<intent-filter>(?:(?!</intent-filter>).)*?'
      r'android\.intent\.action\.VIEW(?:(?!</intent-filter>).)*?'
      r'android\.intent\.category\.DEFAULT(?:(?!</intent-filter>).)*?'
      r'android\.intent\.category\.BROWSABLE(?:(?!</intent-filter>).)*?'
      'android:scheme="${RegExp.escape(callback.scheme)}"'
      r'(?:(?!</intent-filter>).)*?'
      'android:host="${RegExp.escape(callback.host)}"',
      dotAll: true,
    );
    expect(filter.hasMatch(manifest), isTrue);
  });

  test('Flutter does not also route auth links as pages', () {
    expect(manifest, contains('flutter_deeplinking_enabled'));
    expect(
      RegExp(
        r'flutter_deeplinking_enabled"\s*android:value="false"',
      ).hasMatch(manifest),
      isTrue,
    );
  });
}
