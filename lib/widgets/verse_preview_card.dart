import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../generator.dart';

class VersePreviewCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    double width = 300;
    double height = 300;
    if (aspectRatioStr == "3:4") {
      width = 300;
      height = 400;
    } else if (aspectRatioStr == "9:16") {
      width = 225;
      height = 400;
    } else if (aspectRatioStr == "4:3") {
      width = 400;
      height = 300;
    }

    // ⚡ Bolt: Isolate static background image from 60Hz drag/slider layers so
    // dragging text or adjusting dim/font size never rebuilds the image provider.
    final Widget backgroundImage = RepaintBoundary(
      child: Image(
        image: ResizeImage.resizeIfNeeded(
          1080,
          null,
          customImagePath != null
              ? FileImage(File(customImagePath!)) as ImageProvider
              : AssetImage("assets/backgrounds/$selectedBackground"),
        ),
        fit: BoxFit.cover,
        width: width,
        height: height,
      ),
    );

    final Widget dimOverlay = backgroundDimListenable != null
        ? ValueListenableBuilder<double>(
            valueListenable: backgroundDimListenable!,
            builder: (context, dim, _) => ColoredBox(
              color: Colors.black.withAlpha((dim.clamp(0.0, 0.85) * 255).round()),
            ),
          )
        : ColoredBox(
            color: Colors.black.withAlpha(
              (backgroundDim.clamp(0.0, 0.85) * 255).round(),
            ),
          );

    final Listenable textAnimation = Listenable.merge([
      previewListenable,
      ?fontSizeListenable,
      ?yOffsetListenable,
    ]);

    final Widget textOverlay = AnimatedBuilder(
      animation: textAnimation,
      builder: (context, child) {
        final double currentFontSize = fontSizeListenable?.value ?? fontSize;
        final double currentYOffset = yOffsetListenable?.value ?? yOffset;
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
                        verseController.text.isEmpty
                            ? generator.getLocaleString(
                                lang,
                                "preview_verse_placeholder",
                              )
                            : verseController.text,
                        textAlign: TextAlign.center,
                        style: _baseRobotoStyle.copyWith(
                          color: fontColor,
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
                        referenceController.text.isEmpty
                            ? generator.getLocaleString(
                                lang,
                                "reference_placeholder",
                              )
                            : referenceController.text,
                        textAlign: TextAlign.center,
                        style: _baseRobotoStyle.copyWith(
                          color: fontColor,
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
      key: repaintKey,
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

    final Widget interactiveCard = onYOffsetChanged == null
        ? responsiveCard
        : GestureDetector(
            onVerticalDragUpdate: (details) {
              final double baseOffset = yOffsetListenable?.value ?? yOffset;
              final double updated = (baseOffset + details.delta.dy * 1.5)
                  .clamp(-400.0, 400.0);
              onYOffsetChanged!(updated);
            },
            child: responsiveCard,
          );

    return AnimatedBuilder(
      animation: previewListenable,
      builder: (context, child) {
        final String verseText = verseController.text.trim().isEmpty
            ? generator.getLocaleString(lang, "preview_verse_placeholder")
            : verseController.text.trim();
        final String refText = referenceController.text.trim().isEmpty
            ? generator.getLocaleString(lang, "reference_placeholder")
            : referenceController.text.trim();
        final String rawHeader = generator.getLocaleString(
          lang,
          "preview_semantic_label",
        );
        final String header =
            (rawHeader.isEmpty || rawHeader == "preview_semantic_label"
                    ? "Verse card preview ({ratio})"
                    : rawHeader)
                .replaceAll("{ratio}", aspectRatioStr);
        return Semantics(
          container: true,
          image: true,
          excludeSemantics: true,
          label: "$header: \"$verseText\" — $refText",
          child: child,
        );
      },
      child: interactiveCard,
    );
  }
}
