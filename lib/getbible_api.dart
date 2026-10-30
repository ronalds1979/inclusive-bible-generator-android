import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'book_mapping.dart';
import 'package:flutter/foundation.dart'; // added for kDebugMode and debugPrint

class GetBibleAPI {
  static const String baseUrl = "https://api.getbible.net/v2";

  static Future<List<Map<String, String>>> getVersions({
    String lang = "en",
  }) async {
    try {
      if (lang.length < 2) return [];
      String langPrefix = lang.substring(0, 2).toLowerCase();
      if (langPrefix == "pt") {
        return [
          {"id": "almeida", "name": "Almeida Atualizada"},
          {"id": "livre", "name": "Bíblia Livre"},
        ];
      } else if (langPrefix == "en") {
        return [
          {"id": "web", "name": "World English Bible"},
          {"id": "kjv", "name": "King James Version"},
          {"id": "asv", "name": "American Standard Version"},
          {"id": "bbe", "name": "Bible in Basic English"},
        ];
      } else if (langPrefix == "es") {
        return [
          {"id": "valera", "name": "Reina Valera (1909)"},
          {"id": "sse", "name": "Sagradas Escrituras (1569)"},
        ];
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching versions: \$e");
      }
      return [];
    }
  }

  static Map<String, String?> _parseReference(
    String reference, {
    String lang = "en",
  }) {
    String langPrefix = lang.length >= 2
        ? lang.substring(0, 2).toLowerCase()
        : "en";
    Map<String, int> mapping = bookMapping[langPrefix] ?? bookMapping["en"]!;

    RegExp regExp = RegExp(
      r'^((?:\d\s+)?[a-zA-ZáéíóúãõçñÁÉÍÓÚÃÕÇÑ]+(?:\s+[a-zA-ZáéíóúãõçñÁÉÍÓÚÃÕÇÑ]+)*)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$',
    );
    Match? match = regExp.firstMatch(reference.trim());

    if (match == null) {
      return {
        "book_nr": null,
        "chapter": null,
        "start_verse": null,
        "end_verse": null,
      };
    }

    String bookName = match.group(1)!.trim();
    String chapter = match.group(2)!;
    String? startVerse = match.group(3);
    String? endVerse = match.group(4);

    int? bookNr;
    // ⚡ Bolt: Fast-path optimization to avoid O(N) loop and repeated
    // string allocations by checking for an exact match first.
    if (mapping.containsKey(bookName)) {
      bookNr = mapping[bookName];
    } else {
      // Cache the lowercased bookName to avoid redundant string operations in the loop
      String lowerBookName = bookName.toLowerCase();
      for (var entry in mapping.entries) {
        if (entry.key.toLowerCase() == lowerBookName) {
          bookNr = entry.value;
          break;
        }
      }
    }

    return {
      "book_nr": bookNr?.toString(),
      "chapter": chapter,
      "start_verse": startVerse,
      "end_verse": endVerse,
    };
  }

  static Future<String?> getPassage(
    String bibleId,
    String reference, {
    String lang = "en",
  }) async {
    Map<String, String?> parsed = _parseReference(reference, lang: lang);
    String? bookNr = parsed["book_nr"];
    String? chapter = parsed["chapter"];
    String? startVerse = parsed["start_verse"];
    String? endVerse = parsed["end_verse"];

    if (bookNr == null || chapter == null) {
      return null;
    }

    String safeBibleId = Uri.encodeComponent(bibleId);
    String safeBookNr = Uri.encodeComponent(bookNr);
    String safeChapter = Uri.encodeComponent(chapter);
    String url = "$baseUrl/$safeBibleId/$safeBookNr/$safeChapter.json";

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        List verses = data["verses"] ?? [];

        if (startVerse != null) {
          int startIdx = int.parse(startVerse) - 1;
          int endIdx = endVerse != null
              ? int.parse(endVerse)
              : int.parse(startVerse);

          if (startIdx >= 0 && startIdx < verses.length) {
            int endIndex = endIdx > verses.length ? verses.length : endIdx;
            List selectedVerses = verses.sublist(startIdx, endIndex);
            return selectedVerses.map((v) => v["text"] ?? "").join(" ").trim();
          }
          return null;
        } else {
          return verses.map((v) => v["text"] ?? "").join(" ").trim();
        }
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching passage: \$e");
      }
      return null;
    }
  }
}
