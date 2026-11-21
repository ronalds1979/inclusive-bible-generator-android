import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  static const int maxSpokenLength = 200;

  static final RegExp _spokenRefRegex = RegExp(
    r'^((?:[1-3]\s+)?[^\d]+?)\s+(?:(?:chapter|cap[ií]tulo|cap\.?)\s+)?(\d+)(?:\s*(?:[:.,]|(?:verses?|vers[ií]culos?|v\.?))\s*(\d+)(?:\s*(?:[-–]|(?:to|through|a|al|at[eé]))\s*(\d+))?|\s+(\d+)(?:\s*(?:[-–]|(?:to|through|a|al|at[eé]))\s*(\d+))?)?$',
    caseSensitive: false,
  );

  /// Normalizes natural spoken Bible references in English, Portuguese, and
  /// Spanish (e.g. `"John chapter 3 verse 16"`, `"Salmos 23 versículo 1 ao 4"`,
  /// `"Juan 3 versículo 16"`) into standard `"Book Chapter:Verse(-EndVerse)"`.
  static String normalizeSpokenReference(String rawSpoken) {
    final String trimmed = rawSpoken.trim();
    if (trimmed.isEmpty || trimmed.length > maxSpokenLength) {
      return trimmed.length > maxSpokenLength
          ? trimmed.substring(0, maxSpokenLength)
          : trimmed;
    }
    final String cleaned = trimmed
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\b(ao|aos)\b', caseSensitive: false), 'a')
        .replaceAll(RegExp(r'\bprimeiro\b', caseSensitive: false), '1')
        .replaceAll(RegExp(r'\bprimeira\b', caseSensitive: false), '1')
        .replaceAll(RegExp(r'\bprimero\b', caseSensitive: false), '1')
        .replaceAll(RegExp(r'\bprimera\b', caseSensitive: false), '1')
        .replaceAll(RegExp(r'\bfirst\b', caseSensitive: false), '1')
        .replaceAll(RegExp(r'\bsegundo\b', caseSensitive: false), '2')
        .replaceAll(RegExp(r'\bsegunda\b', caseSensitive: false), '2')
        .replaceAll(RegExp(r'\bsecond\b', caseSensitive: false), '2')
        .replaceAll(RegExp(r'\bterceiro\b', caseSensitive: false), '3')
        .replaceAll(RegExp(r'\bterceira\b', caseSensitive: false), '3')
        .replaceAll(RegExp(r'\btercero\b', caseSensitive: false), '3')
        .replaceAll(RegExp(r'\btercera\b', caseSensitive: false), '3')
        .replaceAll(RegExp(r'\bthird\b', caseSensitive: false), '3');

    final RegExpMatch? match = _spokenRefRegex.firstMatch(cleaned);
    if (match == null) return cleaned;

    final String book = match.group(1)!.trim();
    final String chapter = match.group(2)!;
    final String? verse = match.group(3) ?? match.group(5);
    final String? endVerse = match.group(4) ?? match.group(6);

    if (verse == null) {
      return '$book $chapter:1';
    }
    if (endVerse != null) {
      return '$book $chapter:$verse-$endVerse';
    }
    return '$book $chapter:$verse';
  }
}
