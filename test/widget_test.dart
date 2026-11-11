import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/getbible_api.dart';
import 'package:app/generator.dart';
import 'package:app/widgets/gemini_auth_dialog.dart';
import 'package:app/widgets/gemini_background_card.dart';
import 'package:app/widgets/verse_preview_card.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('GetBibleAPI.getVersions returns versions for pt, en, and es', () async {
    expect((await GetBibleAPI.getVersions(lang: "pt")).isNotEmpty, isTrue);
    expect((await GetBibleAPI.getVersions(lang: "en")).isNotEmpty, isTrue);
    expect((await GetBibleAPI.getVersions(lang: "es")).isNotEmpty, isTrue);
  });

  testWidgets('GeminiBackgroundCard enables generate button only when verse is non-empty', (
    WidgetTester tester,
  ) async {
    final generator = Generator();
    generator.locales = {
      "en": {
        "gemini_section_title": "AI Background (Gemini)",
        "gemini_connect_btn": "Connect Gemini",
        "gemini_connected_btn": "Gemini Connected",
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
  });

  testWidgets('GeminiAuthDialog saves and disconnects API key', (
    WidgetTester tester,
  ) async {
    final generator = Generator();
    generator.locales = {
      "en": {
        "gemini_dialog_title": "Connect Gemini Account (API Key)",
        "gemini_dialog_hint": "Enter your key",
        "gemini_api_key_label": "Gemini API Key",
        "gemini_show_key_tooltip": "Show API key",
        "gemini_hide_key_tooltip": "Hide API key",
        "gemini_save_btn": "Save Key",
        "gemini_disconnect_btn": "Disconnect",
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

    expect(find.byTooltip("Show API key"), findsOneWidget);
    await tester.tap(find.byTooltip("Show API key"));
    await tester.pump();
    expect(find.byTooltip("Hide API key"), findsOneWidget);

    await tester.enterText(find.byType(TextField), "AIzaSyTestKey123");
    await tester.tap(find.text("Save Key"));
    await tester.pumpAndSettle();

    expect(savedKey, "AIzaSyTestKey123");
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
}
