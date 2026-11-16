import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/gemini_service.dart';
import 'package:app/generator.dart';
import 'package:app/getbible_api.dart';
import 'package:app/services/stock_photo_service.dart';
import 'package:app/services/temp_file_cleanup.dart';
import 'package:app/widgets/gemini_auth_dialog.dart';
import 'package:app/widgets/youversion_auth_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'GetBibleAPI does not crash on invalid version fetch (simulating error)',
    () async {
      // If it threw an error and wasn't caught, this test would fail
      // By passing an invalid URL/triggering an error, we ensure it's caught and handled gracefully
      // without printing sensitive info to production.
      final result = await GetBibleAPI.getVersions(
        lang: "invalid_format_that_will_throw",
      );
      expect(result, []); // Returns empty list on error
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
    'GeminiService persists and clears API key using FlutterSecureStorage',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final service = GeminiService();
      const testKey = 'AIzaSyTestSecureStorageKey12345678901234';

      await service.saveApiKey(testKey);
      expect(await service.loadApiKey(), testKey);

      await service.saveApiKey('');
      expect(await service.loadApiKey(), isNull);
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
    },
  );

  test(
    'StockPhotoService.parseAllowedWikimediaUri only allows HTTPS Wikimedia hosts',
    () {
      expect(
        StockPhotoService.parseAllowedWikimediaUri(
          'https://upload.wikimedia.org/wikipedia/commons/a/a9/Example.jpg',
        ),
        isNotNull,
      );
      expect(
        StockPhotoService.parseAllowedWikimediaUri(
          'https://commons.wikimedia.org/wiki/Special:FilePath/Example.jpg',
        ),
        isNotNull,
      );
      expect(
        StockPhotoService.parseAllowedWikimediaUri(
          'http://upload.wikimedia.org/wikipedia/commons/a/a9/Example.jpg',
        ),
        isNull,
      );
      expect(
        StockPhotoService.parseAllowedWikimediaUri(
          'https://evil.example.com/example.jpg',
        ),
        isNull,
      );
      expect(StockPhotoService.parseAllowedWikimediaUri('not a url'), isNull);
    },
  );

  test(
    'StockPhotoService.downloadPhotoToTemp rejects disallowed URLs and >20MB responses',
    () async {
      final service = StockPhotoService(
        httpClient: MockClient.streaming((request, bodyStream) async {
          return http.StreamedResponse(
            const Stream<List<int>>.empty(),
            200,
            contentLength: StockPhotoService.maxDownloadBytes + 1,
          );
        }),
      );

      await expectLater(
        service.downloadPhotoToTemp(
          const StockPhotoResult(
            title: 'Bad',
            thumbUrl: 'https://evil.example.com/a.jpg',
            fullUrl: 'https://evil.example.com/a.jpg',
          ),
        ),
        throwsA(isA<HttpException>()),
      );

      await expectLater(
        service.downloadPhotoToTemp(
          const StockPhotoResult(
            title: 'TooBig',
            thumbUrl: 'https://upload.wikimedia.org/a.jpg',
            fullUrl: 'https://upload.wikimedia.org/a.jpg',
          ),
        ),
        throwsA(isA<HttpException>()),
      );
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

  testWidgets(
    'GeminiAuthDialog does not silently read clipboard on initState',
    (WidgetTester tester) async {
      final generator = Generator();
      generator.locales = {
        'en': {
          'gemini_dialog_title': 'Connect Gemini AI',
          'gemini_dialog_hint': 'Get a free Gemini API key',
          'gemini_open_aistudio_btn': 'Get Free Gemini Key',
          'gemini_paste_clipboard_btn': 'Paste Key from Clipboard',
          'gemini_api_key_label': 'Gemini API Key',
          'gemini_save_btn': 'Save & Connect',
          'gemini_disconnect_btn': 'Remove Key',
          'gemini_cancel_btn': 'Cancel',
          'show_api_key_tooltip': 'Show',
          'hide_api_key_tooltip': 'Hide',
        },
      };

      await tester.runAsync(
        () => Clipboard.setData(
          const ClipboardData(text: 'AIzaSyTestClipboardKey1234567890123456'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GeminiAuthDialog(
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

      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    },
  );
}
