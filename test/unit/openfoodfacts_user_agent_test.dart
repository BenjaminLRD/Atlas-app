import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  test('the User-Agent names Atlas, the pubspec version and the contact', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);

    expect(
      OpenFoodFactsService.userAgent,
      'Atlas/$version (lzadeng_be24@thapar.edu)',
    );
    expect(
      OpenFoodFactsService.userAgent.toLowerCase(),
      isNot(contains('aizawl')),
    );
  });

  test('the lookup request sends that User-Agent', () async {
    String? sent;
    final service = OpenFoodFactsService(
      httpClient: MockClient((request) async {
        sent = request.headers['User-Agent'];
        return http.Response('{"status":0}', 200);
      }),
    );

    await service.getProductByBarcode('8901234567890');

    expect(sent, OpenFoodFactsService.userAgent);
  });
}
