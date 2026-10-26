import 'dart:convert';
import 'package:http/http.dart' as http;
import 'book_mapping.dart';

class GetBibleAPI {
  static const String baseUrl = "https://api.getbible.net/v2";

  static Future<List<Map<String, String>>> getVersions({
    String lang = "en",
  }) async {
    try {
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
      print("Error fetching versions: \$e");
      return [];
    }
  }

  static Map<String, String?> _parseReference(
    String reference, {
    String lang = "en",
  }) {
    String langPrefix = lang.substring(0, 2).toLowerCase();
    Map<String, int> mapping = bookMapping[langPrefix] ?? bookMapping["en"]!;

    RegExp regExp = RegExp(
      r'^((?:\d\s+)?[a-zA-ZáéíóúãõçñÁÉÍÓÚÃÕÇÑ\s]+?)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$',
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
    for (var entry in mapping.entries) {
      if (entry.key.toLowerCase() == bookName.toLowerCase()) {
        bookNr = entry.value;
        break;
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

    String url = "$baseUrl/$bibleId/$bookNr/$chapter.json";

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
      print("Error fetching passage: \$e");
      return null;
    }
  }
}
