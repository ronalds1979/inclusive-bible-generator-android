import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/main.dart';
import 'package:app/services/contrast_sampler.dart';
import 'package:app/services/voice_verse_service.dart';
import 'package:app/widgets/vision_simulation.dart';

class _FakeVoiceVerseService extends VoiceVerseService {
  final bool available;
  final String? spokenResult;

  const _FakeVoiceVerseService({
    required this.available,
    this.spokenResult,
  }) : super(isAndroidOverride: true);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> listenForVerse({
    required String locale,
    required String prompt,
  }) async => spokenResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('VisionSimulatorFilter tests', () {
    testWidgets('applies ColorFiltered for CVD modes and ImageFiltered for Low Vision', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VisionSimulatorFilter(
            mode: VisionSimulationMode.protanopia,
            child: Text('Sample'),
          ),
        ),
      );
      expect(find.byType(ColorFiltered), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: VisionSimulatorFilter(
            mode: VisionSimulationMode.lowVisionBlur,
            child: Text('Sample'),
          ),
        ),
      );
      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });

  group('ContrastSampler tests', () {
    test('samples top/center/bottom luminance and picks highest-contrast placement', () {
      // 1px wide x 3px tall image: top=white, center=mid-gray, bottom=black
      final rgba = Uint8List.fromList([
        255, 255, 255, 255, // top: luminance ~1.0
        128, 128, 128, 255, // center: luminance ~0.21
        0, 0, 0, 255, // bottom: luminance 0.0
      ]);
      final profile = ContrastSampler.profileFromRgba(
        rgbaBytes: rgba,
        width: 1,
        height: 3,
      );
      expect(profile.top, greaterThan(0.95));
      expect(profile.bottom, lessThan(0.05));

      final bestForWhite = profile.bestPlacementFor(
        fontColor: Colors.white,
        dim: 0.0,
      );
      expect(bestForWhite.yOffset, equals(110.0));
      expect(bestForWhite.ratio, closeTo(21.0, 0.1));

      final bestForBlack = profile.bestPlacementFor(
        fontColor: Colors.black,
        dim: 0.0,
      );
      expect(bestForBlack.yOffset, equals(-110.0));
      expect(bestForBlack.ratio, closeTo(21.0, 0.1));
    });
  });

  group('VoiceVerseService parser tests', () {
    test('normalizes spoken references across en, pt-BR, and es', () {
      expect(
        VoiceVerseService.normalizeSpokenReference('John chapter 3 verse 16'),
        equals('John 3:16'),
      );
      expect(
        VoiceVerseService.normalizeSpokenReference('Salmos 23 versículo 1 ao 4'),
        equals('Salmos 23:1-4'),
      );
      expect(
        VoiceVerseService.normalizeSpokenReference('Juan capítulo 3 versículo 16'),
        equals('Juan 3:16'),
      );
      expect(
        VoiceVerseService.normalizeSpokenReference('First Corinthians 13 verses 4 to 7'),
        equals('1 Corinthians 13:4-7'),
      );
    });
  });

  group('End-to-end accessibility award features widget tests', () {
    testWidgets(
      'Vision simulator, voice-to-verse button, editable Alt-Text, and Inclusivity Scorecard work',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MyApp(
              voiceVerseService: _FakeVoiceVerseService(
                available: true,
                spokenResult: 'Psalm chapter 23 verse 1',
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // 1. Voice-to-Verse button is visible, populates reference, and syncs Book/Chapter/Verse selectors
        final voiceBtn = find.byTooltip('Speak Bible verse reference');
        expect(voiceBtn, findsOneWidget);
        await tester.ensureVisible(voiceBtn);
        await tester.runAsync(() async {
          await tester.tap(voiceBtn);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('Psalm 23:1'), findsWidgets);
        expect(find.text('Psalms'), findsOneWidget);
        expect(find.text('23'), findsOneWidget);

        // 2. Full-Screen Preview uses eye icon and includes Vision Simulator chips
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
        await tester.tap(find.byTooltip('Expand preview'));
        await tester.pumpAndSettle();
        expect(find.text('Vision Preview'), findsOneWidget);
        await tester.tap(find.text('Protanopia'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        // Ensure verse & reference are filled, enable Dyslexia-Friendly preset for WCAG AAA
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'Psalm 23:1');
        await tester.enterText(textFields.at(1), 'The Lord is my shepherd.');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Style'));
        await tester.pumpAndSettle();
        final dyslexiaChip = find.text('Dyslexia-Friendly');
        await tester.ensureVisible(dyslexiaChip);
        await tester.tap(dyslexiaChip);
        await tester.pumpAndSettle();

        // 3. Step 4: Editable Alt-Text description + Inclusivity Readiness Scorecard (4/4)
        await tester.tap(find.text('Audio & Text'));
        await tester.pumpAndSettle();

        final descField = find.widgetWithText(
          TextField,
          'Image Description (for Alt-Text)',
        );
        await tester.ensureVisible(descField);
        await tester.enterText(descField, 'Sunlit valley with gentle hills.');
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Sunlit valley with gentle hills.'),
          findsWidgets,
        );
        final scorecard = find.text('Inclusivity Readiness (4/4)');
        await tester.ensureVisible(scorecard);
        expect(scorecard, findsOneWidget);
      },
    );

    testWidgets(
      'YouVersion key icon is hidden from UI and About dialog credits YouVersion Platform',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        await tester.runAsync(() async {
          await tester.pumpWidget(const MyApp());
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // Key icon must not be shown to end users
        expect(find.byIcon(Icons.vpn_key_outlined), findsNothing);
        expect(find.byTooltip('YouVersion Key'), findsNothing);

        // About & Credits dialog credits YouVersion Platform
        final aboutBtn = find.byTooltip('About & Credits');
        expect(aboutBtn, findsOneWidget);
        await tester.tap(aboutBtn);
        await tester.pumpAndSettle();

        expect(find.text('About Inclusive Bible Generator'), findsOneWidget);
        expect(find.text('Powered by YouVersion Platform'), findsOneWidget);
        expect(find.text('Visit YouVersion Platform'), findsOneWidget);
      },
    );

    testWidgets(
      'Voice-to-verse syncs Book, Chapter, and Verse selectors above with spoken reference',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MyApp(
              voiceVerseService: _FakeVoiceVerseService(
                available: true,
                spokenResult: 'John chapter 3 verse 16',
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // Initially defaults to Psalms, not John
        expect(find.text('Psalms'), findsOneWidget);
        expect(find.text('John'), findsNothing);

        final voiceBtn = find.byTooltip('Speak Bible verse reference');
        await tester.ensureVisible(voiceBtn);
        await tester.runAsync(() async {
          await tester.tap(voiceBtn);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        // Book, Chapter, and Verse selectors above are now synced to John 3:16
        expect(find.text('John'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('16'), findsOneWidget);
        expect(find.textContaining('John 3:16'), findsWidgets);
      },
    );
  });
}
