import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'book_mapping.dart';

class GetBibleAPI {
  static const String baseUrl = "https://api.getbible.net/v2";
  static const String bollsBaseUrl = "https://bolls.life/get-text";
  static const String youVersionBaseUrl = "https://api.youversion.com/v1";
  static const String youVersionPortalUrl = "https://platform.youversion.com/";
  static const String defaultYouVersionApiKey = String.fromEnvironment(
    'YOUVERSION_API_KEY',
  );
  static const String _yvSecureKeyName = "youversion_api_key";
  static const String _legacyYvKeyFileName = ".youversion_api_key";
  static const FlutterSecureStorage _defaultSecureStorage =
      FlutterSecureStorage();

  static final RegExp _referenceRegExp = RegExp(
    r'^((?:\d\s+)?[a-zA-ZáéíóúâêôãõçñÁÉÍÓÚÂÊÔÃÕÇÑ]+(?:\s+[a-zA-ZáéíóúâêôãõçñÁÉÍÓÚÂÊÔÃÕÇÑ]+)*)\s+(\d+)(?::(\d+)(?:-(\d+))?)?$',
  );

  // ⚡ Bolt: Pre-compute lowercase book mappings once so case-insensitive
  // fallback lookups are O(1) instead of O(N) with per-entry .toLowerCase() allocations.
  static final Map<String, Map<String, int>> _lowercaseBookMapping = {
    for (final langEntry in bookMapping.entries)
      langEntry.key: {
        for (final bookEntry in langEntry.value.entries)
          bookEntry.key.toLowerCase(): bookEntry.value,
      },
  };

  /// Maps version IDs to `bolls.life` translation codes that return verified, clean Scripture text.
  static const Map<String, String> _bollsVersionMap = {
    // Portuguese (pt)
    "naa": "NAA",
    "ara": "ARA",
    "nvt": "NVT",
    "ntlh": "NTLH",
    "acf": "ACF11",
    "arc": "ARC09",
    "kja": "KJA",
    "vfl": "VFL",
    "cnbb": "CNBB",
    "alm21": "ALM21",
    // English (en)
    "web": "WEB",
    "bsb": "BSB",
    "esv": "ESV",
    "nlt": "NLT",
    "nkjv": "NKJV",
    "csb": "CSB17",
    "nasb": "NASB",
    // Spanish (es)
    "rv1960": "RV1960",
    "ntv": "NTV",
    "lbla": "LBLA",
    "pdt": "PDT",
    "btx3": "BTX3",
    "rv2004": "RV2004",
  };

  /// Maps version IDs to official YouVersion Platform Bible IDs.
  static const Map<String, int> _youVersionIdMap = {
    "blt": 3254,
    "bsb": 3034,
    "web": 206,
    "asv": 12,
    "cpdv": 42,
    "fbv": 1932,
    "gnv": 2163,
    "lsv": 2660,
    "wmb": 1209,
    "pddpt": 3365,
    "rves": 147,
    "vbl": 3291,
  };

  /// Curated inspiring USFM passages for Verse of the Day fallback.
  static const List<String> _curatedVotdUsfms = [
    "JHN.3.16",
    "PSA.23.1-4",
    "PHP.4.13",
    "JER.29.11",
    "ROM.8.28",
    "ISA.41.10",
    "MAT.11.28-30",
    "PRO.3.5-6",
    "JOS.1.9",
    "PSA.119.105",
    "1CO.13.4-7",
    "GAL.5.22-23",
    "PSA.46.1",
    "ISA.40.31",
    "ROM.12.2",
    "PSA.27.1",
    "JHN.14.27",
    "HEB.11.1",
    "MAT.5.14-16",
    "PSA.91.1-2",
    "2TI.1.7",
    "1PE.5.7",
    "PSA.34.8",
    "LAM.3.22-23",
    "EPH.2.8-9",
    "PSA.121.1-2",
    "ROM.15.13",
    "MIC.6.8",
    "JHN.8.12",
    "PSA.37.4-5",
    "COL.3.14",
  ];

