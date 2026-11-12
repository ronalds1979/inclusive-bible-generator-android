import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/tts_service.dart';

void main() {
  group('TtsService resolveVoiceConfig tests', () {
    test('resolves Portuguese Female and Male voices', () {
      expect(TtsService.resolveVoiceConfig('pt-BR', 'Female'), {
        'name': 'pt-BR-FranciscaNeural',
        'locale': 'pt-BR',
      });
      expect(TtsService.resolveVoiceConfig('pt-BR', 'Male'), {
        'name': 'pt-BR-AntonioNeural',
        'locale': 'pt-BR',
      });
    });

    test('resolves English Female and Male voices', () {
      expect(TtsService.resolveVoiceConfig('en', 'Female'), {
        'name': 'en-US-JennyNeural',
        'locale': 'en-US',
      });
      expect(TtsService.resolveVoiceConfig('en', 'Male'), {
        'name': 'en-US-GuyNeural',
        'locale': 'en-US',
      });
    });

    test('resolves Spanish Female and Male voices', () {
      expect(TtsService.resolveVoiceConfig('es', 'Female'), {
        'name': 'es-ES-ElviraNeural',
        'locale': 'es-ES',
      });
      expect(TtsService.resolveVoiceConfig('es', 'Male'), {
        'name': 'es-ES-AlvaroNeural',
        'locale': 'es-ES',
      });
    });
  });

  group('TtsService spoken reference and documentary pacing tests', () {
    test('formats 4:11 as chapter and verse instead of clock time across pt, en, and es', () {
      expect(
        TtsService.formatSpokenReference('Filipenses 4:11', 'pt-BR'),
        equals('Filipenses, capítulo 4, versículo 11'),
      );
      expect(
        TtsService.formatSpokenReference('Philippians 4:11', 'en'),
        equals('Philippians, chapter 4, verse 11'),
      );
      expect(
        TtsService.formatSpokenReference('Filipenses 4:11', 'es'),
        equals('Filipenses, capítulo 4, versículo 11'),
      );
    });

    test('formats verse ranges and numbered books naturally across languages', () {
      expect(
        TtsService.formatSpokenReference('1 John 4:8', 'en'),
        equals('First John, chapter 4, verse 8'),
      );
      expect(
        TtsService.formatSpokenReference('Psalm 23:1-4', 'en'),
        equals('Psalm, chapter 23, verses 1 to 4'),
      );
      expect(
        TtsService.formatSpokenReference('Salmos 23:1-4', 'es'),
        equals('Salmos, capítulo 23, versículos 1 al 4'),
      );
      expect(
        TtsService.formatSpokenReference('Salmos 23:1-4', 'pt-BR'),
        equals('Salmos, capítulo 23, versículos 1 a 4'),
      );
    });

    test('buildSpokenScript includes documentary narrator pause and documentarySpeechRate is slower than normal', () {
      expect(
        TtsService.buildSpokenScript(
          verse: 'I have learned in whatever state I am, to be content.',
          reference: 'Philippians 4:11',
          lang: 'en',
        ),
        equals(
          'Philippians, chapter 4, verse 11... I have learned in whatever state I am, to be content.',
        ),
      );
      // Normal flutter_tts speech rate is 0.5; documentary narrator rate is slower (< 0.45)
      expect(TtsService.documentarySpeechRate, lessThan(0.45));
    });
  });
}
