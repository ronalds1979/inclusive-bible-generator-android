import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/main.dart';
import 'package:app/services/gemini_handoff_service.dart';
import 'package:app/services/gemini_nano_service.dart';

class _FakeGeminiNanoService extends GeminiNanoService {
  final GeminiNanoAvailability availability;
  final GeminiNanoDescriptionResult descriptionResult;

  const _FakeGeminiNanoService({
    required this.availability,
    this.descriptionResult = const GeminiNanoDescriptionResult(
      description: 'Golden sunrise over calm ocean waves with soft clouds.',
    ),
  }) : super(isAndroidOverride: true);

  @override
  Future<GeminiNanoAvailability> checkAvailability() async => availability;

  @override
  Future<GeminiNanoDescriptionResult> describeImageBytes(
    Uint8List imageBytes,
  ) async => descriptionResult;

  @override
  Future<GeminiNanoDescriptionResult> describeImageFile(
    String imagePath,
  ) async => descriptionResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GeminiNanoService unit tests', () {
    test('GeminiNanoAvailability maps channel values and compatibility', () {
      expect(
        GeminiNanoAvailability.fromChannelValue('available').isCompatible,
        isTrue,
      );
      expect(
        GeminiNanoAvailability.fromChannelValue('downloadable').isCompatible,
        isTrue,
      );
      expect(
        GeminiNanoAvailability.fromChannelValue('downloading').isCompatible,
        isTrue,
      );
      expect(
        GeminiNanoAvailability.fromChannelValue('unavailable').isCompatible,
        isFalse,
      );
      expect(
        GeminiNanoAvailability.fromChannelValue(null).isCompatible,
        isFalse,
      );
    });

