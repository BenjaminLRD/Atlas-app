import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:atlas/models/machine_scan_result.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/machine/machine_scan_service.dart';

const _proxy = 'https://proj.supabase.co/functions/v1/ai-proxy';

AIConfig _proxyConfig() =>
    AIConfig(proxyUrl: _proxy, accessTokenProvider: () => 'user-token');

String _geminiBody(Object payload) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': payload is String ? payload : jsonEncode(payload)},
        ],
      },
    },
  ],
});

Map<String, dynamic> _chestPress({
  Object? catalogId = 'chest_press_machine',
  Object? confidence = 0.85,
  Object? name = 'Seated chest press machine',
}) => {
  'is_gym_equipment': true,
  'machineName': name,
  'catalogId': catalogId,
  'confidence': confidence,
  'uncertainty': '',
  'primaryMuscles': ['Chest'],
  'secondaryMuscles': ['Triceps', 'Front deltoids'],
  'setup': ['Adjust the seat so the handles sit at mid-chest height'],
  'usage': ['Press the handles forward until the arms are nearly straight'],
  'safetyCues': ['Keep your back against the pad'],
  'commonMistakes': ['Letting the weight stack slam down'],
};

const _photo = ChatAttachment(base64Data: 'aGVsbG8=', mimeType: 'image/jpeg');

MachineScanService _service({http.Client? client, AIConfig? config}) =>
    MachineScanService(config: config ?? _proxyConfig(), httpClient: client);