  static Future<File> _getLegacyYvKeyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File("${dir.path}/$_legacyYvKeyFileName");
  }

  static Future<void> _deleteLegacyYvKeyFile() async {
    try {
      final file = await _getLegacyYvKeyFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<String?> loadYouVersionApiKey({
    FlutterSecureStorage? secureStorage,
  }) async {
    final storage = secureStorage ?? _defaultSecureStorage;
    try {
      final stored = await storage.read(key: _yvSecureKeyName);
      if (stored != null && stored.trim().isNotEmpty) {
        await _deleteLegacyYvKeyFile();
        return stored.trim();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error loading YouVersion API key from secure storage: $e");
      }
    }

    // One-time migration from legacy plaintext file
    try {
      final file = await _getLegacyYvKeyFile();
      if (await file.exists()) {
        final raw = (await file.readAsString()).trim();
        await file.delete();
        if (raw.isNotEmpty) {
          await storage.write(key: _yvSecureKeyName, value: raw);
          return raw;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error migrating legacy YouVersion API key: $e");
      }
    }
    return defaultYouVersionApiKey.isNotEmpty ? defaultYouVersionApiKey : null;
  }

  static Future<void> saveYouVersionApiKey(
    String apiKey, {
    FlutterSecureStorage? secureStorage,
  }) async {
    final storage = secureStorage ?? _defaultSecureStorage;
    try {
      final trimmed = apiKey.trim();
      if (trimmed.isEmpty) {
        await storage.delete(key: _yvSecureKeyName);
      } else {
        await storage.write(key: _yvSecureKeyName, value: trimmed);
      }
      await _deleteLegacyYvKeyFile();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error saving YouVersion API key: $e");
      }
    }
  }

  static Future<String?> detectYouVersionKeyFromClipboard() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final String? text = data?.text?.trim();
      if (text != null && text.length >= 16 && text.length <= 128 && !text.contains(' ')) {
        return text;
      }
    } catch (_) {}
    return null;
  }

  static List<Map<String, String>> _getBuiltInVersions(String langPrefix) {
    if (langPrefix == "pt") {
      return [
        {"id": "naa", "name": "Nova Almeida Atualizada (NAA)"},
        {"id": "ara", "name": "Almeida Revista e Atualizada (ARA)"},
        {"id": "nvt", "name": "Nova Versão Transformadora (NVT)"},
        {"id": "ntlh", "name": "Nova Tradução na Linguagem de Hoje (NTLH)"},
        {"id": "yv:3254", "name": "Bíblia Livre Para Todos (BLT • YouVersion)"},
        {"id": "acf", "name": "Almeida Corrigida Fiel (ACF)"},
        {"id": "arc", "name": "Almeida Revista e Corrigida (ARC)"},
        {"id": "kja", "name": "Bíblia King James Atualizada (KJA)"},
        {"id": "vfl", "name": "Versão Fácil de Ler (VFL)"},
        {"id": "cnbb", "name": "Bíblia CNBB"},
        {"id": "alm21", "name": "Almeida Século 21 (A21)"},
        {"id": "almeida", "name": "Almeida Atualizada (Clássica)"},
        {"id": "livre", "name": "Bíblia Livre"},
      ];
    } else if (langPrefix == "en") {
      return [
        {"id": "web", "name": "World English Bible"},
        {"id": "bsb", "name": "Berean Standard Bible (BSB • YouVersion)"},
        {"id": "esv", "name": "English Standard Version (ESV)"},
        {"id": "nlt", "name": "New Living Translation (NLT)"},
        {"id": "nkjv", "name": "New King James Version (NKJV)"},
        {"id": "csb", "name": "Christian Standard Bible (CSB)"},
        {"id": "nasb", "name": "New American Standard Bible (NASB)"},
        {"id": "yv:1932", "name": "Free Bible Version (FBV • YouVersion)"},
        {"id": "yv:2163", "name": "Geneva Bible (GNV • YouVersion)"},
        {"id": "yv:2660", "name": "Literal Standard Version (LSV • YouVersion)"},
        {"id": "yv:42", "name": "Catholic Public Domain Version (CPDV • YouVersion)"},
        {"id": "yv:1209", "name": "World Messianic Bible (WMB • YouVersion)"},
        {"id": "kjv", "name": "King James Version"},
        {"id": "asv", "name": "American Standard Version"},
        {"id": "bbe", "name": "Bible in Basic English"},
      ];
    } else if (langPrefix == "es") {
      return [
        {"id": "rv1960", "name": "Reina-Valera 1960 (RVR1960)"},
        {"id": "ntv", "name": "Nueva Traducción Viviente (NTV)"},
        {"id": "lbla", "name": "La Biblia de las Américas (LBLA)"},
        {"id": "pdt", "name": "Palabra de Dios para Todos (PDT)"},
        {"id": "yv:3291", "name": "Versión Biblia Libre (VBL • YouVersion)"},
        {"id": "yv:3365", "name": "Palabra de Dios para ti (PdDpt • YouVersion)"},
        {"id": "yv:147", "name": "Reina-Valera Antigua (RVES • YouVersion)"},
        {"id": "btx3", "name": "La Biblia Textual (BTX3)"},
        {"id": "rv2004", "name": "Reina Valera Gómez (RV2004)"},
        {"id": "valera", "name": "Reina Valera (1909)"},
        {"id": "sse", "name": "Sagradas Escrituras (1569)"},
      ];
    }
    return [];
  }

  static Future<List<Map<String, String>>> getVersions({
    String lang = "en",
    String? youVersionApiKey,
    http.Client? httpClient,
  }) async {
    try {
      if (lang.length < 2) return [];
      final String langPrefix = lang.substring(0, 2).toLowerCase();
      final List<Map<String, String>> builtIn = _getBuiltInVersions(langPrefix);
      final String effectiveKey =
          (youVersionApiKey != null && youVersionApiKey.trim().isNotEmpty)
              ? youVersionApiKey.trim()
              : defaultYouVersionApiKey;

      if (effectiveKey.isNotEmpty) {
        final List<Map<String, String>> yvVersions =
            await fetchYouVersionBibles(
              langPrefix: langPrefix,
              apiKey: effectiveKey,
              httpClient: httpClient,
            );
        if (yvVersions.isNotEmpty) {
          final Set<String> seenIds = {};
          final Set<String> seenNames = {};
          final List<Map<String, String>> combined = [];
          for (final v in [...builtIn, ...yvVersions]) {
            if (seenIds.add(v["id"]!) && seenNames.add(v["name"]!)) {
              combined.add(v);
            }
          }
          return combined;
        }
      }
      return builtIn;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching versions: $e");
      }
      return [];
    }
  }

  /// Queries `GET https://api.youversion.com/v1/bibles?language_ranges[]={lang}`
  /// using the `X-YVP-App-Key` header.
  static Future<List<Map<String, String>>> fetchYouVersionBibles({
    required String langPrefix,
    required String apiKey,
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    final String iso3 = langPrefix == "pt"
        ? "por"
        : (langPrefix == "es" ? "spa" : "eng");
    final Uri uri = Uri.parse(
      "$youVersionBaseUrl/bibles?language_ranges%5B%5D=$langPrefix&language_ranges%5B%5D=$iso3&page_size=50",
    );

    try {
      final response = await client
          .get(
            uri,
            headers: {
              "X-YVP-App-Key": apiKey,
              "Accept": "application/json",
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> items = (decoded is Map<String, dynamic> && decoded["data"] is List)
            ? decoded["data"] as List<dynamic>
            : (decoded is List ? decoded : []);

        final List<Map<String, String>> result = [];
        for (final item in items) {
          if (item is Map<String, dynamic> && item["id"] != null) {
            final String id = item["id"].toString();
            final String abbr =
                (item["abbreviation"] ?? item["local_abbreviation"] ?? "")
                    .toString()
                    .trim();
            final String title =
                (item["title"] ?? item["name"] ?? item["local_title"] ?? "Bible $id")
                    .toString()
                    .trim();
            final String displayName = abbr.isNotEmpty && !title.contains(abbr)
                ? "$title ($abbr • YouVersion)"
                : "$title (YouVersion)";
            result.add({"id": "yv:$id", "name": displayName});
          }
        }
        return result;
      } else {
        if (kDebugMode) {
          debugPrint(
            "YouVersion /v1/bibles status (${response.statusCode}): ${response.body}",
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error calling YouVersion /v1/bibles: $e");
      }
    }
    return [];
  }

  static Map<String, String?> _parseReference(
    String reference, {
    String lang = "en",
  }) {
    String langPrefix = lang.length >= 2
        ? lang.substring(0, 2).toLowerCase()
        : "en";
    Map<String, int> mapping = bookMapping[langPrefix] ?? bookMapping["en"]!;

    Match? match = _referenceRegExp.firstMatch(reference.trim());

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

    int? bookNr = mapping[bookName];
    if (bookNr == null) {
      // Check across all languages so a user can type or switch languages seamlessly
      for (final prefix in [langPrefix, "pt", "en", "es"]) {
        final Map<String, int>? lowerMap = _lowercaseBookMapping[prefix];
        if (lowerMap != null) {
          bookNr = lowerMap[bookName.toLowerCase()];
          if (bookNr != null) break;
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

  /// Cleans footnote tags (`<sup>...</sup>`), Strong's numbers (`<S>...</S>`),
  /// and HTML markup from verse text.
  static String cleanVerseText(String raw) {
    String text = raw;
    // Remove footnote and Strong's number tags along with their inner content
    text = text.replaceAll(
      RegExp(r'<(sup|S)\b[^>]*>.*?</\1>', caseSensitive: false, dotAll: true),
      '',
    );
    // Remove remaining HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // Remove stray circled footnote markers or bracketed numbers if any remain
    text = text.replaceAll(RegExp(r'[\u24B6-\u24E9\u2460-\u2473]'), '');
    text = text.replaceAll(RegExp(r'\[\d+\]'), '');
    // Collapse multiple spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static Future<String?> getPassage(
    String bibleId,
    String reference, {
    String lang = "en",
    String? youVersionApiKey,
    http.Client? httpClient,
  }) async {
    final Map<String, String?> parsed = _parseReference(reference, lang: lang);
    final String? bookNrStr = parsed["book_nr"];
    final String? chapter = parsed["chapter"];
    final String? startVerse = parsed["start_verse"];
    final String? endVerse = parsed["end_verse"];

    if (bookNrStr == null || chapter == null) {
      return null;
    }

    final int? bookNr = int.tryParse(bookNrStr);
    if (bookNr == null) return null;

    // Validate range early to prevent invalid start > end requests
    if (startVerse != null && endVerse != null) {
      final int? s = int.tryParse(startVerse);
      final int? e = int.tryParse(endVerse);
      if (s != null && e != null && e < s) {
        return null;
      }
    }

    final client = httpClient ?? http.Client();
    final String normalizedId = bibleId.trim().toLowerCase();
    final String effectiveYvKey =
        (youVersionApiKey != null && youVersionApiKey.trim().isNotEmpty)
            ? youVersionApiKey.trim()
            : defaultYouVersionApiKey;

    // 1. Try YouVersion Platform API (`/v1/bibles/{id}/passages/{usfm}?format=text`)
    // if `bibleId` is a `yv:<id>` version OR if `effectiveYvKey` is set for a mapped version
    int? yvBibleId;
    if (normalizedId.startsWith("yv:")) {
      yvBibleId = int.tryParse(normalizedId.substring(3));
    } else if (effectiveYvKey.isNotEmpty &&
        _youVersionIdMap.containsKey(normalizedId)) {
      yvBibleId = _youVersionIdMap[normalizedId];
    }

    if (yvBibleId != null && effectiveYvKey.isNotEmpty) {
      final String? usfmRef = buildUsfmReference(
        bookNr: bookNr,
        chapter: chapter,
        startVerse: startVerse,
        endVerse: endVerse,
      );
      if (usfmRef != null) {
        final String? yvText = await _fetchFromYouVersion(
          bibleId: yvBibleId,
          usfmRef: usfmRef,
          apiKey: effectiveYvKey,
          client: client,
        );
        if (yvText != null && yvText.isNotEmpty) {
          return yvText;
        }
      }
    }

    // 2. Try verified high-accuracy translations via `bolls.life`
    final String? bollsCode = _bollsVersionMap[normalizedId];
    if (bollsCode != null) {
      final String? bollsText = await _fetchFromBolls(
        translationCode: bollsCode,
        bookNr: bookNr,
        chapter: chapter,
        startVerse: startVerse,
        endVerse: endVerse,
        client: client,
      );
      if (bollsText != null && bollsText.isNotEmpty) {
        return bollsText;
      }
    }

    // 3. Fallback to GetBible v2 (`api.getbible.net/v2`)
    return _fetchFromGetBible(
      bibleId: bibleId,
      bookNr: bookNrStr,
      chapter: chapter,
      startVerse: startVerse,
      endVerse: endVerse,
      client: client,
    );
  }

  static Future<String?> _fetchFromYouVersion({
    required int bibleId,
    required String usfmRef,
    required String apiKey,
    required http.Client client,
  }) async {
    final Uri uri = Uri.parse(
      "$youVersionBaseUrl/bibles/$bibleId/passages/${Uri.encodeComponent(usfmRef)}?format=text",
    );
    try {
      final response = await client
          .get(
            uri,
            headers: {
              "X-YVP-App-Key": apiKey,
              "Accept": "application/json",
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final dynamic content =
              decoded["content"] ??
              (decoded["data"] is Map<String, dynamic>
                  ? (decoded["data"] as Map<String, dynamic>)["content"]
                  : null);
          if (content is String && content.trim().isNotEmpty) {
            return cleanVerseText(content);
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            "YouVersion passage error (${response.statusCode}): ${response.body}",
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching YouVersion passage: $e");
      }
    }
    return null;
  }

  static Future<String?> _fetchFromBolls({
    required String translationCode,
    required int bookNr,
    required String chapter,
    required String? startVerse,
    required String? endVerse,
    required http.Client client,
  }) async {
    final Uri uri = Uri.parse(
      "$bollsBaseUrl/${Uri.encodeComponent(translationCode)}/$bookNr/${Uri.encodeComponent(chapter)}/",
    );
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          if (startVerse != null) {
            final int startV = int.parse(startVerse);
            final int endV = endVerse != null ? int.parse(endVerse) : startV;
            if (endV < startV) return null;

            final List<String> matched = [];
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                final int? vNum = (item["verse"] is int)
                    ? item["verse"] as int
                    : int.tryParse(item["verse"]?.toString() ?? "");
                if (vNum != null && vNum >= startV && vNum <= endV) {
                  final String cleaned = cleanVerseText(
                    (item["text"] ?? "").toString(),
                  );
                  if (cleaned.isNotEmpty) {
                    matched.add(cleaned);
                  }
                }
              }
            }
            return matched.isNotEmpty ? matched.join(" ") : null;
          } else {
            final List<String> allVerses = [];
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                final String cleaned = cleanVerseText(
                  (item["text"] ?? "").toString(),
                );
                if (cleaned.isNotEmpty) {
                  allVerses.add(cleaned);
                }
              }
            }
            return allVerses.isNotEmpty ? allVerses.join(" ") : null;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching Bolls passage ($translationCode): $e");
      }
    }
    return null;
  }

  static Future<String?> _fetchFromGetBible({
    required String bibleId,
    required String bookNr,
    required String chapter,
    required String? startVerse,
    required String? endVerse,
    required http.Client client,
  }) async {
    String safeBibleId = Uri.encodeComponent(bibleId);
    String safeBookNr = Uri.encodeComponent(bookNr);
    String safeChapter = Uri.encodeComponent(chapter);
    String url = "$baseUrl/$safeBibleId/$safeBookNr/$safeChapter.json";

    try {
      final response = await client
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
            if (endIndex < startIdx) return null;
            List selectedVerses = verses.sublist(startIdx, endIndex);
            return selectedVerses
                .map((v) => cleanVerseText((v["text"] ?? "").toString()))
                .join(" ")
                .trim();
          }
          return null;
        } else {
          return verses
              .map((v) => cleanVerseText((v["text"] ?? "").toString()))
              .join(" ")
              .trim();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching GetBible passage: $e");
      }
    }
    return null;
  }

  /// Fetches the YouVersion Verse of the Day (`GET /v1/verse-of-the-days/{day}`)
  /// or resolves a daily curated passage in the requested language and Bible version.
  static Future<Map<String, String>?> getVerseOfTheDay({
    required String lang,
    required String bibleId,
    String? youVersionApiKey,
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    final DateTime now = DateTime.now();
    final int dayOfYear =
        now.difference(DateTime(now.year, 1, 1)).inDays + 1;

    String? usfmPassage;

    final String effectiveYvKey =
        (youVersionApiKey != null && youVersionApiKey.trim().isNotEmpty)
            ? youVersionApiKey.trim()
            : defaultYouVersionApiKey;

    // 1. Query YouVersion `/v1/verse-of-the-days/{day}` using the embedded/configured API key
    if (effectiveYvKey.isNotEmpty) {
      final Uri votdUri = Uri.parse(
        "$youVersionBaseUrl/verse-of-the-days/${dayOfYear.clamp(1, 366)}",
      );
      try {
        final response = await client
            .get(
              votdUri,
              headers: {
                "X-YVP-App-Key": effectiveYvKey,
                "Accept": "application/json",
              },
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic rawUsfm =
                decoded["passage_id"] ??
                decoded["usfm"] ??
                (decoded["data"] is Map<String, dynamic>
                    ? (decoded["data"] as Map<String, dynamic>)["passage_id"]
                    : null);
            if (rawUsfm is String && rawUsfm.trim().isNotEmpty) {
              usfmPassage = rawUsfm.trim();
            } else if (rawUsfm is List && rawUsfm.isNotEmpty) {
              usfmPassage = rawUsfm.first.toString().trim();
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Error fetching YouVersion VOTD: $e");
        }
      }
    }

    // 2. Fallback to curated daily USFM if YouVersion VOTD wasn't returned
    usfmPassage ??=
        _curatedVotdUsfms[(dayOfYear - 1) % _curatedVotdUsfms.length];

    // Parse USFM e.g. "JHN.3.16" or "PSA.23.1-4" or "PSA.23.1-PSA.23.4"
    final Map<String, String>? resolved = resolveUsfmToLocalizedReference(
      usfmPassage,
      lang: lang,
    );
    if (resolved == null) return null;

    final String localizedReference = resolved["reference"]!;
    final String? text = await getPassage(
      bibleId,
      localizedReference,
      lang: lang,
      youVersionApiKey: youVersionApiKey,
      httpClient: client,
    );
    if (text == null || text.isEmpty) return null;

    return {
      "book": resolved["book"]!,
      "chapter": resolved["chapter"]!,
      "verse": resolved["verse"]!,
      "reference": localizedReference,
      "text": text,
    };
  }

  /// Converts a USFM passage ID like `JHN.3.16` or `PSA.23.1-4` into a localized
  /// book name, chapter, verse string, and human-readable reference.
  static Map<String, String>? resolveUsfmToLocalizedReference(
    String usfmPassage, {
    String lang = "pt",
  }) {
    final String cleaned = usfmPassage.trim().toUpperCase();
    // Handle ranges like "PSA.23.1-PSA.23.4" or "PSA.23.1-4" or single "JHN.3.16"
    final List<String> rangeParts = cleaned.split('-');
    final List<String> startTokens = rangeParts.first.split('.');
    if (startTokens.length < 2) return null;

    final String bookUsfm = startTokens[0];
    final int? bookNr = usfmToBookNr[bookUsfm];
    if (bookNr == null) return null;

    final String? bookName = getBookNameByNumber(bookNr, lang);
    if (bookName == null) return null;

    final String chapter = startTokens[1];
    String versePart = startTokens.length >= 3 ? startTokens[2] : "1";

    if (rangeParts.length > 1) {
      final List<String> endTokens = rangeParts.last.split('.');
      final String endVerse = endTokens.last;
      if (endVerse.isNotEmpty && endVerse != versePart) {
        versePart = "$versePart-$endVerse";
      }
    }

    final String reference = "$bookName $chapter:$versePart";
    return {
      "book": bookName,
      "chapter": chapter,
      "verse": versePart,
      "reference": reference,
    };
  }
}