    test('returns unavailable on non-Android platforms', () async {
      const service = GeminiNanoService(isAndroidOverride: false);
      expect(
        await service.checkAvailability(),
        equals(GeminiNanoAvailability.unavailable),
      );
      final result = await service.describeImageBytes(Uint8List.fromList([1]));
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('unavailable'));
    });

    test('communicates with MethodChannel on Android', () async {
      const channel = MethodChannel('test/gemini_nano');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'checkAvailability') return 'downloadable';
            if (call.method == 'describeImage') {
              return 'A serene mountain landscape at dawn.';
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      const service = GeminiNanoService(
        channel: channel,
        isAndroidOverride: true,
      );
      expect(
        await service.checkAvailability(),
        equals(GeminiNanoAvailability.downloadable),
      );
      final result = await service.describeImageBytes(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
      );
      expect(result.isSuccess, isTrue);
      expect(result.description, equals('A serene mountain landscape at dawn.'));
    });
  });

  group('GeminiHandoffService unit tests', () {
    test('builds localized prompts for en, pt-BR, and es', () {
      const service = GeminiHandoffService();

      final enCaption = service.buildPrompt(
        lang: 'en',
        verse: 'The Lord is my shepherd.',
        reference: 'Psalm 23:1',
        aspectRatio: '1:1',
        task: GeminiHandoffTask.devotionalCaption,
      );
      expect(enCaption, contains('Psalm 23:1'));
      expect(enCaption, contains('CamelCase'));

      final ptBg = service.buildPrompt(
        lang: 'pt-BR',
        verse: 'O Senhor é o meu pastor.',
        reference: 'Salmos 23:1',
        aspectRatio: '9:16',
        task: GeminiHandoffTask.customBackground,
      );
      expect(ptBg, contains('9:16'));
      expect(ptBg, contains('Salmos 23:1'));

      final esCaption = service.buildPrompt(
        lang: 'es',
        verse: 'Jehová es mi pastor.',
        reference: 'Salmos 23:1',
        aspectRatio: '3:4',
        task: GeminiHandoffTask.devotionalCaption,
      );
      expect(esCaption, contains('Salmos 23:1'));
      expect(esCaption, contains('español'));
    });

    test('copyAndOpenGemini copies prompt and launches Gemini URL', () async {
      String? copied;
      Uri? launched;
      final service = GeminiHandoffService(
        clipboardHandler: (text) async => copied = text,
        launchHandler: (uri) async {
          launched = uri;
          return true;
        },
      );

      final ok = await service.copyAndOpenGemini(prompt: 'Test prompt');
      expect(ok, isTrue);
      expect(copied, equals('Test prompt'));
      expect(launched, equals(GeminiHandoffService.geminiAppUri));
    });
  });

  group('Advanced features widget tests', () {
    testWidgets(
      'hides Gemini Nano toggle on incompatible device and allows toggling Gemini App handoff',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        String? sharedPrompt;
        final handoff = GeminiHandoffService(
          shareHandler: (text, imagePath) async => sharedPrompt = text,
        );

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MyApp(
              geminiNanoService: const _FakeGeminiNanoService(
                availability: GeminiNanoAvailability.unavailable,
              ),
              geminiHandoffService: handoff,
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // Open Advanced Features dialog from AppBar
        await tester.tap(find.byTooltip('Advanced Features'));
        await tester.pumpAndSettle();

        expect(find.text('Advanced Features'), findsOneWidget);
        // Gemini Nano toggle MUST NOT be offered on incompatible devices
        expect(find.text('On-Device Alt-Text (Gemini Nano)'), findsNothing);
        // Continue in Gemini App toggle IS offered
        expect(find.text('Continue in Gemini App'), findsOneWidget);

        // Enable Continue in Gemini App
        await tester.tap(find.text('Continue in Gemini App'));
        await tester.pumpAndSettle();

        // Close dialog
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Enter verse & reference so Step 4 shows live Alt-Text & Gemini Handoff
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'John 3:16');
        await tester.enterText(textFields.at(1), 'For God so loved the world.');
        await tester.pumpAndSettle();

        // Navigate to Step 4: Audio & Text
        await tester.tap(find.text('Audio & Text'));
        await tester.pumpAndSettle();

        final shareBtn = find.text('Share to Gemini');
        await tester.ensureVisible(shareBtn);
        expect(shareBtn, findsOneWidget);
        expect(find.text('Describe Image (Gemini Nano)'), findsNothing);

        await tester.tap(shareBtn);
        await tester.pumpAndSettle();
        expect(sharedPrompt, contains('John 3:16'));
      },
    );

    testWidgets(
      'offers Gemini Nano toggle on compatible device and updates live Alt-Text',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MyApp(
              geminiNanoService: _FakeGeminiNanoService(
                availability: GeminiNanoAvailability.available,
                descriptionResult: GeminiNanoDescriptionResult(
                  description: 'Warm golden sunrise over misty hills.',
                ),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // Open Advanced Features dialog
        await tester.tap(find.byTooltip('Advanced Features'));
        await tester.pumpAndSettle();

        // Gemini Nano toggle IS offered on compatible devices
        expect(find.text('On-Device Alt-Text (Gemini Nano)'), findsOneWidget);
        await tester.tap(find.text('On-Device Alt-Text (Gemini Nano)'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        // Populate verse & reference
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'Psalm 23:1');
        await tester.enterText(textFields.at(1), 'The Lord is my shepherd.');
        await tester.pumpAndSettle();

        // Go to Step 4: Audio & Text
        await tester.tap(find.text('Audio & Text'));
        await tester.pumpAndSettle();

        final describeBtn = find.text('Describe Image (Gemini Nano)');
        await tester.ensureVisible(describeBtn);
        expect(describeBtn, findsOneWidget);

        await tester.runAsync(() async {
          await tester.tap(describeBtn);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        // Live Alt-Text & editable description now use the on-device Gemini Nano description!
        expect(
          find.textContaining('Warm golden sunrise over misty hills.'),
          findsWidgets,
        );
      },
    );
  });
}
