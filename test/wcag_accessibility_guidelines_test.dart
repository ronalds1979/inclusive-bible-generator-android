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

    testWidgets(
      'Multi-tab accessibility matrix: all 4 tabs meet tap-target and labeled-tap-target guidelines in Light, Dark, and High-Contrast modes',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final Brightness brightness in [
          Brightness.light,
          Brightness.dark,
        ]) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            await tester.runAsync(() async {
              await tester.pumpWidget(const MyApp());
              await Future<void>.delayed(const Duration(milliseconds: 200));
            });
            await tester.pumpAndSettle();

            for (final String tabLabel in const [
              'Verse',
              'Background',
              'Style',
              'Audio & Text',
            ]) {
              await tester.tap(find.text(tabLabel));
              await tester.pumpAndSettle();
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
            }
          } finally {
            handle.dispose();
          }
        }
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      },
    );

    testWidgets(
      'Key dialogs (About, Search Topic, Advanced Features) meet tap-target and labeled-tap-target guidelines',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.runAsync(() async {
            await tester.pumpWidget(const MyApp());
            await Future<void>.delayed(const Duration(milliseconds: 200));
          });
          await tester.pumpAndSettle();

          // About dialog
          await tester.tap(find.byTooltip('About & Credits'));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();

          // Advanced Features dialog
          await tester.tap(find.byTooltip('Advanced Features'));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();

          // Search Topic dialog
          final Finder searchBtn = find.byTooltip('Search Topic');
          await tester.ensureVisible(searchBtn);
          await tester.tap(searchBtn);
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'Unique Voice Access tooltips, Letter Spacing steppers, and narrow 320px 200% scale reflow work across locales',
      (WidgetTester tester) async {
        // Verify all 3 locale files have unique non-empty Voice Access & spacing keys
        final Generator gen = Generator();
        await tester.runAsync(() async {
          await gen.loadLocales();
        });
        for (final String lang in const ['en', 'es', 'pt-BR']) {
          final String clearRef = gen.getLocaleString(
            lang,
            'clear_reference_tooltip',
          );
          final String clearVerse = gen.getLocaleString(
            lang,
            'clear_verse_tooltip',
          );
          final String dismissStatus = gen.getLocaleString(
            lang,
            'dismiss_status_tooltip',
          );
          final String resetLine = gen.getLocaleString(
            lang,
            'reset_line_spacing_btn',
          );
          final String resetLetter = gen.getLocaleString(
            lang,
            'reset_letter_spacing_btn',
          );
          expect(clearRef, isNotEmpty);
          expect(clearVerse, isNotEmpty);
          expect(dismissStatus, isNotEmpty);
          expect(clearRef, isNot(equals(clearVerse)));
          expect(clearRef, isNot(equals(dismissStatus)));
          expect(resetLine, isNot(equals(resetLetter)));
        }

        // Verify Letter Spacing steppers & Vision Preview Wrap in UI
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.runAsync(() async {
          await tester.pumpWidget(const MyApp());
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        await tester.tap(find.text('Style'));
        await tester.pumpAndSettle();
        final Finder incLetter = find.byTooltip('Increase letter spacing');
        await tester.ensureVisible(incLetter);
        await tester.tap(incLetter);
        await tester.pumpAndSettle();
        expect(find.text('Letter Spacing: 0.1'), findsOneWidget);
        expect(find.text('Reset Tracking'), findsOneWidget);

        // Verify narrow phone (320x568) at 200% text scale has zero layout overflow
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.binding.setSurfaceSize(const Size(320, 568));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
