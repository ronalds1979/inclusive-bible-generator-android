import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/main.dart';
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

  testWidgets('GeminiAuthDialog triggers Google Sign-In and Sign-Out callbacks', (
    WidgetTester tester,
  ) async {
    final generator = Generator();
    generator.locales = {
      "en": {
        "gemini_dialog_title": "Google Account (Gemini)",
        "gemini_dialog_hint": "Sign in with your Google Account",
        "gemini_signed_in_as": "Signed in as: {email}",
        "gemini_sign_in_btn": "Sign in with Google",
        "gemini_disconnect_btn": "Sign Out",
        "gemini_cancel_btn": "Close",
      },
    };

    bool signInCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeminiAuthDialog(
            lang: "en",
            generator: generator,
            userEmail: null,
            isSignedIn: false,
            onSignIn: () async {
              signInCalled = true;
              return true;
            },
            onSignOut: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text("Sign in with Google"));
    await tester.pumpAndSettle();

    expect(signInCalled, isTrue);
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

  testWidgets(
    'Full MyApp end-to-end initialization, language switch, and form interaction',
    (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(const MyApp());
        // Allow async asset bundle and initialization to complete
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Verify Portuguese default UI loaded along with default.png from AssetManifest
      expect(find.text("Inclusive Bible Generator"), findsOneWidget);
      expect(find.text("default.png"), findsOneWidget);

      // Switch language to English (US/UK)
      await tester.tap(find.text("Português (Brasil)"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("English (US/UK)").last);
      await tester.pumpAndSettle();

      expect(find.text("Fetch Verse"), findsOneWidget);
      expect(find.text("World English Bible"), findsOneWidget);

      // Enter reference and verse in the form
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), "John 3:16");
      await tester.enterText(textFields.at(1), "For God so loved the world.");
      await tester.pump();

      expect(find.text("John 3:16"), findsWidgets);
      expect(find.text("For God so loved the world."), findsWidgets);
    },
  );
}
