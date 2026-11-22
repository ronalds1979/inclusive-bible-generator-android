import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/generator.dart';
import 'package:app/getbible_api.dart';
import 'package:app/main.dart';
import 'package:app/services/contrast_sampler.dart';
import 'package:app/services/image_validation.dart';
import 'package:app/services/temp_file_cleanup.dart';
import 'package:app/services/voice_verse_service.dart';
import 'package:app/widgets/youversion_auth_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test(
    'GetBibleAPI does not crash on invalid version fetch (simulating error)',
    () async {
      final result = await GetBibleAPI.getVersions(
        lang: "invalid_format_that_will_throw",
      );
      expect(result, []);
    },
  );

  test(
    'GetBibleAPI does not crash on invalid verse range (start > end)',
    () async {
      final result = await GetBibleAPI.getPassage(
        "web",
        "Genesis 1:5-3",
        lang: "en",
      );
      expect(result, isNull);
    },
  );

  test(
    'GetBibleAPI does not embed a hardcoded default YouVersion API key',
    () {
      expect(GetBibleAPI.defaultYouVersionApiKey, isEmpty);
    },
  );

  test(
    'GetBibleAPI persists and clears YouVersion key using FlutterSecureStorage',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const testYvKey = 'yv-test-secure-key-1234567890';

      await GetBibleAPI.saveYouVersionApiKey(testYvKey);
      expect(await GetBibleAPI.loadYouVersionApiKey(), testYvKey);

      await GetBibleAPI.saveYouVersionApiKey('');
      expect(await GetBibleAPI.loadYouVersionApiKey(), isNull);
      expect(GetBibleAPI.cachedYouVersionBiblesCount, equals(0));
    },
  );

  test(
    'pruneTransientFiles removes expired matching files and preserves excluded or fresh files',
    () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'ibg_cleanup_test_',
      );
      try {
        final File oldFile = File('${tempDir.path}/verse_1.png')
          ..writeAsBytesSync([1, 2, 3]);
        final File excludedOldFile = File('${tempDir.path}/verse_2.png')
          ..writeAsBytesSync([1, 2, 3]);
        final File freshFile = File('${tempDir.path}/verse_3.png')
          ..writeAsBytesSync([1, 2, 3]);
        final File unrelatedFile = File('${tempDir.path}/keep_me.txt')
          ..writeAsStringSync('keep');

        final DateTime twoHoursAgo = DateTime.now().subtract(
          const Duration(hours: 2),
        );
        await oldFile.setLastModified(twoHoursAgo);
        await excludedOldFile.setLastModified(twoHoursAgo);
        await unrelatedFile.setLastModified(twoHoursAgo);

        await pruneTransientFiles(
          tempDir,
          prefix: 'verse_',
          suffix: '.png',
          excludePath: excludedOldFile.path,
        );

        expect(await oldFile.exists(), isFalse);
        expect(await excludedOldFile.exists(), isTrue);
        expect(await freshFile.exists(), isTrue);
        expect(await unrelatedFile.exists(), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'YouVersionAuthDialog rejects empty and whitespace-only keys',
    (WidgetTester tester) async {
      final generator = Generator();
      generator.locales = {
        'en': {
          'yv_dialog_title': 'Connect YouVersion',
          'yv_dialog_hint': 'Enter YouVersion API key',
          'yv_open_portal_btn': 'Open Portal',
          'gemini_paste_clipboard_btn': 'Paste',
          'yv_api_key_label': 'YouVersion API Key',
          'gemini_disconnect_btn': 'Disconnect',
          'gemini_cancel_btn': 'Cancel',
          'gemini_save_btn': 'Save',
        },
      };
      String? savedKey;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YouVersionAuthDialog(
              lang: 'en',
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
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(saveButton.onPressed, isNull);
      expect(savedKey, isNull);
    },
  );

  test(
    'GetBibleAPI.normalizeYouVersionApiKey rejects whitespace, control chars, and invalid lengths',
    () {
      expect(
        GetBibleAPI.normalizeYouVersionApiKey('  yv-test-key_123.abc:456  '),
        equals('yv-test-key_123.abc:456'),
      );
      expect(GetBibleAPI.normalizeYouVersionApiKey('short'), isNull);
      expect(GetBibleAPI.normalizeYouVersionApiKey('key with spaces123'), isNull);
      expect(GetBibleAPI.normalizeYouVersionApiKey("yv-key\n12345678"), isNull);
      expect(GetBibleAPI.normalizeYouVersionApiKey('a' * 129), isNull);
    },
  );

  test(
    'GetBibleAPI.getPassage rejects oversized Bible reference strings (>100 chars)',
    () async {
      final longRef = 'Psalm ${'1' * 110}:1';
      final result = await GetBibleAPI.getPassage('web', longRef, lang: 'en');
      expect(result, isNull);
    },
  );

  testWidgets(
    'YouVersionAuthDialog rejects keys containing spaces or newlines',
    (WidgetTester tester) async {
      final generator = Generator();
      generator.locales = {
        'en': {
          'yv_dialog_title': 'Connect YouVersion',
          'yv_dialog_hint': 'Enter YouVersion API key',
          'yv_open_portal_btn': 'Open Portal',
          'gemini_paste_clipboard_btn': 'Paste',
          'yv_api_key_label': 'YouVersion API Key',
          'gemini_disconnect_btn': 'Disconnect',
          'gemini_cancel_btn': 'Cancel',
          'gemini_save_btn': 'Save',
          'show_api_key_tooltip': 'Show',
          'hide_api_key_tooltip': 'Hide',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YouVersionAuthDialog(
              lang: 'en',
              generator: generator,
              initialApiKey: null,
              onSave: (_) async {},
              onDisconnect: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bad key with spaces');
      await tester.pump();

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(saveButton.onPressed, isNull);
    },
  );

  test(
    'isValidRasterImageBytes validates PNG, JPEG, and WebP headers',
    () {
      expect(
        isValidRasterImageBytes(
          Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        isTrue,
      );
      expect(
        isValidRasterImageBytes(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
        ),
        isTrue,
      );
      expect(
        isValidRasterImageBytes(
          Uint8List.fromList([
            0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00,
            0x57, 0x45, 0x42, 0x50,
          ]),
        ),
        isTrue,
      );
      expect(
        isValidRasterImageBytes(
          Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>')),
        ),
        isFalse,
      );
      expect(
        isValidRasterImageBytes(Uint8List.fromList([0x01, 0x02])),
        isFalse,
      );
    },
  );

  test(
    'GetBibleAPI.getPassage validates bibleId, chapter/verse bounds, and accent regex parity',
    () async {
      final mockClient = MockClient((request) async {
        fail('Unexpected HTTP request for invalid query: ${request.url}');
      });

      expect(
        await GetBibleAPI.getPassage(
          '../evil',
          'John 3:16',
          lang: 'en',
          httpClient: mockClient,
        ),
        isNull,
      );
      expect(
        await GetBibleAPI.getPassage(
          'web',
          'Psalms 151:1',
          lang: 'en',
          httpClient: mockClient,
        ),
        isNull,
      );
      expect(
        await GetBibleAPI.getPassage(
          'web',
          'Psalms 119:201',
          lang: 'en',
          httpClient: mockClient,
        ),
        isNull,
      );

      final accentClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'verses': [
                {'text': 'Paraíso de Deus'},
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final accentVerse = await GetBibleAPI.getPassage(
        'almeida',
        'Levítico 1:1',
        lang: 'pt',
        httpClient: accentClient,
      );
      expect(accentVerse, equals('Paraíso de Deus'));
    },
  );

  test(
    'GetBibleAPI.fetchYouVersionBibles ignores malformed API keys passed directly',
    () async {
      final mockClient = MockClient((request) async {
        fail('Malformed YouVersion key should not issue an HTTP request');
      });
      final res = await GetBibleAPI.fetchYouVersionBibles(
        langPrefix: 'en',
        apiKey: "bad\r\nkey",
        httpClient: mockClient,
      );
      expect(res, isEmpty);
    },
  );

  testWidgets(
    'YouVersionAuthDialog disables keyboard suggestions and autocorrect on API key field',
    (WidgetTester tester) async {
      final generator = Generator();
      generator.locales = {
        'en': {
          'gemini_paste_clipboard_btn': 'Paste',
          'gemini_save_btn': 'Save',
          'gemini_disconnect_btn': 'Disconnect',
          'gemini_cancel_btn': 'Cancel',
          'show_api_key_tooltip': 'Show',
          'hide_api_key_tooltip': 'Hide',
          'yv_dialog_title': 'Connect YouVersion',
          'yv_dialog_hint': 'Hint',
          'yv_open_portal_btn': 'Portal',
          'yv_api_key_label': 'Key',
        },
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YouVersionAuthDialog(
              lang: 'en',
              generator: generator,
              initialApiKey: null,
              onSave: (_) async {},
              onDisconnect: () async {},
            ),
          ),
        ),
      );
      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enableSuggestions, isFalse);
      expect(field.autocorrect, isFalse);
    },
  );

  test(
    'ContrastSampler rejects oversized, empty, and non-raster image inputs',
    () async {
      const sampler = ContrastSampler();
      expect(await sampler.sampleImageBytes(Uint8List(0)), isNull);
      expect(
        await sampler.sampleImageBytes(
          Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>')),
        ),
        isNull,
      );

      final Directory tempDir = await Directory.systemTemp.createTemp(
        'ibg_contrast_security_',
      );
      try {
        final File emptyFile = File('${tempDir.path}/empty.png')..createSync();
        expect(await sampler.sampleFile(emptyFile.path), isNull);

        final File svgFile = File('${tempDir.path}/fake.png')
          ..writeAsStringSync('<svg xmlns="http://www.w3.org/2000/svg"/>');
        expect(await sampler.sampleFile(svgFile.path), isNull);

        final File oversizedFile = File('${tempDir.path}/oversized.png');
        final RandomAccessFile raf = await oversizedFile.open(mode: FileMode.write);
        try {
          await raf.writeFrom([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
          await raf.setPosition(ContrastSampler.maxImageBytes);
          await raf.writeByte(0);
        } finally {
          await raf.close();
        }
        expect(await sampler.sampleFile(oversizedFile.path), isNull);
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );

  test(
    'VoiceVerseService.normalizeSpokenReference caps oversized transcripts before regex matching',
    () {
      final String oversized = '${'a ' * 150}3:16';
      final String normalized = VoiceVerseService.normalizeSpokenReference(
        oversized,
      );
      expect(normalized.length, equals(VoiceVerseService.maxSpokenLength));
      expect(
        VoiceVerseService.normalizeSpokenReference('John chapter 3 verse 16'),
        equals('John 3:16'),
      );
    },
  );

  testWidgets(
    'Search Topic and custom image description TextFields enforce maxLength bounds',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MyApp(
            verseSearchOverride: (query, versionId, lang) async => const [
              BibleSearchResult(
                bookName: 'John',
                bookNumber: 43,
                chapter: 14,
                verse: 27,
                reference: 'John 14:27',
                text: 'Peace I leave with you.',
              ),
            ],
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Open Search Topic dialog and verify search query maxLength
      final Finder searchTopicBtn = find.byTooltip('Search Topic');
      await tester.ensureVisible(searchTopicBtn);
      await tester.tap(searchTopicBtn);
      await tester.pumpAndSettle();

      final Finder dialogFieldFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(dialogFieldFinder, findsOneWidget);
      final TextField searchField = tester.widget<TextField>(dialogFieldFinder);
      expect(searchField.maxLength, equals(160));

      // Select a verse so the Audio & Text tab renders the custom description field
      await tester.tap(find.text('Peace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('John 14:27'));
      await tester.pumpAndSettle();

      final Finder audioTab = find.text('Audio & Text');
      await tester.ensureVisible(audioTab);
      await tester.tap(audioTab);
      await tester.pumpAndSettle();

      final Finder descFieldFinder = find.ancestor(
        of: find.text('Image Description (for Alt-Text)'),
        matching: find.byType(TextField),
      );
      expect(descFieldFinder, findsOneWidget);
      final TextField descField = tester.widget<TextField>(descFieldFinder);
      expect(descField.maxLength, equals(500));
    },
  );
}
