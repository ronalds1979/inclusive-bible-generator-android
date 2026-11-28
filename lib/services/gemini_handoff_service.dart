import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum GeminiHandoffTask { devotionalCaption, customBackground }

/// Zero-cost handoff to the user's own Gemini app (or web app), consuming
/// their personal free Gemini quota with no API key or developer billing.
class GeminiHandoffService {
  static final Uri geminiAppUri = Uri.parse('https://gemini.google.com/app');
  static const int maxVersePromptChars = 5000;
  static const int maxReferencePromptChars = 100;
  static final RegExp _unsafePromptCharsRegExp = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u200E\u200F\u202A-\u202E\u2066-\u2069]',
  );
  static final RegExp _safeAspectRatioRegExp = RegExp(r'^\d{1,2}:\d{1,2}$');

  final Future<void> Function(String text, String? imagePath)? _shareHandler;
  final Future<bool> Function(Uri uri)? _launchHandler;
  final Future<void> Function(String text)? _clipboardHandler;

  const GeminiHandoffService({
    @visibleForTesting
    Future<void> Function(String text, String? imagePath)? shareHandler,
    @visibleForTesting Future<bool> Function(Uri uri)? launchHandler,
    @visibleForTesting Future<void> Function(String text)? clipboardHandler,
  }) : _shareHandler = shareHandler,
       _launchHandler = launchHandler,
       _clipboardHandler = clipboardHandler;

  /// Builds a localized prompt tailored to the selected Bible verse,
  /// reference, and card aspect ratio.
  String buildPrompt({
    required String lang,
    required String verse,
    required String reference,
    required String aspectRatio,
    required GeminiHandoffTask task,
  }) {
    final String normalized = _normalizeLang(lang);
    // 🛡️ Sentinel: Strip C0/C1 control and Unicode Bidi override chars and bound lengths before external share/clipboard handoff
    final String strippedVerse = verse.replaceAll(_unsafePromptCharsRegExp, '').trim();
    final String cleanVerse = strippedVerse.length > maxVersePromptChars
        ? strippedVerse.substring(0, maxVersePromptChars)
        : strippedVerse;
    final String strippedRef = reference.replaceAll(_unsafePromptCharsRegExp, '').trim();
    final String cleanRef = strippedRef.length > maxReferencePromptChars
        ? strippedRef.substring(0, maxReferencePromptChars)
        : strippedRef;
    final String safeRatio = _safeAspectRatioRegExp.hasMatch(aspectRatio.trim())
        ? aspectRatio.trim()
        : '4:5';

    if (task == GeminiHandoffTask.customBackground) {
      switch (normalized) {
        case 'pt-BR':
          return 'Crie uma imagem de fundo serena e sem nenhum texto na imagem '
              '(proporção $safeRatio) inspirada neste versículo bíblico:\n'
              '"$cleanVerse" — $cleanRef\n\n'
              'Use iluminação suave e uma área calma com bom contraste para '
              'sobrepor texto legível em um cartão acessível.';
        case 'es':
          return 'Crea una imagen de fondo serena y sin texto en la imagen '
              '(relación de aspecto $safeRatio) inspirada en este versículo bíblico:\n'
              '"$cleanVerse" — $cleanRef\n\n'
              'Usa iluminación suave y un área tranquila con buen contraste para '
              'superponer texto legible en una tarjeta accesible.';
        default:
          return 'Create a serene, text-free background image '
              '(aspect ratio $safeRatio) inspired by this Bible verse:\n'
              '"$cleanVerse" — $cleanRef\n\n'
              'Use soft lighting and a calm, uncluttered area with good contrast '
              'so overlaid verse text stays accessible and easy to read.';
      }
    }

    switch (normalized) {
      case 'pt-BR':
        return 'Ajude-me a tornar esta postagem bíblica acessível:\n'
            'Versículo: "$cleanVerse"\n'
            'Referência: $cleanRef\n\n'
            'Por favor, escreva em português (Brasil):\n'
            '1. Uma descrição de imagem acessível (#PraCegoVer / #ParaTodosVerem) '
            'se eu anexar uma foto.\n'
            '2. Uma legenda curta e acolhedora para redes sociais com uma breve reflexão.\n'
            '3. Hashtags acessíveis em CamelCase (ex.: #VersiculoDoDia #Acessibilidade).';
      case 'es':
        return 'Ayúdame a hacer accesible esta publicación bíblica:\n'
            'Versículo: "$cleanVerse"\n'
            'Referencia: $cleanRef\n\n'
            'Por favor, escribe en español:\n'
            '1. Una descripción de imagen accesible (texto alternativo) si adjunto una foto.\n'
            '2. Un mensaje corto y cálido para redes sociales con una breve reflexión.\n'
            '3. Hashtags accesibles en CamelCase (ej.: #VersiculoDelDia #Accesibilidad).';
      default:
        return 'Help me make this Bible verse post accessible:\n'
            'Verse: "$cleanVerse"\n'
            'Reference: $cleanRef\n\n'
            'Please write in English:\n'
            '1. Concise screen-reader Alt-Text describing the attached photo (if included).\n'
            '2. A short, warm social media caption with a brief devotional reflection.\n'
            '3. Accessible CamelCase hashtags (e.g. #VerseOfTheDay #Accessibility).';
    }
  }

  /// Opens the native share sheet with the prompt (and optional background
  /// image) so the user can hand it directly to the Gemini Android app.
  Future<bool> shareToGemini({
    required String prompt,
    String? imagePath,
  }) async {
    try {
      if (_shareHandler != null) {
        await _shareHandler(prompt, imagePath);
        return true;
      }
      final List<XFile> files = [];
      if (imagePath != null && imagePath.trim().isNotEmpty) {
        final File file = File(imagePath);
        if (await file.exists()) {
          files.add(XFile(file.path));
        }
      }
      await SharePlus.instance.share(
        ShareParams(
          text: prompt,
          files: files.isEmpty ? null : files,
        ),
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sharing prompt to Gemini: $e');
      }
      return false;
    }
  }

  /// Copies the prompt to the clipboard and opens the Gemini app / web URL.
  Future<bool> copyAndOpenGemini({required String prompt}) async {
    try {
      if (_clipboardHandler != null) {
        await _clipboardHandler(prompt);
      } else {
        await Clipboard.setData(ClipboardData(text: prompt));
      }
      if (_launchHandler != null) {
        return await _launchHandler(geminiAppUri);
      }
      return await launchUrl(
        geminiAppUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error opening Gemini app: $e');
      }
      return false;
    }
  }

  static String _normalizeLang(String lang) {
    final String lower = lang.trim().toLowerCase();
    if (lower.startsWith('pt')) return 'pt-BR';
    if (lower.startsWith('es')) return 'es';
    return 'en';
  }
}
