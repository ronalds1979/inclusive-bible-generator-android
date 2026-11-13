import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/main.dart';
import 'package:app/getbible_api.dart';
import 'package:app/book_mapping.dart';
import 'package:app/generator.dart';
import 'package:app/widgets/gemini_auth_dialog.dart';
import 'package:app/widgets/gemini_background_card.dart';
import 'package:app/widgets/verse_preview_card.dart';

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

  testWidgets(
    'GeminiBackgroundCard enables generate button only when verse is non-empty',
    (WidgetTester tester) async {
      final generator = Generator();
      generator.locales = {
        "en": {
          "gemini_section_title": "AI Background (Gemini)",
          "gemini_connect_btn": "Sign in with Google",
          "gemini_connected_btn": "Google Connected",
          "gemini_style_label": "Visual Style:",
          "style_nature": "Serene Nature",
          "style_watercolor": "Watercolor",
          "style_cinematic": "Cinematic Light",
          "style_oil_painting": "Oil Painting",
          "style_minimalist": "Minimalist",
          "gemini_prompt_label": "Extra Scene Details (Optional)",
          "gemini_generate_bg_btn": "Generate Background with Gemini",
          "clear_btn": "Clear",
        },
      };

      final promptController = TextEditingController();
      final verseController = TextEditingController();
      bool generateTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeminiBackgroundCard(
              lang: "en",
              generator: generator,
              isConnected: false,
              selectedStyle: "style_nature",
              onStyleChanged: (_) {},
              promptController: promptController,
              verseController: verseController,
              isGenerating: false,
              onConnectPressed: () {},
              onGeneratePressed: () {
                generateTapped = true;
              },
            ),
          ),
        ),
      );

      final generateBtnFinder = find.widgetWithText(
        ElevatedButton,
        "Generate Background with Gemini",
      );
      expect(generateBtnFinder, findsOneWidget);

      // Initially disabled when verseController is empty
      await tester.tap(generateBtnFinder);
      await tester.pump();
      expect(generateTapped, isFalse);

      // Entering a verse enables the button
      verseController.text = "The Lord is my shepherd.";
      await tester.pump();

      await tester.tap(generateBtnFinder);
      await tester.pump();
      expect(generateTapped, isTrue);

      promptController.dispose();
      verseController.dispose();
    },
  );

  testWidgets('GeminiAuthDialog saves entered API key and triggers callback', (
    WidgetTester tester,
  ) async {
    final generator = Generator();
    generator.locales = {
      "en": {
        "gemini_dialog_title": "Connect Gemini AI",
        "gemini_dialog_hint": "Get a free Gemini API key",
        "gemini_open_aistudio_btn":
            "1. Get Free Gemini Key (Google AI Studio)",
        "gemini_paste_clipboard_btn": "Paste Key from Clipboard",
        "gemini_api_key_label": "Gemini API Key (AIza...)",
        "gemini_save_btn": "Save & Connect",
        "gemini_disconnect_btn": "Remove Key",
        "gemini_cancel_btn": "Cancel",
      },
    };

    String? savedKey;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeminiAuthDialog(
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

    await tester.enterText(
      find.byType(TextField),
      "mock-gemini-key-for-widget-test",
    );
    await tester.pump();
    await tester.tap(find.text("Save & Connect"));
    await tester.pumpAndSettle();

    expect(savedKey, equals("mock-gemini-key-for-widget-test"));
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

      expect(find.text("Español (España)"), findsOneWidget);
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
      await tester.tap(find.text("Português (Brasil)"));
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
}
