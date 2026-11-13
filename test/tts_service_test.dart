import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/tts_service.dart';

void main() {
  group('TtsService device voice selection tests', () {
    test('detectVoiceGender distinguishes male and female without substring collisions', () {
      expect(
        TtsService.detectVoiceGender({
          'name': 'pt-br-x-afs#female_2-local',
          'locale': 'pt-BR',
        }),
        equals('Female'),
      );
      expect(
        TtsService.detectVoiceGender({
          'name': 'pt-br-x-afs#male_1-local',
          'locale': 'pt-BR',
        }),
        equals('Male'),
      );
      expect(
        TtsService.detectVoiceGender({
          'name': 'en-us-x-iom-local',
          'locale': 'en-US',
        }),
        equals('Male'),
      );
      expect(
        TtsService.detectVoiceGender({
          'name': 'en-us-x-sfg-local',
          'locale': 'en-US',
        }),
        equals('Female'),
      );
      expect(
        TtsService.detectVoiceGender({
          'name': 'com.apple.voice.compact.en-US.Aaron',
          'locale': 'en-US',
          'gender': 'male',
        }),
        equals('Male'),
      );
    });

    test('selectVoiceFromAvailable picks Male and Female Android TTS voices', () {
      final List<Map<String, String>> androidVoices = [
        {
          'name': 'pt-br-x-afs#female_1-local',
          'locale': 'pt-BR',
          'quality': 'high',
          'network_required': '0',
        },
        {
          'name': 'pt-br-x-afs#male_1-local',
          'locale': 'pt-BR',
          'quality': 'high',
          'network_required': '0',
        },
        {
          'name': 'en-us-x-sfg-local',
          'locale': 'en-US',
          'quality': 'high',
          'network_required': '0',
        },
        {
          'name': 'en-us-x-iom-local',
          'locale': 'en-US',
          'quality': 'high',
          'network_required': '0',
        },
        {
          'name': 'es-es-x-eec-local',
          'locale': 'es-ES',
          'quality': 'high',
          'network_required': '0',
        },
        {
          'name': 'es-es-x-eed-local',
          'locale': 'es-ES',
          'quality': 'high',
          'network_required': '0',
        },
      ];

      final ptMale = TtsService.selectVoiceFromAvailable(
        androidVoices,
        'pt-BR',
        'Male',
      );
      expect(ptMale.voice, {
        'name': 'pt-br-x-afs#male_1-local',
        'locale': 'pt-BR',
      });
      expect(ptMale.pitch, equals(TtsService.documentaryPitch));

      final enMale = TtsService.selectVoiceFromAvailable(
        androidVoices,
        'en',
        'Male',
      );
      expect(enMale.voice, {
        'name': 'en-us-x-iom-local',
        'locale': 'en-US',
      });
      expect(enMale.pitch, equals(TtsService.documentaryPitch));

      final esMale = TtsService.selectVoiceFromAvailable(
        androidVoices,
        'es',
        'Male',
      );
      expect(esMale.voice, {
        'name': 'es-es-x-eed-local',
        'locale': 'es-ES',
      });
      expect(esMale.pitch, equals(TtsService.documentaryPitch));

      final enFemale = TtsService.selectVoiceFromAvailable(
        androidVoices,
        'en',
        'Female',
      );
      expect(enFemale.voice, {
        'name': 'en-us-x-sfg-local',
        'locale': 'en-US',
      });
      expect(enFemale.pitch, equals(TtsService.documentaryPitch));
    });

    test('falls back to deeper male pitch when device has no Male voice for locale', () {
      final List<Map<String, String>> femaleOnlyVoices = [
        {
          'name': 'pt-br-x-afs-local',
          'locale': 'pt-BR',
          'quality': 'high',
          'network_required': '0',
        },
      ];

      final ptMaleFallback = TtsService.selectVoiceFromAvailable(
        femaleOnlyVoices,
        'pt-BR',
        'Male',
      );
      expect(ptMaleFallback.voice, {
        'name': 'pt-br-x-afs-local',
        'locale': 'pt-BR',
      });
      expect(ptMaleFallback.pitch, equals(TtsService.maleFallbackPitch));
      expect(ptMaleFallback.pitch, lessThan(TtsService.documentaryPitch));
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
