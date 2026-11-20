import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/ai/vision/ai_vision_service.dart';
import 'package:atlas/services/food/food_ai_vision_service.dart';

const _proxy = 'https://proj.supabase.co/functions/v1/ai-proxy';

AIConfig _signedIn() =>
    AIConfig(proxyUrl: _proxy, accessTokenProvider: () => 'user-token');

const _photo = ChatAttachment(base64Data: 'aGVsbG8=', mimeType: 'image/jpeg');

Map<String, dynamic> _estimate({
  Map<String, dynamic> override = const {},
  List<String> remove = const [],
}) {
  final m = <String, dynamic>{
    'is_food': true,
    'foodName': 'Chicken rice bowl',
    'ingredients': ['chicken breast', 'white rice'],
    'servingSize': 450,
    'servingUnit': 'grams',
    'calories': 620,
    'protein': 48,
    'carbohydrates': 75,
    'fats': 12,
    'confidence': 0.82,
    ...override,
  };
  for (final k in remove) {
    m.remove(k);
  }
  return m;
}

String _gemini(Object payload, {String? finishReason}) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': payload is String ? payload : jsonEncode(payload)},
        ],
      },
      'finishReason': ?finishReason,
    },
  ],
});

FoodAIVisionService _service(http.Client client, {AIConfig? config}) =>
    FoodAIVisionService(config: config ?? _signedIn(), httpClient: client);

Future<FoodVisionException> _failure(FoodAIVisionService service) async {
  try {
    await service.analyzeMealImage(attachment: _photo);
  } on FoodVisionException catch (e) {
    return e;
  }
  fail('expected a FoodVisionException');
}

String _proxyError(int code, String message) => jsonEncode({
  'error': {'code': code, 'message': message},
});

