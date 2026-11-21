import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:app/getbible_api.dart';
import 'package:app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GetBibleAPI.searchVerses unit tests', () {
    test('queries Bolls.life /v2/find, cleans HTML, and resolves localized book names', () async {
      Uri? capturedUri;
      final mockClient = MockClient((http.Request request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'exact_matches': 1,
            'total': 1,
            'results': [
              {
                'book': 43,
                'chapter': 14,
                'verse': 27,
                'text': '<mark>Peace</mark> I leave with you.<S>1515</S>',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final results = await GetBibleAPI.searchVerses(
        query: 'peace',
        versionId: 'web',
        lang: 'en',
        client: mockClient,
      );

      expect(capturedUri.toString(), contains('/v2/find/WEB'));
      expect(capturedUri.toString(), contains('search=peace'));
      expect(results, hasLength(1));
      expect(results.first.reference, equals('John 14:27'));
      expect(results.first.text, equals('Peace I leave with you.'));
    });

    test('resolves Portuguese book names and handles HTTP errors gracefully', () async {
      final errorClient = MockClient(
        (_) async => http.Response('Service Unavailable', 503),
      );
      final empty = await GetBibleAPI.searchVerses(
        query: 'paz',
        versionId: 'naa',
        lang: 'pt',
        client: errorClient,
      );
      expect(empty, isEmpty);
    });
  });

  testWidgets(
    'Search Topic dialog searches by theme/phrase and populates verse on selection',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      String? searchedQuery;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MyApp(
            verseSearchOverride: (query, versionId, lang) async {
              searchedQuery = query;
              return const [
                BibleSearchResult(
                  bookName: 'John',
                  bookNumber: 43,
                  chapter: 14,
                  verse: 27,
                  reference: 'John 14:27',
                  text: 'Peace I leave with you. My peace I give to you.',
                ),
              ];
            },
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      final searchTopicBtn = find.text('Search Topic');
      await tester.ensureVisible(searchTopicBtn);
      await tester.tap(searchTopicBtn);
      await tester.pumpAndSettle();

      expect(find.text('Search Bible Verses'), findsOneWidget);

      // Tap quick theme chip "Peace"
      await tester.tap(find.text('Peace'));
      await tester.pumpAndSettle();

      expect(searchedQuery, equals('Peace'));
      expect(find.text('John 14:27'), findsOneWidget);

      // Select the returned verse
      await tester.tap(find.text('John 14:27'));
      await tester.pumpAndSettle();

      expect(find.text('Search Bible Verses'), findsNothing);
      expect(
        find.textContaining('Peace I leave with you. My peace I give to you.'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'Search Topic dialog disables search under 2 chars and clears query/results',
    (WidgetTester tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MyApp(verseSearchOverride: (_, _, _) async => const []),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Search Topic'));
      await tester.tap(find.text('Search Topic'));
      await tester.pumpAndSettle();

      FilledButton searchButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Search'),
      );
      expect(searchButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'a');
      await tester.pump();
      expect(searchButton().onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'xyz');
      await tester.pump();
      expect(searchButton().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();
      expect(find.text('No matching verses found. Try another word or phrase.'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byTooltip('Clear search'),
        ),
      );
      await tester.pumpAndSettle();
      expect(searchButton().onPressed, isNull);
      expect(find.text('No matching verses found. Try another word or phrase.'), findsNothing);
    },
  );
}
