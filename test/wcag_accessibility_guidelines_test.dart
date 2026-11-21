import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/generator.dart';
import 'package:app/main.dart';
import 'package:app/services/contrast_sampler.dart';
import 'package:app/services/tts_service.dart';
import 'package:app/widgets/verse_preview_card.dart';

class _ControllableTtsService extends TtsService {
  Completer<void>? speakCompleter;
  double? lastSpeechRate;

  _ControllableTtsService();

  @override
  Future<void> speakPreview({
    required String verse,
    required String reference,
    required String lang,
    required String gender,
    double? speechRate,
    void Function(int start, int end)? onWordProgress,
  }) async {
    lastSpeechRate = speechRate;
    speakCompleter = Completer<void>();
    await speakCompleter!.future;
  }

  @override
  Future<void> stop() async {
    if (speakCompleter != null && !speakCompleter!.isCompleted) {
      speakCompleter!.complete();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('WCAG 2.1/2.2, EN 301 549 & EAA Accessibility Guidelines', () {
    testWidgets(
      'MaterialApp configures OS highContrastTheme, localizationsDelegates, and updates locale',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.binding.setSurfaceSize(const Size(412, 915));

        await tester.runAsync(() async {
          await tester.pumpWidget(const MyApp());
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        final MaterialApp app = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(app.highContrastTheme, isNotNull);
        expect(app.highContrastDarkTheme, isNotNull);
        expect(app.localizationsDelegates, isNotNull);
        expect(app.supportedLocales.length, greaterThanOrEqualTo(3));
        expect(app.locale, equals(const Locale('en')));
      },
    );

    testWidgets(
      'Meets Android tap target and labeled tap target guidelines on main screen',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.runAsync(() async {
            await tester.pumpWidget(const MyApp());
            await Future<void>.delayed(const Duration(milliseconds: 200));
          });
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'Reflows cleanly at 200% text scale and compact landscape orientation without overflow',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        // Compact phone in landscape (WCAG 1.3.4 / 1.4.10)
        await tester.binding.setSurfaceSize(const Size(720, 360));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.runAsync(() async {
          await tester.pumpWidget(const MyApp());
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Navigate across Style tab where alignment wraps into ChoiceChips at 200%
        await tester.tap(find.text('Style'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SegmentedButton<TextAlign>), findsNothing);
        expect(find.widgetWithText(ChoiceChip, 'Left'), findsOneWidget);
      },
    );

    testWidgets(
      'About dialog exposes EAA/EN 301 549 Accessibility Statement and Privacy Policy',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.binding.setSurfaceSize(const Size(412, 915));

        await tester.runAsync(() async {
          await tester.pumpWidget(const MyApp());
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('About & Credits'));
        await tester.pumpAndSettle();

        expect(find.text('Accessibility Statement'), findsOneWidget);
        expect(find.text('Privacy Policy'), findsOneWidget);
      },
    );

    testWidgets(
      'Persistent Stop Audio bar stays visible across tabs and speech rate is passed to TTS (WCAG 1.4.2)',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.binding.setSurfaceSize(const Size(412, 915));

        final _ControllableTtsService fakeTts = _ControllableTtsService();
        addTearDown(fakeTts.stop);

        await tester.runAsync(() async {
          await tester.pumpWidget(MyApp(ttsService: fakeTts));
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // Enter a verse so Listen Preview is enabled
        final Finder verseField = find.widgetWithText(TextField, 'Bible Verse');
        await tester.ensureVisible(verseField);
        await tester.enterText(verseField, 'The Lord is my shepherd.');
        await tester.pumpAndSettle();

        // Go to Audio & Text tab
        await tester.tap(find.text('Audio & Text'));
        await tester.pumpAndSettle();

        // Select 1.25x speech rate
        await tester.tap(find.widgetWithText(ChoiceChip, '1.25x'));
        await tester.pumpAndSettle();

        // Start audio preview
        final Finder listenBtn = find.text('Listen Preview');
        await tester.ensureVisible(listenBtn);
        await tester.tap(listenBtn);
        await tester.pump();

        expect(
          fakeTts.lastSpeechRate,
          closeTo(TtsService.documentarySpeechRate * 1.25, 0.001),
        );

        // Switch to Step 1 (Verse tab) — persistent Stop Audio banner must remain visible
        await tester.tap(find.text('Verse'));
        await tester.pump();

        expect(find.text('Audio preview is playing'), findsOneWidget);
        final Finder stopBtn = find.text('Stop Audio');
        expect(stopBtn, findsOneWidget);

        await tester.tap(stopBtn);
        await tester.pumpAndSettle();
        expect(find.text('Audio preview is playing'), findsNothing);
      },
    );

    test('ContrastSampler records real band RGB colors and percentiles', () {
      // 2x3 image: top=bright red, center=half white + half black, bottom=pure green
      final Uint8List rgba = Uint8List.fromList([
        // row 0 (top): 2 red pixels
        220, 30, 30, 255, 220, 30, 30, 255,
        // row 1 (center): 1 white + 1 black
        255, 255, 255, 255, 0, 0, 0, 255,
        // row 2 (bottom): 2 green pixels
        30, 180, 40, 255, 30, 180, 40, 255,
      ]);
      final BackgroundLuminanceProfile profile = ContrastSampler.profileFromRgba(
        rgbaBytes: rgba,
        width: 2,
        height: 3,
      );
      expect(profile.topColor, isNotNull);
      expect(profile.topColor!.r, greaterThan(0.8));
      expect(profile.bottomColor, isNotNull);
      expect(profile.bottomColor!.g, greaterThan(0.6));
      expect(profile.worstCaseLuminanceFor(0.0, 1.0), greaterThan(0.9));
      expect(profile.worstCaseLuminanceFor(0.0, 0.0), lessThan(0.1));
    });

    testWidgets(
      'VersePreviewCard supports keyboard arrow repositioning without dragging (WCAG 2.1.1 / 2.5.7)',
      (WidgetTester tester) async {
        final TextEditingController verseCtrl = TextEditingController(
          text: 'For God so loved the world.',
        );
        final TextEditingController refCtrl = TextEditingController(
          text: 'John 3:16',
        );
        final ValueNotifier<double> yOffset = ValueNotifier<double>(0.0);
        final Generator generator = Generator();
        addTearDown(() {
          verseCtrl.dispose();
          refCtrl.dispose();
          yOffset.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: VersePreviewCard(
                  repaintKey: GlobalKey(),
                  aspectRatioStr: '1:1',
                  customImagePath: null,
                  selectedBackground: 'default.png',
                  previewListenable: Listenable.merge([verseCtrl, refCtrl]),
                  verseController: verseCtrl,
                  referenceController: refCtrl,
                  fontColor: Colors.white,
                  fontSize: 22.0,
                  yOffset: 0.0,
                  yOffsetListenable: yOffset,
                  onYOffsetChanged: (v) => yOffset.value = v,
                  lang: 'en',
                  bibleLang: 'es',
                  generator: generator,
                ),
              ),
            ),
          ),
        );

        final FocusNode? focusNode = Focus.maybeOf(
          tester.element(find.byType(GestureDetector)),
        );
        focusNode?.requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(yOffset.value, equals(20.0));

        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(yOffset.value, equals(0.0));
      },
    );
  });
}
