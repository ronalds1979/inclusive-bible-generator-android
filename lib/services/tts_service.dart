import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {
  final FlutterTts _flutterTts;

  /// Calm, measured documentary narrator speech rate for `flutter_tts`
  /// (where `0.5` is normal 1.0x speed on Android, so `0.42` is ~16% slower,
  /// matching the `-15%` documentary narrator pace across pt-BR, en, and es).
  static const double documentarySpeechRate = 0.42;

  /// Slightly warm, grounded narrator pitch.
  static const double documentaryPitch = 0.95;

  static final RegExp _audioRefRegExp = RegExp(
    r'^((?:[1-3]\s+)?[^\d:]+?)\s+(\d+)(?:[:\.](\d+)(?:\s*[-–]\s*(\d+))?)?$',
  );

  static final RegExp _inlineColonNumbersRegExp = RegExp(
    r'\b(\d+)[:\.](\d+)(?:\s*[-–]\s*(\d+))?\b',
  );

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

  static String normalizeLangCode(String lang) {
    final String lower = lang.trim().toLowerCase();
    if (lower.startsWith("en")) return "en";
    if (lower.startsWith("es")) return "es";
    return "pt-BR";
  }

  /// Resolves the target TTS voice configuration (`name` and `locale`) for a
  /// given language (`pt-BR`, `en`, `es`) and gender (`Female`, `Male`).
  static Map<String, String> resolveVoiceConfig(String lang, String gender) {
    final String normalizedLang = normalizeLangCode(lang);
    final String normalizedGender = gender == "Male" ? "Male" : "Female";
    return Map<String, String>.from(
      _voiceProfiles[normalizedLang]![normalizedGender]!,
    );
  }

  static String _expandNumberedBookPrefix(String book, String normalizedLang) {
    final String trimmed = book.trim();
    if (normalizedLang == "en") {
      if (trimmed.startsWith("1 ")) {
        return "First ${trimmed.substring(2).trim()}";
      } else if (trimmed.startsWith("2 ")) {
        return "Second ${trimmed.substring(2).trim()}";
      } else if (trimmed.startsWith("3 ")) {
        return "Third ${trimmed.substring(2).trim()}";
      }
    }
    return trimmed;
  }

  /// Formats a Bible reference (e.g. `Philippians 4:11`, `Salmos 23:1-4`, `Juan 3:16`)
  /// into natural spoken language so TTS engines never interpret `4:11` as clock time
  /// (`"four and eleven minutes"` / `"four eleven"`).
  static String formatSpokenReference(String reference, String lang) {
    final String trimmed = reference.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return trimmed;

    final String normalizedLang = normalizeLangCode(lang);
    final Match? match = _audioRefRegExp.firstMatch(trimmed);

    if (match != null) {
      final String rawBook = match.group(1)!.trim();
      final String book = _expandNumberedBookPrefix(rawBook, normalizedLang);
      final String chapter = match.group(2)!;
      final String? startVerse = match.group(3);
      final String? endVerse = match.group(4);

      if (normalizedLang == "en") {
        if (startVerse != null && endVerse != null) {
          return "$book, chapter $chapter, verses $startVerse to $endVerse";
        } else if (startVerse != null) {
          return "$book, chapter $chapter, verse $startVerse";
        } else {
          return "$book, chapter $chapter";
        }
      } else if (normalizedLang == "es") {
        if (startVerse != null && endVerse != null) {
          return "$book, capítulo $chapter, versículos $startVerse al $endVerse";
        } else if (startVerse != null) {
          return "$book, capítulo $chapter, versículo $startVerse";
        } else {
          return "$book, capítulo $chapter";
        }
      } else {
        // pt-BR
        if (startVerse != null && endVerse != null) {
          return "$book, capítulo $chapter, versículos $startVerse a $endVerse";
        } else if (startVerse != null) {
          return "$book, capítulo $chapter, versículo $startVerse";
        } else {
          return "$book, capítulo $chapter";
        }
      }
    }

    // Fallback: replace any inline `X:Y` or `X:Y-Z` pattern so it is never read as time
    return trimmed.replaceAllMapped(_inlineColonNumbersRegExp, (m) {
      final String ch = m.group(1)!;
      final String v1 = m.group(2)!;
      final String? v2 = m.group(3);
      if (normalizedLang == "en") {
        return v2 != null
            ? "chapter $ch, verses $v1 to $v2"
            : "chapter $ch, verse $v1";
      } else if (normalizedLang == "es") {
        return v2 != null
            ? "capítulo $ch, versículos $v1 al $v2"
            : "capítulo $ch, versículo $v1";
      } else {
        return v2 != null
            ? "capítulo $ch, versículos $v1 a $v2"
            : "capítulo $ch, versículo $v1";
      }
    });
  }

  /// Builds the full spoken narration script with documentary-style pauses
  /// between the reference announcement and the verse text.
  static String buildSpokenScript({
    required String verse,
    required String reference,
    required String lang,
  }) {
    final String cleanVerse = verse.trim();
    final String spokenRef = formatSpokenReference(reference, lang);
    if (spokenRef.isEmpty) {
      return cleanVerse;
    }
    return "$spokenRef... $cleanVerse";
  }

  Future<void> _configureNarratorVoice(
    Map<String, String> voiceConfig,
    String targetLocale,
  ) async {
    await _flutterTts.setLanguage(targetLocale);
    await _flutterTts.setVoice(voiceConfig);
    await _flutterTts.setSpeechRate(documentarySpeechRate);
    await _flutterTts.setPitch(documentaryPitch);
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
      await _configureNarratorVoice(voiceConfig, targetLocale);
      final String textToRead = buildSpokenScript(
        verse: verse,
        reference: reference,
        lang: lang,
      );
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
      await _configureNarratorVoice(voiceConfig, targetLocale);
      final String textToRead = buildSpokenScript(
        verse: verse,
        reference: reference,
        lang: lang,
      );

      if (Platform.isAndroid) {
        final String fileName =
            "verse_audio_${DateTime.now().millisecondsSinceEpoch}.wav";
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          await _flutterTts.awaitSynthCompletion(true);
          await _flutterTts.synthesizeToFile(textToRead, fileName);
          await Future.delayed(const Duration(milliseconds: 800));
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
