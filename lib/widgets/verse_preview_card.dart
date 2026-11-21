import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../generator.dart';

/// Offline-safe font families (bundled Google Fonts + Android system families).
enum VerseFontFamily {
  sans,
  playfairDisplay,
  lora,
  montserrat,
  serif,
  condensed,
  cursive,
  monospace;

  String get localeKey {
    switch (this) {
      case VerseFontFamily.sans:
        return 'font_type_sans';
      case VerseFontFamily.playfairDisplay:
        return 'font_type_playfair';
      case VerseFontFamily.lora:
        return 'font_type_lora';
      case VerseFontFamily.montserrat:
        return 'font_type_montserrat';
      case VerseFontFamily.serif:
        return 'font_type_serif';
      case VerseFontFamily.condensed:
        return 'font_type_condensed';
      case VerseFontFamily.cursive:
        return 'font_type_cursive';
      case VerseFontFamily.monospace:
        return 'font_type_mono';
    }
  }

  TextStyle baseStyle(TextStyle fallbackRoboto) {
    switch (this) {
      case VerseFontFamily.sans:
        return fallbackRoboto;
      case VerseFontFamily.playfairDisplay:
        return const TextStyle(
          fontFamily: 'PlayfairDisplay',
          fontFamilyFallback: ['serif', 'Georgia'],
        );
      case VerseFontFamily.lora:
        return const TextStyle(
          fontFamily: 'Lora',
          fontFamilyFallback: ['serif', 'Georgia'],
        );
      case VerseFontFamily.montserrat:
        return const TextStyle(
          fontFamily: 'Montserrat',
          fontFamilyFallback: ['sans-serif'],
        );
      case VerseFontFamily.serif:
        return const TextStyle(
          fontFamily: 'serif',
          fontFamilyFallback: ['Georgia', 'Times New Roman'],
        );
      case VerseFontFamily.condensed:
        return const TextStyle(
          fontFamily: 'sans-serif-condensed',
          fontFamilyFallback: ['Roboto Condensed', 'sans-serif'],
          letterSpacing: -0.2,
        );
      case VerseFontFamily.cursive:
        return const TextStyle(
          fontFamily: 'cursive',
          fontFamilyFallback: ['Dancing Script', 'serif'],
        );
      case VerseFontFamily.monospace:
        return const TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: ['Courier New'],
        );
    }
  }
}

/// Optional backdrop behind the text block for guaranteed WCAG contrast on
/// busy or high-detail photographs.
enum VerseTextBackdrop {
  none,
  frosted,
  solid;

  String get localeKey {
    switch (this) {
      case VerseTextBackdrop.none:
        return 'backdrop_none';
      case VerseTextBackdrop.frosted:
        return 'backdrop_frosted';
      case VerseTextBackdrop.solid:
        return 'backdrop_solid';
    }
  }
}

/// Optional editorial visual accent rendered on the verse card.
enum VerseCardAccent {
  none,
  divider,
  frame;

  String get localeKey {
    switch (this) {
      case VerseCardAccent.none:
        return 'accent_none';
      case VerseCardAccent.divider:
        return 'accent_divider';
      case VerseCardAccent.frame:
        return 'accent_frame';
    }
  }
}

/// Shadow intensity presets for verse & reference legibility.
enum VerseTextShadow {
  none,
  soft,
  strong;

  String get localeKey {
    switch (this) {
      case VerseTextShadow.none:
        return 'shadow_none';
      case VerseTextShadow.soft:
        return 'shadow_soft';
      case VerseTextShadow.strong:
        return 'shadow_strong';
    }
  }

  List<Shadow> get verseShadows => verseShadowsFor(Colors.white);

  List<Shadow> verseShadowsFor(Color textColor) {
    final bool isDarkText = textColor.computeLuminance() < 0.25;
    switch (this) {
      case VerseTextShadow.none:
        return const [];
      case VerseTextShadow.soft:
        return isDarkText
            ? const [
                Shadow(
                  color: Colors.white70,
                  blurRadius: 8,
                  offset: Offset(0, 1.5),
                ),
              ]
            : const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ];
      case VerseTextShadow.strong:
        return isDarkText
            ? const [
                Shadow(
                  color: Colors.white,
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
                Shadow(
                  color: Colors.white70,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ]
            : const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ];
    }
  }

