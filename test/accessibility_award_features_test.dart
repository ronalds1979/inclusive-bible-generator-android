import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/getbible_api.dart';
import 'package:app/main.dart';
import 'package:app/services/contrast_sampler.dart';
import 'package:app/services/voice_verse_service.dart';
import 'package:app/widgets/vision_simulation.dart';

class _FakeVoiceVerseService extends VoiceVerseService {
  final bool available;
  final String? spokenResult;

  const _FakeVoiceVerseService({
    required this.available,
    this.spokenResult,
  }) : super(isAndroidOverride: true);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String?> listenForVerse({
    required String locale,
    required String prompt,
  }) async => spokenResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('VisionSimulatorFilter tests', () {
    testWidgets('applies ColorFiltered for CVD modes and ImageFiltered for Low Vision', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VisionSimulatorFilter(
            mode: VisionSimulationMode.protanopia,
            child: Text('Sample'),
          ),
        ),
      );
      expect(find.byType(ColorFiltered), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: VisionSimulatorFilter(
            mode: VisionSimulationMode.lowVisionBlur,
            child: Text('Sample'),
          ),
        ),
      );
      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });

  group('ContrastSampler tests', () {
    test('samples top/center/bottom luminance and picks highest-contrast placement', () {
      // 1px wide x 3px tall image: top=white, center=mid-gray, bottom=black
      final rgba = Uint8List.fromList([
        255, 255, 255, 255, // top: luminance ~1.0
        128, 128, 128, 255, // center: luminance ~0.21
        0, 0, 0, 255, // bottom: luminance 0.0
      ]);
      final profile = ContrastSampler.profileFromRgba(
        rgbaBytes: rgba,
        width: 1,
        height: 3,
      );
      expect(profile.top, greaterThan(0.95));
      expect(profile.bottom, lessThan(0.05));

      final bestForWhite = profile.bestPlacementFor(
        fontColor: Colors.white,
        dim: 0.0,
      );
      expect(bestForWhite.yOffset, equals(110.0));
      expect(bestForWhite.ratio, closeTo(21.0, 0.1));

      final bestForBlack = profile.bestPlacementFor(
        fontColor: Colors.black,
        dim: 0.0,
      );
      expect(bestForBlack.yOffset, equals(-110.0));
      expect(bestForBlack.ratio, closeTo(21.0, 0.1));
    });
  });

  group('VoiceVerseService parser tests', () {
    test('normalizes spoken references across en, pt-BR, and es', () {
      expect(
        VoiceVerseService.normalizeSpokenReference('John chapter 3 verse 16'),
        equals('John 3:16'),
      );
      expect(
        VoiceVerseService.normalizeSpokenReference('Salmos 23 versículo 1 ao 4'),
        equals('Salmos 23:1-4'),
      );
      expect(
        VoiceVerseService.normalizeSpokenReference('Juan capítulo 3 versículo 16'),
        equals('Juan 3:16'),
      );
      expect(
        VoiceVerseService.normalizeSpokenReference('First Corinthians 13 verses 4 to 7'),
        equals('1 Corinthians 13:4-7'),
      );
    });

    test('normalizes and parses natural Spanish spoken references', () {
      final cases = <String, ({String normalized, String bookNr, String chapter, String start, String? end})>{
        'Salmo 23 versículo 1': (normalized: 'Salmo 23:1', bookNr: '19', chapter: '23', start: '1', end: null),
        'Salmo 23': (normalized: 'Salmo 23:1', bookNr: '19', chapter: '23', start: '1', end: null),
        'Salmo 23 del 1 al 4': (normalized: 'Salmo 23:1-4', bookNr: '19', chapter: '23', start: '1', end: '4'),
        'Salmos 23 versículos del 1 al 4': (normalized: 'Salmos 23:1-4', bookNr: '19', chapter: '23', start: '1', end: '4'),
        'Primera de Corintios 13 versículo 4': (normalized: '1 Corintios 13:4', bookNr: '46', chapter: '13', start: '4', end: null),
        '1.ª de Juan 4 8': (normalized: '1 Juan 4:8', bookNr: '62', chapter: '4', start: '8', end: null),
        '1ª de Pedro 5 versículo 7': (normalized: '1 Pedro 5:7', bookNr: '60', chapter: '5', start: '7', end: null),
        '2da de Reyes 2 11': (normalized: '2 Reyes 2:11', bookNr: '12', chapter: '2', start: '11', end: null),
        'Primer libro de Samuel 17 45': (normalized: '1 Samuel 17:45', bookNr: '9', chapter: '17', start: '45', end: null),
        'Tercer Juan 1 versículo 2': (normalized: '3 Juan 1:2', bookNr: '64', chapter: '1', start: '2', end: null),
        'San Juan 3 16': (normalized: 'San Juan 3:16', bookNr: '43', chapter: '3', start: '16', end: null),
        'Evangelio según San Mateo 5 versículo 14.': (normalized: 'San Mateo 5:14', bookNr: '40', chapter: '5', start: '14', end: null),
        'Juan capítulo 3, versículo 16.': (normalized: 'Juan 3:16', bookNr: '43', chapter: '3', start: '16', end: null),
        'Juan 3 verso 16 hasta el 18': (normalized: 'Juan 3:16-18', bookNr: '43', chapter: '3', start: '16', end: '18'),
        'Génesis uno uno': (normalized: 'Génesis 1:1', bookNr: '1', chapter: '1', start: '1', end: null),
        'Juan capítulo tres versículo dieciséis': (normalized: 'Juan 3:16', bookNr: '43', chapter: '3', start: '16', end: null),
        'Salmo noventa y uno versículo uno': (normalized: 'Salmo 91:1', bookNr: '19', chapter: '91', start: '1', end: null),
        'Salmo ciento diecinueve ciento cinco': (normalized: 'Salmo 119:105', bookNr: '19', chapter: '119', start: '105', end: null),
        'Cantar de los Cantares 2 1': (normalized: 'Cantar de los Cantares 2:1', bookNr: '22', chapter: '2', start: '1', end: null),
        'Hechos de los Apóstoles 2 38': (normalized: 'Hechos de los Apóstoles 2:38', bookNr: '44', chapter: '2', start: '38', end: null),
        'Juan 3 dos puntos 16': (normalized: 'Juan 3:16', bookNr: '43', chapter: '3', start: '16', end: null),
      };

      for (final entry in cases.entries) {
        final String normalized = VoiceVerseService.normalizeSpokenReference(entry.key);
        expect(normalized, equals(entry.value.normalized), reason: 'normalize("${entry.key}")');
        final parsed = GetBibleAPI.parseReference(normalized, lang: 'es');
        expect(parsed['book_nr'], equals(entry.value.bookNr), reason: 'book_nr for "${entry.key}" -> "$normalized"');
        expect(parsed['chapter'], equals(entry.value.chapter), reason: 'chapter for "${entry.key}"');
        expect(parsed['start_verse'], equals(entry.value.start), reason: 'start_verse for "${entry.key}"');
        expect(parsed['end_verse'], equals(entry.value.end), reason: 'end_verse for "${entry.key}"');
      }
    });

    test('selectBestCandidate picks the first valid Spanish Bible reference from STT alternatives', () {
      final best = VoiceVerseService.selectBestCandidate(
        ['salmo dos tres', 'Salmo 23 versículo 1'],
        lang: 'es',
      );
      expect(best, equals('salmo 2:3'));

      final fallbackToValid = VoiceVerseService.selectBestCandidate(
        ['hola mundo', 'San Juan 3 16', 'Juan 3 6'],
        lang: 'es',
      );
      expect(fallbackToValid, equals('San Juan 3:16'));

      final misplacedAccent = GetBibleAPI.parseReference(
        'Eclesiástes 3:1',
        lang: 'es',
      );
      expect(misplacedAccent['book_nr'], equals('21'));
    });
  });

  group('End-to-end accessibility award features widget tests', () {
    testWidgets(
      'Vision simulator, voice-to-verse button, editable Alt-Text, and Inclusivity Scorecard work',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MyApp(
              voiceVerseService: _FakeVoiceVerseService(
                available: true,
                spokenResult: 'Psalm chapter 23 verse 1',
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // 1. Voice-to-Verse button is visible, populates reference, and syncs Book/Chapter/Verse selectors
        final voiceBtn = find.byTooltip('Speak Bible verse reference');
        expect(voiceBtn, findsOneWidget);
        await tester.ensureVisible(voiceBtn);
        await tester.runAsync(() async {
          await tester.tap(voiceBtn);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(find.textContaining('Psalm 23:1'), findsWidgets);
        expect(find.text('Psalms'), findsOneWidget);
        expect(find.text('23'), findsOneWidget);

        // 2. Full-Screen Preview uses eye icon and includes Vision Simulator chips
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
        await tester.tap(find.byTooltip('Expand preview'));
        await tester.pumpAndSettle();
        expect(find.text('Vision Preview'), findsOneWidget);
        await tester.tap(find.text('Protanopia'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        // Ensure verse & reference are filled, enable Dyslexia-Friendly preset for WCAG AAA
        final textFields = find.byType(TextField);
        await tester.enterText(textFields.first, 'Psalm 23:1');
        await tester.enterText(textFields.at(1), 'The Lord is my shepherd.');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Style'));
        await tester.pumpAndSettle();
        final dyslexiaChip = find.text('Dyslexia-Friendly');
        await tester.ensureVisible(dyslexiaChip);
        await tester.tap(dyslexiaChip);
        await tester.pumpAndSettle();

        // 3. Step 4: Editable Alt-Text description + Inclusivity Readiness Scorecard (4/4)
        await tester.tap(find.text('Audio & Text'));
        await tester.pumpAndSettle();

        final descField = find.widgetWithText(
          TextField,
          'Image Description (for Alt-Text)',
        );
        await tester.ensureVisible(descField);
        await tester.enterText(descField, 'Sunlit valley with gentle hills.');
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Sunlit valley with gentle hills.'),
          findsWidgets,
        );
        final scorecard = find.text('Inclusivity Readiness (4/4)');
        await tester.ensureVisible(scorecard);
        expect(scorecard, findsOneWidget);
      },
    );

    testWidgets(
      'YouVersion key icon is hidden from UI and About dialog credits YouVersion Platform',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        await tester.runAsync(() async {
          await tester.pumpWidget(const MyApp());
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // Key icon must not be shown to end users
        expect(find.byIcon(Icons.vpn_key_outlined), findsNothing);
        expect(find.byTooltip('YouVersion Key'), findsNothing);

        // About & Credits dialog credits YouVersion Platform
        final aboutBtn = find.byTooltip('About & Credits');
        expect(aboutBtn, findsOneWidget);
        await tester.tap(aboutBtn);
        await tester.pumpAndSettle();

        expect(find.text('About Inclusive Bible Generator'), findsOneWidget);
        expect(find.text('Powered by YouVersion Platform'), findsOneWidget);
        expect(find.text('Visit YouVersion Platform'), findsOneWidget);
      },
    );

    testWidgets(
      'Voice-to-verse syncs Book, Chapter, and Verse selectors above with spoken reference',
      (WidgetTester tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MyApp(
              voiceVerseService: _FakeVoiceVerseService(
                available: true,
                spokenResult: 'John chapter 3 verse 16',
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pumpAndSettle();

        // Initially defaults to Psalms, not John
        expect(find.text('Psalms'), findsOneWidget);
        expect(find.text('John'), findsNothing);

        final voiceBtn = find.byTooltip('Speak Bible verse reference');
        await tester.ensureVisible(voiceBtn);
        await tester.runAsync(() async {
          await tester.tap(voiceBtn);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();

        // Book, Chapter, and Verse selectors above are now synced to John 3:16
        expect(find.text('John'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('16'), findsOneWidget);
        expect(find.textContaining('John 3:16'), findsWidgets);
      },
    );
  });
}
