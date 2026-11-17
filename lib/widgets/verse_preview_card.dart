import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../generator.dart';

class VersePreviewCard extends StatefulWidget {
  // ⚡ Bolt: Cache base GoogleFonts TextStyle instead of calling GoogleFonts.roboto() on every frame
  static final TextStyle _baseRobotoStyle = GoogleFonts.roboto();

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
  final ValueListenable<double>? fontSizeListenable;
  final ValueListenable<double>? yOffsetListenable;
  final ValueListenable<double>? backgroundDimListenable;
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
    this.fontSizeListenable,
    this.yOffsetListenable,
    this.backgroundDimListenable,
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
    ?widget.fontSizeListenable,
    ?widget.yOffsetListenable,
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
        oldWidget.fontSizeListenable != widget.fontSizeListenable ||
        oldWidget.yOffsetListenable != widget.yOffsetListenable) {
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

    // ⚡ Bolt: Isolate static background image from 60Hz drag/slider layers so
    // dragging text or adjusting dim/font size never rebuilds the image provider.
    final Widget backgroundImage = RepaintBoundary(
      child: Image(
        image: ResizeImage.resizeIfNeeded(
          1080,
          null,
          widget.customImagePath != null
              ? FileImage(File(widget.customImagePath!)) as ImageProvider
              : AssetImage("assets/backgrounds/${widget.selectedBackground}"),
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

    final Widget textOverlay = AnimatedBuilder(
      animation: _textAnimation,
      builder: (context, child) {
        final double currentFontSize =
            widget.fontSizeListenable?.value ?? widget.fontSize;
        final double currentYOffset =
            widget.yOffsetListenable?.value ?? widget.yOffset;
        final String verseText = widget.verseController.text;
        final String refText = widget.referenceController.text;
        return Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, currentYOffset),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: width - 40.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        verseText.isEmpty ? versePlaceholder : verseText,
                        textAlign: TextAlign.center,
                        style: VersePreviewCard._baseRobotoStyle.copyWith(
                          color: widget.fontColor,
                          fontSize: currentFontSize / 2,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: (currentFontSize * 0.35).clamp(12.0, 24.0),
                      ),
                      Text(
                        refText.isEmpty ? refPlaceholder : refText,
                        textAlign: TextAlign.center,
                        style: VersePreviewCard._baseRobotoStyle.copyWith(
                          color: widget.fontColor,
                          fontSize: (currentFontSize * 0.66) / 2,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
              final double updated = (baseOffset + details.delta.dy * 1.5)
                  .clamp(-400.0, 400.0);
              widget.onYOffsetChanged!(updated);
            },
            child: responsiveCard,
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
        return Semantics(
          container: true,
          image: true,
          excludeSemantics: true,
          label: "$semanticHeader: \"$verseText\" — $refText",
          child: child,
        );
      },
      child: interactiveCard,
    );
  }
}
