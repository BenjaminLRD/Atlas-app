import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:atlas/services/food/off_search_client.dart';
import 'package:atlas/services/food/product_lookup_service.dart';
import 'package:atlas/services/food/product_matcher.dart';

String _fixture() =>
    File('test/fixtures/off_search_mountain_dew_india.json').readAsStringSync();

/// A 200 answer with a UTF-8 body, as the real service sends it.
http.Response _ok(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _empty = '{"hits":[],"count":0}';

const _dew750 = ProductCandidate(
  name: 'Mountain Dew',
  brand: 'PepsiCo',
  sizeValue: 750,
  sizeUnit: 'ml',
);

ProductLookupService _service(
  Future<http.Response> Function(http.Request) handler, {
  List<Uri>? seen,
}) => ProductLookupService(
  client: OffSearchClient(
    httpClient: MockClient((r) async {
      seen?.add(r.url);
      return handler(r);
    }),
    minInterval: Duration.zero,
  ),
);

void main() {
  group('exact', () {
    test('an exact Indian listing is returned after one search', () async {
      final seen = <Uri>[];
      final service = _service((_) async => _ok(_fixture()), seen: seen);

      final result = await service.lookup(_dew750);

      expect(result.status, LookupStatus.exact);
      expect(result.exact!.code, '8902080364053');
      expect(seen, hasLength(1));
      expect(seen.single.queryParameters['q'], contains('en:india'));
    });

    test(
      'an exact match without nutrition is still reported as exact',
      () async {
        final service = _service((_) async => _ok(_fixture()));

        final result = await service.lookup(_dew750);

        expect(result.exact!.hasNutrition, isFalse);
        // Other sizes with data are offered, never merged in.
        expect(result.candidates.map((p) => p.code), contains('8902080364022'));
      },
    );
  });

  group('choose', () {
    test('several sizes and no size on the label: the user chooses', () async {
      final service = _service((_) async => _ok(_fixture()));

      final result = await service.lookup(
        const ProductCandidate(name: 'Mountain Dew', brand: 'PepsiCo'),
      );

      expect(result.status, LookupStatus.choose);
      expect(result.exact, isNull);
      expect(result.candidates.length, greaterThan(1));
    });

    test('a wrong label size is not accepted', () async {
      final service = _service((_) async => _ok(_fixture()));

      final result = await service.lookup(
        const ProductCandidate(
          name: 'Mountain Dew',
          brand: 'PepsiCo',
          sizeValue: 600,
          sizeUnit: 'ml',
        ),
      );

      expect(result.status, LookupStatus.choose);
      expect(result.exact, isNull);
    });
  });

  group('widening the search', () {
    test('nothing in India: search everywhere, never exact', () async {
      final seen = <Uri>[];
      var call = 0;
      final service = _service((r) async {
        call++;
        return call == 1 ? http.Response(_empty, 200) : _ok(_fixture());
      }, seen: seen);

      final result = await service.lookup(_dew750);

      expect(seen, hasLength(2));
      expect(seen[0].queryParameters['q'], contains('en:india'));
      expect(seen[1].queryParameters['q'], isNot(contains('en:india')));
      expect(result.widened, isTrue);
      expect(result.status, isNot(LookupStatus.exact));
    });

    test('nothing anywhere is none', () async {
      final service = _service((_) async => http.Response(_empty, 200));

      final result = await service.lookup(_dew750);

      expect(result.status, LookupStatus.none);
      expect(result.exact, isNull);
      expect(result.candidates, isEmpty);
    });

    test('results that are all unrelated are none', () async {
      final service = _service((_) async => _ok(_fixture()));

      final result = await service.lookup(
        const ProductCandidate(name: 'Amul Butter', brand: 'Amul'),
      );

      expect(result.status, LookupStatus.none);
    });
  });

  group('failures', () {
    test('a failed search reports why and does not guess', () async {
      for (final (response, kind) in [
        (http.Response('', 503), LookupFailureKind.rateLimited),
        (http.Response('', 429), LookupFailureKind.rateLimited),
        (http.Response('', 500), LookupFailureKind.unavailable),
        (http.Response('<html>', 200), LookupFailureKind.badResponse),
      ]) {
        final result = await _service((_) async => response).lookup(_dew750);
        expect(result.status, LookupStatus.failed, reason: '$kind');
        expect(result.failure, kind);
        expect(result.exact, isNull);
        expect(result.message, isNotEmpty);
      }
    });

    test('offline and timeout are distinct', () async {
      final offline = await _service(
        (_) async => throw const SocketException('down'),
      ).lookup(_dew750);
      expect(offline.failure, LookupFailureKind.offline);

      final slow = ProductLookupService(
        client: OffSearchClient(
          httpClient: MockClient((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return _ok(_fixture());
          }),
          timeout: const Duration(milliseconds: 20),
          minInterval: Duration.zero,
        ),
      );
      expect((await slow.lookup(_dew750)).failure, LookupFailureKind.timeout);
    });

    test('a failed widening search is a failure, not a quiet none', () async {
      var call = 0;
      final service = _service((_) async {
        call++;
        return call == 1 ? http.Response(_empty, 200) : http.Response('', 503);
      });

      final result = await service.lookup(_dew750);

      expect(result.status, LookupStatus.failed);
    });
  });

  test('a candidate with no name is not searched', () async {
    var calls = 0;
    final service = _service((_) async {
      calls++;
      return _ok(_fixture());
    });

    final result = await service.lookup(const ProductCandidate(name: '  '));

    expect(result.status, LookupStatus.none);
    expect(calls, 0);
  });

  group('repeat lookups', () {
    ProductLookupService cached(
      Future<http.Response> Function(http.Request) handler,
      List<Uri> seen,
      DateTime Function() now,
    ) => ProductLookupService(
      client: OffSearchClient(
        httpClient: MockClient((r) async {
          seen.add(r.url);
          return handler(r);
        }),
        minInterval: Duration.zero,
      ),
      now: now,
    );

    test('the same product is not searched again straight away', () async {
      final seen = <Uri>[];
      var now = DateTime(2026, 10, 24, 12);
      final service = cached((_) async => _ok(_fixture()), seen, () => now);

      final first = await service.lookup(_dew750);
      now = now.add(const Duration(minutes: 1));
      final second = await service.lookup(_dew750);

      expect(seen, hasLength(1));
      expect(second.status, first.status);
      expect(second.exact!.code, first.exact!.code);
    });

    test('a different product is searched', () async {
      final seen = <Uri>[];
      final service = cached(
        (_) async => _ok(_fixture()),
        seen,
        () => DateTime(2026, 10, 24),
      );

      await service.lookup(_dew750);
      await service.lookup(
        const ProductCandidate(
          name: 'Mountain Dew',
          brand: 'PepsiCo',
          sizeValue: 250,
          sizeUnit: 'ml',
        ),
      );

      expect(seen, hasLength(2));
    });

    test(
      'a different size of the same product is a different lookup',
      () async {
        final seen = <Uri>[];
        final service = cached(
          (_) async => _ok(_fixture()),
          seen,
          () => DateTime(2026, 10, 24),
        );

        await service.lookup(_dew750);
        await service.lookup(
          const ProductCandidate(name: 'Mountain Dew', brand: 'PepsiCo'),
        );

        expect(seen, hasLength(2));
      },
    );

    test('a failed lookup is never kept: the next one tries again', () async {
      final seen = <Uri>[];
      var fail = true;
      final service = cached(
        (_) async => fail ? http.Response('', 503) : _ok(_fixture()),
        seen,
        () => DateTime(2026, 10, 24),
      );

      final first = await service.lookup(_dew750);
      expect(first.status, LookupStatus.failed);

      fail = false;
      final second = await service.lookup(_dew750);

      expect(second.status, LookupStatus.exact);
      expect(seen, hasLength(2));
    });

    test('an old answer is not trusted: it is searched again', () async {
      final seen = <Uri>[];
      var now = DateTime(2026, 10, 24, 8);
      final service = cached((_) async => _ok(_fixture()), seen, () => now);

      await service.lookup(_dew750);
      now = now.add(const Duration(hours: 7));
      await service.lookup(_dew750);

      expect(seen, hasLength(2));
    });

    test('"nothing found" is remembered only briefly', () async {
      final seen = <Uri>[];
      var now = DateTime(2026, 10, 24, 12);
      final service = cached(
        (_) async => http.Response(_empty, 200),
        seen,
        () => now,
      );

      await service.lookup(_dew750);
      final searches = seen.length;
      now = now.add(const Duration(minutes: 2));
      await service.lookup(_dew750);
      expect(seen.length, searches, reason: 'still remembered');

      now = now.add(const Duration(minutes: 10));
      await service.lookup(_dew750);
      expect(seen.length, greaterThan(searches), reason: 'asked again');
    });

    test(
      'a choice between products is remembered, never as an exact match',
      () async {
        final seen = <Uri>[];
        final service = cached(
          (_) async => _ok(_fixture()),
          seen,
          () => DateTime(2026, 10, 24),
        );
        const open = ProductCandidate(name: 'Mountain Dew', brand: 'PepsiCo');

        final first = await service.lookup(open);
        final second = await service.lookup(open);

        expect(first.status, LookupStatus.choose);
        expect(second.status, LookupStatus.choose);
        expect(second.exact, isNull);
        expect(seen, hasLength(1));
      },
    );
  });
}