void main() {
  group('parsing a valid answer', () {
    test(
      'a confident chest press is identified and matched to the catalog',
      () {
        final r = _service().parseResponse(jsonEncode(_chestPress()));

        expect(r.status, MachineScanStatus.identified);
        expect(r.machineName, 'Seated chest press machine');
        expect(r.catalogId, 'chest_press_machine');
        expect(r.catalogName, 'Chest Press Machine');
        expect(r.primaryMuscles, ['Chest']);
        expect(r.secondaryMuscles, ['Triceps', 'Front deltoids']);
        expect(r.setupSteps, hasLength(1));
        expect(r.usageSteps, hasLength(1));
        expect(r.safetyCues, ['Keep your back against the pad']);
        expect(r.commonMistakes, hasLength(1));
        expect(r.confidence, 0.85);
        expect(r.isLowConfidence, isFalse);
        expect(r.hasDetails, isTrue);
        expect(r.uncertaintyNote, isNull);
      },
    );

    test('JSON wrapped in a code fence is read', () {
      final text = '```json\n${jsonEncode(_chestPress())}\n```';
      expect(
        _service().parseResponse(text).status,
        MachineScanStatus.identified,
      );
    });

    test('a catalog id in another case still matches the same item', () {
      final r = _service().parseResponse(
        jsonEncode(_chestPress(catalogId: 'Chest_Press_Machine')),
      );
      expect(r.catalogId, 'chest_press_machine');
    });

    test('with no id, an exact catalog name still matches', () {
      final r = _service().parseResponse(
        jsonEncode(_chestPress(catalogId: null, name: 'Smith Machine')),
      );
      expect(r.catalogId, 'smith_machine');
      expect(r.catalogName, 'Smith Machine');
    });

    test('a confidence given as a percentage is read as a fraction', () {
      final r = _service().parseResponse(
        jsonEncode(_chestPress(confidence: '85')),
      );
      expect(r.confidence, 0.85);
    });

    test('long lists and long text are capped', () {
      final payload = _chestPress()
        ..['usage'] = List.generate(30, (i) => 'Step $i')
        ..['safetyCues'] = ['x' * 1000];
      final r = _service().parseResponse(jsonEncode(payload));
      expect(r.usageSteps, hasLength(8));
      expect(r.safetyCues.single.length, 240);
    });
  });

  group('malformed answers', () {
    for (final bad in [
      'not json at all',
      '',
      '[1, 2, 3]',
      '"text"',
      '{broken',
    ]) {
      test('"$bad" is an error, not a guess', () {
        expect(
          () => _service().parseResponse(bad),
          throwsA(isA<MachineScanException>()),
        );
      });
    }

    test('wrong field types are ignored, not trusted', () {
      final r = _service().parseResponse(
        jsonEncode({
          'is_gym_equipment': true,
          'machineName': 'Leg press',
          'confidence': 'very high',
          'primaryMuscles': 'Quads',
          'secondaryMuscles': {'a': 1},
          'setup': 42,
          'usage': ['Push the sled away'],
        }),
      );
      // Unreadable confidence counts as uncertain, never as certain.
      expect(r.confidence, 0.5);
      expect(r.status, MachineScanStatus.uncertain);
      expect(r.primaryMuscles, isEmpty);
      expect(r.secondaryMuscles, isEmpty);
      expect(r.setupSteps, isEmpty);
      expect(r.usageSteps, ['Push the sled away']);
    });

    test('a missing confidence is uncertain', () {
      final payload = _chestPress()..remove('confidence');
      final r = _service().parseResponse(jsonEncode(payload));
      expect(r.confidence, 0.5);
      expect(r.status, MachineScanStatus.uncertain);
    });

    test('a named machine with no guidance at all is not identified', () {
      final r = _service().parseResponse(
        jsonEncode({
          'is_gym_equipment': true,
          'machineName': 'Mystery rig',
          'confidence': 0.9,
        }),
      );
      expect(r.status, MachineScanStatus.unidentified);
      expect(r.hasDetails, isFalse);
      expect(r.message, contains('Mystery rig'));
    });
  });

  group('low confidence', () {
    test('a middling confidence is flagged as uncertain with a note', () {
      final r = _service().parseResponse(
        jsonEncode(_chestPress(confidence: 0.45)),
      );
      expect(r.status, MachineScanStatus.uncertain);
      expect(r.isLowConfidence, isTrue);
      expect(r.hasDetails, isTrue);
      expect(r.uncertaintyNote, isNotEmpty);
    });

    test("the model's own uncertainty note is kept", () {
      final payload = _chestPress(confidence: 0.5)
        ..['uncertainty'] = 'Could be a pec deck';
      final r = _service().parseResponse(jsonEncode(payload));
      expect(r.uncertaintyNote, 'Could be a pec deck');
    });

    test('a very low confidence is not identified and shows no guidance', () {
      final r = _service().parseResponse(
        jsonEncode(_chestPress(confidence: 0.2)),
      );
      expect(r.status, MachineScanStatus.unidentified);
      expect(r.hasDetails, isFalse);
      expect(r.primaryMuscles, isEmpty);
      expect(r.message, isNotEmpty);
    });

    test('confidence is clamped to 0 to 1', () {
      expect(
        _service()
            .parseResponse(jsonEncode(_chestPress(confidence: 7000)))
            .confidence,
        1.0,
      );
      expect(
        _service()
            .parseResponse(jsonEncode(_chestPress(confidence: -2)))
            .confidence,
        0.0,
      );
    });
  });

  group('unknown equipment', () {
    test('an invented catalog id is dropped, never matched', () {
      final r = _service().parseResponse(
        jsonEncode(
          _chestPress(
            catalogId: 'made_up_machine',
            name: 'Hammer-strength row',
          ),
        ),
      );
      expect(r.status, MachineScanStatus.identified);
      expect(r.machineName, 'Hammer-strength row');
      expect(r.catalogId, isNull);
      expect(r.catalogName, isNull);
      expect(r.hasCatalogMatch, isFalse);
    });

    test('a close but not exact name is not matched', () {
      final r = _service().parseResponse(
        jsonEncode(_chestPress(catalogId: null, name: 'Chest press')),
      );
      expect(r.catalogId, isNull);
    });

    for (final unknown in [
      'unknown',
      'Unidentified',
      'N/A',
      'none',
      '',
      null,
    ]) {
      test('machine name "$unknown" is not identified', () {
        final r = _service().parseResponse(
          jsonEncode(_chestPress(name: unknown)),
        );
        expect(r.status, MachineScanStatus.unidentified);
        expect(r.machineName, isNull);
      });
    }
  });

  group('images that are not gym equipment', () {
    test('is_gym_equipment false gives a clear not-equipment result', () {
      final r = _service().parseResponse(
        jsonEncode({
          'is_gym_equipment': false,
          'confidence': 0.0,
          'uncertainty': 'This is a photo of a sandwich.',
        }),
      );
      expect(r.status, MachineScanStatus.notEquipment);
      expect(r.hasDetails, isFalse);
      expect(r.message, 'This is a photo of a sandwich.');
      expect(r.machineName, isNull);
    });

    test('the flag also works as a string and with a default message', () {
      final r = _service().parseResponse('{"is_gym_equipment": "false"}');
      expect(r.status, MachineScanStatus.notEquipment);
      expect(r.message, "This doesn't look like gym equipment.");
    });

    test('guidance in a not-equipment answer is never shown', () {
      final payload = _chestPress()..['is_gym_equipment'] = false;
      final r = _service().parseResponse(jsonEncode(payload));
      expect(r.status, MachineScanStatus.notEquipment);
      expect(r.primaryMuscles, isEmpty);
      expect(r.safetyCues, isEmpty);
    });
  });

  group('requests', () {
    test(
      'a photo goes through the proxy with the coach quota bucket',
      () async {
        late http.Request seen;
        final client = MockClient((request) async {
          seen = request;
          return http.Response(_geminiBody(_chestPress()), 200);
        });

        final r = await _service(client: client).identify(_photo);

        expect(r.status, MachineScanStatus.identified);
        expect(seen.url.toString(), _proxy);
        expect(seen.headers['Authorization'], 'Bearer user-token');
        final body = jsonDecode(seen.body) as Map<String, dynamic>;
        expect(body['feature'], 'coach');
        expect(MachineScanService.quotaFeature, 'coach');
        final parts =
            (body['request']['contents'] as List).first['parts'] as List;
        expect(
          parts.any((p) => p is Map && p.containsKey('inline_data')),
          isTrue,
        );
        final prompt = (parts.first as Map)['text'] as String;
        expect(prompt, contains('chest_press_machine'));
        expect(prompt, contains('leg_press'));
        expect(prompt, contains('is_gym_equipment'));
        // No API key anywhere in what the app sends.
        expect(seen.body.toLowerCase(), isNot(contains('api_key')));
        expect(
          seen.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-goog-api-key')),
        );
      },
    );

    test(
      'naming a machine sends text only and keeps the chosen catalog item',
      () async {
        late Map<String, dynamic> body;
        final client = MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            _geminiBody(_chestPress(catalogId: null, name: 'Leg press')),
            200,
          );
        });

        final r = await _service(
          client: client,
        ).explain('Leg Press Machine', catalogId: 'leg_press');

        final parts =
            (body['request']['contents'] as List).first['parts'] as List;
        expect(
          parts.any((p) => (p as Map).containsKey('inline_data')),
          isFalse,
        );
        expect((parts.first as Map)['text'], contains('Leg Press Machine'));
        expect(r.catalogId, 'leg_press');
        expect(r.catalogName, 'Leg Press Machine');
      },
    );

    test(
      'a chosen catalog id is ignored if it is not in the catalog',
      () async {
        final client = MockClient(
          (_) async =>
              http.Response(_geminiBody(_chestPress(catalogId: null)), 200),
        );
        final r = await _service(
          client: client,
        ).explain('Something', catalogId: 'not_in_catalog');
        expect(r.catalogId, isNull);
      },
    );

    test('naming nothing is an error before any request', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 200);
      });
      await expectLater(
        _service(client: client).explain('   '),
        throwsA(isA<MachineScanException>()),
      );
      expect(calls, 0);
    });

    test('a photo with no data is an error before any request', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 200);
      });
      await expectLater(
        _service(client: client).identify(const ChatAttachment()),
        throwsA(isA<MachineScanException>()),
      );
      expect(calls, 0);
    });

    test('AI not configured (signed out) is a clear error', () async {
      final signedOut = AIConfig(
        proxyUrl: _proxy,
        accessTokenProvider: () => null,
      );
      await expectLater(
        _service(config: signedOut).identify(_photo),
        throwsA(
          isA<MachineScanException>().having(
            (e) => e.statusCode,
            'status',
            401,
          ),
        ),
      );
    });
  });

  group('request failures', () {
    Future<MachineScanException> failWith(
      Future<http.Response> Function(http.Request) handler,
    ) async {
      try {
        await _service(client: MockClient(handler)).identify(_photo);
      } on MachineScanException catch (e) {
        return e;
      }
      fail('expected a MachineScanException');
    }

    test('429 explains the daily limit', () async {
      final e = await failWith((_) async => http.Response('{}', 429));
      expect(e.statusCode, 429);
      expect(e.message, contains('Daily AI limit'));
    });

    test('401 asks to sign in', () async {
      final e = await failWith((_) async => http.Response('{}', 401));
      expect(e.message, contains('Sign in'));
    });

    test('400 says the photo could not be analyzed', () async {
      final e = await failWith((_) async => http.Response('{}', 400));
      expect(e.message, contains('could not be analyzed'));
    });

    test('a server error is reported as unavailable', () async {
      final e = await failWith((_) async => http.Response('oops', 503));
      expect(e.statusCode, 503);
      expect(e.message, contains('unavailable'));
    });

    test('an empty response is reported as unavailable', () async {
      final e = await failWith((_) async => http.Response('{}', 200));
      expect(e.message, contains('unavailable'));
    });

    test('a response whose text is not JSON is a read error', () async {
      final e = await failWith(
        (_) async => http.Response(_geminiBody('Sorry, I cannot help'), 200),
      );
      expect(e.message, contains('could not be read'));
    });

    test('no network is flagged as a network error', () async {
      final e = await failWith((_) async => throw http.ClientException('down'));
      expect(e.isNetworkError, isTrue);
    });

    test('a timeout gives the shared timeout message', () async {
      final e = await failWith((_) async => throw TimeoutException('slow'));
      expect(e.message, AIConfig.timeoutMessage);
    });
  });

  group('library exercises for a catalog item', () {
    test('only real exercises that need that equipment are returned', () {
      final list = MachineScanService.exercisesFor('chest_press_machine');
      expect(list, isNotEmpty);
      expect(
        list.every((e) => e.requiredEquipment.contains('chest_press_machine')),
        isTrue,
      );
    });

    test('an unknown id returns nothing', () {
      expect(MachineScanService.exercisesFor('made_up_machine'), isEmpty);
    });
  });
}