  List<Shadow> get referenceShadows => referenceShadowsFor(Colors.white);

  List<Shadow> referenceShadowsFor(Color textColor) {
    final bool isDarkText = textColor.computeLuminance() < 0.25;
    switch (this) {
      case VerseTextShadow.none:
        return const [];
      case VerseTextShadow.soft:
        return isDarkText
            ? const [
                Shadow(
                  color: Colors.white70,
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ]
            : const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 1.5),
                ),
              ];
      case VerseTextShadow.strong:
        return isDarkText
            ? const [
                Shadow(
                  color: Colors.white,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
                Shadow(
                  color: Colors.white70,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ]
            : const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 10,
                  offset: Offset(0, 2.5),
                ),
                Shadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ];
    }
  }
}

/// Immutable typography options for [VersePreviewCard].
@immutable
class VerseTextStyleOptions {
  static const double defaultLineHeight = 1.25;
  static const double defaultLetterSpacing = 0.0;

  final VerseFontFamily fontFamily;
  final bool isBold;
  final bool isItalic;
  final VerseTextShadow shadow;
  final TextAlign textAlign;
  final VerseTextBackdrop backdrop;
  final VerseCardAccent accent;
  final double lineHeight;
  final double letterSpacing;

  const VerseTextStyleOptions({
    this.fontFamily = VerseFontFamily.sans,
    this.isBold = true,
    this.isItalic = false,
    this.shadow = VerseTextShadow.soft,
    this.textAlign = TextAlign.center,
    this.backdrop = VerseTextBackdrop.none,
    this.accent = VerseCardAccent.none,
    this.lineHeight = defaultLineHeight,
    this.letterSpacing = defaultLetterSpacing,
  });

  CrossAxisAlignment get crossAxisAlignment {
    switch (textAlign) {
      case TextAlign.left:
      case TextAlign.start:
        return CrossAxisAlignment.start;
      case TextAlign.right:
      case TextAlign.end:
        return CrossAxisAlignment.end;
      case TextAlign.center:
      case TextAlign.justify:
        return CrossAxisAlignment.center;
    }
  }

  bool get isDefault => this == const VerseTextStyleOptions();

  Map<String, dynamic> toJson() => {
    'fontFamily': fontFamily.name,
    'isBold': isBold,
    'isItalic': isItalic,
    'shadow': shadow.name,
    'textAlign': textAlign.name,
    'backdrop': backdrop.name,
    'accent': accent.name,
    'lineHeight': lineHeight,
    'letterSpacing': letterSpacing,
  };

  static VerseTextStyleOptions fromJson(Map<dynamic, dynamic> json) {
    final VerseFontFamily family = VerseFontFamily.values.firstWhere(
      (e) => e.name == json['fontFamily'],
      orElse: () => VerseFontFamily.sans,
    );
    final VerseTextShadow parsedShadow = VerseTextShadow.values.firstWhere(
      (e) => e.name == json['shadow'],
      orElse: () => VerseTextShadow.soft,
    );
    final VerseTextBackdrop parsedBackdrop = VerseTextBackdrop.values
        .firstWhere(
          (e) => e.name == json['backdrop'],
          orElse: () => VerseTextBackdrop.none,
        );
    final VerseCardAccent parsedAccent = VerseCardAccent.values.firstWhere(
      (e) => e.name == json['accent'],
      orElse: () => VerseCardAccent.none,
    );
    final TextAlign parsedAlign;
    switch (json['textAlign']) {
      case 'left':
        parsedAlign = TextAlign.left;
        break;
      case 'right':
        parsedAlign = TextAlign.right;
        break;
      default:
        parsedAlign = TextAlign.center;
    }
    final num? rawLineHeight = json['lineHeight'] as num?;
    final double clampedLineHeight = rawLineHeight != null
        ? double.parse(rawLineHeight.toDouble().clamp(1.0, 2.0).toStringAsFixed(2))
        : defaultLineHeight;
    final num? rawLetterSpacing = json['letterSpacing'] as num?;
    final double clampedLetterSpacing = rawLetterSpacing != null
        ? double.parse(
            rawLetterSpacing.toDouble().clamp(-1.0, 4.0).toStringAsFixed(2),
          )
        : defaultLetterSpacing;
    return VerseTextStyleOptions(
      fontFamily: family,
      isBold: json['isBold'] is bool ? json['isBold'] as bool : true,
      isItalic: json['isItalic'] is bool ? json['isItalic'] as bool : false,
      shadow: parsedShadow,
      textAlign: parsedAlign,
      backdrop: parsedBackdrop,
      accent: parsedAccent,
      lineHeight: clampedLineHeight,
      letterSpacing: clampedLetterSpacing,
    );
  }

