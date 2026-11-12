import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class Generator {
  Map<String, Map<String, dynamic>> locales = {};
  static final RegExp _templateRegex = RegExp(r'\{([^}]+)\}');
  static const Map<String, String> _langAliasMap = {
    "Português (Brasil)": "pt-BR",
    "Português": "pt-BR",
    "English (US/UK)": "en",
    "English": "en",
    "Español (España)": "es",
    "Español": "es",
  };

  Future<void> loadLocales() async {
    const List<String> langCodes = ["pt-BR", "en", "es"];
    // ⚡ Bolt: Load locale JSON files concurrently at startup instead of sequentially
    await Future.wait(langCodes.map((langCode) async {
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
    }));
  }

  String getLocaleString(
    String lang,
    String key, {
    Map<String, String>? kwargs,
  }) {
    // ⚡ Bolt: O(1) fast-path + alias map lookup instead of chained .replaceAll() calls
    if (!locales.containsKey(lang)) {
      lang = _langAliasMap[lang] ?? "pt-BR";
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
