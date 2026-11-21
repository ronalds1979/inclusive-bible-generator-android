import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/verse_preview_card.dart';
import '../widgets/vision_simulation.dart';

/// Utilities for color-blindness (dyschromatopsia) accessibility:
/// - Simulating colors through Protanopia/Deuteranopia/Tritanopia matrices
/// - Computing worst-case WCAG contrast across CVD types
/// - Recommending universally high-contrast text colors
/// - Describing arbitrary colors in plain localized language
class ColorAccessibility {
  static const List<VisionSimulationMode> cvdModes = [
    VisionSimulationMode.protanopia,
    VisionSimulationMode.deuteranopia,
    VisionSimulationMode.tritanopia,
  ];

  /// Transforms [color] through the 4x5 color matrix of [mode].
  static Color simulateColor(Color color, VisionSimulationMode mode) {
    final List<double>? m = mode.colorMatrix;
    if (m == null) return color;
    final double r = (color.r * 255.0);
    final double g = (color.g * 255.0);
    final double b = (color.b * 255.0);

    final int nr = (m[0] * r + m[1] * g + m[2] * b + m[4]).round().clamp(
      0,
      255,
    );
    final int ng = (m[5] * r + m[6] * g + m[7] * b + m[9]).round().clamp(
      0,
      255,
    );
    final int nb = (m[10] * r + m[11] * g + m[12] * b + m[14]).round().clamp(
      0,
      255,
    );
    return Color.fromARGB((color.a * 255.0).round().clamp(0, 255), nr, ng, nb);
  }

  /// Evaluates the minimum WCAG 2.1 contrast ratio between [textColor] and
  /// [backgroundColor] across Protanopia, Deuteranopia, and Tritanopia.
  static ({double minRatio, VisionSimulationMode worstMode})
  worstCaseCvdContrast({
    required Color textColor,
    required Color backgroundColor,
  }) {
    double minRatio = double.infinity;
    VisionSimulationMode worstMode = VisionSimulationMode.protanopia;

    for (final mode in cvdModes) {
      final Color simFg = simulateColor(textColor, mode);
      final Color simBg = simulateColor(backgroundColor, mode);
      final double ratio = VersePreviewCard.computeWcagContrastRatio(
        simFg.computeLuminance(),
        simBg.computeLuminance(),
      );
      if (ratio < minRatio) {
        minRatio = ratio;
        worstMode = mode;
      }
    }
    return (minRatio: minRatio, worstMode: worstMode);
  }

  /// Selects the candidate color with the highest guaranteed minimum contrast
  /// ratio across normal vision and all three CVD types.
  static ({MapEntry<Color, String> entry, double guaranteedRatio})
  suggestSafestTextColor({
    required List<MapEntry<Color, String>> candidates,
    required Color backgroundColor,
  }) {
    MapEntry<Color, String> bestEntry = candidates.first;
    double bestMinRatio = -1.0;

    for (final candidate in candidates) {
      final double normalRatio = VersePreviewCard.computeWcagContrastRatio(
        candidate.key.computeLuminance(),
        backgroundColor.computeLuminance(),
      );
      final double cvdMin = worstCaseCvdContrast(
        textColor: candidate.key,
        backgroundColor: backgroundColor,
      ).minRatio;
      final double guaranteed = math.min(normalRatio, cvdMin);
      if (guaranteed > bestMinRatio) {
        bestMinRatio = guaranteed;
        bestEntry = candidate;
      }
    }
    return (entry: bestEntry, guaranteedRatio: bestMinRatio);
  }

  /// Converts a relative luminance `[0.0, 1.0]` into an equivalent neutral
  /// grayscale [Color] for approximate CVD contrast simulation.
  static Color grayscaleColorForLuminance(double luminance) {
    final double clamped = luminance.clamp(0.0, 1.0);
    final double srgb = clamped <= 0.0031308
        ? clamped * 12.92
        : 1.055 * math.pow(clamped, 1.0 / 2.4) - 0.055;
    final int channel = (srgb * 255.0).round().clamp(0, 255);
    return Color.fromARGB(255, channel, channel, channel);
  }

  /// Returns a plain-language localized name for any arbitrary [color] so
  /// users with dyschromatopsia never have to guess what color is selected.
  static String describeColorName(Color color, String lang) {
    final String normLang = lang.toLowerCase().startsWith('pt')
        ? 'pt-BR'
        : (lang.toLowerCase().startsWith('es') ? 'es' : 'en');
    final HSLColor hsl = HSLColor.fromColor(color);
    final double l = hsl.lightness;
    final double s = hsl.saturation;
    final double h = hsl.hue;

    String pick(String en, String pt, String es) {
      if (normLang == 'pt-BR') return pt;
      if (normLang == 'es') return es;
      return en;
    }

    if (l >= 0.94) return pick('White', 'Branco', 'Blanco');
    if (l <= 0.10) return pick('Black', 'Preto', 'Negro');
    if (s <= 0.12) {
      if (l >= 0.72) return pick('Light Gray', 'Cinza Claro', 'Gris Claro');
      if (l <= 0.35) return pick('Dark Gray', 'Cinza Escuro', 'Gris Oscuro');
      return pick('Gray', 'Cinza', 'Gris');
    }

    final String prefix = l >= 0.75
        ? pick('Light ', 'Claro ', 'Claro ')
        : (l <= 0.30 ? pick('Dark ', 'Escuro ', 'Oscuro ') : '');

    String baseName;
    if (h < 15 || h >= 345) {
      baseName = pick('Red', 'Vermelho', 'Rojo');
    } else if (h < 40) {
      baseName = pick('Orange / Coral', 'Laranja / Coral', 'Naranja / Coral');
    } else if (h < 65) {
      baseName = pick('Gold / Yellow', 'Dourado / Amarelo', 'Dorado / Amarillo');
    } else if (h < 160) {
      baseName = pick('Green', 'Verde', 'Verde');
    } else if (h < 200) {
      baseName = pick('Teal / Cyan', 'Verde-Água / Ciano', 'Turquesa / Cian');
    } else if (h < 255) {
      baseName = pick('Blue', 'Azul', 'Azul');
    } else if (h < 295) {
      baseName = pick('Purple', 'Roxo', 'Morado');
    } else {
      baseName = pick('Pink / Magenta', 'Rosa / Magenta', 'Rosa / Magenta');
    }

    if (normLang == 'en') {
      return '$prefix$baseName'.trim();
    }
    if (prefix.isEmpty) return baseName;
    return '$baseName ${prefix.trim().toLowerCase()}';
  }
}
