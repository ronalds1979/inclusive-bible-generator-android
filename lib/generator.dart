import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class Generator {
  Map<String, Map<String, dynamic>> locales = {};


  Future<void> loadLocales() async {
    List<String> langCodes = ["pt-BR", "en", "es"];
    await Future.wait(langCodes.map((langCode) async {
      try {
        String jsonString = await rootBundle.loadString("locales/$langCode.json");
        locales[langCode] = json.decode(jsonString);
      } catch (e) {
        print("Error loading locale $langCode: \$e");
      }
    }));
  }

  String getLocaleString(String lang, String key, {Map<String, String>? kwargs}) {
    lang = lang
        .replaceAll(" (Brasil)", "")
        .replaceAll("English (US/UK)", "en")
        .replaceAll("Español (España)", "es")
        .replaceAll("Português", "pt-BR");
    if (!locales.containsKey(lang)) {
      lang = "pt-BR";
    }

    String template = locales[lang]?[key] ?? "";
    if (kwargs != null) {
      kwargs.forEach((k, v) {
        template = template.replaceAll("{$k}", v);
      });
    }
    return template;
  }

  Future<Map<String, String>> generateTexts(String lang, String verse, String reference) async {
    String description = getLocaleString(lang, "default_description");
    String altText = getLocaleString(lang, "alt_text_template",
        kwargs: {"description": description, "verse": verse, "reference": reference});
    String caption = getLocaleString(lang, "caption_template",
        kwargs: {"verse": verse, "reference": reference});
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

    img.Image? bgImage;
    if (customImagePath != null && File(customImagePath).existsSync()) {
      bgImage = img.decodeImage(File(customImagePath).readAsBytesSync());
    } else {
      try {
        ByteData data = await rootBundle.load("assets/backgrounds/\$backgroundFilename");
        bgImage = img.decodeImage(data.buffer.asUint8List());
      } catch (e) {
        try {
          ByteData data = await rootBundle.load("assets/backgrounds/default.png");
          bgImage = img.decodeImage(data.buffer.asUint8List());
        } catch (e) {
           bgImage = img.Image(width: targetWidth, height: targetHeight);
           img.fill(bgImage, color: img.ColorRgba8(73, 109, 137, 255));
        }
      }
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
      croppedImage = img.copyCrop(bgImage, x: left, y: 0, width: newW, height: imgH);
    } else if (imgRatio < targetRatio) {
      int newH = (imgW / targetRatio).toInt();
      int top = ((imgH - newH) / 2).toInt();
      croppedImage = img.copyCrop(bgImage, x: 0, y: top, width: imgW, height: newH);
    } else {
      croppedImage = bgImage;
    }

    img.Image resizedImage = img.copyResize(croppedImage, width: targetWidth, height: targetHeight);

    // Overlay
    img.Image overlay = img.Image(width: targetWidth, height: targetHeight);
    img.fill(overlay, color: img.ColorRgba8(0, 0, 0, 128));
    img.compositeImage(resizedImage, overlay);

    return img.encodePng(resizedImage);
  }
}
