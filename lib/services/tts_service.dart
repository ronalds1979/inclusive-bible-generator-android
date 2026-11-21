import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'temp_file_cleanup.dart';

class TtsVoiceSelection {
  final Map<String, String>? voice;
  final String targetLocale;
  final double pitch;

  const TtsVoiceSelection({
    required this.voice,
    required this.targetLocale,
    required this.pitch,
  });
}

class TtsService {
  final FlutterTts _flutterTts;

  /// Calm, measured documentary narrator speech rate for `flutter_tts`
  /// (where `0.5` is normal 1.0x speed on Android, so `0.42` is ~16% slower,
  /// matching the `-15%` documentary narrator pace across pt-BR, en, and es).
  static const double documentarySpeechRate = 0.42;

  /// Slightly warm, grounded narrator pitch when a matching voice is used.
  static const double documentaryPitch = 0.95;

  /// Deeper pitch fallback when the device lacks a dedicated Male voice pack.
  /// Kept at 0.80 (rather than <0.70) to avoid robotic DSP vocoder distortion.
  static const double maleFallbackPitch = 0.80;

  /// Higher pitch fallback when only a Male voice pack is available for Female.
  static const double femaleFallbackPitch = 1.10;

  static final RegExp _audioRefRegExp = RegExp(
    r'^((?:[1-3]\s+)?[^\d:]+?)\s+(\d+)(?:[:\.](\d+)(?:\s*[-–]\s*(\d+))?)?$',
  );

  static final RegExp _inlineColonNumbersRegExp = RegExp(
    r'\b(\d+)[:\.](\d+)(?:\s*[-–]\s*(\d+))?\b',
  );

  static final RegExp _explicitMaleNameRegExp = RegExp(
    r'(?:^|[-_#.\s])male(?:$|[-_#.\s\d])|-m-|smtm\d*',
  );

  static final RegExp _explicitFemaleNameRegExp = RegExp(
    r'female|-f-|smtf\d*',
  );

  // ⚡ Bolt: Pre-compile voice name tokenizer instead of allocating a RegExp per voice
  static final RegExp _voiceTokenSplitRegExp = RegExp(r'[-_#.\s]+');
  static final RegExp _featureSplitRegExp = RegExp(r'[\t,;\s]+');

  /// Minimum WAV byte length (44-byte RIFF/WAVE header + at least 1 audio byte).
  static const int _minValidWavBytes = 44;

  /// Guard timeout for Android `synthesizeToFile` when the engine fails silently.
  static const Duration _synthTimeout = Duration(seconds: 20);

  static const Set<String> _maleVoiceTokens = {
    'iol',
    'iom',
    'tpd',
    'ptd',
    'jmn',
    'pmj',
    'rjs',
    'esd',
    'esf',
    'gbb',
    'gbd',
    'aub',
    'aud',
    'eed',
    'eef',
    'sfd',
    'antonio',
    'guy',
    'alvaro',
    'daniel',
    'jorge',
    'carlos',
    'diego',
    'pedro',
    'lucas',
    'mateus',
    'tiago',
    'felipe',
    'ricardo',
    'arthur',
    'oliver',
    'matthew',
    'david',
    'mark',
    'james',
  };

  static const Set<String> _femaleVoiceTokens = {
    'sfg',
    'iog',
    'tpc',
    'tpf',
    'pte',
    'gba',
    'gbc',
    'aua',
    'auc',
    'ana',
    'eea',
    'eec',
    'eee',
    'sfb',
    'afs',
    'francisca',
    'jenny',
    'elvira',
    'luciana',
    'maria',
    'monica',
    'paulina',
    'samantha',
    'victoria',
    'karen',
    'kate',
    'helena',
    'sofia',
    'camila',
    'laura',
    'marisol',
  };

  List<dynamic>? _cachedDeviceVoices;
  final bool? _isAndroidOverride;
  final Future<Directory> Function()? _tempDirProvider;

  TtsService({
    FlutterTts? flutterTts,
    @visibleForTesting bool? isAndroidOverride,
    @visibleForTesting Future<Directory> Function()? tempDirProvider,
  }) : _flutterTts = flutterTts ?? FlutterTts(),
       _isAndroidOverride = isAndroidOverride,
       _tempDirProvider = tempDirProvider;

