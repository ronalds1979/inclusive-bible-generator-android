import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/generator.dart';
import 'package:app/main.dart';
import 'package:app/widgets/verse_preview_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('VerseTextShadow adapts shadow color for dark vs light text', () {
    final lightTextShadows = VerseTextShadow.soft.verseShadowsFor(Colors.white);
    final darkTextShadows = VerseTextShadow.soft.verseShadowsFor(Colors.black);

    expect(lightTextShadows.first.color, equals(Colors.black54));
    expect(darkTextShadows.first.color, equals(Colors.white70));

    final darkStrong = VerseTextShadow.strong.verseShadowsFor(Colors.black);
    expect(darkStrong.first.color, equals(Colors.white));
  });

  test('VerseTextStyleOptions serializes and sanitizes JSON safely', () {
    const original = VerseTextStyleOptions(
      fontFamily: VerseFontFamily.playfairDisplay,
      isBold: false,
      isItalic: true,
      shadow: VerseTextShadow.strong,
      textAlign: TextAlign.left,
      backdrop: VerseTextBackdrop.frosted,
      lineHeight: 1.55,
    );
    final restored = VerseTextStyleOptions.fromJson(original.toJson());
    expect(restored, equals(original));

    final sanitized = VerseTextStyleOptions.fromJson({
      'fontFamily': 'unknown_font',
      'lineHeight': 99.0,
      'textAlign': 'invalid',
    });
    expect(sanitized.fontFamily, equals(VerseFontFamily.sans));
    expect(sanitized.lineHeight, equals(2.0));
    expect(sanitized.textAlign, equals(TextAlign.center));
  });

  testWidgets(
    'VersePreviewCard updates font type, bold, italic, shadow, backdrop, line spacing, and alignment live',
    (WidgetTester tester) async {
      final generator = Generator()
        ..locales = {
          'en': {
            'preview_verse_placeholder': 'Preview Verse',
            'reference_placeholder': 'Reference',
          },
        };
      final verseController = TextEditingController(text: 'God is love.');
      final refController = TextEditingController(text: '1 John 4:8');
      final styleNotifier = ValueNotifier<VerseTextStyleOptions>(
        const VerseTextStyleOptions(),
      );
      addTearDown(() {
        verseController.dispose();
        refController.dispose();
        styleNotifier.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VersePreviewCard(
              repaintKey: GlobalKey(),
              aspectRatioStr: '1:1',
              customImagePath: null,
              selectedBackground: 'default.png',
              previewListenable: Listenable.merge([
                verseController,
                refController,
              ]),
              verseController: verseController,
              referenceController: refController,
              fontColor: Colors.white,
              fontSize: 32.0,
              yOffset: 0.0,
              textStyleListenable: styleNotifier,
              lang: 'en',
              generator: generator,
            ),
          ),
        ),
      );

      Text verseWidget() => tester.widget<Text>(find.text('God is love.'));
      Text refWidget() => tester.widget<Text>(find.text('1 John 4:8'));

      // Defaults: bold, normal, center, soft shadow
      expect(verseWidget().style?.fontWeight, equals(FontWeight.bold));
      expect(verseWidget().style?.fontStyle, equals(FontStyle.normal));
      expect(verseWidget().textAlign, equals(TextAlign.center));
      expect(verseWidget().style?.shadows?.length, equals(1));

      // Update to Serif, regular (not bold), italic, strong shadow, left-aligned
      styleNotifier.value = const VerseTextStyleOptions(
        fontFamily: VerseFontFamily.serif,
        isBold: false,
        isItalic: true,
        shadow: VerseTextShadow.strong,
        textAlign: TextAlign.left,
      );
      await tester.pump();

      expect(verseWidget().style?.fontFamily, equals('serif'));
      expect(verseWidget().style?.fontWeight, equals(FontWeight.w400));
      expect(verseWidget().style?.fontStyle, equals(FontStyle.italic));
      expect(verseWidget().textAlign, equals(TextAlign.left));
      expect(verseWidget().style?.shadows?.length, equals(2));
      expect(refWidget().textAlign, equals(TextAlign.left));
      expect(refWidget().style?.fontStyle, equals(FontStyle.italic));

      // Update to Monospace, no shadow, right-aligned
      styleNotifier.value = styleNotifier.value.copyWith(
        fontFamily: VerseFontFamily.monospace,
        shadow: VerseTextShadow.none,
        textAlign: TextAlign.right,
      );
      await tester.pump();

      expect(verseWidget().style?.fontFamily, equals('monospace'));
      expect(verseWidget().style?.shadows, isEmpty);
      expect(verseWidget().textAlign, equals(TextAlign.right));
      expect(refWidget().textAlign, equals(TextAlign.right));

      // Update to bundled PlayfairDisplay, Frosted Card backdrop, and 1.65x line spacing
      styleNotifier.value = styleNotifier.value.copyWith(
        fontFamily: VerseFontFamily.playfairDisplay,
        backdrop: VerseTextBackdrop.frosted,
        lineHeight: 1.65,
      );
      await tester.pump();

      expect(verseWidget().style?.fontFamily, equals('PlayfairDisplay'));
      expect(verseWidget().style?.height, equals(1.65));
      expect(find.byType(BackdropFilter), findsOneWidget);

      // Update to bundled Lora and High Contrast solid backdrop
      styleNotifier.value = styleNotifier.value.copyWith(
        fontFamily: VerseFontFamily.lora,
        backdrop: VerseTextBackdrop.solid,
      );
      await tester.pump();

      expect(verseWidget().style?.fontFamily, equals('Lora'));
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );

  testWidgets(
    'Style tab exposes font type, bold, italic, alignment, shadow, and backdrop controls',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Psalm 23:1');
      await tester.enterText(textFields.at(1), 'The Lord is my shepherd.');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      final italicChip = find.text('Italic');
      await tester.ensureVisible(italicChip);
      await tester.tap(italicChip);
      await tester.pumpAndSettle();

      final boldChip = find.text('Bold');
      await tester.ensureVisible(boldChip);
      await tester.tap(boldChip);
      await tester.pumpAndSettle();

      final rightAlign = find.text('Right');
      await tester.ensureVisible(rightAlign);
      await tester.tap(rightAlign);
      await tester.pumpAndSettle();

      final strongShadow = find.text('Strong');
      await tester.ensureVisible(strongShadow);
      await tester.tap(strongShadow);
      await tester.pumpAndSettle();

      final frostedChip = find.text('Frosted Card');
      await tester.ensureVisible(frostedChip);
      await tester.tap(frostedChip);
      await tester.pumpAndSettle();

      final montserratChip = find.text('Montserrat');
      await tester.ensureVisible(montserratChip);
      await tester.tap(montserratChip);
      await tester.pumpAndSettle();

      final Text previewVerse = tester.widget<Text>(
        find.descendant(
          of: find.byType(VersePreviewCard),
          matching: find.text('The Lord is my shepherd.'),
        ),
      );
      expect(previewVerse.style?.fontFamily, equals('Montserrat'));
      expect(previewVerse.style?.fontWeight, equals(FontWeight.w400));
      expect(previewVerse.style?.fontStyle, equals(FontStyle.italic));
      expect(previewVerse.textAlign, equals(TextAlign.right));
      expect(previewVerse.style?.shadows?.length, equals(2));
      expect(
        find.descendant(
          of: find.byType(VersePreviewCard),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Style tab Quick Style Presets and Reset Style work end-to-end',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Psalm 23:1');
      await tester.enterText(textFields.at(1), 'The Lord is my shepherd.');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      final presetChip = find.text('Frosted Devotional');
      await tester.ensureVisible(presetChip);
      await tester.tap(presetChip);
      await tester.pumpAndSettle();

      Text previewVerse() => tester.widget<Text>(
        find.descendant(
          of: find.byType(VersePreviewCard),
          matching: find.text('The Lord is my shepherd.'),
        ),
      );
      expect(previewVerse().style?.fontFamily, equals('Lora'));
      expect(previewVerse().style?.fontStyle, equals(FontStyle.italic));
      expect(previewVerse().style?.height, equals(1.40));
      final resetBtn = find.text('Reset Style');
      expect(resetBtn, findsOneWidget);
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(previewVerse().style?.fontWeight, equals(FontWeight.bold));
      expect(previewVerse().style?.fontStyle, equals(FontStyle.normal));
      expect(previewVerse().style?.height, equals(1.25));
      expect(find.text('Reset Style'), findsNothing);
    },
  );

  testWidgets(
    'Style tab accessibility: line spacing steppers and script legibility tip',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      const longVerse =
          'For God so loved the world, that he gave his one and only Son, '
          'that whoever believes in him should not perish, but have eternal life.';
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'John 3:16');
      await tester.enterText(textFields.at(1), longVerse);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      expect(find.text('Typography'), findsOneWidget);
      expect(find.text('Readability & Contrast'), findsOneWidget);

      // Select Script font on long verse -> legibility tip appears
      final scriptChip = find.text('Script');
      await tester.ensureVisible(scriptChip);
      await tester.tap(scriptChip);
      await tester.pumpAndSettle();

      final useLoraBtn = find.text('Use Lora');
      await tester.ensureVisible(useLoraBtn);
      expect(useLoraBtn, findsOneWidget);

      // Tap 1-tap fix -> switches to Lora and dismisses tip
      await tester.tap(useLoraBtn);
      await tester.pumpAndSettle();
      expect(find.text('Use Lora'), findsNothing);

      Text previewVerse() => tester.widget<Text>(
        find.descendant(
          of: find.byType(VersePreviewCard),
          matching: find.text(longVerse),
        ),
      );
      expect(previewVerse().style?.fontFamily, equals('Lora'));

      // Use accessible '+' stepper button to increase line spacing from 1.25 to 1.30
      final increaseBtn = find.byTooltip('Increase line spacing');
      await tester.ensureVisible(increaseBtn);
      expect(tester.getSize(increaseBtn).height, greaterThanOrEqualTo(48.0));
      await tester.tap(increaseBtn);
      await tester.pumpAndSettle();
      expect(previewVerse().style?.height, equals(1.30));

      // Use '-' stepper button to return to 1.25
      final decreaseBtn = find.byTooltip('Decrease line spacing');
      await tester.ensureVisible(decreaseBtn);
      await tester.tap(decreaseBtn);
      await tester.pumpAndSettle();
      expect(previewVerse().style?.height, equals(1.25));
    },
  );

  test('computeWcagContrastRatio matches W3C WCAG 2.1 formula', () {
    expect(
      VersePreviewCard.computeWcagContrastRatio(1.0, 0.0),
      closeTo(21.0, 0.01),
    );
    expect(
      VersePreviewCard.computeWcagContrastRatio(0.5, 0.5),
      closeTo(1.0, 0.01),
    );
  });

  testWidgets(
    'Dyslexia-Friendly preset, WCAG AAA badge, Full-Screen Preview, and High-Contrast Theme work end-to-end',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Open Full-Screen Preview and close it
      final expandBtn = find.byTooltip('Expand preview');
      expect(expandBtn, findsOneWidget);
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();
      expect(find.text('Full-Screen Preview'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // Enable High-Contrast App Theme in Advanced Features
      await tester.tap(find.byTooltip('Advanced Features'));
      await tester.pumpAndSettle();
      expect(find.text('High-Contrast App Theme'), findsOneWidget);
      await tester.tap(find.text('High-Contrast App Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Navigate to Style tab and select Dyslexia-Friendly preset
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();

      final dyslexiaChip = find.text('Dyslexia-Friendly');
      await tester.ensureVisible(dyslexiaChip);
      await tester.tap(dyslexiaChip);
      await tester.pumpAndSettle();

      // Dyslexia-Friendly preset enables High Contrast backdrop -> WCAG AAA badge appears
      expect(find.textContaining('WCAG AAA'), findsWidgets);

      // Test Font Size '+' stepper button
      final incFontBtn = find.byTooltip('Increase font size');
      await tester.ensureVisible(incFontBtn);
      await tester.tap(incFontBtn);
      await tester.pumpAndSettle();
      expect(find.text('Font Size: 24'), findsOneWidget);
    },
  );
}