  VerseTextStyleOptions copyWith({
    VerseFontFamily? fontFamily,
    bool? isBold,
    bool? isItalic,
    VerseTextShadow? shadow,
    TextAlign? textAlign,
    VerseTextBackdrop? backdrop,
    VerseCardAccent? accent,
    double? lineHeight,
    double? letterSpacing,
  }) {
    return VerseTextStyleOptions(
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      shadow: shadow ?? this.shadow,
      textAlign: textAlign ?? this.textAlign,
      backdrop: backdrop ?? this.backdrop,
      accent: accent ?? this.accent,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is VerseTextStyleOptions &&
            other.fontFamily == fontFamily &&
            other.isBold == isBold &&
            other.isItalic == isItalic &&
            other.shadow == shadow &&
            other.textAlign == textAlign &&
            other.backdrop == backdrop &&
            other.accent == accent &&
            other.lineHeight == lineHeight &&
            other.letterSpacing == letterSpacing);
  }

  @override
  int get hashCode => Object.hash(
    fontFamily,
    isBold,
    isItalic,
    shadow,
    textAlign,
    backdrop,
    accent,
    lineHeight,
    letterSpacing,
  );
}

class VersePreviewCard extends StatefulWidget {
  // ⚡ Bolt: Cache base GoogleFonts TextStyle instead of calling GoogleFonts.roboto() on every frame
  static final TextStyle _baseRobotoStyle = GoogleFonts.roboto();

  static TextStyle resolveBaseTextStyle(VerseFontFamily fontFamily) =>
      fontFamily.baseStyle(_baseRobotoStyle);

  /// Computes the W3C WCAG 2.1 contrast ratio (`1.0` to `21.0`) between two
  /// relative luminances in `[0.0, 1.0]`.
  static double computeWcagContrastRatio(
    double luminanceA,
    double luminanceB,
  ) {
    final double l1 = luminanceA > luminanceB ? luminanceA : luminanceB;
    final double l2 = luminanceA > luminanceB ? luminanceB : luminanceA;
    return (l1 + 0.05) / (l2 + 0.05);
  }

