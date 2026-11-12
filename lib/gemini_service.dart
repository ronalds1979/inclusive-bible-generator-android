import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GeminiService {
  static const String endpoint =
      "https://generativelanguage.googleapis.com/v1beta/interactions";
  static const String apiRevision = "2026-05-20";
  static const String imageModel = "gemini-nano-banana-2.1";
  static const List<String> _fallbackImageModels = [
    "gemini-3.1-flash-lite-image",
    "gemini-2.5-flash-image",
  ];
  static const List<String> _freeTierSceneModels = [
    "gemini-3.8-flash",
    "gemini-3.5-flash-lite",
    "gemini-flash-latest",
    "gemini-2.5-flash",
  ];
  static const String aiStudioUrl = "https://aistudio.google.com/app/apikey";
  static const String _keyFileName = ".gemini_api_key";

  static final RegExp _apiKeyRegExp = RegExp(r'AIza[0-9A-Za-z\-_]{30,45}');

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
  String? lastError;

  GeminiService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Extracts a Google AI Studio Gemini API key (`AIza...`) from arbitrary text,
  /// returning `null` if no key pattern is present.
  static String? extractApiKeyFromText(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = _apiKeyRegExp.firstMatch(text.trim());
    return match?.group(0);
  }

  /// Checks the system clipboard for a valid Gemini API key (`AIza...`).
  Future<String?> detectApiKeyFromClipboard() async {
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      return extractApiKeyFromText(data?.text);
    } catch (e) {
      debugPrint("Error reading clipboard for Gemini key: $e");
      return null;
    }
  }

  Future<File> _getKeyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File("${dir.path}/$_keyFileName");
  }

  Future<String?> loadApiKey() async {
    try {
      final file = await _getKeyFile();
      if (await file.exists()) {
        final raw = (await file.readAsString()).trim();
        final validKey = extractApiKeyFromText(raw);
        if (validKey != null) {
          return validKey;
        }
        await file.delete();
      }
    } catch (e) {
      debugPrint("Error loading Gemini API key: $e");
    }
    return null;
  }

  Future<void> saveApiKey(String apiKey) async {
    try {
      final file = await _getKeyFile();
      final trimmed = apiKey.trim();
      final extracted = extractApiKeyFromText(trimmed) ?? trimmed;
      if (extracted.isEmpty) {
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        await file.writeAsString(extracted, flush: true);
      }
    } catch (e) {
      debugPrint("Error saving Gemini API key: $e");
    }
  }

  static String buildBackgroundPrompt({
    required String verse,
    required String reference,
    String styleKey = "style_nature",
    String customPrompt = "",
  }) {
    final String styleDescription =
        _stylePrompts[styleKey] ?? _stylePrompts["style_nature"]!;
    final StringBuffer buffer = StringBuffer();
    buffer.write(
      "Create an inspiring, respectful background illustration symbolically aligned with the Bible passage ",
    );
    if (reference.trim().isNotEmpty) {
      buffer.write('"$reference": ');
    }
    buffer.write('"$verse". ');
    buffer.write("Visual style: $styleDescription. ");
    if (customPrompt.trim().isNotEmpty) {
      buffer.write("Additional visual details: ${customPrompt.trim()}. ");
    }
    buffer.write(
      "Important: Do NOT include any text, letters, words, numbers, typography, or watermarks in the image, as text will be overlaid later.",
    );
    return buffer.toString();
  }

  static Uint8List? extractImageBytesFromResponse(Map<String, dynamic> data) {
    final outputImage = data["output_image"];
    if (outputImage is Map<String, dynamic>) {
      final b64 = outputImage["data"];
      if (b64 is String && b64.isNotEmpty) {
        return base64Decode(b64);
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
                if (b64 is String && b64.isNotEmpty) {
                  return base64Decode(b64);
                }
              }
            }
          }
        }
      }
    }

    final outputs = data["outputs"];
    if (outputs is List) {
      for (int i = outputs.length - 1; i >= 0; i--) {
        final block = outputs[i];
        if (block is Map<String, dynamic> && block["type"] == "image") {
          final b64 = block["data"];
          if (b64 is String && b64.isNotEmpty) {
            return base64Decode(b64);
          }
        }
      }
    }

    return null;
  }

  static String? extractTextFromResponse(Map<String, dynamic> data) {
    final outputText = data["output_text"];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText.trim();
    }

    final steps = data["steps"];
    if (steps is List) {
      final buffer = StringBuffer();
      for (final step in steps) {
        if (step is Map<String, dynamic> && step["type"] == "model_output") {
          final content = step["content"];
          if (content is List) {
            for (final block in content) {
              if (block is Map<String, dynamic> &&
                  block["type"] == "text" &&
                  block["text"] is String) {
                buffer.write(block["text"] as String);
              }
            }
          }
        }
      }
      if (buffer.isNotEmpty) {
        return buffer.toString().trim();
      }
    }

    final outputs = data["outputs"];
    if (outputs is List) {
      for (int i = outputs.length - 1; i >= 0; i--) {
        final block = outputs[i];
        if (block is Map<String, dynamic> &&
            block["type"] == "text" &&
            block["text"] is String) {
          return (block["text"] as String).trim();
        }
      }
    }
    return null;
  }

  static String extractErrorMessage(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final err = decoded["error"];
        if (err is Map<String, dynamic> && err["message"] is String) {
          return "HTTP $statusCode: ${err["message"]}";
        }
        final errors = decoded["errors"];
        if (errors is List && errors.isNotEmpty) {
          final first = errors.first;
          if (first is Map<String, dynamic> && first["message"] is String) {
            return "HTTP $statusCode: ${first["message"]}";
          }
        }
      } else if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map<String, dynamic>) {
          final err = first["error"];
          if (err is Map<String, dynamic> && err["message"] is String) {
            return "HTTP $statusCode: ${err["message"]}";
          }
        }
      }
    } catch (_) {}
    final snippet = body.trim();
    if (snippet.isNotEmpty) {
      return "HTTP $statusCode: ${snippet.length > 120 ? '${snippet.substring(0, 120)}...' : snippet}";
    }
    return "HTTP $statusCode";
  }

  Future<Uint8List?> generateBackgroundImage({
    required String apiKey,
    required String verse,
    required String reference,
    String aspectRatio = "1:1",
    String styleKey = "style_nature",
    String customPrompt = "",
  }) async {
    lastError = null;
    final trimmedKey = extractApiKeyFromText(apiKey) ?? apiKey.trim();
    if (trimmedKey.isEmpty || verse.trim().isEmpty) {
      lastError = "Missing API key or verse.";
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

    // Attempt 1: Current Interactions API (`2026-05-20`) with `gemini-nano-banana-2.1`
    final primaryBody = jsonEncode({
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
            body: primaryBody,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final Uint8List? bytes = extractImageBytesFromResponse(decoded);
        if (bytes != null) return bytes;
        lastError = "No image returned in response.";
      } else {
        lastError = extractErrorMessage(response.statusCode, response.body);
        debugPrint(
          "Gemini primary API error (${response.statusCode}): ${response.body}",
        );

        // If the API key itself is invalid or unauthorized, stop immediately
        if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.body.contains("API_KEY_INVALID")) {
          return null;
        }

        // Fallback if `gemini-nano-banana-2.1` hits Free Tier 0-quota (429), 400, or 404
        if (response.statusCode == 429 ||
            response.statusCode == 400 ||
            response.statusCode == 404) {
          final fallbackBytes = await _tryFallbackImageAndFreeTierScene(
            apiKey: trimmedKey,
            prompt: prompt,
            verse: verse.trim(),
            reference: reference.trim(),
            styleKey: styleKey,
            customPrompt: customPrompt.trim(),
            targetRatio: targetRatio,
          );
          if (fallbackBytes != null) {
            lastError = null;
            return fallbackBytes;
          }
        }
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint("Error generating Gemini background image: $e");
    }
    return null;
  }

  Future<Uint8List?> _tryFallbackImageAndFreeTierScene({
    required String apiKey,
    required String prompt,
    required String verse,
    required String reference,
    required String styleKey,
    required String customPrompt,
    required String targetRatio,
  }) async {
    // 1. Try lighter Nano Banana image models first in case they have Free Tier quota
    for (final model in _fallbackImageModels) {
      final body = jsonEncode({
        "model": model,
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
                "x-goog-api-key": apiKey,
                "Content-Type": "application/json",
                "Api-Revision": apiRevision,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = jsonDecode(response.body);
          final Uint8List? bytes = extractImageBytesFromResponse(decoded);
          if (bytes != null) return bytes;
        } else {
          debugPrint(
            "Gemini image fallback ($model) status (${response.statusCode}): ${response.body}",
          );
        }
      } catch (e) {
        debugPrint("Gemini image fallback ($model) exception: $e");
      }
    }

    // 2. Free-Tier Gemini Scene Designer (`gemini-3.8-flash` / `gemini-3.5-flash-lite`)
    // Google AI Studio Free Tier sets `limit: 0 requests per day on Free Tier` on raster
    // Nano Banana models in many regions unless billing is attached, whereas Gemini Flash
    // text models have generous Free Tier quota. We ask Gemini Flash to compose a bespoke
    // visual scene specification for the verse and render it on a high-res Canvas.
    final int randomSalt = DateTime.now().millisecondsSinceEpoch % 100000;
    final String sceneRequestPrompt =
        '''
Design a BRIGHT, LUMINOUS, uplifting background illustration scene inspired by this Bible passage:
Reference: "$reference"
Verse: "$verse"
Visual Style: "$styleKey" (${_stylePrompts[styleKey] ?? ""})
Extra scene details: "$customPrompt"
Variation seed: $randomSalt

Return ONLY a JSON object with these keys:
{
  "skyColors": ["#HEX_TOP", "#HEX_UPPER_MID", "#HEX_LOWER_MID", "#HEX_HORIZON"],
  "glowColor": "#HEX_GLOW",
  "celestialType": "sun" | "moon" | "star" | "rays_only" | "none",
  "lightX": 0.5,
  "lightY": 0.28,
  "rayCount": 14,
  "landscapeType": "mountains" | "hills" | "waters" | "dunes" | "minimal",
  "layerColors": ["#HEX_FAR", "#HEX_MID", "#HEX_NEAR", "#HEX_FOREGROUND"],
  "bokehCount": 26,
  "seed": $randomSalt
}
IMPORTANT: Choose BRIGHT, WARM, VIBRANT, DAYLIGHT or GOLDEN-HOUR colors (such as sky blues, warm golden sunlight, soft peach/coral, sunlit emerald/sage greens, turquoise waters, soft lavender, and radiant amber). Avoid dark, black, or navy colors.
''';

    for (final textModel in _freeTierSceneModels) {
      final body = jsonEncode({
        "model": textModel,
        "input": [
          {"type": "text", "text": sceneRequestPrompt},
        ],
      });

      try {
        final response = await _httpClient
            .post(
              Uri.parse(endpoint),
              headers: {
                "x-goog-api-key": apiKey,
                "Content-Type": "application/json",
                "Api-Revision": apiRevision,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = jsonDecode(response.body);
          final String? rawText = extractTextFromResponse(decoded);
          if (rawText != null && rawText.isNotEmpty) {
            final Map<String, dynamic>? sceneSpec = _parseJsonMapFromText(
              rawText,
            );
            if (sceneSpec != null) {
              final Uint8List? rendered = await renderSceneToPng(
                sceneSpec: sceneSpec,
                aspectRatio: targetRatio,
                styleKey: styleKey,
              );
              if (rendered != null) return rendered;
            }
          }
        } else {
          lastError = extractErrorMessage(response.statusCode, response.body);
          debugPrint(
            "Gemini Free-Tier Scene ($textModel) error (${response.statusCode}): ${response.body}",
          );
        }
      } catch (e) {
        debugPrint("Gemini Free-Tier Scene ($textModel) exception: $e");
      }
    }

    return null;
  }

  static Map<String, dynamic>? _parseJsonMapFromText(String rawText) {
    try {
      String cleaned = rawText.trim();
      final int firstBrace = cleaned.indexOf('{');
      final int lastBrace = cleaned.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace > firstBrace) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  static Color _parseHexColor(dynamic hexStr, Color fallback) {
    if (hexStr is! String) return fallback;
    String cleaned = hexStr.trim().replaceAll('#', '');
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    if (cleaned.length == 8) {
      final int? val = int.tryParse(cleaned, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  /// Ensures a color is bright and luminous enough so backgrounds never look too dark.
  static Color _ensureMinLightness(Color color, double minLightness) {
    final HSLColor hsl = HSLColor.fromColor(color);
    if (hsl.lightness < minLightness) {
      final double boosted =
          (minLightness + (hsl.lightness * 0.35)).clamp(minLightness, 0.85);
      return hsl
          .withLightness(boosted)
          .withSaturation((hsl.saturation * 1.1).clamp(0.25, 0.90))
          .toColor();
    }
    return color;
  }

  /// Renders a Gemini-authored scene specification into high-resolution PNG bytes.
  static Future<Uint8List?> renderSceneToPng({
    required Map<String, dynamic> sceneSpec,
    String aspectRatio = "1:1",
    String styleKey = "style_nature",
  }) async {
    try {
      int width = 1080;
      int height = 1080;
      switch (aspectRatio) {
        case "3:4":
          width = 900;
          height = 1200;
          break;
        case "9:16":
          width = 900;
          height = 1600;
          break;
        case "4:3":
          width = 1200;
          height = 900;
          break;
        default:
          width = 1080;
          height = 1080;
      }

      final double w = width.toDouble();
      final double h = height.toDouble();

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

      final int seed = (sceneSpec["seed"] is num)
          ? (sceneSpec["seed"] as num).toInt()
          : 42;
      final math.Random rng = math.Random(seed);

      // 1. Parse and brighten sky palette
      final List<Color> defaultSky = [
        const Color(0xFF4A90E2),
        const Color(0xFF7BC6CC),
        const Color(0xFFF6D365),
        const Color(0xFFFDA085),
      ];
      final List<Color> skyColors = [];
      if (sceneSpec["skyColors"] is List) {
        int idx = 0;
        for (final item in (sceneSpec["skyColors"] as List)) {
          final Color raw = _parseHexColor(
            item,
            defaultSky[idx % defaultSky.length],
          );
          // Keep sky colors bright and airy (lightness >= 0.50..0.64)
          skyColors.add(_ensureMinLightness(raw, 0.50 + (idx * 0.04).clamp(0.0, 0.16)));
          idx++;
        }
      }
      while (skyColors.length < 3) {
        skyColors.add(defaultSky[skyColors.length % defaultSky.length]);
      }

      final Rect fullRect = Rect.fromLTWH(0, 0, w, h);
      final List<double> skyStops = List.generate(
        skyColors.length,
        (i) => i / (skyColors.length - 1),
      );
      final Paint skyPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(w * 0.5, 0),
          Offset(w * 0.5, h),
          skyColors,
          skyStops,
        );
      canvas.drawRect(fullRect, skyPaint);

      // 2. Parse light / celestial source
      final Color glowColor = _ensureMinLightness(
        _parseHexColor(sceneSpec["glowColor"], const Color(0xFFFFF3B0)),
        0.74,
      );
      final String celestialType =
          (sceneSpec["celestialType"] as String?)?.toLowerCase() ?? "sun";
      final double lightX = ((sceneSpec["lightX"] as num?)?.toDouble() ?? 0.5)
          .clamp(0.15, 0.85);
      final double lightY = ((sceneSpec["lightY"] as num?)?.toDouble() ?? 0.28)
          .clamp(0.12, 0.58);
      final Offset lightCenter = Offset(w * lightX, h * lightY);

      // 3. Style-specific soft watercolor / oil washes in the backdrop
      if (styleKey == "style_watercolor" || styleKey == "style_oil_painting") {
        final int washCount = styleKey == "style_watercolor" ? 14 : 10;
        for (int i = 0; i < washCount; i++) {
          final Color washColor = Color.lerp(
            skyColors[i % skyColors.length],
            Colors.white,
            0.25,
          )!.withAlpha(65);
          final double rx = rng.nextDouble() * w;
          final double ry = rng.nextDouble() * h * 0.75;
          final double radius = w * (0.18 + rng.nextDouble() * 0.25);
          final Paint washPaint = Paint()
            ..color = washColor
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55);
          canvas.drawCircle(Offset(rx, ry), radius, washPaint);
        }
      }

      // 4. Volumetric light rays & celestial glow
      if (celestialType != "none") {
        // Large warm atmospheric radial bloom
        final double bloomRadius = math.max(w, h) * 0.75;
        final Paint bloomPaint = Paint()
          ..shader = ui.Gradient.radial(
            lightCenter,
            bloomRadius,
            [
              Colors.white.withAlpha(185),
              glowColor.withAlpha(140),
              glowColor.withAlpha(45),
              glowColor.withAlpha(0),
            ],
            [0.0, 0.22, 0.55, 1.0],
          );
        canvas.drawCircle(lightCenter, bloomRadius, bloomPaint);

        // Volumetric rays
        final int rayCount = ((sceneSpec["rayCount"] as num?)?.toInt() ?? 12)
            .clamp(0, 24);
        if (rayCount > 0 && styleKey != "style_minimalist") {
          final double maxRayLen = math.max(w, h) * 1.3;
          for (int i = 0; i < rayCount; i++) {
            final double baseAngle =
                (i / rayCount) * math.pi * 2 + (rng.nextDouble() * 0.12);
            final double spread = 0.04 + rng.nextDouble() * 0.06;
            final Offset p1 = Offset(
              lightCenter.dx + math.cos(baseAngle - spread) * maxRayLen,
              lightCenter.dy + math.sin(baseAngle - spread) * maxRayLen,
            );
            final Offset p2 = Offset(
              lightCenter.dx + math.cos(baseAngle + spread) * maxRayLen,
              lightCenter.dy + math.sin(baseAngle + spread) * maxRayLen,
            );
            final Path rayPath = Path()
              ..moveTo(lightCenter.dx, lightCenter.dy)
              ..lineTo(p1.dx, p1.dy)
              ..lineTo(p2.dx, p2.dy)
              ..close();
            final Paint rayPaint = Paint()
              ..shader = ui.Gradient.radial(
                lightCenter,
                maxRayLen * 0.85,
                [
                  Colors.white.withAlpha(65),
                  glowColor.withAlpha(28),
                  glowColor.withAlpha(0),
                ],
                [0.0, 0.48, 1.0],
              );
            canvas.drawPath(rayPath, rayPaint);
          }
        }

        // Celestial disc or guiding star
        if (celestialType == "star") {
          final Paint starPaint = Paint()
            ..color = Colors.white.withAlpha(245)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          final double starRadius = w * 0.085;
          final Path starPath = Path()
            ..moveTo(lightCenter.dx, lightCenter.dy - starRadius)
            ..quadraticBezierTo(
              lightCenter.dx,
              lightCenter.dy,
              lightCenter.dx + starRadius,
              lightCenter.dy,
            )
            ..quadraticBezierTo(
              lightCenter.dx,
              lightCenter.dy,
              lightCenter.dx,
              lightCenter.dy + starRadius,
            )
            ..quadraticBezierTo(
              lightCenter.dx,
              lightCenter.dy,
              lightCenter.dx - starRadius,
              lightCenter.dy,
            )
            ..quadraticBezierTo(
              lightCenter.dx,
              lightCenter.dy,
              lightCenter.dx,
              lightCenter.dy - starRadius,
            )
            ..close();
          canvas.drawPath(starPath, starPaint);
        } else if (celestialType == "sun" || celestialType == "moon") {
          final double discRadius =
              w * (celestialType == "moon" ? 0.065 : 0.095);
          final Paint discPaint = Paint()
            ..color = Colors.white.withAlpha(235)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
          canvas.drawCircle(lightCenter, discRadius, discPaint);
        }
      }

      // 5. Landscape / Horizon layers (brightened, colorful atmospheric perspective)
      final List<Color> defaultLayers = [
        const Color(0xFF7CA982),
        const Color(0xFF5C8D76),
        const Color(0xFF427AA1),
        const Color(0xFF356088),
      ];
      final List<Color> layerColors = [];
      if (sceneSpec["layerColors"] is List) {
        int idx = 0;
        for (final item in (sceneSpec["layerColors"] as List)) {
          final Color raw = _parseHexColor(
            item,
            defaultLayers[idx % defaultLayers.length],
          );
          // Distant layers are lighter/hazier (0.48), foreground still colorful (0.36)
          final double minL = (0.48 - idx * 0.04).clamp(0.35, 0.55);
          layerColors.add(_ensureMinLightness(raw, minL));
          idx++;
        }
      }
      while (layerColors.length < 4) {
        layerColors.add(defaultLayers[layerColors.length % defaultLayers.length]);
      }

      final String landscapeType =
          (sceneSpec["landscapeType"] as String?)?.toLowerCase() ?? "hills";

      final int numLayers = landscapeType == "minimal" ? 2 : 4;
      for (int layerIdx = 0; layerIdx < numLayers; layerIdx++) {
        final double progress = layerIdx / math.max(1, numLayers - 1);
        final double baseHeightY = h * (0.58 + progress * 0.27);
        final double amplitude = landscapeType == "mountains"
            ? h * (0.085 - progress * 0.02)
            : (landscapeType == "waters"
                  ? h * 0.015
                  : h * (0.042 - progress * 0.01));

        final Path layerPath = Path()..moveTo(0, h);
        final int segments = landscapeType == "mountains" ? 7 : 5;
        double prevX = 0;
        double prevY =
            baseHeightY + (rng.nextDouble() * 2 - 1) * amplitude * 0.6;
        layerPath.lineTo(prevX, prevY);

        for (int s = 1; s <= segments; s++) {
          final double nextX = (s / segments) * w;
          final double nextY =
              baseHeightY + (rng.nextDouble() * 2 - 1) * amplitude;
          final double ctrlX = (prevX + nextX) / 2;
          final double ctrlY =
              (prevY + nextY) / 2 +
              (rng.nextDouble() * 2 - 1) * amplitude * 0.8;
          layerPath.quadraticBezierTo(ctrlX, ctrlY, nextX, nextY);
          prevX = nextX;
          prevY = nextY;
        }
        layerPath.lineTo(w, h);
        layerPath.close();

        // Blend distant layers softly with the horizon glow so the scene feels sunlit
        final Color rawLayerColor = layerColors[layerIdx % layerColors.length];
        final Color topLayerColor = Color.lerp(
          rawLayerColor,
          skyColors.last,
          (1.0 - progress) * 0.35,
        )!;
        final Color bottomLayerColor = Color.lerp(
          rawLayerColor,
          skyColors.first,
          0.22,
        )!;

        final Paint layerPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(w * 0.5, baseHeightY - amplitude),
            Offset(w * 0.5, h),
            [topLayerColor.withAlpha(235), bottomLayerColor],
          );
        canvas.drawPath(layerPath, layerPaint);

        // Warm sunlit mist between layers
        if (layerIdx < numLayers - 1) {
          final Rect mistRect = Rect.fromLTWH(
            0,
            baseHeightY - h * 0.04,
            w,
            h * 0.12,
          );
          final Paint mistPaint = Paint()
            ..shader = ui.Gradient.linear(
              Offset(w * 0.5, mistRect.top),
              Offset(w * 0.5, mistRect.bottom),
              [
                glowColor.withAlpha(0),
                Colors.white.withAlpha(45),
                glowColor.withAlpha(0),
              ],
              [0.0, 0.5, 1.0],
            );
          canvas.drawRect(mistRect, mistPaint);
        }
      }

      // 6. Water reflections if landscapeType == "waters"
      if (landscapeType == "waters") {
        final Paint shimmerPaint = Paint()
          ..color = Colors.white.withAlpha(135)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        for (int i = 0; i < 28; i++) {
          final double t = i / 28.0;
          final double y = h * (0.68 + t * 0.28);
          final double spreadW = w * (0.04 + t * 0.22);
          final double x =
              lightCenter.dx + (rng.nextDouble() * 2 - 1) * spreadW * 0.4;
          final double lineW = spreadW * (0.3 + rng.nextDouble() * 0.7);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, y), width: lineW, height: 3.5),
              const Radius.circular(2),
            ),
            shimmerPaint,
          );
        }
      }

      // 7. Bokeh / atmospheric light particles
      final int bokehCount =
          ((sceneSpec["bokehCount"] as num?)?.toInt() ?? 22).clamp(0, 45);
      for (int i = 0; i < bokehCount; i++) {
        final double bx = rng.nextDouble() * w;
        final double by = rng.nextDouble() * h * 0.85;
        final double br = 2.5 + rng.nextDouble() * (w * 0.014);
        final int alpha = 55 + rng.nextInt(120);
        final Paint bokehPaint = Paint()
          ..color = Colors.white.withAlpha(alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, br * 0.75);
        canvas.drawCircle(Offset(bx, by), br, bokehPaint);
      }

      final ui.Picture picture = recorder.endRecording();
      final ui.Image img = await picture.toImage(width, height);
      final ByteData? byteData = await img.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error rendering Gemini scene to PNG: $e");
      return null;
    }
  }
}