void main() {
  group('a successful analysis', () {
    test('goes through the proxy with the chat settings and returns the '
        'estimate', () async {
      late http.Request seen;
      final service = _service(
        MockClient((request) async {
          seen = request;
          return http.Response(_gemini(_estimate()), 200);
        }),
      );

      final r = await service.analyzeMealImage(attachment: _photo);

      expect(r.foodName, 'Chicken rice bowl');
      expect(r.calories, 620);
      expect(r.protein, 48);
      expect(r.carbohydrates, 75);
      expect(r.fats, 12);
      expect(r.servingSize, 450);
      expect(r.confidenceLevel, 'High');

      expect(seen.url.toString(), _proxy);
      expect(seen.headers['Authorization'], 'Bearer user-token');
      expect(
        seen.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-goog-api-key')),
      );
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['feature'], 'food_scan');
      expect(body['model'], 'gemini-2.5-flash');
      final request = body['request'] as Map<String, dynamic>;
      final content = (request['contents'] as List).single as Map;
      expect(content['role'], 'user');
      final parts = content['parts'] as List;
      expect(parts.last['inline_data']['data'], 'aGVsbG8=');
      expect(parts.last['inline_data']['mime_type'], 'image/jpeg');

      // The AI chat's settings, plus JSON output.
      final config = request['generationConfig'] as Map<String, dynamic>;
      expect(config['maxOutputTokens'], AIConfig.maxOutputTokens);
      expect(config['thinkingConfig'], {
        'thinkingBudget': AIConfig.thinkingBudget,
      });
      expect(config['temperature'], 0.2);
      expect(config['response_mime_type'], 'application/json');
    });

    test('waits as long as the AI chat does', () {
      expect(FoodAIVisionService.requestTimeout, AIConfig.requestTimeout);
    });

    test('answer text split over several parts is joined', () async {
      final json = jsonEncode(_estimate());
      final half = json.length ~/ 2;
      final service = _service(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': json.substring(0, half)},
                      {'text': json.substring(half)},
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );
      final r = await service.analyzeMealImage(attachment: _photo);
      expect(r.calories, 620);
    });

    test('confirmed zeros are kept as values (for example water)', () async {
      final service = _service(
        MockClient(
          (_) async => http.Response(
            _gemini(
              _estimate(
                override: {
                  'foodName': 'Water',
                  'calories': 0,
                  'protein': 0,
                  'carbohydrates': 0,
                  'fats': 0,
                  'confirmedZero': [
                    'calories',
                    'protein',
                    'carbohydrates',
                    'fats',
                  ],
                },
              ),
            ),
            200,
          ),
        ),
      );
      final r = await service.analyzeMealImage(attachment: _photo);
      expect(r.calories, 0);
      expect(r.unknownNutrients, isEmpty);
      expect(r.foodName, 'Water');
    });

    test('bare zeros are not accepted as an estimate', () async {
      final service = _service(
        MockClient(
          (_) async => http.Response(
            _gemini(
              _estimate(
                override: {
                  'foodName': 'Water',
                  'calories': 0,
                  'protein': 0,
                  'carbohydrates': 0,
                  'fats': 0,
                },
              ),
            ),
            200,
          ),
        ),
      );
      expect(
        () => service.analyzeMealImage(attachment: _photo),
        throwsA(isA<FoodVisionException>()),
      );
    });
  });

  group('before any request', () {
    Future<void> expectNoRequest(
      AIConfig config,
      String message,
      int status,
    ) async {
      var requests = 0;
      final service = _service(
        MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
        config: config,
      );
      final e = await _failure(service);
      expect(e.message, message);
      expect(e.statusCode, status);
      expect(requests, 0);
    }

    test('a build without backend settings says so (same as the chat)', () {
      return expectNoRequest(
        AIConfig(),
        'Atlas AI is not set up in this build of the app: the Supabase URL '
        'and anon key were missing when it was built.',
        503,
      );
    });

    test('a signed-out user is asked to sign in', () {
      return expectNoRequest(
        AIConfig(proxyUrl: _proxy, accessTokenProvider: () => null),
        'Sign in to use Atlas AI.',
        401,
      );
    });

    test('a photo with no data is reported before any request', () async {
      final e = await _failureWith(const ChatAttachment());
      expect(e.message, contains('could not be read'));
    });
  });

  group('distinct failures', () {
    test('expired session: the proxy message', () async {
      final e = await _failure(
        _service(
          MockClient(
            (_) async => http.Response(
              _proxyError(401, 'Your session expired. Sign in again.'),
              401,
            ),
          ),
        ),
      );
      expect(e.message, 'Your session expired. Sign in again.');
      expect(e.statusCode, 401);
    });

    test('401 with an unknown body: a generic sign-in message', () async {
      final e = await _failure(
        _service(MockClient((_) async => http.Response('<html>', 401))),
      );
      expect(e.message, 'Please sign in again to use Atlas AI.');
      expect(e.message, isNot(contains('html')));
    });

    test('daily limit: the proxy message for free and for pro', () async {
      for (final m in [
        'Daily AI limit reached. Upgrade to Atlas Pro for more.',
        'Daily AI limit reached. It resets at midnight UTC.',
      ]) {
        final e = await _failure(
          _service(
            MockClient((_) async => http.Response(_proxyError(429, m), 429)),
          ),
        );
        expect(e.message, m);
        expect(e.statusCode, 429);
      }
    });

    test(
      '429 from the model itself is a busy notice, not a quota claim',
      () async {
        final e = await _failure(
          _service(
            MockClient(
              (_) async =>
                  http.Response(_proxyError(429, 'Resource exhausted'), 429),
            ),
          ),
        );
        expect(e.message, contains('busy'));
        expect(e.message, isNot(contains('Daily')));
      },
    );

    test('403 says the AI is not available for this account', () async {
      final e = await _failure(
        _service(MockClient((_) async => http.Response('{}', 403))),
      );
      expect(e.message, contains('not available for this account'));
    });

    test('400 and 422: the photo could not be analyzed', () async {
      for (final code in [400, 422]) {
        final e = await _failure(
          _service(MockClient((_) async => http.Response('{}', code))),
        );
        expect(e.message, 'Unable to analyze this image.');
      }
    });

    test('413: the photo is too large', () async {
      final e = await _failure(
        _service(MockClient((_) async => http.Response('{}', 413))),
      );
      expect(e.message, contains('too large'));
    });

    test('server failures show the status and never the body', () async {
      for (final code in [500, 502, 503, 504]) {
        final e = await _failure(
          _service(
            MockClient((_) async => http.Response('secret stack trace', code)),
          ),
        );
        expect(e.message, contains('server error $code'));
        expect(e.message, isNot(contains('secret')));
        expect(e.statusCode, code);
      }
    });

    test(
      'the server not being set up is shown as the proxy wrote it',
      () async {
        final e = await _failure(
          _service(
            MockClient(
              (_) async => http.Response(
                _proxyError(503, 'Atlas AI is not configured on the server.'),
                503,
              ),
            ),
          ),
        );
        expect(e.message, 'Atlas AI is not configured on the server.');
      },
    );

    test('a timeout has its own message', () async {
      final e = await _failure(
        _service(MockClient((_) async => throw TimeoutException('slow'))),
      );
      expect(e.message, AIConfig.timeoutMessage);
    });

    test('no connection is flagged as a network error', () async {
      for (final error in [
        http.ClientException('down'),
        const SocketException('down'),
      ]) {
        final e = await _failure(
          _service(MockClient((_) async => throw error)),
        );
        expect(e.isNetworkError, isTrue);
        expect(e.message, contains('internet'));
      }
    });
  });

  group('empty, blocked and unreadable answers', () {
    Future<FoodVisionException> answer(String body) =>
        _failure(_service(MockClient((_) async => http.Response(body, 200))));

    test('an empty body or no candidates: no result', () async {
      for (final body in ['{}', '{"candidates": []}']) {
        final e = await answer(body);
        expect(e.message, contains('returned no result'));
      }
    });

    test('a candidate without text: no result', () async {
      final e = await answer(
        jsonEncode({
          'candidates': [
            {
              'content': {'parts': []},
            },
          ],
        }),
      );
      expect(e.message, contains('returned no result'));
    });

    test('a blocked prompt is reported as blocked', () async {
      final e = await answer(
        jsonEncode({
          'promptFeedback': {'blockReason': 'SAFETY'},
        }),
      );
      expect(e.message, contains('could not use this photo'));
    });

    test('a safety-stopped answer is reported as blocked', () async {
      final e = await answer(
        jsonEncode({
          'candidates': [
            {'finishReason': 'SAFETY'},
          ],
        }),
      );
      expect(e.message, contains('could not use this photo'));
    });

    test('an answer cut off by the length limit says so', () async {
      final e = await answer(
        jsonEncode({
          'candidates': [
            {'finishReason': 'MAX_TOKENS'},
          ],
        }),
      );
      expect(e.message, contains('ran out of room'));
    });

    test('a body that is not JSON is unreadable', () async {
      for (final body in ['<html>', '', '[1]', '"x"']) {
        final e = await answer(body);
        expect(e.message, contains('could not be read'));
      }
    });

    test('model text that is not JSON is an unreadable answer', () async {
      final e = await answer(_gemini('Sorry, I cannot help with that.'));
      expect(e.message, 'Unable to analyze this image.');
    });
  });

  group('the estimate itself', () {
    Future<FoodVisionException> incomplete(
      Map<String, dynamic> estimate,
    ) async {
      final service = _service(
        MockClient((_) async => http.Response(_gemini(estimate), 200)),
      );
      return _failure(service);
    }

    test('a photo with no food', () async {
      final e = await incomplete({'is_food': false, 'confidence': 0.0});
      expect(e.message, contains('No food detected'));
    });

    test('a missing value is unknown, never a zero', () async {
      const nutrients = {
        'calories': 'calories',
        'protein': 'protein',
        'carbohydrates': 'carbohydrates',
        'fats': 'fats',
      };
      for (final key in nutrients.keys) {
        final service = _service(
          MockClient(
            (_) async => http.Response(_gemini(_estimate(remove: [key])), 200),
          ),
        );
        final r = await service.analyzeMealImage(attachment: _photo);
        expect(r.unknownNutrients, {key}, reason: key);
      }
    });

    test('no nutrition numbers at all is an error', () async {
      final e = await incomplete(
        _estimate(remove: ['calories', 'protein', 'carbohydrates', 'fats']),
      );
      expect(e.message, contains('complete nutrition estimate'));
    });

    test(
      'a missing or empty portion is an error, not an invented 100 g',
      () async {
        final missing = await incomplete(_estimate(remove: ['servingSize']));
        expect(missing.message, contains('complete nutrition estimate'));
        final zero = await incomplete(_estimate(override: {'servingSize': 0}));
        expect(zero.message, contains('complete nutrition estimate'));
      },
    );

    test('values given as text are read', () async {
      final service = _service(
        MockClient(
          (_) async => http.Response(
            _gemini(
              _estimate(
                override: {
                  'servingSize': '450',
                  'calories': '620',
                  'protein': '48.5',
                  'carbohydrates': '75',
                  'fats': '12',
                },
              ),
            ),
            200,
          ),
        ),
      );
      final r = await service.analyzeMealImage(attachment: _photo);
      expect(r.protein, 48.5);
      expect(r.calories, 620);
    });

    test('no confidence counts as uncertain, not as confident', () async {
      final service = _service(
        MockClient(
          (_) async =>
              http.Response(_gemini(_estimate(remove: ['confidence'])), 200),
        ),
      );
      final r = await service.analyzeMealImage(attachment: _photo);
      expect(r.confidence, 0.5);
      expect(r.confidenceLevel, 'Medium');
    });

    test('fields of the wrong type are an unreadable answer', () async {
      final e = await incomplete(_estimate(override: {'foodName': 42}));
      expect(e.message, 'Unable to analyze this image.');
    });
  });

  group('taking or choosing the photo', () {
    test('a photo comes back as picked', () async {
      final service = AIVisionService(
        picker: _FakePicker(
          XFile.fromData(
            Uint8List.fromList([1, 2, 3, 4]),
            name: 'meal.jpg',
            mimeType: 'image/jpeg',
          ),
        ),
      );
      final r = await service.pickWithOutcome(source: ImageSource.camera);
      expect(r.outcome, ImagePickOutcome.picked);
      expect(r.attachment!.base64Data, base64Encode([1, 2, 3, 4]));
    });

    test('closing the camera is a cancel with a message', () async {
      final service = AIVisionService(picker: _FakePicker(null));
      final r = await service.pickWithOutcome(source: ImageSource.gallery);
      expect(r.outcome, ImagePickOutcome.cancelled);
      expect(r.message, 'No photo was selected.');
      expect(r.attachment, isNull);
    });

    test(
      'a denied camera permission is a failure that says what to do',
      () async {
        final service = AIVisionService(
          picker: _FakePicker.throwing(
            PlatformException(code: 'camera_access_denied'),
          ),
        );
        final r = await service.pickWithOutcome(source: ImageSource.camera);
        expect(r.outcome, ImagePickOutcome.failed);
        expect(r.message, contains('Camera access is off'));
        expect(r.message, contains('Settings'));
      },
    );

    test(
      'a denied gallery permission is a failure that says what to do',
      () async {
        final service = AIVisionService(
          picker: _FakePicker.throwing(
            PlatformException(code: 'photo_access_denied'),
          ),
        );
        final r = await service.pickWithOutcome(source: ImageSource.gallery);
        expect(r.outcome, ImagePickOutcome.failed);
        expect(r.message, contains('Photo access is off'));
      },
    );

    test('other picker errors are failures with a message', () async {
      for (final error in <Object>[
        PlatformException(code: 'no_available_camera'),
        StateError('boom'),
      ]) {
        final service = AIVisionService(picker: _FakePicker.throwing(error));
        final r = await service.pickWithOutcome(source: ImageSource.camera);
        expect(r.outcome, ImagePickOutcome.failed);
        expect(r.message, isNotEmpty);
        expect(r.message, isNot(contains('boom')));
      }
    });
  });
}

Future<FoodVisionException> _failureWith(ChatAttachment attachment) async {
  final service = FoodAIVisionService(
    config: _signedIn(),
    httpClient: MockClient((_) async => http.Response('{}', 200)),
  );
  try {
    await service.analyzeMealImage(attachment: attachment);
  } on FoodVisionException catch (e) {
    return e;
  }
  fail('expected a FoodVisionException');
}

class _FakePicker extends ImagePicker {
  _FakePicker(this._file) : _error = null;
  _FakePicker.throwing(Object error) : _file = null, _error = error;

  final XFile? _file;
  final Object? _error;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (_error != null) throw _error;
    return _file;
  }
}