  /// Resolves the largest slider font size `<= requestedFontSize` that fits
  /// cleanly inside `(maxWidth, maxHeight)` without causing `FittedBox` to
  /// shrink the rendered text when the slider is increased past the card limit.
  @visibleForTesting
  static double resolveFittingFontSize({
    required double requestedFontSize,
    required String verseText,
    required String refText,
    required bool verseIsPlaceholder,
    required bool refIsPlaceholder,
    required double maxWidth,
    required double maxHeight,
    required TextScaler textScaler,
    required TextDirection textDirection,
    VerseTextStyleOptions textStyleOptions = const VerseTextStyleOptions(),
  }) {
    if (requestedFontSize <= 8.0 || maxWidth <= 0 || maxHeight <= 0) {
      return requestedFontSize;
    }

    final TextStyle baseStyle = resolveBaseTextStyle(
      textStyleOptions.fontFamily,
    );
    final FontWeight verseWeight = verseIsPlaceholder
        ? FontWeight.w500
        : (textStyleOptions.isBold ? FontWeight.bold : FontWeight.w400);
    final FontStyle verseFontStyle = (verseIsPlaceholder ||
            textStyleOptions.isItalic)
        ? FontStyle.italic
        : FontStyle.normal;
    final FontStyle refFontStyle = (refIsPlaceholder ||
            textStyleOptions.isItalic)
        ? FontStyle.italic
        : FontStyle.normal;

    bool fits(double sliderSize) {
      final double versePx = sliderSize / 2.0;
      final double refPx = (sliderSize * 0.66) / 2.0;
      final double gap = (sliderSize * 0.35).clamp(12.0, 24.0);

      final TextPainter versePainter = TextPainter(
        text: TextSpan(
          text: verseText,
          style: baseStyle.copyWith(
            fontSize: versePx,
            height: textStyleOptions.lineHeight,
            letterSpacing: textStyleOptions.letterSpacing != 0.0
                ? textStyleOptions.letterSpacing
                : null,
            fontWeight: verseWeight,
            fontStyle: verseFontStyle,
          ),
        ),
        textAlign: textStyleOptions.textAlign,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);

      final TextPainter refPainter = TextPainter(
        text: TextSpan(
          text: refText,
          style: baseStyle.copyWith(
            fontSize: refPx,
            fontWeight: textStyleOptions.isBold
                ? FontWeight.w600
                : FontWeight.w400,
            fontStyle: refFontStyle,
          ),
        ),
        textAlign: textStyleOptions.textAlign,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);

      final double totalHeight = versePainter.height + gap + refPainter.height;
      final double maxLineWidth = versePainter.width > refPainter.width
          ? versePainter.width
          : refPainter.width;
      versePainter.dispose();
      refPainter.dispose();
      return totalHeight <= maxHeight && maxLineWidth <= maxWidth + 0.5;
    }

    if (fits(requestedFontSize)) {
      return requestedFontSize;
    }

    double lo = 8.0;
    if (!fits(lo)) {
      return lo;
    }
    // Use a fixed upper bound when clamping so every slider value above the
    // card's maximum fitting size converges to the exact same size (never
    // decreasing as the user drags the slider higher).
    double hi = requestedFontSize > 120.0 ? requestedFontSize : 120.0;
    for (int i = 0; i < 12; i++) {
      final double mid = (lo + hi) * 0.5;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo < requestedFontSize ? lo : requestedFontSize;
  }

  final GlobalKey repaintKey;
  final String aspectRatioStr;
  final String? customImagePath;
  final String selectedBackground;
  final Listenable previewListenable;
  final TextEditingController verseController;
  final TextEditingController referenceController;
  final Color fontColor;
  final double fontSize;
  final double yOffset;
  final double backgroundDim;
  final VerseTextStyleOptions textStyleOptions;
  final ValueListenable<Color>? fontColorListenable;
  final ValueListenable<double>? fontSizeListenable;
  final ValueListenable<double>? yOffsetListenable;
  final ValueListenable<double>? backgroundDimListenable;
  final ValueListenable<VerseTextStyleOptions>? textStyleListenable;
  final ValueChanged<double>? onYOffsetChanged;
  final String lang;
  final Generator generator;

  const VersePreviewCard({
    super.key,
    required this.repaintKey,
    required this.aspectRatioStr,
    required this.customImagePath,
    required this.selectedBackground,
    required this.previewListenable,
    required this.verseController,
    required this.referenceController,
    required this.fontColor,
    required this.fontSize,
    required this.yOffset,
    this.backgroundDim = 0.15,
    this.textStyleOptions = const VerseTextStyleOptions(),
    this.fontColorListenable,
    this.fontSizeListenable,
    this.yOffsetListenable,
    this.backgroundDimListenable,
    this.textStyleListenable,
    this.onYOffsetChanged,
    required this.lang,
    required this.generator,
  });

  @override
  State<VersePreviewCard> createState() => _VersePreviewCardState();
}

class _VersePreviewCardState extends State<VersePreviewCard> {
  late Listenable _textAnimation;

