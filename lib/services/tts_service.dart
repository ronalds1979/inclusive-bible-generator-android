import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {
  final FlutterTts _flutterTts;

  TtsService({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  static const Map<String, Map<String, Map<String, String>>> _voiceProfiles = {
    "pt-BR": {
      "Female": {"name": "pt-BR-FranciscaNeural", "locale": "pt-BR"},
      "Male": {"name": "pt-BR-AntonioNeural", "locale": "pt-BR"},
    },
    "en": {
      "Female": {"name": "en-US-JennyNeural", "locale": "en-US"},
      "Male": {"name": "en-US-GuyNeural", "locale": "en-US"},
    },
    "es": {
      "Female": {"name": "es-ES-ElviraNeural", "locale": "es-ES"},
      "Male": {"name": "es-ES-AlvaroNeural", "locale": "es-ES"},
    },
  };

  /// Resolves the target TTS voice configuration (`name` and `locale`) for a
  /// given language (`pt-BR`, `en`, `es`) and gender (`Female`, `Male`).
  static Map<String, String> resolveVoiceConfig(String lang, String gender) {
    final String normalizedLang = _voiceProfiles.containsKey(lang)
        ? lang
        : (lang.startsWith("en")
              ? "en"
              : (lang.startsWith("es") ? "es" : "pt-BR"));
    final String normalizedGender = gender == "Male" ? "Male" : "Female";
    return Map<String, String>.from(
      _voiceProfiles[normalizedLang]![normalizedGender]!,
    );
  }

  Future<void> speakPreview({
    required String verse,
    required String reference,
    required String lang,
    required String gender,
  }) async {
    final Map<String, String> voiceConfig = resolveVoiceConfig(lang, gender);
    final String targetLocale = voiceConfig["locale"]!;
    try {
      await _flutterTts.stop();
      await _flutterTts.setLanguage(targetLocale);
      await _flutterTts.setVoice(voiceConfig);
      final String textToRead = reference.trim().isNotEmpty
          ? "$reference. $verse"
          : verse;
      await _flutterTts.speak(textToRead);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error playing TTS preview: $e");
      }
    }
  }

  Future<String?> generateAudio({
    required String verse,
    required String reference,
    required String lang,
    required String gender,
  }) async {
    final Map<String, String> voiceConfig = resolveVoiceConfig(lang, gender);
    final String targetLocale = voiceConfig["locale"]!;

    try {
      await _flutterTts.setLanguage(targetLocale);
      await _flutterTts.setVoice(voiceConfig);

      final String textToRead = "$reference. $verse";
      if (Platform.isAndroid) {
        final String fileName =
            "verse_audio_${DateTime.now().millisecondsSinceEpoch}.wav";
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          await _flutterTts.synthesizeToFile(textToRead, fileName);
          await Future.delayed(const Duration(seconds: 2));
          return "${dir.path}/$fileName";
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error generating TTS audio: $e");
      }
    }
    return null;
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
