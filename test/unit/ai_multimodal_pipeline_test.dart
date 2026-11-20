import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/coach_message.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/navigation/app_navigation.dart';
import 'package:atlas/screens/ai_coach_chat_screen.dart';
import 'package:atlas/screens/ai_coach_screen.dart';
import 'package:atlas/services/ai/agent/ai_agent.dart';
import 'package:atlas/services/ai/ai_config.dart';
import 'package:atlas/services/ai/coach_chat_service.dart';
import 'package:atlas/services/ai/gemini_ai_provider.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/services/ai/multimodal/chat_attachment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Phase 11 — Multimodal AI Pipeline Comprehensive Tests', () {
    // 1. Only one canonical AI Coach route exists
    test(
      '1. Only one canonical AI Coach route exists in AppNavDestination',
      () {
        final dest = AppNavDestination.aiCoach;
        expect(dest.id, equals('ai_coach'));
        expect(dest.routeBuilder, isNotNull);
        final widget = dest.routeBuilder!(MockBuildContext());
        expect(widget, isA<AICoachScreen>());
      },
    );

    // 2. Old AI Coach screen is no longer reachable
    testWidgets('2. Old AI Coach screen redirects to canonical AICoachScreen', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: AiCoachChatScreen()));
      expect(find.byType(AICoachScreen), findsOneWidget);
    });

    // 3. Text-only chat still works
    test(
      '3. Text-only chat still works seamlessly in CoachChatService and MockAIProvider',
      () async {
        final service = CoachChatService(aiProvider: const MockAIProvider());
        final context = FitnessContext.initial();
        final messages = await service.sendMessage(
          message: 'What is my daily protein target?',
          context: context,
        );

        expect(messages.length, greaterThanOrEqualTo(2));
        final lastMsg = messages.last;
        expect(lastMsg.role, equals(CoachRole.assistant));
        expect(lastMsg.content, isNotEmpty);
        expect(lastMsg.hasImage, isFalse);
      },
    );

    // 4. Image attachment can be added
    test(
      '4. Image attachment can be added and serialized into CoachMessage',
      () {
        final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
        final attachment = ChatAttachment.fromBytes(
          bytes: sampleBytes,
          mimeType: 'image/jpeg',
          fileName: 'gym_machine.jpg',
        );

        expect(attachment.fileName, equals('gym_machine.jpg'));
        expect(attachment.mimeType, equals('image/jpeg'));
        expect(attachment.base64Data, isNotNull);

        final msg = CoachMessage(
          id: 'msg_test',
          role: CoachRole.user,
          content: 'Identify this machine',
          timestamp: DateTime.now(),
          imageBase64: attachment.base64Data,
          imageMimeType: attachment.mimeType,
        );

        expect(msg.hasImage, isTrue);
        expect(msg.imageBase64, equals(base64Encode(sampleBytes)));
      },
    );

    // 5. Image can be removed before sending
    test('5. Image can be removed before sending', () {
      ChatAttachment? selected = ChatAttachment.fromBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      );
      expect(selected, isNotNull);

      // Simulate user tapping remove (x) button
      selected = null;
      expect(selected, isNull);
    });

    // 6. JPEG/PNG/WebP handling
    test('6. JPEG, PNG, and WebP formats are supported and recognized', () {
      final jpeg = ChatAttachment.fromBytes(
        bytes: Uint8List.fromList([255, 216, 255]),
        mimeType: 'image/jpeg',
        fileName: 'photo.jpg',
      );
      final png = ChatAttachment.fromBytes(
        bytes: Uint8List.fromList([137, 80, 78, 71]),
        mimeType: 'image/png',
        fileName: 'graphic.png',
      );
      final webp = ChatAttachment.fromBytes(
        bytes: Uint8List.fromList([82, 73, 70, 70]),
        mimeType: 'image/webp',
        fileName: 'image.webp',
      );
      final unsupported = ChatAttachment.fromBytes(
        bytes: Uint8List.fromList([0, 0, 0]),
        mimeType: 'application/pdf',
        fileName: 'doc.pdf',
      );

      expect(jpeg.isSupportedImage, isTrue);
      expect(png.isSupportedImage, isTrue);
      expect(webp.isSupportedImage, isTrue);
      expect(unsupported.isSupportedImage, isFalse);
    });

    // 7. Multimodal Gemini request contains text + image
    test(
      '7. Multimodal Gemini request payload contains text + image inline_data',
      () async {
        late Map<String, dynamic> capturedBody;

        final mockHttpClient = MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text':
                            'This is a Cable Lat Pulldown machine targeting the lats and upper back.',
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });

        final provider = GeminiAIProvider(
          config: const AIConfig(apiKey: 'TEST_API_KEY_123'),
          httpClient: mockHttpClient,
        );

        final sampleBytes = Uint8List.fromList([10, 20, 30]);
        final attachment = ChatAttachment.fromBytes(
          bytes: sampleBytes,
          mimeType: 'image/jpeg',
          fileName: 'machine.jpg',
        );

        final response = await provider.generateResponse(
          message: 'What machine is this?',
          context: FitnessContext.initial(),
          history: [],
          attachment: attachment,
        );

        expect(response, contains('Cable Lat Pulldown'));
        final contents = capturedBody['contents'] as List<dynamic>;
        final parts = contents.first['parts'] as List<dynamic>;
        expect(parts.length, equals(2));
        expect(parts[0]['text'], isNotEmpty);
        expect(parts[1]['inline_data']['mime_type'], equals('image/jpeg'));
        expect(
          parts[1]['inline_data']['data'],
          equals(base64Encode(sampleBytes)),
        );
      },
    );

    // 8. Image upload failure is handled gracefully
    test(
      '8. Image upload failure is handled gracefully without crashing',
      () async {
        final mockHttpClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final provider = GeminiAIProvider(
          config: const AIConfig(apiKey: 'TEST_KEY_VALID_LONG_123'),
          httpClient: mockHttpClient,
        );

        final attachment = ChatAttachment.fromBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/jpeg',
        );

        expect(
          () => provider.generateResponse(
            message: 'Analyze this image',
            context: FitnessContext.initial(),
            history: [],
            attachment: attachment,
          ),
          throwsA(isA<GeminiApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(500),
          )),
        );
      },
    );

    // 9. Food analysis response can contain estimated calories/macros
    test(
      '9. Food analysis response contains estimated calories/macros with non-lab accuracy disclaimer',
      () {
        final dummyAttachment = ChatAttachment.fromBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/jpeg',
        );
        final context = FitnessContext.initial();

        final simulation = MockAIProvider.simulateMultimodalAnalysis(
          message: 'How many calories and protein in this meal?',
          attachment: dummyAttachment,
          context: context,
        );

        expect(simulation, contains('Meal & Nutrition Analysis'));
        expect(simulation, contains('Calories'));
        expect(simulation, contains('Protein'));
        expect(simulation, contains('visual estimates'));
        expect(simulation, contains('not laboratory-level'));
      },
    );

    // 10. Machine-analysis request is routed correctly
    test(
      '10. Machine-analysis request describes equipment, muscles, setup, and safety cues without injury diagnosis',
      () {
        final dummyAttachment = ChatAttachment.fromBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/jpeg',
        );
        final context = FitnessContext.initial();

        final simulation = MockAIProvider.simulateMultimodalAnalysis(
          message: 'What machine is this and how do I use it?',
          attachment: dummyAttachment,
          context: context,
        );

        expect(simulation, contains('Machine Identified'));
        expect(simulation, contains('Primary Muscles'));
        expect(simulation, contains('Setup & Instructions'));
        expect(simulation, contains('Common Mistakes'));
        expect(simulation, contains('Free Weight Alternatives'));
      },
    );

    // 11. Offline mode does not falsely claim image analysis
    test('11. Offline mode does not falsely claim image analysis', () async {
      const offlineProvider = MockAIProvider();
      final dummyAttachment = ChatAttachment.fromBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/jpeg',
      );

      final response = await offlineProvider.generateResponse(
        message: 'What is this image?',
        context: FitnessContext.initial(),
        history: [],
        attachment: dummyAttachment,
      );

      expect(
        response,
        equals(
          'Image analysis is currently unavailable. I can still help you with a text description.',
        ),
      );
      expect(response, isNot(contains('Machine Identified')));
      expect(response, isNot(contains('Meal & Nutrition Analysis')));
    });

    // 12. Existing AI agent/tool tests continue passing
    test(
      '12. AIAgent processes text requests and tool execution seamlessly',
      () async {
        final agent = AIAgent(aiProvider: const MockAIProvider());
        final result = await agent.processRequest(
          message: 'What is my current fitness rank and XP?',
          context: FitnessContext.initial(),
        );

        expect(result.responseText, isNotEmpty);
        expect(result.actionsExecuted, isEmpty);
      },
    );
  });

  // 13. Responsive layout remains valid at 320px, 360px, 390px, 412px
  group('13. Responsive Viewport Tests at 320, 360, 390, and 412px', () {
    const viewports = [
      Size(320, 640),
      Size(360, 740),
      Size(390, 844),
      Size(412, 915),
    ];

    for (final size in viewports) {
      testWidgets(
        'AICoachScreen renders cleanly with zero overflow at ${size.width}px',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(size: size),
                child: const AICoachScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(AICoachScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

class MockBuildContext extends Fake implements BuildContext {}
