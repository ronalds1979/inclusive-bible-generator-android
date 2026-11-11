import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GeminiService {
  static const String endpoint =
      "https://generativelanguage.googleapis.com/v1beta/interactions";
  static const String apiRevision = "2026-05-20";
  static const String imageModel = "gemini-nano-banana-2.1";
  static const String _keyFileName = ".gemini_api_key";

  static const List<String> styleKeys = [
    "style_nature",
    "style_watercolor",
    "style_cinematic",
    "style_oil_painting",
    "style_minimalist",
  ];

  static const Map<String, String> _stylePrompts = {
    "style_nature":
        "serene natural landscape, soft atmospheric lighting, peaceful scenery",
    "style_watercolor":
        "soft artistic watercolor painting, gentle pastel brushstrokes, expressive texture",
    "style_cinematic":
        "cinematic warm golden hour lighting, volumetric rays, inspiring depth of field",
    "style_oil_painting":
        "classical fine art oil painting, rich warm textures, timeless composition",
    "style_minimalist":
        "minimalist abstract background, subtle gradients, calm contemplative aesthetic",
  };

  final http.Client _httpClient;

  GeminiService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<File> _getKeyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File("${dir.path}/$_keyFileName");
  }

  Future<String?> loadApiKey() async {
    try {
      final file = await _getKeyFile();
      if (await file.exists()) {
        final key = (await file.readAsString()).trim();
        return key.isNotEmpty ? key : null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error loading Gemini API key: $e");
      }
    }
    return null;
  }

  Future<void> saveApiKey(String apiKey) async {
    try {
      final file = await _getKeyFile();
      final trimmed = apiKey.trim();
      if (trimmed.isEmpty) {
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        await file.writeAsString(trimmed, flush: true);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error saving Gemini API key: $e");
      }
    }
  }

  static String buildBackgroundPrompt({
    required String verse,
    required String reference,
    String styleKey = "style_nature",
    String customPrompt = "",
  }) {
    // 🛡️ Sentinel: Enforce length limits on user-controlled prompt inputs to prevent DoS
    final String safeVerse =
        verse.length > 5000 ? verse.substring(0, 5000) : verse;
    final String safeReference =
        reference.length > 500 ? reference.substring(0, 500) : reference;
    final String safeCustomPrompt = customPrompt.length > 1000
        ? customPrompt.substring(0, 1000)
        : customPrompt;

    final String styleDescription =
        _stylePrompts[styleKey] ?? _stylePrompts["style_nature"]!;
    final StringBuffer buffer = StringBuffer();
    buffer.write(
      "Create an inspiring, respectful background illustration symbolically aligned with the Bible passage ",
    );
    if (safeReference.trim().isNotEmpty) {
      buffer.write('"${safeReference.trim()}": ');
    }
    buffer.write('"$safeVerse". ');
    buffer.write("Visual style: $styleDescription. ");
    if (safeCustomPrompt.trim().isNotEmpty) {
      buffer.write("Additional visual details: ${safeCustomPrompt.trim()}. ");
    }
    buffer.write(
      "Important: Do NOT include any text, letters, words, numbers, typography, or watermarks in the image, as text will be overlaid later.",
    );
    return buffer.toString();
  }

  static Uint8List? extractImageBytesFromResponse(Map<String, dynamic> data) {
    // 🛡️ Sentinel: Guard base64Decode against malformed payloads or oversized strings (> 28MB base64 ~ 20MB binary)
    Uint8List? tryDecodeBase64(String b64) {
      if (b64.isEmpty || b64.length > 28 * 1024 * 1024) return null;
      try {
        return base64Decode(b64);
      } on FormatException {
        return null;
      }
    }

    final outputImage = data["output_image"];
    if (outputImage is Map<String, dynamic>) {
      final b64 = outputImage["data"];
      if (b64 is String) {
        final decoded = tryDecodeBase64(b64);
        if (decoded != null) return decoded;
      }
    }

    final steps = data["steps"];
    if (steps is List) {
      for (int i = steps.length - 1; i >= 0; i--) {
        final step = steps[i];
        if (step is Map<String, dynamic> && step["type"] == "model_output") {
          final content = step["content"];
          if (content is List) {
            for (int j = content.length - 1; j >= 0; j--) {
              final block = content[j];
              if (block is Map<String, dynamic> && block["type"] == "image") {
                final b64 = block["data"];
                if (b64 is String) {
                  final decoded = tryDecodeBase64(b64);
                  if (decoded != null) return decoded;
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  Future<Uint8List?> generateBackgroundImage({
    required String apiKey,
    required String verse,
    required String reference,
    String aspectRatio = "1:1",
    String styleKey = "style_nature",
    String customPrompt = "",
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty || verse.trim().isEmpty) {
      return null;
    }

    final prompt = buildBackgroundPrompt(
      verse: verse.trim(),
      reference: reference.trim(),
      styleKey: styleKey,
      customPrompt: customPrompt,
    );

    final validRatios = {"1:1", "3:4", "4:3", "16:9", "9:16"};
    final targetRatio = validRatios.contains(aspectRatio) ? aspectRatio : "1:1";

    final requestBody = jsonEncode({
      "model": imageModel,
      "input": [
        {"type": "text", "text": prompt},
      ],
      "response_format": {
        "type": "image",
        "aspect_ratio": targetRatio,
        "image_size": "1K",
      },
    });

    try {
      final response = await _httpClient
          .post(
            Uri.parse(endpoint),
            headers: {
              "x-goog-api-key": trimmedKey,
              "Content-Type": "application/json",
              "Api-Revision": apiRevision,
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        return extractImageBytesFromResponse(decoded);
      } else {
        if (kDebugMode) {
          debugPrint(
            "Gemini API error (${response.statusCode}): ${response.body}",
          );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error generating Gemini background image: $e");
      }
      return null;
    }
  }
}
