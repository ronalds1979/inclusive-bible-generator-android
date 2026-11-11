import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../generator.dart';

class VersePreviewCard extends StatelessWidget {
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
    required this.lang,
    required this.generator,
  });

  @override
  Widget build(BuildContext context) {
    double width = 300;
    double height = 300;
    if (aspectRatioStr == "3:4") {
      height = 400;
    } else if (aspectRatioStr == "4:3") {
      width = 400;
      height = 300;
    }

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: customImagePath != null
                ? FileImage(File(customImagePath!)) as ImageProvider
                : AssetImage("assets/backgrounds/$selectedBackground"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(128),
              BlendMode.darken,
            ),
          ),
        ),
        child: AnimatedBuilder(
          animation: previewListenable,
          builder: (context, child) {
            return Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Transform.translate(
                      offset: Offset(0, yOffset - 20),
                      child: Text(
                        verseController.text.isEmpty
                            ? generator.getLocaleString(
                                lang,
                                "preview_verse_placeholder",
                              )
                            : verseController.text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(
                          color: fontColor,
                          fontSize: fontSize / 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: Offset(0, yOffset + (fontSize / 2) + 40),
                    child: Text(
                      referenceController.text.isEmpty
                          ? generator.getLocaleString(
                              lang,
                              "reference_placeholder",
                            )
                          : referenceController.text,
                      style: GoogleFonts.roboto(
                        color: fontColor,
                        fontSize: (fontSize * 0.66) / 2,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
