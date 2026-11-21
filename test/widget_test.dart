import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/main.dart';
import 'package:app/getbible_api.dart';
import 'package:app/book_mapping.dart';
import 'package:app/generator.dart';
import 'package:app/widgets/verse_preview_card.dart';
import 'package:app/widgets/youversion_auth_dialog.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('GetBibleAPI.getVersions returns rich versions for pt, en, and es', () async {
    final ptVersions = await GetBibleAPI.getVersions(lang: "pt");
    final enVersions = await GetBibleAPI.getVersions(lang: "en");
    final esVersions = await GetBibleAPI.getVersions(lang: "es");

    expect(ptVersions.length, greaterThanOrEqualTo(10));
    expect(enVersions.length, greaterThanOrEqualTo(10));
    expect(esVersions.length, greaterThanOrEqualTo(8));
    expect(enVersions.first["name"], equals("World English Bible"));
  });

  test('GetBibleAPI.cleanVerseText strips footnotes, Strong numbers, and HTML tags', () {
    const raw =
        'Porque Deus amou ao mundo<S>2889</S> de tal maneira<sup>[a]</sup> que deu o seu Filho<br>unigênito.';
    expect(
      GetBibleAPI.cleanVerseText(raw),
      equals('Porque Deus amou ao mundo de tal maneira que deu o seu Filho unigênito.'),
    );
  });

  test('USFM conversion and localized resolution work across languages', () {
    expect(
      buildUsfmReference(bookNr: 43, chapter: '3', startVerse: '16'),
      equals('JHN.3.16'),
    );
    expect(
      buildUsfmReference(bookNr: 19, chapter: '23', startVerse: '1', endVerse: '6'),
      equals('PSA.23.1-6'),
    );
    expect(
      GetBibleAPI.resolveUsfmToLocalizedReference('JHN.3.16', lang: 'pt')?['reference'],
      equals('João 3:16'),
    );
    expect(
      GetBibleAPI.resolveUsfmToLocalizedReference('PSA.23.1-4', lang: 'es')?['reference'],
      equals('Salmos 23:1-4'),
    );
    expect(getChapterCountForBook('Salmos', 'pt'), equals(150));
    expect(getVerseCountForChapter('Salmos', 119, 'pt'), equals(176));
    expect(getVerseCountForChapter('John', 3, 'en'), equals(36));
  });

  testWidgets('VersePreviewCard updates live when controllers change', (
    WidgetTester tester,
  ) async {
    final generator = Generator();
    generator.locales = {
      "en": {
        "preview_verse_placeholder": "Preview Verse",
        "reference_placeholder": "Reference",
      },
    };

    final verseController = TextEditingController();
    final referenceController = TextEditingController();
    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VersePreviewCard(
            repaintKey: repaintKey,
            aspectRatioStr: "1:1",
            customImagePath: null,
            selectedBackground: "default.png",
            previewListenable: Listenable.merge([
              verseController,
              referenceController,
            ]),
            verseController: verseController,
            referenceController: referenceController,
            fontColor: Colors.white,
            fontSize: 60.0,
            yOffset: 0.0,
            lang: "en",
            generator: generator,
          ),
        ),
      ),
    );

    expect(find.text("Preview Verse"), findsOneWidget);
    expect(find.text("Reference"), findsOneWidget);

    verseController.text = "God is love.";
    referenceController.text = "1 John 4:8";
    await tester.pump();

    expect(find.text("God is love."), findsOneWidget);
    expect(find.text("1 John 4:8"), findsOneWidget);

    verseController.dispose();
    referenceController.dispose();
  });

  test('resolveAppLanguageForLocale maps device locales with English fallback', () {
    expect(
      resolveAppLanguageForLocale(const Locale('pt', 'BR')),
      equals('Português (Brasil)'),
    );
    expect(
      resolveAppLanguageForLocale(const Locale('pt')),
      equals('Português (Brasil)'),
    );
    expect(
      resolveAppLanguageForLocale(const Locale('es', 'ES')),
      equals('Español (España)'),
    );
    expect(
      resolveAppLanguageForLocale(const Locale('en', 'US')),
      equals('English (US/UK)'),
    );
    expect(
      resolveAppLanguageForLocale(const Locale('fr', 'FR')),
      equals('English (US/UK)'),
    );
  });

  testWidgets(
    'MyApp recognizes Spanish device locale on startup',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('es', 'ES');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text("ES-ES"), findsOneWidget);
      expect(find.text("Buscar Versículo"), findsOneWidget);
    },
  );

  testWidgets(
    'Full MyApp end-to-end initialization, 4-tab navigation, language switch, and form interaction',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('pt', 'BR');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        // Allow async asset bundle and initialization to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Verify Portuguese default UI loaded along with NavigationBar
      expect(find.text("Inclusive Bible Generator"), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Switch language to English (US/UK)
      await tester.tap(find.text("PT-BR"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("English (US/UK)").last);
      await tester.pumpAndSettle();

      expect(find.text("Fetch Verse"), findsOneWidget);
      expect(find.text("World English Bible"), findsOneWidget);

      // Verify Chapter and Verse dropdowns are rendered
      expect(find.byType(DropdownButton<int>), findsNWidgets(2));

      // Enter reference and verse in the form
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), "John 3:16");
      await tester.enterText(textFields.at(1), "For God so loved the world.");
      await tester.pump();

      expect(find.text("John 3:16"), findsWidgets);
      expect(find.text("For God so loved the world."), findsWidgets);

      // Verify guided step-by-step navigation (Verse -> Background -> Style -> Back)
      expect(find.text("Step 1 of 4: Verse"), findsOneWidget);
      await tester.ensureVisible(find.text("Next: Background"));
      await tester.tap(find.text("Next: Background"));
      await tester.pumpAndSettle();

      expect(find.text("Step 2 of 4: Background"), findsOneWidget);
      await tester.ensureVisible(find.text("Next: Style"));
      await tester.tap(find.text("Next: Style"));
      await tester.pumpAndSettle();

      expect(find.text("Step 3 of 4: Style"), findsOneWidget);
      await tester.ensureVisible(find.text("Back").last);
      await tester.tap(find.text("Back").last);
      await tester.pumpAndSettle();

      expect(find.text("Step 2 of 4: Background"), findsOneWidget);
    },
  );

  testWidgets('Accessibility guidelines: semantics, tap targets, and audio transcript', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Verify Android tap target (>=48x48dp) and labeled tap target guidelines
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      // Verify layout does not overflow or clip under large system font scaling
      tester.platformDispatcher.textScaleFactorTestValue = 1.15;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();

      // Enter verse & reference and verify live preview Semantics label
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), "Psalm 23:1");
      await tester.enterText(textFields.at(1), "The Lord is my shepherd.");
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          RegExp(r'Verse card preview \(1:1\):.*The Lord is my shepherd\.'),
        ),
        findsOneWidget,
      );

      // Navigate to Style tab and verify default font size is 22
      await tester.tap(find.text("Style"));
      await tester.pumpAndSettle();
      expect(find.text("Font Size: 22"), findsOneWidget);

      // Navigate to Audio & Text tab and verify Audio Transcript is shown
      await tester.tap(find.text("Audio & Text"));
      await tester.pumpAndSettle();

      expect(find.text("Audio Transcript"), findsOneWidget);
      expect(
        find.text("Psalm, chapter 23, verse 1... The Lord is my shepherd."),
        findsOneWidget,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Remembers preferred Bible version per language when switching languages', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('pt', 'BR');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.runAsync(() async {
      await tester.pumpWidget(const MyApp());
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Select a non-default Portuguese Bible version
    await tester.tap(find.text("Nova Almeida Atualizada (NAA)"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Almeida Revista e Atualizada (ARA)").last);
    await tester.pumpAndSettle();
    expect(find.text("Almeida Revista e Atualizada (ARA)"), findsOneWidget);

    // Switch Bible language to English
    await tester.tap(find.text("English"));
    await tester.pumpAndSettle();
    expect(find.text("World English Bible"), findsOneWidget);

    // Switch back to Portuguese and verify ARA is remembered
    await tester.tap(find.text("Português"));
    await tester.pumpAndSettle();
    expect(find.text("Almeida Revista e Atualizada (ARA)"), findsOneWidget);
  });

  testWidgets('VersePreviewCard prevents overlap between long verse text and reference', (
    WidgetTester tester,
  ) async {
    const String longVerse =
        "Because God so loved the world that he gave his one and only Son, "
        "that whoever believes in him shall not perish but have eternal life. "
        "For God did not send his Son into the world to condemn the world, "
        "but to save the world through him.";
    const String reference = "John 3:16-17";
    final verseController = TextEditingController(text: longVerse);
    final referenceController = TextEditingController(text: reference);
    final listenable = Listenable.merge([verseController, referenceController]);
    final generator = Generator();
    addTearDown(() {
      verseController.dispose();
      referenceController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: VersePreviewCard(
              repaintKey: GlobalKey(),
              aspectRatioStr: "9:16",
              customImagePath: null,
              selectedBackground: "bg1.jpg",
              previewListenable: listenable,
              verseController: verseController,
              referenceController: referenceController,
              fontColor: Colors.white,
              fontSize: 48,
              yOffset: 0,
              lang: "en",
              generator: generator,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect verseRect = tester.getRect(find.text(longVerse));
    final Rect referenceRect = tester.getRect(find.text(reference));

    expect(verseRect.bottom, lessThan(referenceRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('YouVersionAuthDialog provides toggle tooltip and saves trimmed key', (
    WidgetTester tester,
  ) async {
    final generator = Generator();
    generator.locales = {
      "en": {
        "yv_dialog_title": "YouVersion Platform API",
        "yv_dialog_hint": "Enter your key",
        "yv_open_portal_btn": "Open Portal",
        "gemini_paste_clipboard_btn": "Paste Key",
        "yv_api_key_label": "YouVersion App Key",
        "show_api_key_tooltip": "Show API key",
        "hide_api_key_tooltip": "Hide API key",
        "gemini_save_btn": "Save & Connect",
        "gemini_cancel_btn": "Close",
      },
    };
    String? savedKey;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YouVersionAuthDialog(
            lang: "en",
            generator: generator,
            initialApiKey: null,
            onSave: (key) async {
              savedKey = key;
            },
            onDisconnect: () async {},
          ),
        ),
      ),
    );

    expect(find.byTooltip("Show API key"), findsOneWidget);
    await tester.tap(find.byTooltip("Show API key"));
    await tester.pump();
    expect(find.byTooltip("Hide API key"), findsOneWidget);

    await tester.enterText(find.byType(TextField), "  yv-test-key-123  ");
    await tester.pump();
    await tester.tap(find.text("Save & Connect"));
    await tester.pumpAndSettle();

    expect(savedKey, equals("yv-test-key-123"));
  });

  testWidgets('VersePreviewCard double-tap resets vertical offset to zero', (
    WidgetTester tester,
  ) async {
    final generator = Generator();
    generator.locales = {
      "en": {
        "preview_verse_placeholder": "Preview Verse",
        "reference_placeholder": "Reference",
      },
    };
    final verseController = TextEditingController(text: "God is love.");
    final referenceController = TextEditingController(text: "1 John 4:8");
    double offset = 120.0;
    addTearDown(() {
      verseController.dispose();
      referenceController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VersePreviewCard(
            repaintKey: GlobalKey(),
            aspectRatioStr: "1:1",
            customImagePath: null,
            selectedBackground: "default.png",
            previewListenable: Listenable.merge([
              verseController,
              referenceController,
            ]),
            verseController: verseController,
            referenceController: referenceController,
            fontColor: Colors.white,
            fontSize: 40,
            yOffset: offset,
            onYOffsetChanged: (updated) {
              offset = updated;
            },
            lang: "en",
            generator: generator,
          ),
        ),
      ),
    );

    final Finder cardFinder = find.byType(VersePreviewCard);
    await tester.tap(cardFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cardFinder);
    await tester.pumpAndSettle();

    expect(offset, equals(0.0));
  });

  testWidgets('Audio & Text tab shows live Alt-Text & Caption and Style tab resets font size', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.binding.setSurfaceSize(const Size(412, 915));

    await tester.runAsync(() async {
      await tester.pumpWidget(const MyApp());
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), "John 3:16");
    await tester.enterText(textFields.at(1), "For God so loved the world.");
    await tester.pump();

    // Navigate to Style tab, change font size slider, and verify Reset button restores 22
    await tester.tap(find.text("Style"));
    await tester.pumpAndSettle();
    expect(find.text("Font Size: 22"), findsOneWidget);

    final sliderFinder = find.byType(Slider).first;
    await tester.ensureVisible(sliderFinder);
    await tester.pumpAndSettle();
    await tester.drag(sliderFinder, const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(find.text("Reset"), findsOneWidget);

    await tester.ensureVisible(find.text("Reset"));
    await tester.tap(find.text("Reset"));
    await tester.pumpAndSettle();
    expect(find.text("Font Size: 22"), findsOneWidget);

    // Navigate to Audio & Text tab and verify live Alt-Text & Caption are generated immediately
    await tester.tap(find.text("Audio & Text"));
    await tester.pumpAndSettle();

    expect(find.text("Copy Alt-Text"), findsOneWidget);
    expect(find.text("Copy Caption"), findsOneWidget);
    expect(find.textContaining("For God so loved the world."), findsWidgets);
  });

  testWidgets(
    'VersePreviewCard yOffsetListenable updates Transform without rebuilding Text',
    (WidgetTester tester) async {
      final generator = Generator();
      generator.locales = {
        "en": {
          "preview_verse_placeholder": "Preview Verse",
          "reference_placeholder": "Reference",
        },
      };
      final verseController = TextEditingController(text: "God is love.");
      final referenceController = TextEditingController(text: "1 John 4:8");
      final yOffsetNotifier = ValueNotifier<double>(0.0);
      addTearDown(() {
        verseController.dispose();
        referenceController.dispose();
        yOffsetNotifier.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VersePreviewCard(
              repaintKey: GlobalKey(),
              aspectRatioStr: "1:1",
              customImagePath: null,
              selectedBackground: "default.png",
              previewListenable: Listenable.merge([
                verseController,
                referenceController,
              ]),
              verseController: verseController,
              referenceController: referenceController,
              fontColor: Colors.white,
              fontSize: 40,
              yOffset: 0.0,
              yOffsetListenable: yOffsetNotifier,
              lang: "en",
              generator: generator,
            ),
          ),
        ),
      );

      final Text verseWidgetBefore = tester.widget<Text>(
        find.text("God is love."),
      );
      final Finder transformFinder = find.ancestor(
        of: find.text("God is love."),
        matching: find.byType(Transform),
      );
      expect(
        tester.widget<Transform>(transformFinder).transform.getTranslation().y,
        equals(0.0),
      );

      yOffsetNotifier.value = 75.0;
      await tester.pump();

      final Text verseWidgetAfter = tester.widget<Text>(
        find.text("God is love."),
      );
      expect(identical(verseWidgetBefore, verseWidgetAfter), isTrue);
      expect(
        tester.widget<Transform>(transformFinder).transform.getTranslation().y,
        equals(75.0),
      );
    },
  );

  testWidgets(
    'Background tab surfaces low-contrast warning and Auto-Dim adjusts dim to 35%',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await tester.binding.setSurfaceSize(const Size(412, 915));

      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text("Background"));
      await tester.pumpAndSettle();

      expect(find.text("Background Dim (Contrast): 15%"), findsOneWidget);
      final Finder autoDimFinder = find.widgetWithText(TextButton, "Auto-Dim");
      expect(autoDimFinder, findsOneWidget);

      await tester.ensureVisible(autoDimFinder);
      await tester.tap(autoDimFinder);
      await tester.pumpAndSettle();

      expect(find.text("Background Dim (Contrast): 35%"), findsOneWidget);
      expect(find.widgetWithText(TextButton, "Auto-Dim"), findsNothing);
    },
  );

  testWidgets(
    'VersePreviewCard font size never decreases when slider exceeds 50',
    (WidgetTester tester) async {
      const String verse =
          'Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito, '
          'para que todo aquele que nele crê não pereça, mas tenha a vida eterna.';
      const String reference = 'João 3:16';
      final verseController = TextEditingController(text: verse);
      final referenceController = TextEditingController(text: reference);
      final fontSizeNotifier = ValueNotifier<double>(22.0);
      final generator = Generator();
      addTearDown(() {
        verseController.dispose();
        referenceController.dispose();
        fontSizeNotifier.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: VersePreviewCard(
                repaintKey: GlobalKey(),
                aspectRatioStr: '1:1',
                customImagePath: null,
                selectedBackground: 'default.png',
                previewListenable: Listenable.merge([
                  verseController,
                  referenceController,
                ]),
                verseController: verseController,
                referenceController: referenceController,
                fontColor: Colors.white,
                fontSize: 22.0,
                fontSizeListenable: fontSizeNotifier,
                yOffset: 0.0,
                lang: 'pt-BR',
                generator: generator,
              ),
            ),
          ),
        ),
      );

      double previousRenderedFontSize = 0.0;
      for (final double sliderValue in [22.0, 40.0, 50.0, 70.0, 95.0, 120.0]) {
        fontSizeNotifier.value = sliderValue;
        await tester.pump();

        final Text verseWidget = tester.widget<Text>(find.text(verse));
        final double renderedFontSize = verseWidget.style!.fontSize!;
        final Rect verseRect = tester.getRect(find.text(verse));
        final Rect refRect = tester.getRect(find.text(reference));

        expect(
          renderedFontSize,
          greaterThanOrEqualTo(previousRenderedFontSize),
          reason:
              'Rendered font size should never shrink at slider=$sliderValue',
        );
        expect(verseRect.bottom, lessThan(refRect.top));
        expect(tester.takeException(), isNull);
        previousRenderedFontSize = renderedFontSize;
      }
    },
  );
}