  Listenable _buildTextAnimation() => Listenable.merge([
    widget.previewListenable,
    ?widget.fontColorListenable,
    ?widget.fontSizeListenable,
    ?widget.textStyleListenable,
  ]);

  @override
  void initState() {
    super.initState();
    _textAnimation = _buildTextAnimation();
  }

  @override
  void didUpdateWidget(covariant VersePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewListenable != widget.previewListenable ||
        oldWidget.fontColorListenable != widget.fontColorListenable ||
        oldWidget.fontSizeListenable != widget.fontSizeListenable ||
        oldWidget.textStyleListenable != widget.textStyleListenable) {
      _textAnimation = _buildTextAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = 300;
    double height = 300;
    if (widget.aspectRatioStr == "3:4") {
      width = 300;
      height = 400;
    } else if (widget.aspectRatioStr == "9:16") {
      width = 225;
      height = 400;
    } else if (widget.aspectRatioStr == "4:3") {
      width = 400;
      height = 300;
    }

    // ⚡ Bolt: Pre-resolve locale placeholder & header strings outside 60Hz AnimatedBuilders
    final String versePlaceholder = widget.generator.getLocaleString(
      widget.lang,
      "preview_verse_placeholder",
    );
    final String refPlaceholder = widget.generator.getLocaleString(
      widget.lang,
      "reference_placeholder",
    );
    final String rawHeader = widget.generator.getLocaleString(
      widget.lang,
      "preview_semantic_label",
    );
    final String semanticHeader =
        (rawHeader.isEmpty || rawHeader == "preview_semantic_label"
                ? "Verse card preview ({ratio})"
                : rawHeader)
            .replaceAll("{ratio}", widget.aspectRatioStr);

    final String safeBgName = widget.selectedBackground
        .split('/')
        .last
        .split('\\')
        .last;

    // ⚡ Bolt: Isolate static background image from 60Hz drag/slider layers so
    // dragging text or adjusting dim/font size never rebuilds the image provider.
    final Widget backgroundImage = RepaintBoundary(
      child: Image(
        image: ResizeImage.resizeIfNeeded(
          1080,
          null,
          widget.customImagePath != null
              ? FileImage(File(widget.customImagePath!)) as ImageProvider
              : AssetImage("assets/backgrounds/$safeBgName"),
        ),
        fit: BoxFit.cover,
        width: width,
        height: height,
      ),
    );

    final Widget dimOverlay = widget.backgroundDimListenable != null
        ? ValueListenableBuilder<double>(
            valueListenable: widget.backgroundDimListenable!,
            builder: (context, dim, _) => ColoredBox(
              color: Colors.black.withAlpha((dim.clamp(0.0, 0.85) * 255).round()),
            ),
          )
        : ColoredBox(
            color: Colors.black.withAlpha(
              (widget.backgroundDim.clamp(0.0, 0.85) * 255).round(),
            ),
          );

    final TextScaler textScaler = MediaQuery.textScalerOf(context);
    final TextDirection textDirection = Directionality.of(context);
    final double maxTextWidth = width - 40.0;
    final double maxTextHeight = height - 32.0;

    // ⚡ Bolt: Decouple 60Hz vertical drag/slider yOffset updates from text
    // layout & shadow rasterization. When a frosted BackdropFilter is active,
    // skip the inner RepaintBoundary so the blur samples the background image.
    final Widget textContent = AnimatedBuilder(
      animation: _textAnimation,
      builder: (context, child) {
        final Color currentFontColor =
            widget.fontColorListenable?.value ?? widget.fontColor;
        final double requestedFontSize =
            widget.fontSizeListenable?.value ?? widget.fontSize;
        final VerseTextStyleOptions currentStyle =
            widget.textStyleListenable?.value ?? widget.textStyleOptions;
        final TextStyle baseStyle = VersePreviewCard.resolveBaseTextStyle(
          currentStyle.fontFamily,
        );
        final String verseText = widget.verseController.text;
        final String refText = widget.referenceController.text;
        final bool verseIsPlaceholder = verseText.isEmpty;
        final bool refIsPlaceholder = refText.isEmpty;
        final String displayVerse =
            verseIsPlaceholder ? versePlaceholder : verseText;
        final String displayRef = refIsPlaceholder ? refPlaceholder : refText;
        final bool hasBackdrop =
            currentStyle.backdrop != VerseTextBackdrop.none;
        final double effectiveMaxWidth = hasBackdrop
            ? (maxTextWidth - 28.0).clamp(80.0, maxTextWidth)
            : maxTextWidth;
        final double effectiveMaxHeight = hasBackdrop
            ? (maxTextHeight - 24.0).clamp(80.0, maxTextHeight)
            : maxTextHeight;
        final double effectiveFontSize =
            VersePreviewCard.resolveFittingFontSize(
              requestedFontSize: requestedFontSize,
              verseText: displayVerse,
              refText: displayRef,
              verseIsPlaceholder: verseIsPlaceholder,
              refIsPlaceholder: refIsPlaceholder,
              maxWidth: effectiveMaxWidth,
              maxHeight: effectiveMaxHeight,
              textScaler: textScaler,
              textDirection: textDirection,
              textStyleOptions: currentStyle,
            );
        final Widget textColumn = SizedBox(
          width: effectiveMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: currentStyle.crossAxisAlignment,
            children: [
              Text(
                displayVerse,
                textAlign: currentStyle.textAlign,
                style: baseStyle.copyWith(
                  color: verseIsPlaceholder
                      ? currentFontColor.withValues(alpha: 0.6)
                      : currentFontColor,
                  fontSize: effectiveFontSize / 2,
                  height: currentStyle.lineHeight,
                  letterSpacing: currentStyle.letterSpacing != 0.0
                      ? currentStyle.letterSpacing
                      : null,
                  fontWeight: verseIsPlaceholder
                      ? FontWeight.w500
                      : (currentStyle.isBold
                            ? FontWeight.bold
                            : FontWeight.w400),
                  fontStyle: (verseIsPlaceholder || currentStyle.isItalic)
                      ? FontStyle.italic
                      : FontStyle.normal,
                  shadows: currentStyle.shadow.verseShadowsFor(
                    currentFontColor,
                  ),
                ),
              ),
              if (currentStyle.accent == VerseCardAccent.divider)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: (effectiveFontSize * 0.18).clamp(6.0, 12.0),
                  ),
                  child: Container(
                    width: 44,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: currentFontColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: (effectiveFontSize * 0.35).clamp(12.0, 24.0),
                ),
              Text(
                displayRef,
                textAlign: currentStyle.textAlign,
                style: baseStyle.copyWith(
                  color: refIsPlaceholder
                      ? currentFontColor.withValues(alpha: 0.6)
                      : currentFontColor,
                  fontSize: (effectiveFontSize * 0.66) / 2,
                  letterSpacing: 0.4,
                  fontWeight: currentStyle.isBold
                      ? FontWeight.w600
                      : FontWeight.w400,
                  fontStyle: (refIsPlaceholder || currentStyle.isItalic)
                      ? FontStyle.italic
                      : FontStyle.normal,
                  shadows: currentStyle.shadow.referenceShadowsFor(
                    currentFontColor,
                  ),
                ),
              ),
            ],
          ),
        );

        final bool darkText = currentFontColor.computeLuminance() < 0.4;
        Widget styledTextBlock = textColumn;
        if (currentStyle.backdrop == VerseTextBackdrop.frosted) {
          styledTextBlock = ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 12.0,
                ),
                decoration: BoxDecoration(
                  color: darkText
                      ? Colors.white.withValues(alpha: 0.72)
                      : Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: darkText
                        ? Colors.black.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.22),
                    width: 1.0,
                  ),
                ),
                child: textColumn,
              ),
            ),
          );
        } else if (currentStyle.backdrop == VerseTextBackdrop.solid) {
          styledTextBlock = Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: darkText
                  ? Colors.white.withValues(alpha: 0.90)
                  : Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: darkText
                    ? Colors.black.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.18),
                width: 1.0,
              ),
            ),
            child: textColumn,
          );
        }

        final Widget paddedBlock = Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: 16.0,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: styledTextBlock,
          ),
        );

        return currentStyle.backdrop == VerseTextBackdrop.frosted
            ? paddedBlock
            : RepaintBoundary(child: paddedBlock);
      },
    );

    final Widget textOverlay = Align(
      alignment: Alignment.center,
      child: widget.yOffsetListenable != null
          ? ValueListenableBuilder<double>(
              valueListenable: widget.yOffsetListenable!,
              builder: (context, currentYOffset, child) => Transform.translate(
                offset: Offset(0, currentYOffset),
                child: child,
              ),
              child: textContent,
            )
          : Transform.translate(
              offset: Offset(0, widget.yOffset),
              child: textContent,
            ),
    );

    final Widget frameOverlay = AnimatedBuilder(
      animation: _textAnimation,
      builder: (context, _) {
        final VerseTextStyleOptions currentStyle =
            widget.textStyleListenable?.value ?? widget.textStyleOptions;
        if (currentStyle.accent != VerseCardAccent.frame) {
          return const SizedBox.shrink();
        }
        final Color currentFontColor =
            widget.fontColorListenable?.value ?? widget.fontColor;
        return IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: currentFontColor.withValues(alpha: 0.45),
                  width: 1.25,
                ),
              ),
            ),
          ),
        );
      },
    );

    final Widget card = RepaintBoundary(
      key: widget.repaintKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              backgroundImage,
              dimOverlay,
              frameOverlay,
              textOverlay,
            ],
          ),
        ),
      ),
    );

    final Widget responsiveCard = FittedBox(
      fit: BoxFit.contain,
      child: card,
    );

    final Widget interactiveCard = widget.onYOffsetChanged == null
        ? responsiveCard
        : GestureDetector(
            onDoubleTap: () {
              HapticFeedback.lightImpact();
              widget.onYOffsetChanged!(0.0);
            },
            onVerticalDragUpdate: (details) {
              final double baseOffset =
                  widget.yOffsetListenable?.value ?? widget.yOffset;
              final double rawUpdated =
                  (baseOffset + details.delta.dy * 1.5).clamp(-400.0, 400.0);
              final bool crossedCenter =
                  (baseOffset < 0 && rawUpdated >= 0) ||
                  (baseOffset > 0 && rawUpdated <= 0);
              final double updated =
                  (crossedCenter || rawUpdated.abs() < 3.0) && baseOffset != 0.0
                      ? 0.0
                      : rawUpdated;
              if ((updated == 0.0 && baseOffset != 0.0) ||
                  (baseOffset > -400.0 && updated == -400.0) ||
                  (baseOffset < 400.0 && updated == 400.0)) {
                HapticFeedback.selectionClick();
              }
              widget.onYOffsetChanged!(updated);
            },
            child: responsiveCard,
          );

    final String resetHint = widget.generator.getLocaleString(
      widget.lang,
      "reset_position_btn",
    );

    return AnimatedBuilder(
      animation: widget.previewListenable,
      builder: (context, child) {
        final String trimmedVerse = widget.verseController.text.trim();
        final String trimmedRef = widget.referenceController.text.trim();
        final String verseText =
            trimmedVerse.isEmpty ? versePlaceholder : trimmedVerse;
        final String refText =
            trimmedRef.isEmpty ? refPlaceholder : trimmedRef;
        final double activeYOffset =
            widget.yOffsetListenable?.value ?? widget.yOffset;
        final bool canResetOffset =
            widget.onYOffsetChanged != null && activeYOffset != 0.0;
        return Semantics(
          container: true,
          image: true,
          excludeSemantics: true,
          onTap: canResetOffset
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onYOffsetChanged!(0.0);
                }
              : null,
          onTapHint: canResetOffset && resetHint.isNotEmpty
              ? resetHint
              : null,
          label: "$semanticHeader: \"$verseText\" — $refText",
          child: child,
        );
      },
      child: interactiveCard,
    );
  }
}
