import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:app/services/tts_service.dart';

class _FakeFlutterTts extends FlutterTts {
  final List<Map<String, String>> voices;
  final Future<dynamic> Function(
    _FakeFlutterTts tts,
    String text,
    String fileName,
    bool isFullPath,
    Map<String, String>? activeVoice,
  ) onSynthesize;

  Map<String, String>? activeVoice;
  String? activeLanguage;
  int clearVoiceCalls = 0;
  int stopCalls = 0;

  _FakeFlutterTts({required this.voices, required this.onSynthesize});

  @override
  Future<dynamic> get getVoices async => voices;

  @override
  Future<dynamic> setLanguage(String language) async {
    activeLanguage = language;
    return 1;
  }

  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    activeVoice = Map<String, String>.from(voice);
    return 1;
  }

  @override
  Future<dynamic> clearVoice() async {
    clearVoiceCalls++;
    activeVoice = null;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> awaitSynthCompletion(bool awaitCompletion) async => 1;

  @override
  Future<dynamic> stop() async {
    stopCalls++;
    return 1;
  }

  @override
  Future<dynamic> synthesizeToFile(
    String text,
    String fileName, [
    bool isFullPath = false,
  ]) {
    return onSynthesize(this, text, fileName, isFullPath, activeVoice);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(ptMaleFallback.pitch, greaterThanOrEqualTo(0.78));
      expect(ptMaleFallback.pitch, lessThan(TtsService.documentaryPitch));
    });

    test('prefers genuine pt-BR male voice over pitch-shifted local female voice and detects Samsung voices', () {
      final List<Map<String, String>> mixedVoices = [
        {
          'name': 'pt-br-x-afs-local',
          'locale': 'pt-BR',
          'quality': 'high',
          'network_required': '0',
        },
        {
          'name': 'pt-br-x-ptd-network',
          'locale': 'pt-BR',
          'quality': 'high',
          'network_required': '1',
        },
      ];

      final ptMale = TtsService.selectVoiceFromAvailable(
        mixedVoices,
        'pt-BR',
        'Male',
      );
      expect(ptMale.voice, {
        'name': 'pt-br-x-ptd-network',
        'locale': 'pt-BR',
      });
      expect(ptMale.pitch, equals(TtsService.documentaryPitch));

      expect(
        TtsService.detectVoiceGender({
          'name': 'pt-br-SMTm00',
          'locale': 'pt-BR',
        }),
        equals('Male'),
      );
      expect(
        TtsService.detectVoiceGender({
          'name': 'pt-br-SMTf00',
          'locale': 'pt-BR',
        }),
        equals('Female'),
      );
    });

    test('skips notInstalled and network-only pt-BR female voices in favor of installed local voice', () {
      final List<Map<String, String>> ptBrVoices = [
        {
          'name': 'pt-br-x-afs-local',
          'locale': 'pt-BR',
          'quality': 'very high',
          'network_required': '0',
          'features': 'notInstalled\tlegacySetLanguageVoice',
        },
        {
          'name': 'pt-br-x-afs-network',
          'locale': 'pt-BR',
          'quality': 'very high',
          'network_required': '1',
          'features': 'networkTimeoutMs',
        },
        {
          'name': 'pt-br-x-pte-local',
          'locale': 'pt-BR',
          'quality': 'high',
          'network_required': '0',
          'features': 'embeddedTts',
        },
      ];

      final ptFemale = TtsService.selectVoiceFromAvailable(
        ptBrVoices,
        'pt-BR',
        'Female',
      );
      expect(ptFemale.voice, {
        'name': 'pt-br-x-pte-local',
        'locale': 'pt-BR',
      });
      expect(ptFemale.pitch, equals(TtsService.documentaryPitch));
    });

    test('returns null voice when all pt-BR voices are notInstalled so engine default is used', () {
      final List<Map<String, String>> notInstalledOnly = [
        {
          'name': 'pt-br-x-afs-local',
          'locale': 'pt-BR',
          'quality': 'high',
          'network_required': '0',
          'features': 'notInstalled',
        },
      ];

      final ptFemale = TtsService.selectVoiceFromAvailable(
        notInstalledOnly,
        'pt-BR',
        'Female',
      );
      expect(ptFemale.voice, isNull);
      expect(ptFemale.targetLocale, equals('pt-BR'));
      expect(ptFemale.pitch, equals(TtsService.documentaryPitch));
    });

    test('generateAudio falls back to default pt-BR voice when explicit female voice errors', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'tts_service_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final fakeTts = _FakeFlutterTts(
        voices: [
          {
            'name': 'pt-br-x-afs-local',
            'locale': 'pt-BR',
            'quality': 'high',
            'network_required': '0',
          },
        ],
        onSynthesize: (tts, text, fileName, isFullPath, activeVoice) async {
          if (activeVoice != null) {
            // Simulate Android flutter_tts bug: onError fires while the
            // synthesizeToFile Future itself never completes.
            scheduleMicrotask(() {
              tts.errorHandler?.call('Error from TextToSpeech (synth) - -6');
            });
            return Completer<dynamic>().future;
          }
          // Fallback attempt with default locale voice succeeds and writes a valid WAV.
          final File out = File(fileName);
          await out.writeAsBytes(List<int>.filled(128, 1));
          return 1;
        },
      );

      final service = TtsService(
        flutterTts: fakeTts,
        isAndroidOverride: true,
        tempDirProvider: () async => tempDir,
      );

      final String? audioPath = await service.generateAudio(
        verse: 'Lâmpada para os meus pés é a tua palavra.',
        reference: 'Salmos 119:105',
        lang: 'pt-BR',
        gender: 'Female',
      );

      expect(audioPath, isNotNull);
      expect(await File(audioPath!).exists(), isTrue);
      expect(await File(audioPath).length(), greaterThan(44));
      expect(fakeTts.clearVoiceCalls, equals(1));
      expect(fakeTts.activeLanguage, equals('pt-BR'));
      expect(fakeTts.stopCalls, greaterThanOrEqualTo(2));
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
