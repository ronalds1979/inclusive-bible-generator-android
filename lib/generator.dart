import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class Generator {
  Map<String, Map<String, dynamic>> locales = {};
  static final RegExp _templateRegex = RegExp(r'\{([^}]+)\}');

  Future<void> loadLocales() async {
    const List<String> langCodes = ["pt-BR", "en", "es"];
    for (final String langCode in langCodes) {
      try {
        final String jsonString = await rootBundle.loadString(
          "locales/$langCode.json",
        );
        locales[langCode] = json.decode(jsonString);
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Error loading locale $langCode: $e");
        }
      }
    }
  }

  String getLocaleString(
    String lang,
    String key, {
    Map<String, String>? kwargs,
  }) {
    // ⚡ Bolt: Fast-path optimization to skip expensive string replacements
    // if the provided language string is already pre-normalized. This reduces
    // unnecessary allocations since this method is called frequently during builds.
    if (!locales.containsKey(lang)) {
      lang = lang
          .replaceAll(" (Brasil)", "")
          .replaceAll("English (US/UK)", "en")
          .replaceAll("Español (España)", "es")
          .replaceAll("Português", "pt-BR");

      if (!locales.containsKey(lang)) {
        lang = "pt-BR";
      }
    }

    String template = locales[lang]?[key] ?? "";
    if (kwargs != null && kwargs.isNotEmpty) {
      template = template.replaceAllMapped(_templateRegex, (match) {
        final matchKey = match.group(1);
        return kwargs[matchKey] ?? match.group(0)!;
      });
    }
    return template;
  }

  Future<Map<String, String>> generateTexts(
    String lang,
    String verse,
    String reference, {
    String? customDescription,
  }) async {
    final String description =
        (customDescription != null && customDescription.trim().isNotEmpty)
        ? customDescription.trim()
        : getLocaleString(lang, "default_description");
    final String altText = getLocaleString(
      lang,
      "alt_text_template",
      kwargs: {
        "description": description,
        "verse": verse,
        "reference": reference,
      },
    );
    final String caption = getLocaleString(
      lang,
      "caption_template",
      kwargs: {"verse": verse, "reference": reference},
    );
    return {"altText": altText, "caption": caption};
  }
}
