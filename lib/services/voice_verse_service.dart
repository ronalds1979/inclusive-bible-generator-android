import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../getbible_api.dart';

/// Zero-cost on-device voice-to-verse bridge using Android's built-in
/// `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` system activity.
class VoiceVerseService {
  static const MethodChannel _defaultChannel = MethodChannel(
    'com.ronalds1979.inclusivebible/voice_input',
  );

  final MethodChannel _channel;
  final bool? _isAndroidOverride;

  const VoiceVerseService({
    MethodChannel? channel,
    @visibleForTesting bool? isAndroidOverride,
  }) : _channel = channel ?? _defaultChannel,
       _isAndroidOverride = isAndroidOverride;

  bool get _isAndroid => _isAndroidOverride ?? (!kIsWeb && Platform.isAndroid);

  Future<bool> isAvailable() async {
    if (!_isAndroid) return false;
    try {
      return (await _channel.invokeMethod<bool>('isAvailable')) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> listenForVerse({
    required String locale,
    required String prompt,
  }) async {
    if (!_isAndroid) return null;
    try {
      final String? spoken = await _channel.invokeMethod<String>(
        'listenForVerse',
        {'locale': locale, 'prompt': prompt},
      );
      final String trimmed = (spoken ?? '').trim();
      return trimmed.isEmpty ? null : trimmed;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Listens for a spoken Bible reference and returns up to 5 ranked
  /// recognition candidates from Android's `RecognizerIntent.EXTRA_RESULTS`.
  Future<List<String>> listenForVerseCandidates({
    required String locale,
    required String prompt,
  }) async {
    if (!_isAndroid) return const [];
    try {
      final List<String>? raw = await _channel.invokeListMethod<String>(
        'listenForVerseCandidates',
        {'locale': locale, 'prompt': prompt},
      );
      if (raw != null) {
        return raw
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
    } on MissingPluginException {
      // Fall back to single-result `listenForVerse` (also supports test doubles
      // that only override `listenForVerse`).
    } on PlatformException {
      return const [];
    } catch (_) {
      return const [];
    }
    final String? single = await listenForVerse(locale: locale, prompt: prompt);
    if (single == null || single.trim().isEmpty) return const [];
    return [single.trim()];
  }

  static const int maxSpokenLength = 200;

  static final RegExp _edgePunctuationRegex = RegExp(
    r'^[¿¡.,;:!?\s]+|[.,;:!?\s]+$',
  );
  static final RegExp _symbolicOrdinalPrefixRegex = RegExp(
    r'^([1-3])(?:\.?\s*[ªº°]|(?:ra|ro|er|da|do|a|o)\b\.?)\s+',
    caseSensitive: false,
  );
  static final RegExp _leadingBookIntroRegex = RegExp(
    r'^(?:el\s+|la\s+|los\s+|las\s+|o\s+|a\s+)?(?:libro\s+de\s+(?:los\s+|las\s+)?|evangelio\s+(?:seg[uú]n|de)\s+|carta\s+(?:a\s+(?:los\s+)?|de\s+)|ep[ií]stola\s+(?:a\s+(?:los\s+)?|de\s+))',
    caseSensitive: false,
  );
  static final RegExp _numberedBookConnectorRegex = RegExp(
    r'^([1-3])\s+(?:(?:libro|carta|ep[ií]stola)\s+)?(?:de\s+(?:los\s+|las\s+)?|del\s+|a\s+(?:los\s+|las\s+)?|do\s+|da\s+)',
    caseSensitive: false,
  );

  static const Map<String, int> _spanishUnits = {
    'uno': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
  };

  static const Map<String, int> _spanishTeensAndTwenties = {
    'diez': 10,
    'once': 11,
    'doce': 12,
    'trece': 13,
    'catorce': 14,
    'quince': 15,
    'dieciséis': 16,
    'dieciseis': 16,
    'diecisiete': 17,
    'dieciocho': 18,
    'diecinueve': 19,
    'veinte': 20,
    'veintiuno': 21,
    'veintidós': 22,
    'veintidos': 22,
    'veintitrés': 23,
    'veintitres': 23,
    'veinticuatro': 24,
    'veinticinco': 25,
    'veintiséis': 26,
    'veintiseis': 26,
    'veintisiete': 27,
    'veintiocho': 28,
    'veintinueve': 29,
  };

  static const Map<String, int> _spanishTens = {
    'treinta': 30,
    'cuarenta': 40,
    'cincuenta': 50,
    'sesenta': 60,
    'setenta': 70,
    'ochenta': 80,
    'noventa': 90,
  };

  static final RegExp _spanishCompoundTensRegex = RegExp(
    r'\b(treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa)\s+y\s+(uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve)\b',
    caseSensitive: false,
  );

  static final RegExp _spanishSingleNumberRegex = RegExp(
    r'\b(veintinueve|veintiocho|veintisiete|veintis[eé]is|veinticinco|veinticuatro|veintitr[eé]s|veintid[oó]s|veintiuno|veinte|diecinueve|dieciocho|diecisiete|diecis[eé]is|quince|catorce|trece|doce|once|diez|noventa|ochenta|setenta|sesenta|cincuenta|cuarenta|treinta|nueve|ocho|siete|seis|cinco|cuatro|tres|dos|uno)\b',
    caseSensitive: false,
  );

  static final RegExp _spanishCientoWithNumberRegex = RegExp(
    r'\bciento\s+(\d{1,2})\b',
    caseSensitive: false,
  );

  static final RegExp _spanishCienRegex = RegExp(
    r'\bcien\b',
    caseSensitive: false,
  );

  /// Converts spoken Spanish cardinal number words (1..199) into digits so
  /// transcripts like `"Génesis uno uno"` or `"Salmo veintitrés versículo uno"`
  /// parse cleanly.
  static String _replaceSpanishNumberWords(String input) {
    String result = input.replaceAllMapped(_spanishCompoundTensRegex, (m) {
      final int tens = _spanishTens[m.group(1)!.toLowerCase()] ?? 0;
      final int unit = _spanishUnits[m.group(2)!.toLowerCase()] ?? 0;
      return '${tens + unit}';
    });

    result = result.replaceAllMapped(_spanishSingleNumberRegex, (m) {
      final String word = m.group(1)!.toLowerCase();
      final int? value =
          _spanishTeensAndTwenties[word] ??
          _spanishTens[word] ??
          _spanishUnits[word];
      return value != null ? '$value' : m.group(0)!;
    });

    result = result.replaceAllMapped(_spanishCientoWithNumberRegex, (m) {
      final int remainder = int.tryParse(m.group(1)!) ?? 0;
      return '${100 + remainder}';
    });

    result = result.replaceAll(_spanishCienRegex, '100');
    return result;
  }

  // ⚡ Bolt: Pre-compile spoken-reference normalization RegExps once and collapse
  // 15 sequential ordinal word passes into a single regex + O(1) map lookup.
  static final RegExp _multiSpaceRegex = RegExp(r'\s+');
  static final RegExp _dosPuntosRegex = RegExp(
    r'\bdos\s+puntos\b',
    caseSensitive: false,
  );
  static final RegExp _portugueseRangePrepRegex = RegExp(
    r'\b(ao|aos)\b',
    caseSensitive: false,
  );
  static final RegExp _spanishHastaRegex = RegExp(
    r'\bhasta(?:\s+(?:el|la))?\b',
    caseSensitive: false,
  );
  static const Map<String, String> _ordinalWordMap = {
    'primeiro': '1',
    'primeira': '1',
    'primero': '1',
    'primera': '1',
    'primer': '1',
    'first': '1',
    'segundo': '2',
    'segunda': '2',
    'second': '2',
    'terceiro': '3',
    'terceira': '3',
    'tercero': '3',
    'tercera': '3',
    'tercer': '3',
    'third': '3',
  };
  static final RegExp _ordinalWordRegex = RegExp(
    r'\b(primeir[oa]|primer[oa]?|first|segund[oa]|second|terceir[oa]|tercer[oa]?|third)\b',
    caseSensitive: false,
  );

  static final RegExp _spokenRefRegex = RegExp(
    r'^((?:[1-3]\s+)?[^\d]+?)\s+(?:(?:chapter|cap[ií]tulo|cap\.?)\s+)?(?:n[uú]mero\s+)?(\d+)(?:(?:\s*[:.,;]\s*|\s+(?:y|con|en\s+el)\s+|\s+)(?:(?:verses?|vers[ií]culos?|versos?|vv?\.?)\s+)?(?:(?:del|desde\s+el|do|from)\s+)?(\d+)(?:\s*(?:[-–]|,?\s*(?:to|through|a|al|at[eé]))\s*(\d+))?)?$',
    caseSensitive: false,
  );

  /// Normalizes natural spoken Bible references in English, Portuguese, and
  /// Spanish (e.g. `"John chapter 3 verse 16"`, `"Salmos 23 versículo 1 ao 4"`,
  /// `"Primera de Corintios 13 versículos del 4 al 7"`, `"Salmo 23"`) into
  /// standard `"Book Chapter:Verse(-EndVerse)"`.
  static String normalizeSpokenReference(String rawSpoken) {
    final String trimmed = rawSpoken.trim();
    if (trimmed.isEmpty || trimmed.length > maxSpokenLength) {
      return trimmed.length > maxSpokenLength
          ? trimmed.substring(0, maxSpokenLength)
          : trimmed;
    }
    String cleaned = trimmed
        .replaceAll(_edgePunctuationRegex, '')
        .replaceAll(_multiSpaceRegex, ' ');
    if (cleaned.isEmpty) return trimmed;

    cleaned = cleaned
        .replaceAll(_dosPuntosRegex, ':')
        .replaceAll(_portugueseRangePrepRegex, 'a')
        .replaceAll(_spanishHastaRegex, 'al')
        .replaceAllMapped(
          _ordinalWordRegex,
          (m) => _ordinalWordMap[m.group(1)!.toLowerCase()] ?? m.group(0)!,
        )
        .replaceFirstMapped(_symbolicOrdinalPrefixRegex, (m) => '${m.group(1)} ')
        .replaceFirst(_leadingBookIntroRegex, '')
        .replaceFirstMapped(_numberedBookConnectorRegex, (m) => '${m.group(1)} ')
        .replaceAll(_multiSpaceRegex, ' ')
        .trim();

    cleaned = _replaceSpanishNumberWords(cleaned);

    final RegExpMatch? match = _spokenRefRegex.firstMatch(cleaned);
    if (match == null) return cleaned;

    final String book = match.group(1)!.trim();
    final String chapter = match.group(2)!;
    final String? verse = match.group(3);
    final String? endVerse = match.group(4);

    if (verse == null) {
      return '$book $chapter:1';
    }
    if (endVerse != null) {
      return '$book $chapter:$verse-$endVerse';
    }
    return '$book $chapter:$verse';
  }

  /// Picks the first candidate from Android's `EXTRA_RESULTS` that normalizes
  /// and parses to a recognized Bible book & chapter in [lang], falling back
  /// to normalizing the first candidate when none resolves.
  static String selectBestCandidate(
    List<String> candidates, {
    String lang = 'en',
  }) {
    String? fallback;
    for (final String raw in candidates) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final String normalized = normalizeSpokenReference(trimmed);
      fallback ??= normalized;
      final Map<String, String?> parsed = GetBibleAPI.parseReference(
        normalized,
        lang: lang,
      );
      if (parsed['book_nr'] != null && parsed['chapter'] != null) {
        return normalized;
      }
    }
    return fallback ?? '';
  }
}
