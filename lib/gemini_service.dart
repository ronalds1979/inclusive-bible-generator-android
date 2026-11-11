import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String endpoint =
      "https://generativelanguage.googleapis.com/v1beta/interactions";
  static const String apiRevision = "2026-05-20";
  static const String imageModel = "gemini-nano-banana-2.1";

  static const List<String> oauthScopes = <String>[
    'email',
    'https://www.googleapis.com/auth/generative-language',
    'https://www.googleapis.com/auth/cloud-platform',
  ];

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
  final GoogleSignIn _googleSignIn;

  String? _cachedAccessToken;
  String? _userEmail;

  GeminiService({http.Client? httpClient, GoogleSignIn? googleSignIn})
    : _httpClient = httpClient ?? http.Client(),
      _googleSignIn =
          googleSignIn ?? GoogleSignIn(scopes: oauthScopes);

  String? get userEmail => _userEmail ?? _googleSignIn.currentUser?.email;
  bool get isSignedIn =>
      (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) ||
      _googleSignIn.currentUser != null;

  /// Attempts to silently restore a previous Google Sign-In session.
  Future<String?> signInSilently() async {
    try {
      final GoogleSignInAccount? account =
          await _googleSignIn.signInSilently();
      if (account != null) {
        _userEmail = account.email;
        final GoogleSignInAuthentication auth = await account.authentication;
        _cachedAccessToken = auth.accessToken;
        return _cachedAccessToken;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Silent Google Sign-In error: $e");
      }
    }
    return null;
  }

  /// Triggers the interactive Google Sign-In flow (account picker / username & password).
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return null;
      }
      _userEmail = account.email;
      final GoogleSignInAuthentication auth = await account.authentication;
      _cachedAccessToken = auth.accessToken;
      return _cachedAccessToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Interactive Google Sign-In error: $e");
      }
      return null;
    }
  }

  /// Retrieves a fresh OAuth access token from the active Google account.
  Future<String?> getAccessToken() async {
    try {
      final GoogleSignInAccount? account = _googleSignIn.currentUser;
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        if (auth.accessToken != null && auth.accessToken!.isNotEmpty) {
          _cachedAccessToken = auth.accessToken;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error refreshing Google OAuth token: $e");
      }
    }
    return _cachedAccessToken;
  }

  /// Signs out from the connected Google Account.
  Future<void> signOut() async {
    _cachedAccessToken = null;
    _userEmail = null;
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error signing out of Google: $e");
      }
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
    return null;
  }

  Future<Uint8List?> generateBackgroundImage({
    required String accessToken,
    required String verse,
    required String reference,
    String aspectRatio = "1:1",
    String styleKey = "style_nature",
    String customPrompt = "",
  }) async {
    final trimmedToken = accessToken.trim();
    if (trimmedToken.isEmpty || verse.trim().isEmpty) {
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
              "Authorization": "Bearer $trimmedToken",
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
