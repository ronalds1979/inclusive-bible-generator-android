import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Uint8List _processImageTask(Map<String, dynamic> args) {
  Uint8List? imageBytes = args['imageBytes'];
  int targetWidth = args['targetWidth'];
  int targetHeight = args['targetHeight'];

  img.Image? bgImage;
  if (imageBytes != null) {
    bgImage = img.decodeImage(imageBytes);
  }

  if (bgImage == null) {
    bgImage = img.Image(width: targetWidth, height: targetHeight);
    img.fill(bgImage, color: img.ColorRgba8(73, 109, 137, 255));
  }

  int imgW = bgImage.width;
  int imgH = bgImage.height;
  double imgRatio = imgW / imgH;
  double targetRatio = targetWidth / targetHeight;

  img.Image croppedImage;
  if (imgRatio > targetRatio) {
    int newW = (imgH * targetRatio).toInt();
    int left = ((imgW - newW) / 2).toInt();
    croppedImage = img.copyCrop(
      bgImage,
      x: left,
      y: 0,
      width: newW,
      height: imgH,
    );
  } else if (imgRatio < targetRatio) {
    int newH = (imgW / targetRatio).toInt();
    int top = ((imgH - newH) / 2).toInt();
    croppedImage = img.copyCrop(
      bgImage,
      x: 0,
      y: top,
      width: imgW,
      height: newH,
    );
  } else {
    croppedImage = bgImage;
  }

  img.Image resizedImage = img.copyResize(
    croppedImage,
    width: targetWidth,
    height: targetHeight,
  );

  // Overlay
  img.Image overlay = img.Image(width: targetWidth, height: targetHeight);
  img.fill(overlay, color: img.ColorRgba8(0, 0, 0, 128));
  img.compositeImage(resizedImage, overlay);

  return img.encodePng(resizedImage);
}

class Generator {
  Map<String, Map<String, dynamic>> locales = {};
  static final RegExp _templateRegex = RegExp(r'\{([^}]+)\}');

  Future<void> loadLocales() async {
    List<String> langCodes = ["pt-BR", "en", "es"];
    for (String langCode in langCodes) {
      try {
        String jsonString = await rootBundle.loadString(
          "locales/$langCode.json",
        );
        locales[langCode] = json.decode(jsonString);
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Error loading locale $langCode: \$e");
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
        final key = match.group(1);
        return kwargs[key] ?? match.group(0)!;
      });
    }
    return template;
  }

  Future<Map<String, String>> generateTexts(
    String lang,
    String verse,
    String reference,
  ) async {
    String description = getLocaleString(lang, "default_description");
    String altText = getLocaleString(
      lang,
      "alt_text_template",
      kwargs: {
        "description": description,
        "verse": verse,
        "reference": reference,
      },
    );
    String caption = getLocaleString(
      lang,
      "caption_template",
      kwargs: {"verse": verse, "reference": reference},
    );
    return {"altText": altText, "caption": caption};
  }

  Future<Uint8List> generateImageBytes(
    String lang,
    String verse,
    String reference, {
    String backgroundFilename = "default.png",
    String? customImagePath,
    String aspectRatio = "1:1",
    String fontType = "Roboto-Regular.ttf",
    String fontColor = "#FFFFFF",
    int fontSize = 60,
    int yOffset = 0,
  }) async {
    int targetWidth = 1080;
    int targetHeight = 1080;

    if (aspectRatio == "3:4") {
      targetWidth = 1080;
      targetHeight = 1440;
    } else if (aspectRatio == "4:3") {
      targetWidth = 1440;
      targetHeight = 1080;
    }

    Uint8List? imageBytes;

    if (customImagePath != null && await File(customImagePath).exists()) {
      imageBytes = await File(customImagePath).readAsBytes();
    } else {
      try {
        ByteData data = await rootBundle.load(
          "assets/backgrounds/\$backgroundFilename",
        );
        imageBytes = data.buffer.asUint8List();
      } catch (e) {
        try {
          ByteData data = await rootBundle.load(
            "assets/backgrounds/default.png",
          );
          imageBytes = data.buffer.asUint8List();
        } catch (e) {
          imageBytes = null;
        }
      }
    }

    // ⚡ Bolt: Offload heavy image manipulation (decoding, cropping, encoding)
    // to a background isolate using compute() to prevent severe UI jank.
    return await compute(_processImageTask, {
      'imageBytes': imageBytes,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight,
    });
  }
}
