import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/machine_scan_result.dart';
import 'package:atlas/screens/exercise_library_screen.dart';
import 'package:atlas/screens/machine_scanner_screen.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';
import 'package:atlas/services/machine/machine_scan_service.dart';

/// A 1x1 PNG, so the preview has something real to decode.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

const _photo = ChatAttachment(base64Data: _png, mimeType: 'image/png');

class _FakeService extends MachineScanService {
  _FakeService({this.identifyResult, this.explainResult, this.error})
    : super(config: AIConfig());

  MachineScanResult? identifyResult;
  MachineScanResult? explainResult;
  Object? error;

  int identifyCalls = 0;
  final List<({String name, String? id})> explainCalls = [];

  @override
  Future<MachineScanResult> identify(ChatAttachment attachment) async {
    identifyCalls++;
    if (error != null) throw error!;
    return identifyResult!;
  }

  @override
  Future<MachineScanResult> explain(
    String machineName, {
    String? catalogId,
  }) async {
    explainCalls.add((name: machineName, id: catalogId));
    if (error != null) throw error!;
    return explainResult!;
  }
}

MachineScanResult _chestPress({
  MachineScanStatus status = MachineScanStatus.identified,
  double confidence = 0.85,
  String? note,
  String? catalogId = 'chest_press_machine',
}) => MachineScanResult(
  status: status,
  machineName: 'Seated chest press machine',
  catalogId: catalogId,
  catalogName: catalogId == null ? null : 'Chest Press Machine',
  primaryMuscles: const ['Chest'],
  secondaryMuscles: const ['Triceps'],
  setupSteps: const ['Adjust the seat to mid-chest height'],
  usageSteps: const ['Press the handles forward'],
  safetyCues: const ['Keep your back against the pad'],
  commonMistakes: const ['Letting the weights slam'],
  confidence: confidence,
  uncertaintyNote: note,
);

Future<void> _open(
  WidgetTester tester,
  _FakeService service, {
  ChatAttachment? photo = _photo,
}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MachineScannerScreen(
        service: service,
        imageSource: (_) async => photo,
      ),
    ),
  );
}

