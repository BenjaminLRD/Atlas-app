import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:atlas/services/food/off_search_client.dart';

String _fixture() =>
    File('test/fixtures/off_search_mountain_dew_india.json').readAsStringSync();

/// A 200 answer with a UTF-8 body, as the real service sends it.
http.Response _ok(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

OffSearchClient _client(
  MockClient mock, {
  Duration minInterval = Duration.zero,
  Future<void> Function(Duration)? wait,
  DateTime Function()? now,
}) => OffSearchClient(
  httpClient: mock,
  minInterval: minInterval,
  wait: wait,
  now: now,
);

Future<ProductLookupException> _failure(Future<Object?> call) async {
  try {
    await call;
  } on ProductLookupException catch (e) {
    return e;
  }
  fail('expected a ProductLookupException');
}

void main() {
  group('the request', () {
    test(
      'asks the Open Food Facts search API for what the parser reads',
      () async {
        late http.Request seen;
        final client = _client(
          MockClient((r) async {
            seen = r;
            return _ok(_fixture());
          }),
        );

        await client.search('PepsiCo Mountain Dew', indiaOnly: true);

        expect(seen.url.host, 'search.openfoodfacts.org');
        expect(seen.url.path, '/search');
        expect(
          seen.url.queryParameters['q'],
          contains('countries_tags:"en:india"'),
        );
        expect(seen.url.queryParameters['q'], contains('Mountain Dew'));
        final fields = seen.url.queryParameters['fields']!.split(',');
        expect(
          fields,
          containsAll([
            'code',
            'product_name',
            'brands',
            'quantity',
            'nutriments',
            'countries_tags',
          ]),
        );
        expect(seen.url.queryParameters['page_size'], isNotEmpty);
        expect(seen.headers['User-Agent'], startsWith('Atlas/'));
        expect(seen.headers['User-Agent'], contains('@'));
      },
    );

    test('a widened search has no country filter', () async {
      late Uri seen;
      final client = _client(
        MockClient((r) async {
          seen = r.url;
          return _ok(_fixture());
        }),
      );

      await client.search('Mountain Dew');

      expect(seen.queryParameters['q'], 'Mountain Dew');
    });

    test('search syntax typed in a name cannot change the query', () async {
      late Uri seen;
      final client = _client(
        MockClient((r) async {
          seen = r.url;
          return _ok(_fixture());
        }),
      );

      await client.search('Dew" OR code:* (x) -y');

      final q = seen.queryParameters['q']!;
      expect(q, isNot(contains('"')));
      expect(q, isNot(contains('(')));
      expect(q, isNot(contains('*')));
    });

    test('no network call happens for an empty query', () async {
      var calls = 0;
      final client = _client(
        MockClient((r) async {
          calls++;
          return _ok(_fixture());
        }),
      );

      expect(await client.search('   '), isEmpty);
      expect(calls, 0);
    });
  });

  group('the answer', () {
    test('real hits become products', () async {
      final client = _client(MockClient((_) async => _ok(_fixture())));

      final products = await client.search('Mountain Dew', indiaOnly: true);

      expect(products, hasLength(11));
      expect(products.map((p) => p.code), contains('8902080364053'));
    });

    test('no hits is an empty list, not an error', () async {
      final client = _client(
        MockClient((_) async => http.Response('{"hits":[],"count":0}', 200)),
      );
      expect(await client.search('nothing'), isEmpty);
    });

    test('a hit that cannot be read is skipped, the rest are kept', () async {
      final body = jsonEncode({
        'hits': [
          {
            'code': '1',
            'product_name': 'Good',
            'nutriments': {'energy-kcal_100g': 10},
          },
          {'code': 5},
          'not a map',
          {'product_name': 'no code'},
          {'code': '2', 'brands': 7, 'nutriments': 'broken'},
        ],
      });
      final client = _client(MockClient((_) async => http.Response(body, 200)));

      final products = await client.search('x');

      expect(products.map((p) => p.code), contains('1'));
      expect(products.map((p) => p.code), isNot(contains('5')));
    });
  });

  group('failures are typed and never thrown as raw errors', () {
    test('a timeout', () async {
      final client = OffSearchClient(
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _ok(_fixture());
        }),
        timeout: const Duration(milliseconds: 20),
        minInterval: Duration.zero,
      );
      final e = await _failure(client.search('x'));
      expect(e.kind, LookupFailureKind.timeout);
      expect(e.message, isNotEmpty);
    });

    test('no network', () async {
      final client = _client(
        MockClient((_) async => throw const SocketException('down')),
      );
      expect(
        (await _failure(client.search('x'))).kind,
        LookupFailureKind.offline,
      );

      final other = _client(
        MockClient((_) async => throw http.ClientException('down')),
      );
      expect(
        (await _failure(other.search('x'))).kind,
        LookupFailureKind.offline,
      );
    });

    test('too many requests', () async {
      final client = _client(MockClient((_) async => http.Response('', 429)));
      expect(
        (await _failure(client.search('x'))).kind,
        LookupFailureKind.rateLimited,
      );
    });

    test('a busy server (503) is rate limiting too', () async {
      final client = _client(MockClient((_) async => http.Response('', 503)));
      expect(
        (await _failure(client.search('x'))).kind,
        LookupFailureKind.rateLimited,
      );
    });

    test('another server error', () async {
      final client = _client(MockClient((_) async => http.Response('', 500)));
      expect(
        (await _failure(client.search('x'))).kind,
        LookupFailureKind.unavailable,
      );
    });

    test('an answer that is not JSON', () async {
      for (final body in ['<html>', '', '[1]', '"x"', '{"hits":"no"}']) {
        final client = _client(
          MockClient((_) async => http.Response(body, 200)),
        );
        expect(
          (await _failure(client.search('x'))).kind,
          LookupFailureKind.badResponse,
          reason: body,
        );
      }
    });
  });

  group('the request rate stays below Open Food Facts limits', () {
    test('a second search waits out the minimum interval', () async {
      var now = DateTime(2026, 10, 23, 12);
      final waits = <Duration>[];
      final client = OffSearchClient(
        httpClient: MockClient((_) async => _ok(_fixture())),
        minInterval: const Duration(seconds: 6),
        now: () => now,
        wait: (d) async {
          waits.add(d);
          now = now.add(d);
        },
      );

      await client.search('a');
      expect(waits, isEmpty, reason: 'the first search does not wait');

      now = now.add(const Duration(seconds: 2));
      await client.search('b');
      expect(waits, [const Duration(seconds: 4)]);

      now = now.add(const Duration(seconds: 10));
      await client.search('c');
      expect(waits, hasLength(1), reason: 'enough time had passed');
    });

    test('the default interval is at least six seconds', () {
      expect(
        OffSearchClient.defaultMinInterval,
        greaterThanOrEqualTo(const Duration(seconds: 6)),
      );
    });

    test('a failed request still counts toward the interval', () async {
      var now = DateTime(2026, 10, 23, 12);
      final waits = <Duration>[];
      var first = true;
      final client = OffSearchClient(
        httpClient: MockClient((_) async {
          if (first) {
            first = false;
            return http.Response('', 503);
          }
          return _ok(_fixture());
        }),
        minInterval: const Duration(seconds: 6),
        now: () => now,
        wait: (d) async {
          waits.add(d);
          now = now.add(d);
        },
      );

      await _failure(client.search('a'));
      await client.search('b');

      expect(waits, [const Duration(seconds: 6)]);
    });
  });
}
