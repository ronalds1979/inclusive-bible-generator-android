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
}