Future<void> _scan(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('machine_take_photo')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  testWidgets('starts with photo options and the AI-can-be-wrong notice', (
    tester,
  ) async {
    await _open(tester, _FakeService());

    expect(find.byKey(const Key('machine_take_photo')), findsOneWidget);
    expect(find.byKey(const Key('machine_choose_photo')), findsOneWidget);
    expect(find.byKey(const Key('machine_pick_manually')), findsOneWidget);
    expect(find.byKey(const Key('machine_disclaimer')), findsOneWidget);
    expect(find.textContaining('can be wrong'), findsOneWidget);
  });

  testWidgets('guidance stays hidden until the user confirms the machine', (
    tester,
  ) async {
    final service = _FakeService(identifyResult: _chestPress());
    await _open(tester, service);
    await _scan(tester);

    expect(service.identifyCalls, 1);
    expect(find.text('Seated chest press machine'), findsOneWidget);
    expect(find.textContaining('Confidence: 85%'), findsOneWidget);
    expect(
      find.text('Matches Atlas equipment: Chest Press Machine'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('machine_confirm_question')), findsOneWidget);
    // Nothing to act on yet.
    expect(find.textContaining('Keep your back against the pad'), findsNothing);
    expect(find.textContaining('Adjust the seat'), findsNothing);

    await tester.tap(find.byKey(const Key('machine_confirm_yes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('machine_confirmed')), findsOneWidget);
    expect(find.text('Primary: Chest'), findsOneWidget);
    expect(find.text('Secondary: Triceps'), findsOneWidget);
    expect(find.textContaining('1. Adjust the seat'), findsOneWidget);
    expect(find.textContaining('1. Press the handles forward'), findsOneWidget);
    expect(
      find.textContaining('Keep your back against the pad'),
      findsOneWidget,
    );
    expect(find.textContaining('Letting the weights slam'), findsOneWidget);
    expect(find.text('Exercises in Atlas for this machine'), findsOneWidget);
    expect(find.byKey(const Key('machine_disclaimer')), findsOneWidget);
  });

  testWidgets('a machine that is not in the catalog says so', (tester) async {
    final service = _FakeService(identifyResult: _chestPress(catalogId: null));
    await _open(tester, service);
    await _scan(tester);

    expect(find.text("Not in Atlas's equipment list"), findsOneWidget);
    expect(find.textContaining('Matches Atlas equipment'), findsNothing);

    await tester.tap(find.byKey(const Key('machine_confirm_yes')));
    await tester.pumpAndSettle();
    expect(
      find.text('Exercises in Atlas for this machine'),
      findsNothing,
      reason: 'no catalog match, so no library exercises are claimed',
    );
  });

  testWidgets('a low-confidence result is clearly flagged', (tester) async {
    final service = _FakeService(
      identifyResult: _chestPress(
        status: MachineScanStatus.uncertain,
        confidence: 0.45,
        note: 'Could be a pec deck',
      ),
    );
    await _open(tester, service);
    await _scan(tester);

    expect(find.text('Atlas is not sure, but this might be'), findsOneWidget);
    expect(find.textContaining('Confidence: 45% (low)'), findsOneWidget);
    expect(find.text('Could be a pec deck'), findsOneWidget);
    expect(
      find.textContaining('Check the label on the machine'),
      findsOneWidget,
    );
    expect(find.textContaining('Keep your back against the pad'), findsNothing);
  });

  testWidgets('a photo that is not gym equipment shows a clear result', (
    tester,
  ) async {
    final service = _FakeService(
      identifyResult: const MachineScanResult(
        status: MachineScanStatus.notEquipment,
        message: 'This is a photo of a sandwich.',
      ),
    );
    await _open(tester, service);
    await _scan(tester);

    expect(find.byKey(const Key('machine_not_equipment')), findsOneWidget);
    expect(find.text('This is a photo of a sandwich.'), findsOneWidget);
    expect(find.byKey(const Key('machine_confirm_yes')), findsNothing);
    expect(find.byKey(const Key('machine_try_another')), findsOneWidget);
  });

  testWidgets('an unidentified machine offers a retry and manual choice', (
    tester,
  ) async {
    final service = _FakeService(
      identifyResult: const MachineScanResult(
        status: MachineScanStatus.unidentified,
        confidence: 0.2,
        message: 'Atlas could not tell which machine this is.',
      ),
    );
    await _open(tester, service);
    await _scan(tester);

    expect(find.byKey(const Key('machine_unidentified')), findsOneWidget);
    expect(find.byKey(const Key('machine_confirm_yes')), findsNothing);
    expect(find.byKey(const Key('machine_correct')), findsOneWidget);

    await tester.tap(find.byKey(const Key('machine_try_another')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('machine_take_photo')), findsOneWidget);
  });

  testWidgets('a failed scan shows the message and Try again repeats it', (
    tester,
  ) async {
    final service = _FakeService(
      error: const MachineScanException('Connect to the internet.'),
    );
    await _open(tester, service);
    await _scan(tester);

    expect(find.byKey(const Key('machine_error_text')), findsOneWidget);
    expect(find.text('Connect to the internet.'), findsOneWidget);

    service
      ..error = null
      ..identifyResult = _chestPress();
    await tester.tap(find.byKey(const Key('machine_retry')));
    await tester.pumpAndSettle();

    expect(service.identifyCalls, 2);
    expect(find.text('Seated chest press machine'), findsOneWidget);
  });

  testWidgets('an unexpected error becomes a friendly message', (tester) async {
    final service = _FakeService(error: StateError('boom'));
    await _open(tester, service);
    await _scan(tester);

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('no photo (camera refused) explains what to do', (tester) async {
    final service = _FakeService();
    await _open(tester, service, photo: null);
    await _scan(tester);

    expect(service.identifyCalls, 0);
    expect(find.textContaining('Allow camera access'), findsOneWidget);
    expect(find.byKey(const Key('machine_retry')), findsNothing);
    expect(find.byKey(const Key('machine_start_over')), findsOneWidget);
  });

  testWidgets('correcting from the catalog explains the chosen machine', (
    tester,
  ) async {
    final service = _FakeService(
      identifyResult: _chestPress(),
      explainResult: const MachineScanResult(
        status: MachineScanStatus.identified,
        machineName: 'Leg Press Machine',
        catalogId: 'leg_press',
        catalogName: 'Leg Press Machine',
        primaryMuscles: ['Quadriceps'],
        usageSteps: ['Push the sled away'],
        safetyCues: ['Do not lock your knees'],
        confidence: 0.9,
      ),
    );
    await _open(tester, service);
    await _scan(tester);

    await tester.tap(find.byKey(const Key('machine_correct')));
    await tester.pumpAndSettle();
    expect(find.text('Which machine is it?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('machine_option_leg_press')));
    await tester.pumpAndSettle();

    expect(service.explainCalls.single.name, 'Leg Press Machine');
    expect(service.explainCalls.single.id, 'leg_press');
    expect(find.text('You chose'), findsOneWidget);
    expect(find.byKey(const Key('machine_confirmed')), findsOneWidget);
    expect(find.text('Machine chosen by you'), findsOneWidget);
    expect(find.textContaining('Do not lock your knees'), findsOneWidget);
    // The AI's earlier wrong guess is gone.
    expect(find.text('Seated chest press machine'), findsNothing);
  });

  testWidgets('a typed machine name is explained without a catalog id', (
    tester,
  ) async {
    final service = _FakeService(explainResult: _chestPress(catalogId: null));
    await _open(tester, service);

    await tester.tap(find.byKey(const Key('machine_pick_manually')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('machine_name_field')),
      'Pec deck',
    );
    await tester.tap(find.byKey(const Key('machine_name_submit')));
    await tester.pumpAndSettle();

    expect(service.explainCalls.single, (name: 'Pec deck', id: null));
    expect(find.byKey(const Key('machine_confirmed')), findsOneWidget);
  });

  testWidgets('a typed name that is not equipment is reported as such', (
    tester,
  ) async {
    final service = _FakeService(
      explainResult: const MachineScanResult(
        status: MachineScanStatus.notEquipment,
        message: 'That is not gym equipment.',
      ),
    );
    await _open(tester, service);

    await tester.tap(find.byKey(const Key('machine_pick_manually')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('machine_name_field')),
      'Pizza',
    );
    await tester.tap(find.byKey(const Key('machine_name_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('machine_not_equipment')), findsOneWidget);
    expect(find.byKey(const Key('machine_confirmed')), findsNothing);
  });

  testWidgets(
    'photo to result: the real service sends the photo and the screen shows '
    'the answer',
    (tester) async {
      late http.Request seen;
      final service = MachineScanService(
        config: AIConfig(
          proxyUrl: 'https://proj.supabase.co/functions/v1/ai-proxy',
          accessTokenProvider: () => 'user-token',
        ),
        httpClient: MockClient((request) async {
          seen = request;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'is_gym_equipment': true,
                          'machineName': 'Leg Press Machine',
                          'catalogId': 'leg_press',
                          'confidence': 0.92,
                          'primaryMuscles': ['Quadriceps'],
                          'usage': ['Push the sled away'],
                          'safetyCues': ['Do not lock your knees'],
                        }),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MachineScannerScreen(
            service: service,
            imageSource: (fromCamera) async => fromCamera ? _photo : null,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('machine_take_photo')));
      await tester.pumpAndSettle();

      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['feature'], 'coach');
      final parts =
          (body['request']['contents'] as List).first['parts'] as List;
      final inline = parts.whereType<Map>().firstWhere(
        (p) => p.containsKey('inline_data'),
      );
      expect(inline['inline_data']['data'], _png);
      expect(find.text('Leg Press Machine'), findsOneWidget);
      expect(
        find.text('Matches Atlas equipment: Leg Press Machine'),
        findsOneWidget,
      );
      expect(find.textContaining('Do not lock your knees'), findsNothing);

      await tester.tap(find.byKey(const Key('machine_confirm_yes')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Do not lock your knees'), findsOneWidget);
    },
  );

  testWidgets('the Exercise Library opens the machine scanner', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ExerciseLibraryScreen()));
    await tester.pump();

    await tester.tap(find.byTooltip('Scan a machine'));
    await tester.pumpAndSettle();

    expect(find.byType(MachineScannerScreen), findsOneWidget);
    expect(find.byKey(const Key('machine_take_photo')), findsOneWidget);
  });
}