  static const Map<String, String> _defaultLocales = {
    "pt-BR": "pt-BR",
    "en": "en-US",
    "es": "es-ES",
  };

  static String normalizeLangCode(String lang) {
    final String lower = lang.trim().toLowerCase();
    if (lower.startsWith("en")) return "en";
    if (lower.startsWith("es")) return "es";
    return "pt-BR";
  }

  static String resolveTargetLocale(String lang) {
    return _defaultLocales[normalizeLangCode(lang)]!;
  }

  /// Classifies a TTS voice map as `"Male"`, `"Female"`, or `null` if unknown.
  static String? detectVoiceGender(Map<dynamic, dynamic> voice) {
    final String explicitGender = (voice["gender"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
    if (explicitGender == "male") return "Male";
    if (explicitGender == "female") return "Female";

    final String name = (voice["name"] ?? "").toString().trim().toLowerCase();
    if (name.isEmpty) return null;

    // Check female before male because "female" contains "male".
    if (_explicitFemaleNameRegExp.hasMatch(name)) return "Female";
    if (_explicitMaleNameRegExp.hasMatch(name)) return "Male";

    final List<String> tokens = name.split(_voiceTokenSplitRegExp);
    for (final String token in tokens) {
      if (_femaleVoiceTokens.contains(token)) return "Female";
      if (_maleVoiceTokens.contains(token)) return "Male";
    }
    return null;
  }

  static bool _matchesLanguage(String locale, String normalizedLang) {
    final String lower = locale.trim().toLowerCase().replaceAll('_', '-');
    if (normalizedLang == "en") return lower == "en" || lower.startsWith("en-");
    if (normalizedLang == "es") return lower == "es" || lower.startsWith("es-");
    return lower == "pt" || lower.startsWith("pt-");
  }

  /// Returns `true` when Android reports `KEY_FEATURE_NOT_INSTALLED`
  /// (`"notInstalled"`) in the voice's `features` metadata.
  static bool isVoiceNotInstalled(Map<dynamic, dynamic> voice) {
    final String features = (voice["features"] ?? "").toString().toLowerCase();
    if (features.isEmpty) return false;
    return features.split(_featureSplitRegExp).contains("notinstalled");
  }

  /// Returns `true` when the voice requires a network connection to synthesize.
  static bool isNetworkVoice(Map<dynamic, dynamic> voice) {
    final String networkRequired = (voice["network_required"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
    if (networkRequired == "1" || networkRequired == "true") {
      return true;
    }
    final String name = (voice["name"] ?? "").toString().trim().toLowerCase();
    return name.contains("-network");
  }

  static int _scoreVoice(
    Map<dynamic, dynamic> voice,
    String normalizedLang,
    String normalizedGender,
  ) {
    int score = 0;

    // Prefer locally installed offline voices over network voices of the same
    // gender (+800), while still allowing a genuine matching-gender neural
    // network voice (+1500) to beat a wrong-gender local voice (-1500) so we
    // avoid robotic pitch-shifting whenever a real Male/Female voice exists.
    // `generateAudio` automatically falls back to the local default voice if
    // a network voice fails to synthesize offline.
    if (!isNetworkVoice(voice)) {
      score += 800;
    }

    final String? detectedGender = detectVoiceGender(voice);
    if (detectedGender == normalizedGender) {
      score += 1500;
    } else if (detectedGender != null) {
      score -= 1500;
    }

    final String locale = (voice["locale"] ?? "")
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', '-');
    if (normalizedLang == "pt-BR" && locale == "pt-br") {
      score += 100;
    } else if (normalizedLang == "en" && locale == "en-us") {
      score += 100;
    } else if (normalizedLang == "es") {
      if (locale == "es-es") {
        score += 50;
      } else if (locale == "es-us" || locale == "es-419" || locale == "es-mx") {
        score += 25;
      }
    }

    final String quality = (voice["quality"] ?? "").toString().toLowerCase();
    if (quality == "very high") {
      score += 15;
    } else if (quality == "high") {
      score += 10;
    } else if (quality == "normal") {
      score += 5;
    }

    return score;
  }

  /// Selects the best matching device voice and narrator pitch from [rawVoices]
  /// for the given [lang] (`pt-BR`, `en`, `es`) and [gender] (`Female`, `Male`).
  static TtsVoiceSelection selectVoiceFromAvailable(
    List<dynamic>? rawVoices,
    String lang,
    String gender,
  ) {
    final String normalizedLang = normalizeLangCode(lang);
    final String normalizedGender = gender == "Male" ? "Male" : "Female";
    final String fallbackLocale = resolveTargetLocale(normalizedLang);

    if (rawVoices == null || rawVoices.isEmpty) {
      return TtsVoiceSelection(
        voice: null,
        targetLocale: fallbackLocale,
        pitch: normalizedGender == "Male"
            ? maleFallbackPitch
            : documentaryPitch,
      );
    }

    final List<Map<dynamic, dynamic>> candidates = rawVoices
        .whereType<Map<dynamic, dynamic>>()
        .where((v) {
          final String name = (v["name"] ?? "").toString().trim();
          final String locale = (v["locale"] ?? "").toString().trim();
          return name.isNotEmpty &&
              locale.isNotEmpty &&
              !isVoiceNotInstalled(v) &&
              _matchesLanguage(locale, normalizedLang);
        })
        .toList();

    if (candidates.isEmpty) {
      return TtsVoiceSelection(
        voice: null,
        targetLocale: fallbackLocale,
        pitch: normalizedGender == "Male"
            ? maleFallbackPitch
            : documentaryPitch,
      );
    }

    Map<dynamic, dynamic> bestVoice = candidates.first;
    int bestScore = _scoreVoice(bestVoice, normalizedLang, normalizedGender);
    for (int i = 1; i < candidates.length; i++) {
      final int score = _scoreVoice(
        candidates[i],
        normalizedLang,
        normalizedGender,
      );
      if (score > bestScore) {
        bestScore = score;
        bestVoice = candidates[i];
      }
    }

    final String? bestGender = detectVoiceGender(bestVoice);
    double pitch = documentaryPitch;
    if (bestGender != normalizedGender) {
      if (normalizedGender == "Male") {
        pitch = maleFallbackPitch;
      } else if (bestGender == "Male") {
        pitch = femaleFallbackPitch;
      }
    }

    final String selectedLocale = bestVoice["locale"].toString().trim();
    return TtsVoiceSelection(
      voice: {
        "name": bestVoice["name"].toString().trim(),
        "locale": selectedLocale,
      },
      targetLocale: selectedLocale,
      pitch: pitch,
    );
  }

  Future<TtsVoiceSelection> resolveDeviceVoice(
    String lang,
    String gender,
  ) async {
    if (_cachedDeviceVoices != null) {
      return selectVoiceFromAvailable(_cachedDeviceVoices, lang, gender);
    }
    try {
      final dynamic voices = await _flutterTts.getVoices;
      if (voices is List) {
        if (voices.isNotEmpty) {
          _cachedDeviceVoices = voices;
        }
        return selectVoiceFromAvailable(voices, lang, gender);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching TTS voices: $e");
      }
    }
    return selectVoiceFromAvailable(null, lang, gender);
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

  Future<void> _clearVoiceSafely() async {
    try {
      await _flutterTts.clearVoice();
    } catch (_) {
      // Some platforms/engines do not support clearVoice; setLanguage below
      // will still reset the active locale voice.
    }
  }

  Future<TtsVoiceSelection> _configureNarratorVoice(
    String lang,
    String gender,
  ) async {
    final TtsVoiceSelection selection = await resolveDeviceVoice(lang, gender);
    if (selection.voice == null) {
      await _clearVoiceSafely();
    }
    await _flutterTts.setLanguage(selection.targetLocale);
    if (selection.voice != null) {
      await _flutterTts.setVoice(selection.voice!);
    }
    await _flutterTts.setSpeechRate(documentarySpeechRate);
    await _flutterTts.setPitch(selection.pitch);
    return selection;
  }

  static Future<bool> _isValidAudioFile(String path) async {
    final File file = File(path);
    if (!await file.exists()) return false;
    final int length = await file.length();
    return length > _minValidWavBytes;
  }

  static Future<void> _deleteFileQuietly(String path) async {
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<bool> _synthesizeToFileSafely(String text, String fullPath) async {
    final Completer<bool> errorCompleter = Completer<bool>();
    final ErrorHandler? previousErrorHandler = _flutterTts.errorHandler;
    _flutterTts.setErrorHandler((dynamic message) {
      if (kDebugMode) {
        debugPrint("TTS synthesis error: $message");
      }
      if (!errorCompleter.isCompleted) {
        errorCompleter.complete(false);
      }
      previousErrorHandler?.call(message);
    });

    try {
      await _flutterTts.awaitSynthCompletion(true);
      final Future<bool> synthFuture = _flutterTts
          .synthesizeToFile(text, fullPath, true)
          .then((dynamic res) => res == 1 || res == true)
          .catchError((Object e) {
            if (kDebugMode) {
              debugPrint("Error in synthesizeToFile: $e");
            }
            return false;
          });

      final bool succeeded = await Future.any<bool>([
        synthFuture,
        errorCompleter.future,
      ]).timeout(_synthTimeout, onTimeout: () => false);

      if (!succeeded) {
        await _flutterTts.stop();
        return false;
      }
      return await _isValidAudioFile(fullPath);
    } finally {
      _flutterTts.errorHandler = previousErrorHandler;
    }
  }

  Future<void> speakPreview({
    required String verse,
    required String reference,
    required String lang,
    required String gender,
    void Function(int start, int end)? onWordProgress,
  }) async {
    try {
      await _flutterTts.stop();
      await _configureNarratorVoice(lang, gender);
      final String textToRead = buildSpokenScript(
        verse: verse,
        reference: reference,
        lang: lang,
      );
      if (onWordProgress != null) {
        _flutterTts.setProgressHandler((
          String text,
          int start,
          int end,
          String word,
        ) {
          onWordProgress(start, end);
        });
      }
      await _flutterTts.speak(textToRead);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error playing TTS preview: $e");
      }
    } finally {
      if (onWordProgress != null) {
        _flutterTts.setProgressHandler((_, _, _, _) {});
      }
    }
  }

  Future<String?> generateAudio({
    required String verse,
    required String reference,
    required String lang,
    required String gender,
  }) async {
    try {
      if (!(_isAndroidOverride ?? Platform.isAndroid)) {
        return null;
      }

      final String textToRead = buildSpokenScript(
        verse: verse,
        reference: reference,
        lang: lang,
      );
      if (textToRead.trim().isEmpty) {
        return null;
      }

      final Directory dir = await (_tempDirProvider ?? getTemporaryDirectory)();
      await pruneTransientFiles(dir, prefix: 'verse_audio_', suffix: '.wav');

      await _flutterTts.stop();
      final TtsVoiceSelection selection = await _configureNarratorVoice(
        lang,
        gender,
      );

      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final String fullPath = "${dir.path}/verse_audio_$timestamp.wav";
      if (await _synthesizeToFileSafely(textToRead, fullPath)) {
        return fullPath;
      }
      await _deleteFileQuietly(fullPath);

      // Fallback: if an explicit device voice failed to synthesize (e.g. voice
      // pack unavailable or network synthesis error), reset to the engine's
      // default installed voice for the target locale and retry once.
      if (selection.voice != null) {
        await _flutterTts.stop();
        await _clearVoiceSafely();
        await _flutterTts.setLanguage(resolveTargetLocale(lang));
        await _flutterTts.setSpeechRate(documentarySpeechRate);
        await _flutterTts.setPitch(
          gender == "Male" ? maleFallbackPitch : documentaryPitch,
        );
        final String fallbackPath =
            "${dir.path}/verse_audio_${timestamp}_fallback.wav";
        if (await _synthesizeToFileSafely(textToRead, fallbackPath)) {
          return fallbackPath;
        }
        await _deleteFileQuietly(fallbackPath);
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
